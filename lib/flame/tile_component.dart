import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' show Colors, Color, FontWeight,
    TextAlign, TextOverflow;
import '../models/tile.dart';
import '../models/player.dart';
import 'board_layout.dart';

// ---------------------------------------------------------------------------
// TileComponent
// ---------------------------------------------------------------------------
// Draws one board space on the Flame canvas.
//
// Position and size are set externally by LagosGameBoard after construction
// so the board-centering offset can be applied uniformly.
//
// Fires onTileTapped(index) when tapped — LagosGameBoard forwards this to
// Flutter for the property bottom sheet.
// ---------------------------------------------------------------------------
class TileComponent extends PositionComponent with TapCallbacks {
  Tile tile;   // mutable so LagosGameBoard can update owner reference
  final int index;
  final BoardLayout layout;
  final void Function(int index) onTileTapped;

  late final ui.Paint _bgPaint;
  late final ui.Paint _borderPaint;

  TileComponent({
    required this.tile,
    required this.index,
    required this.layout,
    required this.onTileTapped,
  }) {
    _bgPaint = ui.Paint()..color = const ui.Color(0xFFF5F0E8);
    _borderPaint = ui.Paint()
      ..color       = const ui.Color(0xFF333333)
      ..strokeWidth = 0.8
      ..style       = ui.PaintingStyle.stroke;
  }

  // =========================================================================
  // render
  // =========================================================================
  @override
  void render(ui.Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // ── Background ──────────────────────────────────────────────────────
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, w, h), _bgPaint);

    // ── Color strip ─────────────────────────────────────────────────────
    if (tile.colorGroup != Colors.transparent) {
      final stripPaint = ui.Paint()..color = tile.colorGroup;
      canvas.drawRect(_stripRect(w, h), stripPaint);

      if (tile.isOwned) {
        final ownerPaint = ui.Paint()..color = tile.owner!.tokenColor;
        final sr = _stripRect(w, h);
        canvas.drawCircle(
          ui.Offset(sr.center.dx, sr.center.dy),
          sr.shortestSide * 0.3,
          ownerPaint,
        );
      }
    }

    // ── Border ──────────────────────────────────────────────────────────
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, w, h), _borderPaint);

    // ── Text ────────────────────────────────────────────────────────────
    _drawText(canvas, w, h);
  }

  // =========================================================================
  // Strip rect — color band on the inward-facing edge of each side
  // =========================================================================
  ui.Rect _stripRect(double w, double h) {
    const ratio = 0.22;
    if (_isCorner) return ui.Rect.zero;
    if (_isBottom) return ui.Rect.fromLTWH(0, 0, w, h * ratio);
    if (_isTop)    return ui.Rect.fromLTWH(0, h * (1 - ratio), w, h * ratio);
    if (_isLeft)   return ui.Rect.fromLTWH(w * (1 - ratio), 0, w * ratio, h);
    // right side
    return ui.Rect.fromLTWH(0, 0, w * ratio, h);
  }

  // =========================================================================
  // Text drawing
  // =========================================================================
  void _drawText(ui.Canvas canvas, double w, double h) {
    if (_isCorner) {
      _drawCorner(canvas, w, h);
      return;
    }

    canvas.save();
    canvas.translate(w / 2, h / 2);
    if (_isBottom) canvas.rotate(3.14159265);
    if (_isLeft)   canvas.rotate(1.57079633);
    if (_isRight)  canvas.rotate(-1.57079633);
    canvas.translate(-w / 2, -h / 2);

    // After rotation, use rotated dimensions for text layout
    final rw = (_isLeft || _isRight) ? h : w;
    final rh = (_isLeft || _isRight) ? w : h;

    _paintText(
      canvas,
      tile.name,
      ui.Rect.fromLTWH(1, rh * 0.24, rw - 2, rh * 0.5),
      fontSize: rw * 0.088,
      bold: false,
    );

    if (tile.price > 0) {
      _paintText(
        canvas,
        '₦${_fmt(tile.price)}',
        ui.Rect.fromLTWH(1, rh * 0.72, rw - 2, rh * 0.2),
        fontSize: rw * 0.08,
        bold: false,
      );
    }

    canvas.restore();
  }

  void _drawCorner(ui.Canvas canvas, double w, double h) {
    const emojis = {0: '🚀', 10: '⛓', 20: '🌴', 30: '🚔'};
    _paintText(
      canvas,
      emojis[index] ?? '',
      ui.Rect.fromLTWH(0, h * 0.1, w, h * 0.42),
      fontSize: w * 0.28,
      bold: false,
    );
    _paintText(
      canvas,
      tile.name,
      ui.Rect.fromLTWH(2, h * 0.54, w - 4, h * 0.4),
      fontSize: w * 0.1,
      bold: true,
    );
  }

  void _paintText(
    ui.Canvas canvas,
    String text,
    ui.Rect bounds, {
    required double fontSize,
    required bool bold,
  }) {
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.center,
        fontSize: fontSize,
        fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.w500,
        maxLines: 3,
        ellipsis: '…',
      ),
    )
      ..pushStyle(ui.TextStyle(color: const ui.Color(0xFF111111)))
      ..addText(text);

    final para = pb.build()
      ..layout(ui.ParagraphConstraints(width: bounds.width));
    canvas.drawParagraph(para, bounds.topLeft);
  }

  // =========================================================================
  // Tap
  // =========================================================================
  @override
  void onTapDown(TapDownEvent event) => onTileTapped(index);

  // =========================================================================
  // Side helpers
  // =========================================================================
  bool get _isCorner => index == 0 || index == 10 || index == 20 || index == 30;
  bool get _isBottom => index >= 1  && index <= 9;
  bool get _isLeft   => index >= 11 && index <= 19;
  bool get _isTop    => index >= 21 && index <= 29;
  bool get _isRight  => index >= 31 && index <= 39;

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) buf.write(',');
      buf.write(s[i]);
      c++;
    }
    return buf.toString().split('').reversed.join();
  }
}
