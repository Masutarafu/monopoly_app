import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/game_controller.dart';
import '../models/game_state.dart';
import '../models/card_model.dart';
import '../models/board_data.dart';
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
    final stream = ref.read(gameBridgeProvider);

    _flameGame = LagosGameBoard(
      gameStateStream: stream,

      // Tile tapped → show Flutter bottom sheet
      onTileTapped: (index, board) {
        if (!mounted) return;
        TileInfoSheet.show(context, board[index], index);
      },

      // Roll animation finished → let the controller apply the roll
      onRollAnimationComplete: () {
        if (!mounted) return;
        ref.read(gameControllerProvider.notifier).resolveRoll();
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
          child: Stack(
            children: [
              Positioned.fill(child: GameWidget(game: _flameGame!)),
              // Interactive zoom / pan controls overlay
              Positioned(
                top: 8,
                right: 8,
                child: _ZoomControls(game: _flameGame!),
              ),
              const Positioned(
                left: 8,
                bottom: 8,
                child: _ZoomHint(),
              ),
              // Drawn-card modal (topmost)
              if (gameState.showCardModal)
                Positioned.fill(child: _CardModal(gameState: gameState)),
            ],
          ),
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

              if (player.isInJail &&
                  gameState.phase == GamePhase.waitingToRoll &&
                  player.heldJailFreeCards.isNotEmpty)
                _ActionButton(
                  label: '🎁  Use Jail-Free Card',
                  color: const Color(0xFF8E24AA),
                  onTap: controller.useJailFreeCard,
                ),

              if (gameState.phase == GamePhase.liquidating)
                _ActionButton(
                  label: '💸  Settle Debt ₦${_fmt(gameState.pendingDebt)}',
                  color: const Color(0xFFEF5350),
                  onTap: controller.settleDebt,
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

// ============================================================================
// _ZoomControls — floating zoom buttons + level readout over the board
// ============================================================================
class _ZoomControls extends StatelessWidget {
  final LagosGameBoard game;
  const _ZoomControls({required this.game});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: game.zoomLevelNotifier,
      builder: (context, zoom, _) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ZoomButton(icon: Icons.add, onTap: game.zoomIn),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${(zoom * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _ZoomButton(icon: Icons.remove, onTap: game.zoomOut),
              _ZoomButton(icon: Icons.fit_screen, onTap: game.resetView),
            ],
          ),
        );
      },
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

// ============================================================================
// _ZoomHint — discoverability hint for the interactive view controls
// ============================================================================
class _ZoomHint extends StatelessWidget {
  const _ZoomHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Scroll / pinch to zoom · drag to pan',
        style: TextStyle(color: Colors.white70, fontSize: 11),
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

// ============================================================================
// _CardModal — overlay showing the drawn Chance / Community Chest card
// ============================================================================
class _CardModal extends ConsumerWidget {
  final GameState gameState;
  const _CardModal({required this.gameState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(gameControllerProvider.notifier);
    final card = gameState.drawnCardId == null
        ? null
        : BoardData.cardById(gameState.drawnCardId!);
    if (card == null) return const SizedBox.shrink();

    final isChance = card.deck == CardDeck.chance;
    final deckColor =
        isChance ? const Color(0xFF7B1FA2) : const Color(0xFF1565C0);
    final deckLabel = isChance ? 'CHANCE' : 'COMMUNITY CHEST';

    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 36),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: deckColor, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                deckLabel,
                style: TextStyle(
                  color: deckColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                card.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF3E2723),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              if (gameState.cardResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: deckColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    gameState.cardResult!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFF4E342E), fontSize: 12.5),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _ActionButton(
                label: 'OK',
                color: deckColor,
                onTap: controller.dismissCard,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
