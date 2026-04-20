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
// The Flame entry point. It:
//   1. Builds 40 TileComponents from the initial board state
//   2. Builds one TokenComponent per player
//   3. Builds a DiceComponent
//   4. Listens to a Stream<GameState> (from gameBridgeProvider) and updates
//      components whenever state changes
//   5. Fires Flutter callbacks (onTileTapped, onMoveComplete, onRollComplete)
//      so the Flame layer never needs to know about Riverpod
//
// The game board occupies the full canvas. Dice sit in the center overlay.
// ---------------------------------------------------------------------------
class LagosGameBoard extends FlameGame {
  // ── Callbacks into Flutter ───────────────────────────────────────────────
  final void Function(int tileIndex, List<Tile> board) onTileTapped;
  final void Function() onRollAnimationComplete;

  // ── Stream from Riverpod ─────────────────────────────────────────────────
  final Stream<GameState> gameStateStream;
  StreamSubscription<GameState>? _stateSub;

  // ── Internal state ───────────────────────────────────────────────────────
  GameState? _lastState;
  BoardLayout? _layout;

  // Component maps — keyed by player id / tile index
  final Map<String, TokenComponent> _tokens   = {};
  final Map<int, TileComponent>     _tiles    = {};
  DiceComponent? _diceComponent;

  // Pending movement queue — prevents overlapping animations
  bool _animating = false;

  LagosGameBoard({
    required this.gameStateStream,
    required this.onTileTapped,
    required this.onRollAnimationComplete,
  });

  // =========================================================================
  // onLoad — build all initial components
  // =========================================================================
  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Disable default Flame background color
    camera.backdrop.add(
      RectangleComponent(
        size: Vector2.all(10000),
        paint: ui.Paint()..color = const ui.Color(0xFF0D1A0D),
      ),
    );

    // Subscribe to state stream
    _stateSub = gameStateStream.listen(_onStateChanged);
  }

  // =========================================================================
  // onGameResize — rebuild layout when canvas size changes
  // =========================================================================
  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    _rebuildBoard(canvasSize);
  }

  void _rebuildBoard(Vector2 canvasSize) {
    final boardSize = canvasSize.x < canvasSize.y
        ? canvasSize.x
        : canvasSize.y;

    _layout = BoardLayout(boardSize);

    // Rebuild tile components
    for (final tc in _tiles.values) tc.removeFromParent();
    _tiles.clear();

    final board = _lastState?.board;
    if (board == null) return;

    for (int i = 0; i < 40; i++) {
      final tc = TileComponent(
        tile: board[i],
        index: i,
        layout: _layout!,
        onTileTapped: (idx) => onTileTapped(idx, board),
      );
      _tiles[i] = tc;
      world.add(tc);
    }

    // Rebuild token components
    for (final token in _tokens.values) token.removeFromParent();
    _tokens.clear();

    final players = _lastState?.players ?? [];
    for (final player in players) {
      _buildToken(player);
    }

    // Dice — centered on board
    _diceComponent?.removeFromParent();
    final diceW = boardSize * 0.28;
    final diceH = boardSize * 0.14;
    _diceComponent = DiceComponent(
      position: Vector2(
        (canvasSize.x - diceW) / 2,
        (canvasSize.y - diceH) / 2,
      ),
      size: Vector2(diceW, diceH),
    );
    world.add(_diceComponent!);
  }

  void _buildToken(Player player) {
    if (_layout == null) return;
    final token = TokenComponent(
      player: player,
      layout: _layout!,
      startIndex: player.position,
    );
    _tokens[player.id] = token;
    world.add(token);
  }

  // =========================================================================
  // _onStateChanged — called every time Riverpod emits a new GameState
  // =========================================================================
  void _onStateChanged(GameState newState) {
    final prev = _lastState;
    _lastState = newState;

    if (_layout == null) return;

    // ── Sync tile ownership visuals ────────────────────────────────────────
    for (int i = 0; i < newState.board.length; i++) {
      _tiles[i]?.tile.owner = newState.board[i].owner;
    }

    // ── Add tokens for new players (lobby → board transition) ─────────────
    for (final player in newState.players) {
      if (!_tokens.containsKey(player.id)) {
        _buildToken(player);
      }
    }

    // ── Detect dice roll — trigger dice animation ──────────────────────────
    final diceChanged = prev == null ||
        newState.lastDie1 != prev.lastDie1 ||
        newState.lastDie2 != prev.lastDie2;

    if (diceChanged && newState.lastDie1 > 0 && !_animating) {
      _animating = true;
      _diceComponent?.roll(
        die1: newState.lastDie1,
        die2: newState.lastDie2,
        onComplete: () {
          // ── After dice settle, move the token ───────────────────────────
          _animateTokenMovement(newState, prev);
        },
      );
    }
  }

  // =========================================================================
  // _animateTokenMovement — slide the current player's token
  // =========================================================================
  void _animateTokenMovement(GameState newState, GameState? prev) {
    // Find which player moved (their position changed)
    Player? movedPlayer;
    for (final player in newState.players) {
      final prevPlayer = prev?.players.firstWhere(
        (p) => p.id == player.id,
        orElse: () => player,
      );
      if (prevPlayer?.position != player.position) {
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

    token.moveTo(movedPlayer.position, onComplete: () {
      _animating = false;
      onRollAnimationComplete();
    });
  }

  // =========================================================================
  // dispose
  // =========================================================================
  @override
  void onRemove() {
    _stateSub?.cancel();
    super.onRemove();
  }
}
