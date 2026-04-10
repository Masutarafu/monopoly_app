import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/game_controller.dart';
import '../models/board_data.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/tile.dart';

// ============================================================================
// BoardWidget — top-level entry point for the visual board
// ============================================================================
class BoardWidget extends ConsumerWidget {
  const BoardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameControllerProvider);

    return Column(
      children: [
        Expanded(
          child: _LagosBoard(gameState: gameState),
        ),
        _ControlPanel(gameState: gameState),
      ],
    );
  }
}

// ============================================================================
// _LagosBoard — paints the 40-tile square board
// ============================================================================
//
// Layout:   [bottom row  0–9  ] = bottom  (left → right)
//           [left column 10–19] = left    (bottom → top)
//           [top row     20–29] = top     (right → left)
//           [right column30–39] = right   (top → bottom)
//
// Each side has 10 tiles: 4 corners shared between sides.
// The board is square; corners are larger than edge tiles.
// ============================================================================
class _LagosBoard extends StatelessWidget {
  final GameState gameState;
  const _LagosBoard({required this.gameState});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest.shortestSide;
      // Corner tiles are 1.6× the width of edge tiles
      // 8 edge tiles + 2 corner tiles per side = size
      // cornerSize + 8 * edgeSize + cornerSize = size
      // Let cornerSize = 1.6 * edgeSize → edgeSize = size / (8 + 3.2) = size / 11.2
      final edgeSize = size / 11.2;
      final cornerSize = edgeSize * 1.6;

