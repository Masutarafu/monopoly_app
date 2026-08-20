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
// Player is a fully immutable value object. Every change produces a new
// instance via copyWith(), and toJson()/fromJson() make the whole game state
// transportable — the foundation for save/load, pass-and-play multiplayer and
// network sync.
// ---------------------------------------------------------------------------
class Player {
  final String id;          // Unique identifier (e.g. 'player_1')
  final String name;        // Display name
  final Color tokenColor;   // Color used to render the token on the board

  final int position;       // Board index 0–39 (0 = GO)
  final int balance;        // Cash on hand in dollars
  final PlayerStatus status;
  final int jailTurns;      // Counts turns spent in jail (max 3 before forced pay)
  final List<int> ownedTileIndices; // Indices into the board tile list
  final List<String> heldJailFreeCards; // "Get Out of Jail Free" card ids held

  Player({
    required this.id,
    required this.name,
    required this.tokenColor,
    this.position = 0,
    this.balance = 1500,    // Standard Monopoly starting cash
    this.status = PlayerStatus.active,
    this.jailTurns = 0,
    List<int>? ownedTileIndices,
    List<String>? heldJailFreeCards,
  })  : ownedTileIndices = ownedTileIndices ?? [],
        heldJailFreeCards = heldJailFreeCards ?? [];

  // -------------------------------------------------------------------------
  // Computed helpers
  // -------------------------------------------------------------------------

  bool get isInJail => status == PlayerStatus.inJail;
  bool get isBankrupt => status == PlayerStatus.bankrupt;
  bool get isActive => status == PlayerStatus.active;

  // -------------------------------------------------------------------------
  // copyWith — produces a new Player with selective field overrides
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
    List<String>? heldJailFreeCards,
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
      heldJailFreeCards:
          heldJailFreeCards ?? List.from(this.heldJailFreeCards),
    );
  }

  // -------------------------------------------------------------------------
  // JSON serialization
  // -------------------------------------------------------------------------
  // tokenColor is encoded as its 32-bit ARGB integer so it survives any
  // transport (file, clipboard, wire).
  // -------------------------------------------------------------------------
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tokenColor': tokenColor.toARGB32(),
        'position': position,
        'balance': balance,
        'status': status.name,
        'jailTurns': jailTurns,
        'ownedTileIndices': ownedTileIndices,
        'heldJailFreeCards': heldJailFreeCards,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        name: json['name'] as String,
        tokenColor: Color(json['tokenColor'] as int),
        position: json['position'] as int,
        balance: json['balance'] as int,
        status: PlayerStatus.values.byName(json['status'] as String),
        jailTurns: json['jailTurns'] as int,
        ownedTileIndices:
            (json['ownedTileIndices'] as List).cast<int>(),
        // Defaults for snapshots saved before the card pipeline existed.
        heldJailFreeCards:
            (json['heldJailFreeCards'] as List?)?.cast<String>() ?? [],
      );

  @override
  String toString() => 'Player($name, pos:$position, \$$balance, $status)';
}
