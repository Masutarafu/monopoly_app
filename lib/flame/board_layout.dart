import 'dart:ui';

// ---------------------------------------------------------------------------
// BoardLayout
// ---------------------------------------------------------------------------
// Central source of truth for tile positions on the board.
//
// Both the Flame layer (TileComponent, TokenComponent) and the Flutter layer
// (tile tap popup) use this to convert a tile index (0–39) into a pixel
// position and size on the board canvas.
//
// Winding order (clockwise from GO at bottom-right):
//
//   TL(20) →→ 21..29 →→ TR(30)
//     ↑                    ↓
//   19..11                31..39
//     ↑                    ↓
//   BL(10) ←← 9..1  ←← BR(0=GO)
// ---------------------------------------------------------------------------
class BoardLayout {
  final double boardSize;

  // Size math — same formula as the Flutter board widget:
  // 2*cornerSize + 9*edgeSize = boardSize, cornerSize = 1.6 * edgeSize
  // → edgeSize = boardSize / 12.2
  late final double edgeSize;
  late final double cornerSize;

  BoardLayout(this.boardSize) {
    edgeSize   = boardSize / 12.2;
    cornerSize = edgeSize * 1.6;
  }

  // -------------------------------------------------------------------------
  // tileRect(index) — returns the Rect of a tile in board-local coordinates.
  // Top-left of the board is (0, 0).
  // -------------------------------------------------------------------------
  Rect tileRect(int index) {
    assert(index >= 0 && index < 40, 'Tile index out of bounds: $index');

    if (index == 0)  return _corner(boardSize - cornerSize, boardSize - cornerSize); // BR — GO
    if (index == 10) return _corner(0, boardSize - cornerSize);                       // BL — Jail
    if (index == 20) return _corner(0, 0);                                            // TL — Free Parking
    if (index == 30) return _corner(boardSize - cornerSize, 0);                       // TR — LASTMA

    // Bottom row: indices 1–9, rendered right→left
    // index 1 is just left of GO (BR corner), index 9 is just right of Jail (BL corner)
    if (index >= 1 && index <= 9) {
      final slot = index; // slot 1 = rightmost edge tile, slot 9 = leftmost
      final x = boardSize - cornerSize - (slot * edgeSize);
      final y = boardSize - cornerSize;
      return Rect.fromLTWH(x, y, edgeSize, cornerSize);
    }

    // Left column: indices 11–19, rendered bottom→top
    if (index >= 11 && index <= 19) {
      final slot = index - 10; // slot 1 = bottom, slot 9 = top
      final x = 0.0;
      final y = boardSize - cornerSize - (slot * edgeSize);
      return Rect.fromLTWH(x, y, cornerSize, edgeSize);
    }

    // Top row: indices 21–29, rendered left→right
    if (index >= 21 && index <= 29) {
      final slot = index - 20; // slot 1 = leftmost, slot 9 = rightmost
      final x = cornerSize + ((slot - 1) * edgeSize);
      final y = 0.0;
      return Rect.fromLTWH(x, y, edgeSize, cornerSize);
    }

    // Right column: indices 31–39, rendered top→bottom
    if (index >= 31 && index <= 39) {
      final slot = index - 30; // slot 1 = top, slot 9 = bottom
      final x = boardSize - cornerSize;
      final y = cornerSize + ((slot - 1) * edgeSize);
      return Rect.fromLTWH(x, y, cornerSize, edgeSize);
    }

    throw ArgumentError('Unhandled tile index: $index');
  }

  // Center point of a tile — used for token positioning
  Offset tileCenter(int index) {
    final r = tileRect(index);
    return r.center;
  }

  Rect _corner(double x, double y) =>
      Rect.fromLTWH(x, y, cornerSize, cornerSize);
}
