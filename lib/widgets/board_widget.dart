import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/game_controller.dart';
import '../models/board_data.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/tile.dart';
import 'lobby_screen.dart';

// ============================================================================
// BoardWidget
// ============================================================================
class BoardWidget extends ConsumerWidget {
  const BoardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameControllerProvider);
    return Column(
      children: [
        Expanded(child: _LagosBoard(gameState: gameState)),
        _ControlPanel(gameState: gameState),
      ],
    );
  }
}

// ============================================================================
// _LagosBoard
// ============================================================================
//
// CORRECT clockwise Monopoly winding order, viewed from above:
//
//   Corner 20 (Free Parking) ←─── Top row 29..21 ───── Corner 30 (LASTMA)
//        │                                                      │
//   Left col 19..11 (bottom→top)               Right col 31..39 (top→bottom)
//        │                                                      │
//   Corner 10 (Jail) ──────── Bottom row 9..1 ──────── Corner 0 (GO)
//
// GO is BOTTOM-RIGHT. Players move: right→up→left→down (clockwise).
//
// Tile index → screen position mapping:
//   Bottom row : indices  0 (BR corner), 1–9  right→left, then  10 (BL corner)
//   Left col   : indices 10 (BL corner), 11–19 bottom→top, then 20 (TL corner)
//   Top row    : indices 20 (TL corner), 21–29 left→right, then 30 (TR corner)
//   Right col  : indices 30 (TR corner), 31–39 top→bottom, then back to 0
// ============================================================================
class _LagosBoard extends StatelessWidget {
  final GameState gameState;
  const _LagosBoard({required this.gameState});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Use shortest side so the board stays square on any screen
      final size = constraints.biggest.shortestSide;

      // Size math:
      // Each side = 2 corners + 9 edge tiles  (corners are shared)
      // cornerSize = 1.6 * edgeSize
      // 2*cornerSize + 9*edgeSize = size
      // 2*(1.6*e) + 9*e = size  →  12.2*e = size
      final edgeSize   = size / 12.2;
      final cornerSize = edgeSize * 1.6;

