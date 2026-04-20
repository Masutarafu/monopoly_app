import 'dart:ui' as ui;
import 'dart:collection';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import '../models/player.dart';
import 'board_layout.dart';
// import 'package:flutter/foundation.dart';
import 'package:flutter/animation.dart';

// ---------------------------------------------------------------------------
// TokenComponent
// ---------------------------------------------------------------------------
// Renders a player's token as a colored circle on the Flame canvas.
//
// Movement: when moveTo(index) is called, the token slides from its current
// position to the destination tile center using Flame's MoveToEffect.
// During movement, it leaves a fading trail of ghost circles behind it.
//
// The trail works by recording the token's position every frame into a
// fixed-length queue. Each ghost is drawn with decreasing opacity.
// ---------------------------------------------------------------------------
class TokenComponent extends PositionComponent {
  final Player player;
  final BoardLayout layout;

  // Trail — stores recent positions (newest last)
  final Queue<Vector2> _trail = Queue();
  static const int _trailLength = 18;

  late final ui.Paint _tokenPaint;
  late final ui.Paint _borderPaint;
  late final ui.Paint _shadowPaint;

  bool _isMoving = false;

  TokenComponent({
    required this.player,
    required this.layout,
    required int startIndex,
  }) {
    final center = layout.tileCenter(startIndex);
    position = Vector2(center.dx, center.dy);
    // Token is drawn centered on its position
    anchor = Anchor.center;
    size = Vector2.all(_tokenRadius * 2);

    _tokenPaint = ui.Paint()..color = player.tokenColor;
    _borderPaint = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF)
      ..strokeWidth = 1.5
      ..style = ui.PaintingStyle.stroke;
    _shadowPaint = ui.Paint()
      ..color = ui.Color(0x55000000)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3);
  }

  double get _tokenRadius => layout.edgeSize * 0.28;

  // -------------------------------------------------------------------------
  // moveTo — slides token to a new tile with a trail
  // -------------------------------------------------------------------------
  void moveTo(int tileIndex, {VoidCallback? onComplete}) {
    final dest = layout.tileCenter(tileIndex);
    _isMoving = true;
    _trail.clear();

    add(
      MoveToEffect(
        Vector2(dest.dx, dest.dy),
        EffectController(duration: 0.55, curve: _SmoothCurve()),
        onComplete: () {
          _isMoving = false;
          onComplete?.call();
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // update — record trail positions every frame while moving
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
  // render — draw trail ghosts then the live token
  // -------------------------------------------------------------------------
  @override
  void render(ui.Canvas canvas) {
    final r = _tokenRadius;

    // ── Trail ────────────────────────────────────────────────────────────
    final trailList = _trail.toList();
    for (int i = 0; i < trailList.length; i++) {
      final progress = i / _trailLength; // 0.0 (oldest) → 1.0 (newest)
      final opacity = progress * 0.45; // max 45% opacity
      final radius = r * (0.45 + 0.4 * progress);

      final trailPaint = ui.Paint()
        ..color = player.tokenColor.withOpacity(opacity);

      // Trail positions are in world space; render offset from our position
      final offset = trailList[i] - position;
      canvas.drawCircle(
        ui.Offset(offset.x, offset.y),
        radius,
        trailPaint,
      );
    }

    // ── Shadow ────────────────────────────────────────────────────────────
    canvas.drawCircle(ui.Offset(1.5, 1.5), r * 0.9, _shadowPaint);

    // ── Token circle ──────────────────────────────────────────────────────
    canvas.drawCircle(ui.Offset.zero, r, _tokenPaint);
    canvas.drawCircle(ui.Offset.zero, r, _borderPaint);

    // ── Player initial ────────────────────────────────────────────────────
    _drawInitial(canvas, r);
  }

  void _drawInitial(ui.Canvas canvas, double r) {
    final initial = player.name.isNotEmpty ? player.name[0].toUpperCase() : '?';

    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.center,
        fontSize: r * 1.0,
        fontWeight: ui.FontWeight.bold,
      ),
    )
      ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF)))
      ..addText(initial);

    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: r * 2));

    canvas.drawParagraph(
      paragraph,
      ui.Offset(-r, -r * 0.65),
    );
  }
}

// Simple smooth ease-in-out curve for the slide animation
class _SmoothCurve extends Curve {
  const _SmoothCurve();

  @override
  double transformInternal(double t) =>
      t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
}
