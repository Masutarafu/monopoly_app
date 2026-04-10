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
  landedOnProperty, // Waiting for buy / pass decision
  payingRent,       // Animation/confirmation for rent payment
  inJailDecision,   // Jailed player deciding what to do
  gameOver,         // A winner has been declared
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
  final String? message;            // Status message shown in the UI

  const GameState({
    required this.players,
    required this.board,
    required this.currentPlayerIndex,
    required this.phase,
    this.lastDie1 = 0,
    this.lastDie2 = 0,
    this.message,
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
    String? message,
    bool clearMessage = false,
  }) {
    return GameState(
      players: players ?? this.players,
      board: board ?? this.board,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      phase: phase ?? this.phase,
      lastDie1: lastDie1 ?? this.lastDie1,
      lastDie2: lastDie2 ?? this.lastDie2,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
