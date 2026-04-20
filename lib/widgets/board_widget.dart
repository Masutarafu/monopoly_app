import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/game_controller.dart';
import '../models/game_state.dart';
import '../models/tile.dart';
import '../flame/lagos_game_board.dart';
import 'lobby_screen.dart';
import 'tile_info_sheet.dart';

// ============================================================================
// BoardWidget — top-level screen during gameplay
// ============================================================================
// Architecture:
//   - GameWidget (Flame) owns the board surface (tiles, tokens, dice)
//   - _ControlPanel (Flutter) owns the action buttons and player balances
//   - Flame fires callbacks into Flutter; Flutter calls GameController methods
//   - GameController state flows into Flame via the gameBridgeProvider stream
// ============================================================================
class BoardWidget extends ConsumerStatefulWidget {
  const BoardWidget({super.key});

  @override
  ConsumerState<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends ConsumerState<BoardWidget> {
  LagosGameBoard? _flameGame;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_flameGame == null) {
      _initFlameGame();
    }
  }

  void _initFlameGame() {
    // Read the stream from the bridge provider
    final stream = ref.read(gameBridgeProvider.stream);

    _flameGame = LagosGameBoard(
      gameStateStream: stream,

      // Tile tapped → show Flutter bottom sheet
      onTileTapped: (index, board) {
        if (!mounted) return;
        TileInfoSheet.show(context, board[index], index);
      },

      // Roll animation finished → unblock the controller
      onRollAnimationComplete: () {
        // Currently the controller processes state synchronously, so no
        // action needed here. This hook is ready for when we add the
        // "wait for animation before evaluating landing" feature.
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameControllerProvider);

    return Column(
      children: [
        // ── Flame board surface ──────────────────────────────────────────
        Expanded(
          child: GameWidget(game: _flameGame!),
        ),

        // ── Flutter control panel ────────────────────────────────────────
        _ControlPanel(gameState: gameState),
      ],
    );
  }
}

// ============================================================================
// _ControlPanel — unchanged Flutter UI below the Flame board
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

          // ── Player balances ──────────────────────────────────────────
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
                            isBankrupt ? Colors.grey : p.tokenColor),
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
                          isBankrupt ? 'Bankrupt' : '₦${_fmt(p.balance)}',
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

  void _confirmEndGame(BuildContext context, WidgetRef ref) {
    if (gameState.phase == GamePhase.gameOver) {
      _goToLobby(context);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A1B),
        title: const Text('End Game?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Return to the lobby and start a new game?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
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
        child: Text(label,
            style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ),
    );
  }
}