      return Center(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              // ── Green felt center ──────────────────────────────────────
              Positioned(
                left: cornerSize,
                top: cornerSize,
                child: Container(
                  width: size - cornerSize * 2,
                  height: size - cornerSize * 2,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: Center(
                    child: _CenterLogo(size: size - cornerSize * 2),
                  ),
                ),
              ),

              // ── Bottom row (0–9, left→right) ──────────────────────────
              Positioned(
                left: 0,
                bottom: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildCorner(0, cornerSize, gameState),
                    for (int i = 1; i <= 9; i++)
                      _buildEdgeTile(
                          i, edgeSize, cornerSize, Side.bottom, gameState),
                  ],
                ),
              ),

              // ── Left column (10–19, bottom→top) ───────────────────────
              Positioned(
                left: 0,
                top: cornerSize,
                child: Column(
                  children: [
                    for (int i = 19; i >= 11; i--)
                      _buildEdgeTile(
                          i, edgeSize, cornerSize, Side.left, gameState),
                    _buildCorner(10, cornerSize, gameState),
                  ],
                ),
              ),

              // ── Top row (20–29, right→left) ───────────────────────────
              Positioned(
                left: 0,
                top: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCorner(20, cornerSize, gameState),
                    for (int i = 29; i >= 21; i--)
                      _buildEdgeTile(
                          i, edgeSize, cornerSize, Side.top, gameState),
                  ],
                ),
              ),

              // ── Right column (30–39, top→bottom) ──────────────────────
              Positioned(
                right: 0,
                top: cornerSize,
                child: Column(
                  children: [
                    _buildCorner(30, cornerSize, gameState),
                    for (int i = 31; i <= 39; i++)
                      _buildEdgeTile(
                          i, edgeSize, cornerSize, Side.right, gameState),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildCorner(int index, double size, GameState gs) {
    final tile = gs.board[index];
    final players = gs.players.where((p) => p.position == index).toList();
    return _CornerTile(tile: tile, index: index, size: size, players: players);
  }

  Widget _buildEdgeTile(
      int index, double edgeSize, double cornerSize, Side side, GameState gs) {
    final tile = gs.board[index];
    final players = gs.players.where((p) => p.position == index).toList();
    return _EdgeTile(
      tile: tile,
      index: index,
      edgeSize: edgeSize,
      longSize: cornerSize,
      side: side,
      players: players,
    );
  }
}

// ============================================================================
// Side enum — used to rotate tiles correctly
// ============================================================================
enum Side { bottom, left, top, right }

// ============================================================================
// _EdgeTile — a single non-corner board space
// ============================================================================
class _EdgeTile extends StatelessWidget {
  final Tile tile;
  final int index;
  final double edgeSize; // narrow dimension (width for bottom/top)
  final double longSize; // tall dimension (height for bottom/top)
  final Side side;
  final List<Player> players;

  const _EdgeTile({
    required this.tile,
    required this.index,
    required this.edgeSize,
    required this.longSize,
    required this.side,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    final isHorizontal = side == Side.bottom || side == Side.top;
    final w = isHorizontal ? edgeSize : longSize;
    final h = isHorizontal ? longSize : edgeSize;

    Widget content = _TileContent(
      tile: tile,
      width: w,
      height: h,
      side: side,
      players: players,
    );

    return SizedBox(width: w, height: h, child: content);
  }
}

// ============================================================================
// _TileContent — renders the color strip, name, price and tokens
// ============================================================================
class _TileContent extends StatelessWidget {
  final Tile tile;
  final double width;
  final double height;
  final Side side;
  final List<Player> players;

  const _TileContent({
    required this.tile,
    required this.width,
    required this.height,
    required this.side,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    final stripSize = (side == Side.bottom || side == Side.top)
        ? height * 0.22
        : width * 0.22;

    // Color strip direction based on which side we're on
    Widget colorStrip = Container(
      color: tile.colorGroup == Colors.transparent
          ? Colors.transparent
          : tile.colorGroup,
      width:
          side == Side.left || side == Side.right ? stripSize : double.infinity,
      height:
          side == Side.bottom || side == Side.top ? stripSize : double.infinity,
    );

    // Ownership indicator
    if (tile.isOwned) {
      colorStrip = Stack(
        children: [
          colorStrip,
          Positioned.fill(
            child: Center(
              child: Icon(
                Icons.home,
                size: stripSize * 0.6,
                color: tile.owner!.tokenColor,
              ),
            ),
          ),
        ],
      );
    }

    // Name + price text
    final nameText = Text(
      tile.name,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: width * 0.09,
        fontWeight: FontWeight.w600,
        color: Colors.black,
        height: 1.1,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );

    final priceText = tile.price > 0
        ? Text(
            '₦${_fmt(tile.price)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: width * 0.08,
              color: Colors.black87,
            ),
          )
        : const SizedBox.shrink();

    // Token dots
    final tokenRow = players.isNotEmpty
        ? Wrap(
            alignment: WrapAlignment.center,
            spacing: 1,
            children: players
                .map((p) => CircleAvatar(
                      radius: width * 0.1,
                      backgroundColor: p.tokenColor,
                    ))
                .toList(),
          )
        : const SizedBox.shrink();

    // Assemble tile body with color strip on the correct edge
    Widget body;
    switch (side) {
      case Side.bottom:
        body = Column(
          children: [
            colorStrip,
            Expanded(
              child: RotatedBox(
                quarterTurns: 2,
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [nameText, priceText, tokenRow],
                  ),
                ),
              ),
            ),
          ],
        );
        break;
      case Side.top:
        body = Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [nameText, priceText, tokenRow],
                ),
              ),
            ),
            colorStrip,
          ],
        );
        break;
      case Side.left:
        body = Row(
          children: [
            Expanded(
              child: RotatedBox(
                quarterTurns: 1,
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [nameText, priceText, tokenRow],
                  ),
                ),
              ),
            ),
            colorStrip,
          ],
        );
        break;
      case Side.right:
        body = Row(
          children: [
            colorStrip,
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [nameText, priceText, tokenRow],
                  ),
                ),
              ),
            ),
          ],
        );
        break;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        border: Border.all(color: Colors.black87, width: 0.5),
      ),
      child: body,
    );
  }

  String _fmt(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }
}

// ============================================================================
// _CornerTile — the four large corner spaces
// ============================================================================
class _CornerTile extends StatelessWidget {
  final Tile tile;
  final int index;
  final double size;
  final List<Player> players;

  const _CornerTile({
    required this.tile,
    required this.index,
    required this.size,
    required this.players,
  });

