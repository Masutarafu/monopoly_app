import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// DiceComponent
// ---------------------------------------------------------------------------
// Draws two dice on the Flame canvas with a tumbling animation.
//
// Animation stages:
//   1. IDLE      — dice show last result (or blank on first load)
//   2. ROLLING   — dice rapidly cycle through faces + rotate + scale
//   3. SETTLING  — dice slow down and snap to final values
//   4. DONE      — static display of the result, callback fires
//
// Usage:
//   diceComponent.roll(die1: 4, die2: 2, onComplete: () { ... });
// ---------------------------------------------------------------------------
class DiceComponent extends PositionComponent {
  // The two die values to land on (set before rolling)
  int _targetDie1 = 1;
  int _targetDie2 = 1;

  // Currently displayed faces (cycle during animation)
  int _displayDie1 = 1;
  int _displayDie2 = 1;

  // Animation state
  _DiceState _state = _DiceState.idle;
  double _elapsed = 0;
  double _rotation = 0;
  double _scale = 1.0;
  VoidCallback? _onComplete;

  static const double _rollDuration = 1.0; // seconds of fast tumbling
  static const double _settleDuration = 0.35; // seconds of slow settle

  final Random _rng = Random();
  late final ui.Paint _dicePaint;
  late final ui.Paint _shadowPaint;
  late final ui.Paint _dotPaint;

  DiceComponent({required Vector2 position, required Vector2 size})
      : super(position: position, size: size) {
    _dicePaint = ui.Paint()..color = const ui.Color(0xFFFFFDE7);
    _shadowPaint = ui.Paint()
      ..color = const ui.Color(0x55000000)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
    _dotPaint = ui.Paint()..color = const ui.Color(0xFF1A1A1A);
  }

  // -------------------------------------------------------------------------
  // roll() — start the animation with known target values
  // -------------------------------------------------------------------------
  void roll({required int die1, required int die2, VoidCallback? onComplete}) {
    _targetDie1 = die1;
    _targetDie2 = die2;
    _state = _DiceState.rolling;
    _elapsed = 0;
    _rotation = 0;
    _onComplete = onComplete;
  }

  // -------------------------------------------------------------------------
  // update — drives all animation stages
  // -------------------------------------------------------------------------
  @override
  void update(double dt) {
    super.update(dt);

    if (_state == _DiceState.idle || _state == _DiceState.done) return;

    _elapsed += dt;

    if (_state == _DiceState.rolling) {
      // Rapidly cycle faces + spin + bounce scale
      _displayDie1 = _rng.nextInt(6) + 1;
      _displayDie2 = _rng.nextInt(6) + 1;
      _rotation = _elapsed * 8;
      _scale = 1.0 + sin(_elapsed * 20) * 0.06;

      if (_elapsed >= _rollDuration) {
        _state = _DiceState.settling;
        _elapsed = 0;
      }
    } else if (_state == _DiceState.settling) {
      // Slow down and snap toward target
      final progress = _elapsed / _settleDuration;

      if (progress < 0.5) {
        _displayDie1 = _rng.nextInt(6) + 1;
        _displayDie2 = _rng.nextInt(6) + 1;
      } else {
        _displayDie1 = _targetDie1;
        _displayDie2 = _targetDie2;
      }

      _rotation = _rotation * (1 - progress * 0.15);
      _scale = 1.0 + (1.0 - progress) * 0.04;

      if (_elapsed >= _settleDuration) {
        _displayDie1 = _targetDie1;
        _displayDie2 = _targetDie2;
        _rotation = 0;
        _scale = 1.0;
        _state = _DiceState.done;
        _onComplete?.call();
        _onComplete = null;
      }
    }
  }

  // -------------------------------------------------------------------------
  // render — draw both dice side by side
  // -------------------------------------------------------------------------
  @override
  void render(ui.Canvas canvas) {
    final dieSize = size.x * 0.42;
    final gap = size.x * 0.08;
    final y = size.y / 2;

    final cx1 = dieSize / 2 + gap;
    final cx2 = cx1 + dieSize + gap;

    _drawDie(canvas, ui.Offset(cx1, y), dieSize, _displayDie1);
    _drawDie(canvas, ui.Offset(cx2, y), dieSize, _displayDie2);
  }

  void _drawDie(ui.Canvas canvas, ui.Offset center, double dieSize, int face) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(_scale, _scale);
    canvas.rotate(_rotation * 0.15); // subtle tilt — not full spin

    final half = dieSize / 2;
    final rect = ui.Rect.fromLTWH(-half, -half, dieSize, dieSize);
    final rrect =
        ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(dieSize * 0.15));

    // Shadow
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        rect.translate(2, 2),
        ui.Radius.circular(dieSize * 0.15),
      ),
      _shadowPaint,
    );

    // Die face
    canvas.drawRRect(rrect, _dicePaint);

    // Border
    canvas.drawRRect(
      rrect,
      ui.Paint()
        ..color = const ui.Color(0xFFBBB090)
        ..strokeWidth = 1.2
        ..style = ui.PaintingStyle.stroke,
    );

    // Dots
    _drawDots(canvas, face, dieSize);

    canvas.restore();
  }

  // Standard pip layout for faces 1–6
  void _drawDots(ui.Canvas canvas, int face, double dieSize) {
    final r = dieSize * 0.09;
    final off = dieSize * 0.28;

    // Dot positions: [top-left, top-right, mid-left, center,
    //                 mid-right, bot-left, bot-right]
    final tl = ui.Offset(-off, -off);
    final tr = ui.Offset(off, -off);
    final ml = ui.Offset(-off, 0);
    final c = ui.Offset(0, 0);
    final mr = ui.Offset(off, 0);
    final bl = ui.Offset(-off, off);
    final br = ui.Offset(off, off);

    final layouts = {
      1: [c],
      2: [tl, br],
      3: [tl, c, br],
      4: [tl, tr, bl, br],
      5: [tl, tr, c, bl, br],
      6: [tl, tr, ml, mr, bl, br],
    };

    for (final dot in layouts[face] ?? []) {
      canvas.drawCircle(dot, r, _dotPaint);
    }
  }
}

enum _DiceState { idle, rolling, settling, done }
