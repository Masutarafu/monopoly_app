import 'package:flutter/material.dart';
import 'player.dart';

// ---------------------------------------------------------------------------
// TileType Enum
// ---------------------------------------------------------------------------
// Defines the category of each space on the board.
// Keeping this as an enum (not a set of booleans) means adding a new tile
// type later (e.g. CommunityChest) only requires one change here.
// ---------------------------------------------------------------------------
enum TileType {
  property,   // Buyable land / street
  railroad,   // Buyable railroad
  utility,    // Buyable utility (Electric Co., Water Works)
  tax,        // Go to Jail, Income Tax, Luxury Tax
  corner,     // GO, Jail/Just Visiting, Free Parking, Go To Jail
  chance,     // Chance card space
  community,  // Community Chest card space
}

// ---------------------------------------------------------------------------
// Tile Model
// ---------------------------------------------------------------------------
// Immutable data describing a single board space.
//
// The owner is an immutable Player copy, not a reference into the live player
// list — ownership changes therefore produce a new Tile via copyWith(), never
// an in-place mutation. Combined with toJson()/fromJson() this keeps the
// board fully transportable for save/load and multiplayer sync.
// ---------------------------------------------------------------------------
class Tile {
  final String name;
  final TileType type;
  final Color colorGroup;      // Colors.transparent for non-property tiles
  final int price;             // 0 for non-buyable tiles
  final int baseRent;          // 0 for non-buyable tiles
  final bool isMortgaged;      // Mortgaged tiles collect no rent
  final Player? owner;         // Immutable — changes via copyWith()

  const Tile({
    required this.name,
    required this.type,
    this.colorGroup = Colors.transparent,
    this.price = 0,
    this.baseRent = 0,
    this.isMortgaged = false,
    this.owner,
  });

  // -------------------------------------------------------------------------
  // Computed helpers
  // -------------------------------------------------------------------------

  bool get isBuyable =>
      (type == TileType.property ||
       type == TileType.railroad ||
       type == TileType.utility) &&
      price > 0;

  bool get isOwned => owner != null;

  // Returns the rent owed to the owner when a player lands here.
  // A mortgaged property never collects rent — regardless of type or group
  // completeness. (Full rent tables with houses/hotels come in a later task.)
  int get currentRent => isOwned && !isMortgaged ? baseRent : 0;

  // Rent resolved per tile type at the moment of landing. Houses/hotels and
  // group-complete doubling are a later task and intentionally omitted here.
  //
  //   • property  → baseRent
  //   • railroad  → scales with how many railroads the owner holds
  //                 (1 RR = ₦2,500 · 2 = ₦5,000 · 3 = ₦10,000 · 4 = ₦20,000)
  //   • utility   → scales with the dice roll total and how many utilities the
  //                 owner holds (1 utility = 4× · both = 10×, ×100 Naira scale)
  int currentRentFor({int rollTotal = 0, int ownedCount = 0}) {
    if (!isOwned || isMortgaged) return 0;
    switch (type) {
      case TileType.utility:
        return rollTotal * (ownedCount >= 2 ? 1000 : 400);
      case TileType.railroad:
        if (ownedCount <= 0) return 0;
        return 2500 * (1 << (ownedCount - 1));
      default:
        return baseRent;
    }
  }

  // -------------------------------------------------------------------------
  // copyWith — produces a new Tile with selective field overrides
  // -------------------------------------------------------------------------
  Tile copyWith({
    String? name,
    TileType? type,
    Color? colorGroup,
    int? price,
    int? baseRent,
    bool? isMortgaged,
    Player? owner,
    bool clearOwner = false,
  }) {
    return Tile(
      name: name ?? this.name,
      type: type ?? this.type,
      colorGroup: colorGroup ?? this.colorGroup,
      price: price ?? this.price,
      baseRent: baseRent ?? this.baseRent,
      isMortgaged: isMortgaged ?? this.isMortgaged,
      owner: clearOwner ? null : (owner ?? this.owner),
    );
  }

  // -------------------------------------------------------------------------
  // JSON serialization
  // -------------------------------------------------------------------------
  // colorGroup is encoded as its 32-bit ARGB integer (0 for
  // Colors.transparent) so the group color survives any transport.
  // -------------------------------------------------------------------------
  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'colorGroup': colorGroup.toARGB32(),
        'price': price,
        'baseRent': baseRent,
        'isMortgaged': isMortgaged,
        'owner': owner?.toJson(),
      };

  factory Tile.fromJson(Map<String, dynamic> json) => Tile(
        name: json['name'] as String,
        type: TileType.values.byName(json['type'] as String),
        colorGroup: Color(json['colorGroup'] as int),
        price: json['price'] as int,
        baseRent: json['baseRent'] as int,
        // Defaults to false for tiles saved before mortgage support existed.
        isMortgaged: (json['isMortgaged'] as bool?) ?? false,
        owner: json['owner'] == null
            ? null
            : Player.fromJson(json['owner'] as Map<String, dynamic>),
      );

  @override
  String toString() => 'Tile($name, $type, \$$price)';
}
