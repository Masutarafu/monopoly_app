import 'tile.dart';
import 'player.dart';

// ---------------------------------------------------------------------------
// GamePhase Enum
// ---------------------------------------------------------------------------
// Tracks what the game is currently waiting for.
// The UI uses this to enable/disable buttons (e.g. "Roll Dice" is only
// available during the rolling phase, not after a player has landed).
// ---------------------------------------------------------------------------
enum GamePhase {
  waitingToRoll,    // Current player hasn't rolled yet
  animating,        // Dice/token animation playing; landing not yet resolved
  landedOnProperty, // Waiting for buy / pass decision
  payingRent,       // Animation/confirmation for rent payment
  inJailDecision,   // Jailed player deciding what to do
  liquidating,      // Player owes a debt they can't cover in cash — must
                    // mortgage assets until pendingDebt can be settled
  gameOver,         // A winner has been declared
}

// ---------------------------------------------------------------------------
// PendingRentModifier Enum
// ---------------------------------------------------------------------------
// Set by "advance to the nearest …" cards and consumed by the very next rent
// evaluation when the player lands there.
//   • doubleRent      → nearest railroad card: rent × 2
//   • utilityTenDice  → nearest utility card: rent = lastRollTotal × 1000
// ---------------------------------------------------------------------------
enum PendingRentModifier {
  none,
  doubleRent,
  utilityTenDice,
}

// ---------------------------------------------------------------------------
// GameState — immutable snapshot of the entire game
// ---------------------------------------------------------------------------
// Architecture note: Riverpod's StateNotifier requires that state be replaced
// (not mutated) so the UI can diff old vs new and rebuild only what changed.
// GameState is therefore a value object — every "change" produces a new
// instance via copyWith().
// ---------------------------------------------------------------------------
class GameState {
  final List<Player> players;
  final List<Tile> board;
  final int currentPlayerIndex;     // Index into players list
  final GamePhase phase;
  final int lastDie1;               // Last roll result, die 1
  final int lastDie2;               // Last roll result, die 2
final int consecutiveDoubles;     // Doubles rolled in a row this turn
                                  // sequence (3 in a row → Jail)
  final int pendingDebt;            // Debt owed during liquidation (0 otherwise)
  final String? debtCreditorId;     // Player owed the pending debt; null = bank
  final String? message;            // Status message shown in the UI

  // ── Card pipeline state ─────────────────────────────────────────────────
  final List<String> chanceDeckQueue;      // Remaining Chance card ids (top first)
  final List<String> communityDeckQueue;   // Remaining Community Chest card ids
  final bool showCardModal;                // UI should show the drawn-card modal
  final String? drawnCardId;               // Card id currently in the modal (or pending)
  final String? cardResult;                // Result text shown under the card
  final int? pendingLandingIndex;          // Deferred landing for movement cards
  final bool pendingTurnEnd;               // Advance the turn after the modal dismisses
  final PendingRentModifier pendingRentModifier; // Rent boost from a nearest-* card

  const GameState({
    required this.players,
    required this.board,
    required this.currentPlayerIndex,
    required this.phase,
    this.lastDie1 = 0,
    this.lastDie2 = 0,
    this.consecutiveDoubles = 0,
    this.pendingDebt = 0,
    this.debtCreditorId,
    this.message,
    this.chanceDeckQueue = const [],
    this.communityDeckQueue = const [],
    this.showCardModal = false,
    this.drawnCardId,
    this.cardResult,
    this.pendingLandingIndex,
    this.pendingTurnEnd = false,
    this.pendingRentModifier = PendingRentModifier.none,
  });

  // -------------------------------------------------------------------------
  // Computed helpers
  // -------------------------------------------------------------------------

  Player get currentPlayer => players[currentPlayerIndex];

  int get lastRollTotal => lastDie1 + lastDie2;

  bool get isDoubles => lastDie1 == lastDie2 && lastDie1 > 0;

  // Returns the active (non-bankrupt) players
  List<Player> get activePlayers =>
      players.where((p) => !p.isBankrupt).toList();

  // Returns the tile the current player is standing on
  Tile get currentTile => board[currentPlayer.position];