      return Center(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              // ── Green felt center ────────────────────────────────────
              Positioned(
                left: cornerSize,
                top: cornerSize,
                child: Container(
                  width:  size - cornerSize * 2,
                  height: size - cornerSize * 2,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20),
                    border: Border.all(color: Colors.black54, width: 1),
                  ),
                  child: Center(child: _CenterLogo(size: size - cornerSize * 2)),
                ),
              ),

              // ── BOTTOM ROW — index 9 down to 1, then corner 0 (GO) at BR ──
              // Rendered right-to-left so GO ends up on the right
              Positioned(
                left: 0,
                bottom: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _corner(10, cornerSize),   // BL — Jail
                    for (int i = 9; i >= 1; i--)
                      _edge(i, edgeSize, cornerSize, Side.bottom),
                    _corner(0, cornerSize),    // BR — GO
                  ],
                ),
              ),

              // ── LEFT COLUMN — index 11 up to 19 (bottom→top), corner 20 at TL ──
              Positioned(
                left: 0,
                top: cornerSize,
                child: Column(
                  children: [
                    for (int i = 19; i >= 11; i--)
                      _edge(i, edgeSize, cornerSize, Side.left),
                  ],
                ),
              ),

              // ── TOP ROW — corner 20 at TL, index 21 to 29, corner 30 at TR ──
              Positioned(
                left: 0,
                top: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _corner(20, cornerSize),   // TL — Free Parking
                    for (int i = 21; i <= 29; i++)
                      _edge(i, edgeSize, cornerSize, Side.top),
                    _corner(30, cornerSize),   // TR — LASTMA
                  ],
                ),
              ),

              // ── RIGHT COLUMN — index 31 to 39 (top→bottom) ──
              Positioned(
                right: 0,
                top: cornerSize,
                child: Column(
                  children: [
                    for (int i = 31; i <= 39; i++)
                      _edge(i, edgeSize, cornerSize, Side.right),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _corner(int index, double size) {
    final tile    = gameState.board[index];
    final players = gameState.players.where((p) => p.position == index).toList();
    return _CornerTile(tile: tile, index: index, size: size, players: players);
  }

  Widget _edge(int index, double edgeSize, double longSize, Side side) {
    final tile    = gameState.board[index];
    final players = gameState.players.where((p) => p.position == index).toList();
    return _EdgeTile(
      tile: tile,
      edgeSize: edgeSize,
      longSize: longSize,
      side: side,
      players: players,
    );
  }
}

// ============================================================================
// Side enum
// ============================================================================
enum Side { bottom, left, top, right }

// ============================================================================
// _EdgeTile
// ============================================================================
class _EdgeTile extends StatelessWidget {
  final Tile tile;
  final double edgeSize;
  final double longSize;
  final Side side;
  final List<Player> players;

  const _EdgeTile({
    super.key,
    required this.tile,
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
    return SizedBox(
      width: w,
      height: h,
      child: _TileContent(
        tile: tile,
        width: w,
        height: h,
        side: side,
        players: players,
      ),
    );
  }
}

// ============================================================================
// _TileContent — color strip + name + price + tokens
// ============================================================================
class _TileContent extends StatelessWidget {
  final Tile tile;
  final double width;
  final double height;
  final Side side;
  final List<Player> players;

  const _TileContent({
    super.key,
    required this.tile,
    required this.width,
    required this.height,
    required this.side,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    final isHoriz   = side == Side.bottom || side == Side.top;
    final stripSize = isHoriz ? height * 0.22 : width * 0.22;
    final hasColor  = tile.colorGroup != Colors.transparent;

    // ── Color strip ────────────────────────────────────────────────────
    Widget colorStrip = Container(
      color: hasColor ? tile.colorGroup : Colors.transparent,
      width:  isHoriz ? double.infinity : stripSize,
      height: isHoriz ? stripSize : double.infinity,
      child: tile.isOwned
          ? Center(
              child: Icon(Icons.home,
                  size: stripSize * 0.6, color: tile.owner!.tokenColor),
            )
          : null,
    );

    // ── Text content ────────────────────────────────────────────────────
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
            style: TextStyle(fontSize: width * 0.08, color: Colors.black87),
          )
        : const SizedBox.shrink();

    // ── Player tokens ───────────────────────────────────────────────────
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

    Widget textBody = Padding(
      padding: const EdgeInsets.all(1.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [nameText, priceText, tokenRow],
      ),
    );

    // Rotate text so it reads inward from each edge
    int quarterTurns = 0;
    switch (side) {
      case Side.bottom: quarterTurns = 2; break;
      case Side.left:   quarterTurns = 1; break;
      case Side.top:    quarterTurns = 0; break;
      case Side.right:  quarterTurns = 3; break;
    }
    if (quarterTurns != 0) {
      textBody = RotatedBox(quarterTurns: quarterTurns, child: textBody);
    }

    // ── Assemble strip + text based on side ────────────────────────────
    Widget body;
    switch (side) {
      case Side.bottom:
        body = Column(children: [colorStrip, Expanded(child: textBody)]);
        break;
      case Side.top:
        body = Column(children: [Expanded(child: textBody), colorStrip]);
        break;
      case Side.left:
        body = Row(children: [Expanded(child: textBody), colorStrip]);
        break;
      case Side.right:
        body = Row(children: [colorStrip, Expanded(child: textBody)]);
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

// ============================================================================
// _CornerTile
// ============================================================================
class _CornerTile extends StatelessWidget {
  final Tile tile;
  final int index;
  final double size;
  final List<Player> players;

  const _CornerTile({
    super.key,
    required this.tile,
    required this.index,
    required this.size,
    required this.players,
  });

  String get _emoji {
    switch (index) {
      case 0:  return '🚀';
      case 10: return '⛓️';
      case 20: return '🌴';
      case 30: return '🚔';
      default: return '⬛';
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
// _CenterLogo
// ============================================================================
class _CenterLogo extends StatelessWidget {
  final double size;
  const _CenterLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('🏙️', style: TextStyle(fontSize: size * 0.15)),
        Text(
          'LAGOS',
          style: TextStyle(
            fontSize: size * 0.13,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 6,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 2)),
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
// _ControlPanel
// ============================================================================
class _ControlPanel extends ConsumerWidget {
  final GameState gameState;
  const _ControlPanel({super.key, required this.gameState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    final player     = gameState.currentPlayer;
    final tile       = gameState.currentTile;

    return Container(
      color: const Color(0xFF1B2A1B),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Status message ───────────────────────────────────────────
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
          const SizedBox(height: 8),

          // ── Dice ─────────────────────────────────────────────────────
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
          const SizedBox(height: 8),

          // ── Player balances — Wrap so 8 players fit on small screens ──
          // Each card shrinks to fit; bankrupt players shown greyed out
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: gameState.players.map((p) {
              final isCurrent  = p.id == player.id;
              final isBankrupt = p.isBankrupt;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isBankrupt
                      ? Colors.white10
                      : isCurrent
                          ? p.tokenColor.withOpacity(0.25)
                          : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                  border: isCurrent && !isBankrupt
                      ? Border.all(color: p.tokenColor, width: 1.5)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 6,
                      backgroundColor:
                          isBankrupt ? Colors.grey : p.tokenColor,
                    ),
                    const SizedBox(width: 5),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.name,
                          style: TextStyle(
                            color: isBankrupt ? Colors.white38 : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            decoration: isBankrupt
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        Text(
                          isBankrupt
                              ? 'Bankrupt'
                              : '₦${_fmt(p.balance)}',
                          style: TextStyle(
                            color: isBankrupt
                                ? Colors.white38
                                : const Color(0xFFFFD600),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // ── Action buttons ───────────────────────────────────────────
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

              if (player.isInJail &&
                  gameState.phase == GamePhase.waitingToRoll)
                _ActionButton(
                  label: '💸  Pay ₦5,000 Fine',
                  color: const Color(0xFFEF5350),
                  onTap: controller.payJailFine,
                ),

              // End Game — always visible so players can quit anytime
              _ActionButton(
                label: gameState.phase == GamePhase.gameOver
                    ? '🔄  New Game'
                    : '🚪  End Game',
                color: const Color(0xFF37474F),
                onTap: () => _confirmEndGame(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Confirmation dialog before ending mid-game ───────────────────────────
  void _confirmEndGame(BuildContext context, WidgetRef ref) {
    // If game is already over, go straight back to lobby
    if (gameState.phase == GamePhase.gameOver) {
      _goToLobby(context);
      return;
    }

    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A1B),
        title: const Text('End Game?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to end the current game and return to the lobby?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, true);
              _goToLobby(context);
            },
            child: const Text('End Game',
                style: TextStyle(
                    color: Color(0xFFEF5350), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _goToLobby(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LobbyScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (route) => false,
    );
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

// ============================================================================
// _DieBox
// ============================================================================
class _DieBox extends StatelessWidget {
  final int value;
  const _DieBox({super.key, required this.value});

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
          BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(1, 2)),
        ],
      ),
      child: Center(
        child: Text(faces[value], style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}

// ============================================================================
// _ActionButton
// ============================================================================
class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionButton({
    super.key,
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
                color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
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