  String get _emoji {
    switch (index) {
      case 0:
        return '🚀'; // GO
      case 10:
        return '⛓️'; // Jail
      case 20:
        return '🌴'; // Freedom Park
      case 30:
        return '🚔'; // LASTMA
      default:
        return '⬛';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E8),
        border: Border.all(color: Colors.black87, width: 0.8),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_emoji, style: TextStyle(fontSize: size * 0.28)),
                const SizedBox(height: 2),
                Text(
                  tile.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: size * 0.1,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          // Player tokens
          if (players.isNotEmpty)
            Positioned(
              bottom: 4,
              right: 4,
              child: Wrap(
                spacing: 2,
                children: players
                    .map((p) => CircleAvatar(
                          radius: size * 0.1,
                          backgroundColor: p.tokenColor,
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// _CenterLogo — the Lagos Monopoly branding in the board center
// ============================================================================
class _CenterLogo extends StatelessWidget {
  final double size;
  const _CenterLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '🏙️',
          style: TextStyle(fontSize: size * 0.15),
        ),
        Text(
          'LAGOS',
          style: TextStyle(
            fontSize: size * 0.13,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 6,
            shadows: const [
              Shadow(
                  color: Colors.black54, blurRadius: 4, offset: Offset(1, 2)),
            ],
          ),
        ),
        Text(
          'MONOPOLY',
          style: TextStyle(
            fontSize: size * 0.065,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFFFD600),
            letterSpacing: 3,
          ),
        ),
        SizedBox(height: size * 0.03),
        Text(
          '₦',
          style: TextStyle(
            fontSize: size * 0.12,
            color: const Color(0xFFFFD600),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// _ControlPanel — action buttons + player info strip at the bottom
// ============================================================================
class _ControlPanel extends ConsumerWidget {
  final GameState gameState;
  const _ControlPanel({required this.gameState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    final player = gameState.currentPlayer;
    final tile = gameState.currentTile;

    return Container(
      color: const Color(0xFF1B2A1B),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Status message ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              gameState.message ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(height: 10),

          // ── Dice display ───────────────────────────────────────────────
          if (gameState.lastDie1 > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DieBox(value: gameState.lastDie1),
                const SizedBox(width: 8),
                _DieBox(value: gameState.lastDie2),
                if (gameState.isDoubles) ...[
                  const SizedBox(width: 8),
                  const Text('DOUBLES! 🎉',
                      style: TextStyle(
                          color: Color(0xFFFFD600),
                          fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          const SizedBox(height: 10),

          // ── Player balances ────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: gameState.players.map((p) {
                final isCurrent = p.id == player.id;
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? p.tokenColor.withOpacity(0.25)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                    border: isCurrent
                        ? Border.all(color: p.tokenColor, width: 1.5)
                        : null,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 7, backgroundColor: p.tokenColor),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          Text('₦${_fmt(p.balance)}',
                              style: const TextStyle(
                                  color: Color(0xFFFFD600), fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // ── Action buttons ─────────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (gameState.phase == GamePhase.waitingToRoll)
                _ActionButton(
                  label: '🎲  Roll Dice',
                  color: const Color(0xFFFFD600),
                  textColor: Colors.black,
                  onTap: controller.rollDice,
                ),
              if (gameState.phase == GamePhase.landedOnProperty) ...[
                _ActionButton(
                  label: '🏠  Buy  ₦${_fmt(tile.price)}',
                  color: const Color(0xFF43A047),
                  onTap: controller.buyProperty,
                ),
                _ActionButton(
                  label: '✋  Pass',
                  color: Colors.white24,
                  onTap: controller.passProperty,
                ),
              ],
              if (player.isInJail && gameState.phase == GamePhase.waitingToRoll)
                _ActionButton(
                  label: '💸  Pay ₦5,000 Fine',
                  color: const Color(0xFFEF5350),
                  onTap: controller.payJailFine,
                ),
              if (gameState.phase == GamePhase.gameOver)
                _ActionButton(
                  label: '🔄  New Game',
                  color: const Color(0xFF1565C0),
                  onTap: () {}, // wired in next task
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }
}

class _DieBox extends StatelessWidget {
  final int value;
  const _DieBox({required this.value});

  @override
  Widget build(BuildContext context) {
    const faces = ['', '⚀', '⚁', '⚂', '⚃', '⚄', '⚅'];
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(1, 2))
        ],
      ),
      child: Center(
        child: Text(
          faces[value],
          style: const TextStyle(fontSize: 26),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    this.textColor = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
                color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
              color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }
}
