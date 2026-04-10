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
// Using const constructors where possible keeps memory usage low and makes
// the 40-tile board list compile-time constant.
// ---------------------------------------------------------------------------
class Tile {
  final String name;
  final TileType type;
  final Color colorGroup;      // Colors.transparent for non-property tiles
  final int price;             // 0 for non-buyable tiles
  final int baseRent;          // 0 for non-buyable tiles
  Player? owner;               // Mutable — changes during gameplay

  Tile({
    required this.name,
    required this.type,
    this.colorGroup = Colors.transparent,
    this.price = 0,
    this.baseRent = 0,
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
  // (Simplified: full rent tables with houses/hotels come in a later task.)
  int get currentRent => isOwned ? baseRent : 0;

  @override
  String toString() => 'Tile($name, $type, \$$price)';
}
