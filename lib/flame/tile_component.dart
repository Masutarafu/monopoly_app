import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' show Colors, Color, TextStyle,
    FontWeight, TextAlign, TextOverflow;
import '../models/tile.dart';
import '../models/player.dart';
import 'board_layout.dart';

// ---------------------------------------------------------------------------
// TileComponent
// ---------------------------------------------------------------------------
// Draws a single board space on the Flame canvas.
// On tap it fires onTileTapped(index) which the parent FlameGame forwards
// to Flutter for the property popup sheet.
// ---------------------------------------------------------------------------
class TileComponent extends PositionComponent with TapCallbacks {
  final Tile tile;
  final int index;
  final BoardLayout layout;
  final void Function(int index) onTileTapped;

  // Players currently standing on this tile (updated from game state)
  List<Player> occupants = [];

  // Cached paints — created once, reused every render frame
  late final ui.Paint _bgPaint;
  late final ui.Paint _borderPaint;
  late final ui.Paint _stripPaint;

  TileComponent({
    required this.tile,
    required this.index,
    required this.layout,
    required this.onTileTapped,
  }) {
    final rect = layout.tileRect(index);
    position = Vector2(rect.left, rect.top);
    size     = Vector2(rect.width, rect.height);

    _bgPaint = ui.Paint()..color = const Color(0xFFF5F0E8);
    _borderPaint = ui.Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 0.8
      ..style = ui.PaintingStyle.stroke;
    _stripPaint = ui.Paint()
      ..color = tile.colorGroup == Colors.transparent
          ? const Color(0x00000000)
          : tile.colorGroup;
  }

  @override
  void render(ui.Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final rect = ui.Rect.fromLTWH(0, 0, w, h);

    // ── Background ──────────────────────────────────────────────────────
    canvas.drawRect(rect, _bgPaint);

    // ── Color strip ─────────────────────────────────────────────────────
    if (tile.colorGroup != Colors.transparent) {
      final stripRect = _stripRect(w, h);
      canvas.drawRect(stripRect, _stripPaint);

      // Ownership dot on the strip
      if (tile.isOwned) {
        final ownerPaint = ui.Paint()..color = tile.owner!.tokenColor;
        final dotR = stripRect.shortestSide * 0.3;
        canvas.drawCircle(stripRect.center, dotR, ownerPaint);
      }
    }

    // ── Border ───────────────────────────────────────────────────────────
    canvas.drawRect(rect, _borderPaint);

    // ── Text (name + price) ──────────────────────────────────────────────
    _drawTileText(canvas, w, h);
  }

  // ── Returns the color strip rect for each board side ──────────────────
  ui.Rect _stripRect(double w, double h) {
    const stripRatio = 0.22;
    // Corner tiles have no strip
    if (_isCorner) return ui.Rect.zero;

    if (_isBottom) return ui.Rect.fromLTWH(0, 0, w, h * stripRatio);
    if (_isTop)    return ui.Rect.fromLTWH(0, h * (1 - stripRatio), w, h * stripRatio);
    if (_isLeft)   return ui.Rect.fromLTWH(w * (1 - stripRatio), 0, w * stripRatio, h);
    // right
    return ui.Rect.fromLTWH(0, 0, w * stripRatio, h);
  }

  void _drawTileText(ui.Canvas canvas, double w, double h) {
    if (_isCorner) {
      _drawCornerContent(canvas, w, h);
      return;
    }

    // Rotate canvas so text reads inward from each edge
    canvas.save();
    canvas.translate(w / 2, h / 2);
    if (_isBottom) canvas.rotate(3.14159); // 180°
    if (_isLeft)   canvas.rotate(1.5708);  // 90° CW
    if (_isRight)  canvas.rotate(-1.5708); // 90° CCW
    canvas.translate(-w / 2, -h / 2);

    // After rotation, treat tile as if it's a "top" tile for text layout
    final rotW = (_isLeft || _isRight) ? h : w;
    final rotH = (_isLeft || _isRight) ? w : h;

    _paintText(
      canvas,
      tile.name,
      ui.Rect.fromLTWH(1, rotH * 0.25, rotW - 2, rotH * 0.5),
      fontSize: rotW * 0.09,
      bold: false,
    );

    if (tile.price > 0) {
      _paintText(
        canvas,
        '₦${_fmt(tile.price)}',
        ui.Rect.fromLTWH(1, rotH * 0.72, rotW - 2, rotH * 0.2),
        fontSize: rotW * 0.08,
        bold: false,
      );
    }

    canvas.restore();
  }

  void _drawCornerContent(ui.Canvas canvas, double w, double h) {
    const emojis = {0: '🚀', 10: '⛓', 20: '🌴', 30: '🚔'};
    final emoji = emojis[index] ?? '';

    _paintText(
      canvas,
      emoji,
      ui.Rect.fromLTWH(0, h * 0.15, w, h * 0.4),
      fontSize: w * 0.3,
      bold: false,
    );
    _paintText(
      canvas,
      tile.name,
      ui.Rect.fromLTWH(2, h * 0.55, w - 4, h * 0.38),
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
    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.bold : FontWeight.w500,
        maxLines: 3,
        ellipsis: '…',
      ),
    )
      ..pushStyle(ui.TextStyle(color: const Color(0xFF111111)))
      ..addText(text);

    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: bounds.width));

    canvas.drawParagraph(paragraph, bounds.topLeft);
  }

  // ── Side helpers ─────────────────────────────────────────────────────────
  bool get _isCorner => index == 0 || index == 10 || index == 20 || index == 30;
  bool get _isBottom => index >= 1  && index <= 9;
  bool get _isLeft   => index >= 11 && index <= 19;
  bool get _isTop    => index >= 21 && index <= 29;
  bool get _isRight  => index >= 31 && index <= 39;

  // ── Tap handling ──────────────────────────────────────────────────────────
  @override
  void onTapDown(TapDownEvent event) => onTileTapped(index);

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