  // -------------------------------------------------------------------------
  // copyWith — produces a new GameState with selective field overrides
  // -------------------------------------------------------------------------
  GameState copyWith({
    List<Player>? players,
    List<Tile>? board,
    int? currentPlayerIndex,
    GamePhase? phase,
    int? lastDie1,
    int? lastDie2,
    int? consecutiveDoubles,
    int? pendingDebt,
    String? debtCreditorId,
    String? message,
    bool clearMessage = false,
    List<String>? chanceDeckQueue,
    List<String>? communityDeckQueue,
    bool? showCardModal,
    String? drawnCardId,
    bool clearDrawnCard = false,
    String? cardResult,
    bool clearCardResult = false,
    int? pendingLandingIndex,
    bool clearPendingLandingIndex = false,
    bool? pendingTurnEnd,
    PendingRentModifier? pendingRentModifier,
  }) {
    return GameState(
      players: players ?? this.players,
      board: board ?? this.board,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      phase: phase ?? this.phase,
      lastDie1: lastDie1 ?? this.lastDie1,
      lastDie2: lastDie2 ?? this.lastDie2,
      consecutiveDoubles: consecutiveDoubles ?? this.consecutiveDoubles,
      pendingDebt: pendingDebt ?? this.pendingDebt,
      debtCreditorId: debtCreditorId ?? this.debtCreditorId,
      message: clearMessage ? null : (message ?? this.message),
      chanceDeckQueue: chanceDeckQueue ?? this.chanceDeckQueue,
      communityDeckQueue: communityDeckQueue ?? this.communityDeckQueue,
      showCardModal: showCardModal ?? this.showCardModal,
      drawnCardId: clearDrawnCard ? null : (drawnCardId ?? this.drawnCardId),
      cardResult: clearCardResult ? null : (cardResult ?? this.cardResult),
      pendingLandingIndex: clearPendingLandingIndex
          ? null
          : (pendingLandingIndex ?? this.pendingLandingIndex),
      pendingTurnEnd: pendingTurnEnd ?? this.pendingTurnEnd,
      pendingRentModifier:
          pendingRentModifier ?? this.pendingRentModifier,
    );
  }

  // -------------------------------------------------------------------------
  // JSON serialization
  // -------------------------------------------------------------------------
  // The full game snapshot in a plain Dart map — ready for jsonEncode() so it
  // can be saved to a file, shared as pass-and-play, or broadcast to peers.
  // -------------------------------------------------------------------------
  Map<String, dynamic> toJson() => {
        'players': players.map((p) => p.toJson()).toList(),
        'board': board.map((t) => t.toJson()).toList(),
        'currentPlayerIndex': currentPlayerIndex,
        'phase': phase.name,
        'lastDie1': lastDie1,
        'lastDie2': lastDie2,
        'consecutiveDoubles': consecutiveDoubles,
        'pendingDebt': pendingDebt,
        'debtCreditorId': debtCreditorId,
        'message': message,
        'chanceDeckQueue': chanceDeckQueue,
        'communityDeckQueue': communityDeckQueue,
        'showCardModal': showCardModal,
        'drawnCardId': drawnCardId,
        'cardResult': cardResult,
        'pendingLandingIndex': pendingLandingIndex,
        'pendingTurnEnd': pendingTurnEnd,
        'pendingRentModifier': pendingRentModifier.name,
      };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
        players: (json['players'] as List)
            .map((p) => Player.fromJson(p as Map<String, dynamic>))
            .toList(),
        board: (json['board'] as List)
            .map((t) => Tile.fromJson(t as Map<String, dynamic>))
            .toList(),
        currentPlayerIndex: json['currentPlayerIndex'] as int,
        phase: GamePhase.values.byName(json['phase'] as String),
        lastDie1: json['lastDie1'] as int,
        lastDie2: json['lastDie2'] as int,
        // Defaults to 0 for snapshots saved before this counter existed.
        consecutiveDoubles: (json['consecutiveDoubles'] as int?) ?? 0,
        // Defaults for snapshots saved before liquidation support existed.
        pendingDebt: (json['pendingDebt'] as int?) ?? 0,
        debtCreditorId: json['debtCreditorId'] as String?,
        message: json['message'] as String?,
        // Defaults for snapshots saved before the card pipeline existed.
        chanceDeckQueue: (json['chanceDeckQueue'] as List?)?.cast<String>() ?? [],
        communityDeckQueue:
            (json['communityDeckQueue'] as List?)?.cast<String>() ?? [],
        showCardModal: (json['showCardModal'] as bool?) ?? false,
        drawnCardId: json['drawnCardId'] as String?,
        cardResult: json['cardResult'] as String?,
        pendingLandingIndex: json['pendingLandingIndex'] as int?,
        pendingTurnEnd: (json['pendingTurnEnd'] as bool?) ?? false,
        pendingRentModifier: PendingRentModifier.values
                .asNameMap()[json['pendingRentModifier']] ??
            PendingRentModifier.none,
      );
}
