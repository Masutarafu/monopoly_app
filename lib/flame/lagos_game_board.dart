import 'dart:async';
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/tile.dart';
import 'board_layout.dart';
import 'tile_component.dart';
import 'token_component.dart';
import 'dice_component.dart';

// ---------------------------------------------------------------------------
// LagosGameBoard — FlameGame
// ---------------------------------------------------------------------------
// Three fixes vs the previous version:
//
// 1. CENTERING: Board is offset by (canvas - boardSize) / 2 on both axes
//    so it sits in the middle of the GameWidget, not at (0,0).
//
// 2. FIRST BUILD: Board is built on the first stream emission, not in
//    onGameResize. This guarantees _lastState is populated with real tile
//    and player data before we try to construct components.
//
// 3. DICE ON HUD: DiceComponent is added to camera.viewport (the HUD layer)
//    instead of world. HUD components render at fixed screen coordinates,
//    so the dice are always centered and visible.
// ---------------------------------------------------------------------------
class LagosGameBoard extends FlameGame {
  final void Function(int tileIndex, List<Tile> board) onTileTapped;
  final void Function() onRollAnimationComplete;
  final Stream<GameState> gameStateStream;

  StreamSubscription<GameState>? _stateSub;
  GameState? _lastState;
  BoardLayout? _layout;
  bool _boardBuilt = false;
  bool _animating  = false;

  final Map<String, TokenComponent> _tokens = {};
  final Map<int, TileComponent>     _tiles  = {};
  DiceComponent? _diceComponent;

  LagosGameBoard({
    required this.gameStateStream,
    required this.onTileTapped,
    required this.onRollAnimationComplete,
  });

  // =========================================================================
  // onLoad
  // =========================================================================
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Keep (0,0) at top-left so world coords match screen coords directly
    camera.viewfinder.anchor = Anchor.topLeft;

    // Dark background
    camera.backdrop.add(
      RectangleComponent(
        size: Vector2(10000, 10000),
        paint: ui.Paint()..color = const ui.Color(0xFF0D1A0D),
      ),
    );

    _stateSub = gameStateStream.listen(_onStateChanged);
  }

  // =========================================================================
  // onGameResize — rebuild if canvas dimensions change after first build
  // =========================================================================
  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    if (_boardBuilt && _lastState != null) {
      _buildBoard(_lastState!);
    }
  }

  // =========================================================================
  // _onStateChanged
  // =========================================================================
  void _onStateChanged(GameState newState) {
    final prev = _lastState;
    _lastState = newState;

    if (!_boardBuilt) {
      _buildBoard(newState);
      _boardBuilt = true;
      return;
    }

    if (_layout == null) return;

    // Sync ownership indicators on tiles
    for (int i = 0; i < newState.board.length; i++) {
      _tiles[i]?.tile.owner = newState.board[i].owner;
    }

    // Spawn tokens for any new players
    for (final player in newState.players) {
      if (!_tokens.containsKey(player.id)) {
        _spawnToken(player);
      }
    }

    // Detect new roll and trigger animation sequence
    final diceChanged = prev != null &&
        newState.lastDie1 > 0 &&
        (newState.lastDie1 != prev.lastDie1 ||
         newState.lastDie2 != prev.lastDie2);

    if (diceChanged && !_animating) {
      _animating = true;
      _diceComponent?.roll(
        die1: newState.lastDie1,
        die2: newState.lastDie2,
        onComplete: () => _animateTokenMovement(newState, prev),
      );
    }
  }

  // =========================================================================
  // _buildBoard — full rebuild (first load or resize)
  // =========================================================================
  void _buildBoard(GameState state) {
    // Tear down previous components
    for (final t in _tiles.values)  t.removeFromParent();
    for (final t in _tokens.values) t.removeFromParent();
    _diceComponent?.removeFromParent();
    _tiles.clear();
    _tokens.clear();

    final cv        = canvasSize;
    final boardSize = cv.x < cv.y ? cv.x : cv.y;
    final ox        = (cv.x - boardSize) / 2; // centering offset X
    final oy        = (cv.y - boardSize) / 2; // centering offset Y

    _layout = BoardLayout(boardSize);

    // ── 40 tile components ────────────────────────────────────────────────
    for (int i = 0; i < 40; i++) {
      final r  = _layout!.tileRect(i);
      final tc = TileComponent(
        tile: state.board[i],
        index: i,
        layout: _layout!,
        onTileTapped: (idx) => onTileTapped(idx, state.board),
      );
      tc.position = Vector2(r.left + ox, r.top + oy);
      tc.size     = Vector2(r.width, r.height);
      _tiles[i] = tc;
      world.add(tc);
    }

    // ── Token components ──────────────────────────────────────────────────
    for (final player in state.players) {
      _spawnToken(player, ox: ox, oy: oy);
    }

    // ── Dice on HUD (camera.viewport) — always visible, fixed position ────
    final diceW = boardSize * 0.26;
    final diceH = boardSize * 0.13;
    _diceComponent = DiceComponent(
      position: Vector2((cv.x - diceW) / 2, (cv.y - diceH) / 2),
      size:     Vector2(diceW, diceH),
    );
    camera.viewport.add(_diceComponent!);
  }

  // =========================================================================
  // _spawnToken
  // =========================================================================
  void _spawnToken(Player player, {double ox = 0, double oy = 0}) {
    if (_layout == null) return;
    final center = _layout!.tileCenter(player.position);
    final token  = TokenComponent(
      player:     player,
      layout:     _layout!,
      startIndex: player.position,
    );
    token.position = Vector2(center.dx + ox, center.dy + oy);
    _tokens[player.id] = token;
    world.add(token);
  }

  // =========================================================================
  // _animateTokenMovement — called after dice animation completes
  // =========================================================================
  void _animateTokenMovement(GameState newState, GameState? prev) {
    final cv        = canvasSize;
    final boardSize = cv.x < cv.y ? cv.x : cv.y;
    final ox        = (cv.x - boardSize) / 2;
    final oy        = (cv.y - boardSize) / 2;

    Player? movedPlayer;
    for (final player in newState.players) {
      final prevPos = prev?.players
          .firstWhere((p) => p.id == player.id, orElse: () => player)
          .position;
      if (prevPos != player.position) {
        movedPlayer = player;
        break;
      }
    }

    if (movedPlayer == null) {
      _animating = false;
      onRollAnimationComplete();
      return;
    }

    final token = _tokens[movedPlayer.id];
    if (token == null) {
      _animating = false;
      onRollAnimationComplete();
      return;
    }

    final destCenter = _layout!.tileCenter(movedPlayer.position);
    token.moveToPosition(
      Vector2(destCenter.dx + ox, destCenter.dy + oy),
      onComplete: () {
        _animating = false;
        onRollAnimationComplete();
      },
    );
  }

  @override
  void onRemove() {
    _stateSub?.cancel();
    super.onRemove();
  }
}
