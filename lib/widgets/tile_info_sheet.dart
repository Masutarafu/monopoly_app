import 'package:flutter/material.dart';
import '../models/tile.dart';
import '../models/board_data.dart';

// ---------------------------------------------------------------------------
// TileInfoSheet
// ---------------------------------------------------------------------------
// Flutter bottom sheet shown when a player taps any tile on the Flame board.
// Displays: tile name, color group, owner, price, and rent.
// ---------------------------------------------------------------------------
class TileInfoSheet extends StatelessWidget {
  final Tile tile;
  final int tileIndex;

  const TileInfoSheet({
    super.key,
    required this.tile,
    required this.tileIndex,
  });

  static void show(BuildContext context, Tile tile, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TileInfoSheet(tile: tile, tileIndex: index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2A1B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tile.colorGroup == Colors.transparent
              ? Colors.white24
              : tile.colorGroup,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Color band header ──────────────────────────────────────────
          if (tile.colorGroup != Colors.transparent)
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: tile.colorGroup,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Tile name + type badge ───────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tile.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _TypeBadge(tile.type),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Details grid ─────────────────────────────────────────
                if (tile.isBuyable) ...[
                  _InfoRow(
                    icon: '💰',
                    label: 'Price',
                    value: '${BoardData.currencySymbol}${_fmt(tile.price)}',
                  ),
                  _InfoRow(
                    icon: '🏠',
                    label: 'Base Rent',
                    value: tile.baseRent > 0
                        ? '${BoardData.currencySymbol}${_fmt(tile.baseRent)}'
                        : 'Dice × multiplier',
                  ),
                  _InfoRow(
                    icon: '👤',
                    label: 'Owner',
                    value: tile.isOwned ? tile.owner!.name : 'Unowned',
                    valueColor: tile.isOwned
                        ? tile.owner!.tokenColor
                        : Colors.white54,
                  ),
                ],

                if (tile.type == TileType.tax)
                  _InfoRow(
                    icon: '🧾',
                    label: 'Tax Amount',
                    value: '${BoardData.currencySymbol}${_fmt(tile.price)}',
                    valueColor: const Color(0xFFEF5350),
                  ),

                if (tile.type == TileType.corner)
                  _InfoRow(
                    icon: '📍',
                    label: 'Type',
                    value: _cornerDescription(tileIndex),
                  ),

                const SizedBox(height: 16),

                // ── Close button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white12,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Close',
                        style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _cornerDescription(int index) {
    switch (index) {
      case 0:  return 'Collect ₦${_fmt(BoardData.goSalary)} when passing';
      case 10: return 'Jail — Just Visiting or serving time';
      case 20: return 'Free Parking — nothing happens';
      case 30: return 'LASTMA — Go directly to Jail!';
      default: return '';
    }
  }

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

class _InfoRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text('$label:',
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final TileType type;
  const _TypeBadge(this.type);

  String get _label {
    switch (type) {
      case TileType.property:  return 'Property';
      case TileType.railroad:  return 'Transit';
      case TileType.utility:   return 'Utility';
      case TileType.tax:       return 'Tax';
      case TileType.corner:    return 'Corner';
      case TileType.chance:    return 'Chance';
      case TileType.community: return 'Community';
    }
  }

  Color get _color {
    switch (type) {
      case TileType.property:  return const Color(0xFF43A047);
      case TileType.railroad:  return const Color(0xFF78909C);
      case TileType.utility:   return const Color(0xFFFFD54F);
      case TileType.tax:       return const Color(0xFFEF5350);
      case TileType.corner:    return const Color(0xFF1565C0);
      case TileType.chance:    return const Color(0xFFFFA726);
      case TileType.community: return const Color(0xFF8E24AA);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color, width: 1),
      ),
      child: Text(
        _label,
        style: TextStyle(
            color: _color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
