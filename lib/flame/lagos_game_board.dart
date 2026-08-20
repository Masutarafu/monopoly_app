import 'dart:async';
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';
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
class LagosGameBoard extends FlameGame
    with PanDetector, ScaleDetector, ScrollDetector {
  final void Function(int tileIndex, List<Tile> board) onTileTapped;
  final void Function() onRollAnimationComplete;
  final Stream<GameState> gameStateStream;

  StreamSubscription<GameState>? _stateSub;
  GameState? _lastState;
  BoardLayout? _layout;
  bool _boardBuilt = false;
  bool _animating  = false;

  // ── Zoom / pan state ────────────────────────────────────────────────────
  static const double _minZoom = 0.5;
  static const double _maxZoom = 5.0;

  double _zoom = 1.0;
  Vector2 _pan = Vector2.zero();
  double _gestureStartZoom = 1.0;

  /// Notifies the Flutter zoom-controls overlay whenever the zoom level
  /// changes.
  final ValueNotifier<double> zoomLevelNotifier = ValueNotifier<double>(1.0);

  // Last board size used for a rebuild. GameWidget calls onGameResize on
  // EVERY build (not just size changes), so this guards against rebuilding
  // the whole board — and destroying in-flight animations — pointlessly.
  double? _lastBoardSize;

  // Set when a rebuild tears down an in-flight animation; consumed by
  // update() so the controller gate is released from the game loop, never
  // from the widget build/layout phase (mutating Riverpod state there throws).
  bool _releaseGate = false;

  final Map<String, TokenComponent> _tokens = {};
  final Map<int, TileComponent>     _tiles  = {};
  DiceComponent? _diceComponent;

  // A state that arrived while an animation was playing; deferred until the
  // in-flight animation completes so no move is ever skipped.
  GameState? _pendingState;
  GameState? _pendingPrev;

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
  // onGameResize — rebuild only when the board size actually changed.
  // =========================================================================
  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    if (!_boardBuilt || _lastState == null) return;
    final boardSize = canvasSize.x < canvasSize.y ? canvasSize.x : canvasSize.y;
    if (_lastBoardSize != boardSize) {
      _buildBoard(_lastState!);
      _clampAndApply();
    }
  }

  // =========================================================================
  // update — flush any deferred controller-gate releases from the game loop.
  // =========================================================================
  @override
  void update(double dt) {
    super.update(dt);
    if (_releaseGate) {
      _releaseGate = false;
      onRollAnimationComplete();
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
      _tiles[i]?.tile = newState.board[i];
    }

    // Spawn tokens for any new players
    for (final player in newState.players) {
      if (!_tokens.containsKey(player.id)) {
        _spawnToken(player);
      }
    }

    if (_animating) {
      // An animation is already in flight — defer this state instead of
      // dropping it (identical consecutive rolls would otherwise never move
      // the token, and queued rolls would be lost).
      _pendingState = newState;
      _pendingPrev = prev;
      return;
    }

    _tryStartAnimation(newState, prev);
  }

  // =========================================================================
  // _tryStartAnimation — starts the dice tumble (a roll was initiated) or
  // the token slide (a player's position changed). Every animation ends by
  // unblocking the controller via onRollAnimationComplete() so turn-state
  // transitions always wait for the visuals to finish.
  // =========================================================================
  void _tryStartAnimation(GameState newState, GameState? prev) {
    if (newState.phase == GamePhase.animating) {
      final dice = _diceComponent;
      if (dice == null) {
        // No dice on screen — release the controller from the game loop.
        _releaseGate = true;
        return;
      }
      _animating = true;
      dice.roll(
        die1: newState.lastDie1,
        die2: newState.lastDie2,
        onComplete: () {
          _animating = false;
          // Release the controller: it resolves the landing, which emits the
          // moved state that drives the token slide.
          onRollAnimationComplete();
          _processPending();
        },
      );
      return;
    }

    if (_findMovedPlayer(prev, newState) != null) {
      _animateTokenMovement(newState, prev);
    }
  }

  // =========================================================================
  // _processPending — drains any state that arrived mid-animation.
  // =========================================================================
  void _processPending() {
    if (_animating) return;
    final pending = _pendingState;
    if (pending == null) return;
    final prev = _pendingPrev;
    _pendingState = null;
    _pendingPrev = null;
    _tryStartAnimation(pending, prev);
  }

  // =========================================================================
  // Zoom / pan
  // =========================================================================
  // The viewfinder is anchored top-left, so with zoom z the visible world
  // rect is [position, position + canvasSize / z]. Panning moves the
  // position; zooming keeps the world point under a focal screen point fixed
  // so the gesture zooms exactly where the pointer (or pinch) is aimed.
  // =========================================================================

  void zoomIn()  => _setZoom(_zoom * 1.3);
  void zoomOut() => _setZoom(_zoom / 1.3);
  void resetView() => _setZoom(1.0);

  void _setZoom(double newZoom, {Vector2? focalScreen}) {
    final clamped = newZoom.clamp(_minZoom, _maxZoom).toDouble();
    if (clamped == _zoom) return;

    final f = focalScreen ?? Vector2(canvasSize.x / 2, canvasSize.y / 2);

    // World point currently under the focal screen point…
    final wx = f.x / _zoom + _pan.x;
    final wy = f.y / _zoom + _pan.y;

    _zoom = clamped;
    zoomLevelNotifier.value = _zoom;

    // …must stay under the focal point after the zoom.
    _pan = Vector2(wx - f.x / _zoom, wy - f.y / _zoom);
    _clampAndApply();
  }

  // Keeps the board inside the visible area: centered when the whole board
  // fits, clamped to the board bounds when zoomed in.
  void _clampAndApply() {
    final layout = _layout;
    if (layout == null) return;

    final bsz  = layout.boardSize;
    final ox   = (canvasSize.x - bsz) / 2;
    final oy   = (canvasSize.y - bsz) / 2;
    final visW = canvasSize.x / _zoom;
    final visH = canvasSize.y / _zoom;

    final px = visW >= bsz
        ? ox + (bsz - visW) / 2
        : _pan.x.clamp(ox + bsz - visW, ox).toDouble();
    final py = visH >= bsz
        ? oy + (bsz - visH) / 2
        : _pan.y.clamp(oy + bsz - visH, oy).toDouble();

    _pan = Vector2(px, py);
    camera.viewfinder.position = _pan;
    camera.viewfinder.zoom     = _zoom;
  }

  // ── Drag to pan ─────────────────────────────────────────────────────────
  @override
  void onPanUpdate(DragUpdateInfo info) {
    _pan = _pan - (info.delta.global / _zoom);
    _clampAndApply();
  }

  // ── Pinch to zoom ───────────────────────────────────────────────────────
  @override
  void onScaleStart(ScaleStartInfo info) {
    _gestureStartZoom = _zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    // info.scale is relative to the start of the gesture.
    _setZoom(_gestureStartZoom * info.scale.global.x,
        focalScreen: info.eventPosition.widget);
  }

  // ── Mouse wheel zoom ────────────────────────────────────────────────────
  @override
  void onScroll(PointerScrollInfo info) {
    final dy = info.scrollDelta.global.y;
    if (dy == 0) return;
    _setZoom(
      _zoom * (dy < 0 ? 1.15 : 1 / 1.15),
      focalScreen: info.eventPosition.widget,
    );
  }

  // Returns the first player whose position changed between prev and next.
  Player? _findMovedPlayer(GameState? prev, GameState next) {
    if (prev == null) return null;
    for (final player in next.players) {
      final prevPlayer = prev.players
          .firstWhere((p) => p.id == player.id, orElse: () => player);
      if (prevPlayer.position != player.position) return player;
    }
    return null;
  }

  // =========================================================================
  // _buildBoard — full rebuild (first load or resize)
  // =========================================================================
  void _buildBoard(GameState state) {
    // A rebuild tears down any in-flight animation (its completion callback
    // is lost with the component), so remember that the controller gate is
    // still engaged and must be released after the rebuild.
    final wasBusy = _animating || _pendingState != null;

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

    _lastBoardSize = boardSize;

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

    // Re-constrain the zoom/pan view to the new board geometry.
    _clampAndApply();

    // Nothing is animating after a rebuild — tokens were placed at their
    // model positions. If the controller gate was engaged, release it — but
    // from the game loop, never synchronously here (this runs inside the
    // widget build/layout phase, where mutating Riverpod state throws).
    _animating = false;
    _pendingState = null;
    _pendingPrev = null;
    if (wasBusy) {
      _releaseGate = true;
    }
  }

  // =========================================================================
  // _spawnToken — creates a token for a player and places it on its tile at
  // the correct stacked offset.
  // =========================================================================
  void _spawnToken(Player player, {double ox = 0, double oy = 0}) {
    if (_layout == null || _lastState == null) return;
    final token = TokenComponent(player: player, layout: _layout!);
    _tokens[player.id] = token;
    world.add(token);
    // Recompute the slots of every token — the newcomer may share a tile
    // with tokens that are already placed.
    _syncAllTokenSlots(ox: ox, oy: oy);
  }

  // =========================================================================
  // Token stacking helpers
  // =========================================================================
  // Players that share a tile are ordered by their position in state.players
  // (stable across emissions — the controller never reorders the list), so
  // each token gets a deterministic slot within its tile. The tile's
  // tokenOffset() then spreads the slots into a micro-grid, so no two tokens
  // overlap completely even when several players stand on the same tile.
  // =========================================================================

  (int, int) _slotFor(Player player, GameState state) {
    final group =
        state.players.where((p) => p.position == player.position).toList();
    final slotIndex = group.indexWhere((p) => p.id == player.id);
    return (slotIndex < 0 ? 0 : slotIndex, group.length);
  }

  Vector2 _tokenTarget(Player player, GameState state, double ox, double oy) {
    final (slotIndex, slotCount) = _slotFor(player, state);
    final center = _layout!.tileCenter(player.position);
    final offset = _layout!.tokenOffset(player.position, slotIndex, slotCount);
    return Vector2(
      center.dx + offset.dx + ox,
      center.dy + offset.dy + oy,
    );
  }

  // Instantly repositions every token to its correct stacked slot.
  void _syncAllTokenSlots({required double ox, required double oy}) {
    final state = _lastState;
    if (state == null || _layout == null) return;
    for (final player in state.players) {
      final token = _tokens[player.id];
      if (token == null) continue;
      final (slotIndex, slotCount) = _slotFor(player, state);
      token.setSlot(slotIndex, slotCount);
      token.position = _tokenTarget(player, state, ox, oy);
    }
  }

  // =========================================================================
  // _animateTokenMovement — slides the moved player's token to its new tile
  // while every token whose stacking slot shifted (tokens sharing the
  // mover's destination) is repositioned instantly.
  // =========================================================================
  void _animateTokenMovement(GameState newState, GameState? prev) {
    final cv        = canvasSize;
    final boardSize = cv.x < cv.y ? cv.x : cv.y;
    final ox        = (cv.x - boardSize) / 2;
    final oy        = (cv.y - boardSize) / 2;

    final movedPlayer = _findMovedPlayer(prev, newState);
    if (movedPlayer == null) {
      _animating = false;
      onRollAnimationComplete();
      _processPending();
      return;
    }

    final token = _tokens[movedPlayer.id];
    if (token == null) {
      _animating = false;
      onRollAnimationComplete();
      _processPending();
      return;
    }

    // Instantly shift every token except the mover to its new stacked slot.
    for (final player in newState.players) {
      if (player.id == movedPlayer.id) continue;
      final other = _tokens[player.id];
      if (other == null) continue;
      final (slotIndex, slotCount) = _slotFor(player, newState);
      other.setSlot(slotIndex, slotCount);
      other.position = _tokenTarget(player, newState, ox, oy);
    }

    // The mover keeps its slide animation to its final stacked position.
    final (slotIndex, slotCount) = _slotFor(movedPlayer, newState);
    token.setSlot(slotIndex, slotCount);

    _animating = true;
    token.moveToPosition(
      _tokenTarget(movedPlayer, newState, ox, oy),
      onComplete: () {
        _animating = false;
        onRollAnimationComplete();
        _processPending();
      },
    );
  }

  @override
  void onRemove() {
    _stateSub?.cancel();
    zoomLevelNotifier.dispose();
    super.onRemove();
  }
}
