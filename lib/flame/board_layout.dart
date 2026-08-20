import 'dart:math';
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

  // -------------------------------------------------------------------------
  // tokenOffset(index, slotIndex, slotCount) — stacking offset for multiple
  // tokens that share the same tile.
  //
  // Returns the offset (board-local coordinates) from the tile center where
  // the slotIndex-th token should sit when slotCount tokens share the tile.
  //
  // Layout strategy (slot 0 = first player listed on the tile):
  //   • 1 token   → tile center (zero offset)
  //   • 2–6 tokens → micro-grid aligned with the tile's long axis:
  //                   1–3 tokens → single column stacked along the long axis
  //                   4–6 tokens → 2 columns × up to 3 rows
  //   • 7+ tokens → radial ring around the tile center
  //
  // Spacing is edgeSize * 0.42, which keeps every stacked token inside the
  // tile body for both edge tiles and corners.
  // -------------------------------------------------------------------------
  Offset tokenOffset(int index, int slotIndex, int slotCount) {
    assert(
      slotIndex >= 0 && slotIndex < slotCount,
      'Token slot out of range: $slotIndex of $slotCount',
    );
    if (slotCount <= 1) return Offset.zero;

    final spacing = edgeSize * 0.42;

    // 7+ tokens on one tile — radial ring.
    if (slotCount > 6) {
      final angle = (2 * pi * slotIndex / slotCount) - (pi / 2);
      return Offset(cos(angle) * spacing, sin(angle) * spacing);
    }

    // Micro-grid: stack along the tile's long axis, 1–2 columns on the short
    // axis so tokens never spill over the tile's narrow dimension.
    final longIsHorizontal = _longIsHorizontal(index);
    final cols   = slotCount <= 3 ? 1 : 2;
    final perCol = (slotCount / cols).ceil();
    final col    = slotIndex % cols;
    final row    = slotIndex ~/ cols;

    final long  = (row - (perCol - 1) / 2) * spacing;
    final short = (col - (cols - 1) / 2) * spacing;

    return longIsHorizontal ? Offset(long, short) : Offset(short, long);
  }

  // Tiles whose long axis runs horizontally are the left/right edge columns
  // (their width is the corner dimension). Bottom row, top row and corners
  // stack vertically.
  bool _longIsHorizontal(int index) =>
      (index >= 11 && index <= 19) || (index >= 31 && index <= 39);

  Rect _corner(double x, double y) =>
      Rect.fromLTWH(x, y, cornerSize, cornerSize);
}
