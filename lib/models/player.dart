import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// PlayerStatus Enum
// ---------------------------------------------------------------------------
enum PlayerStatus {
  active,     // Normal play
  inJail,     // Sitting in jail, must roll doubles or pay to leave
  bankrupt,   // Eliminated from the game
}

// ---------------------------------------------------------------------------
// Player Model
// ---------------------------------------------------------------------------
// Represents all mutable state that belongs to a single player.
//
// Architecture note: Player is a plain Dart class (not a ChangeNotifier).
// The GameController (StateNotifier) owns a List<Player> and is responsible
// for producing new copies of the list whenever state changes — keeping our
// data flow unidirectional and predictable.
// ---------------------------------------------------------------------------
class Player {
  final String id;          // Unique identifier (e.g. 'player_1')
  final String name;        // Display name
  final Color tokenColor;   // Color used to render the token on the board

  int position;             // Board index 0–39 (0 = GO)
  int balance;              // Cash on hand in dollars
  PlayerStatus status;
  int jailTurns;            // Counts turns spent in jail (max 3 before forced pay)
  List<int> ownedTileIndices; // Indices into the board tile list

  Player({
    required this.id,
    required this.name,
    required this.tokenColor,
    this.position = 0,
    this.balance = 1500,    // Standard Monopoly starting cash
    this.status = PlayerStatus.active,
    this.jailTurns = 0,
    List<int>? ownedTileIndices,
  }) : ownedTileIndices = ownedTileIndices ?? [];

  // -------------------------------------------------------------------------
  // Computed helpers
  // -------------------------------------------------------------------------

  bool get isInJail => status == PlayerStatus.inJail;
  bool get isBankrupt => status == PlayerStatus.bankrupt;
  bool get isActive => status == PlayerStatus.active;

  // -------------------------------------------------------------------------
  // copyWith — used by GameController to produce immutable state snapshots
  // -------------------------------------------------------------------------
  // Riverpod's StateNotifier works best when you replace state rather than
  // mutate it in place. copyWith makes that clean and readable.
  // -------------------------------------------------------------------------
  Player copyWith({
    String? id,
    String? name,
    Color? tokenColor,
    int? position,
    int? balance,
    PlayerStatus? status,
    int? jailTurns,
    List<int>? ownedTileIndices,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      tokenColor: tokenColor ?? this.tokenColor,
      position: position ?? this.position,
      balance: balance ?? this.balance,
      status: status ?? this.status,
      jailTurns: jailTurns ?? this.jailTurns,
      ownedTileIndices: ownedTileIndices ?? List.from(this.ownedTileIndices),
    );
  }

  @override
  String toString() => 'Player($name, pos:$position, \$$balance, $status)';
}
