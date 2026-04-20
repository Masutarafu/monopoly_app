import 'dart:ui' as ui;
import 'dart:collection';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';   // Curve
import 'package:flutter/foundation.dart';  // VoidCallback
import '../models/player.dart';
import 'board_layout.dart';

// ---------------------------------------------------------------------------
// TokenComponent
// ---------------------------------------------------------------------------
// A colored circle representing one player on the Flame board.
//
// moveToPosition(Vector2 dest) slides the token from its current world
// position to dest, leaving a fading trail of ghost circles behind it.
//
// Trail: every update() frame while moving, the token's current position
// is pushed into a fixed-length Queue. Each ghost is rendered with
// decreasing opacity and size (oldest = most transparent + smallest).
// ---------------------------------------------------------------------------
class TokenComponent extends PositionComponent {
  final Player player;
  final BoardLayout layout;

  final Queue<Vector2> _trail = Queue();
  static const int _trailLength = 20;

  late final ui.Paint _tokenPaint;
  late final ui.Paint _borderPaint;
  late final ui.Paint _shadowPaint;

  bool _isMoving = false;

  TokenComponent({
    required this.player,
    required this.layout,
    required int startIndex,
  }) {
    anchor = Anchor.center;
    size   = Vector2.all(_radius * 2);

    _tokenPaint  = ui.Paint()..color = player.tokenColor;
    _borderPaint = ui.Paint()
      ..color      = const ui.Color(0xFFFFFFFF)
      ..strokeWidth = 1.5
      ..style      = ui.PaintingStyle.stroke;
    _shadowPaint = ui.Paint()
      ..color     = const ui.Color(0x55000000)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3);
  }

  double get _radius => layout.edgeSize * 0.28;

  // -------------------------------------------------------------------------
  // moveToPosition — slides to a world-space Vector2 with trail
  // -------------------------------------------------------------------------
  void moveToPosition(Vector2 dest, {VoidCallback? onComplete}) {
    _isMoving = true;
    _trail.clear();

    add(
      MoveToEffect(
        dest.clone(),
        EffectController(duration: 0.6, curve: const _EaseInOut()),
        onComplete: () {
          _isMoving = false;
          onComplete?.call();
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // update — record trail positions while moving
  // -------------------------------------------------------------------------
  @override
  void update(double dt) {
    super.update(dt);
    if (_isMoving) {
      _trail.addLast(position.clone());
      while (_trail.length > _trailLength) {
        _trail.removeFirst();
      }
    }
  }

  // -------------------------------------------------------------------------
  // render — trail ghosts → shadow → token circle → initial letter
  // -------------------------------------------------------------------------
  @override
  void render(ui.Canvas canvas) {
    final r = _radius;

    // ── Trail ────────────────────────────────────────────────────────────
    final trailList = _trail.toList();
    for (int i = 0; i < trailList.length; i++) {
      final t       = i / _trailLength;           // 0 = oldest, 1 = newest
      final opacity = t * 0.4;
      final radius  = r * (0.4 + 0.45 * t);

      // Trail positions are world coords; we need offset from our position
      final offset = trailList[i] - position;
      canvas.drawCircle(
        ui.Offset(offset.x, offset.y),
        radius,
        ui.Paint()..color = player.tokenColor.withOpacity(opacity),
      );
    }

    // ── Shadow ────────────────────────────────────────────────────────────
    canvas.drawCircle(const ui.Offset(1.5, 1.5), r * 0.9, _shadowPaint);

    // ── Token ─────────────────────────────────────────────────────────────
    canvas.drawCircle(ui.Offset.zero, r, _tokenPaint);
    canvas.drawCircle(ui.Offset.zero, r, _borderPaint);

    // ── Initial letter ────────────────────────────────────────────────────
    _drawInitial(canvas, r);
  }

  void _drawInitial(ui.Canvas canvas, double r) {
    final letter = player.name.isNotEmpty ? player.name[0].toUpperCase() : '?';
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.center,
        fontSize: r * 1.0,
        fontWeight: ui.FontWeight.bold,
      ),
    )
      ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF)))
      ..addText(letter);

    final para = pb.build()..layout(ui.ParagraphConstraints(width: r * 2));
    canvas.drawParagraph(para, ui.Offset(-r, -r * 0.65));
  }
}

// ---------------------------------------------------------------------------
// _EaseInOut — smooth ease-in-out Curve for the slide animation
// ---------------------------------------------------------------------------
class _EaseInOut extends Curve {
  const _EaseInOut();

  @override
  double transformInternal(double t) =>
      t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
}
