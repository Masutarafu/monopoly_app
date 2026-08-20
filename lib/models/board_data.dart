import 'package:flutter/material.dart';
import 'card_model.dart';
import 'tile.dart';

// ---------------------------------------------------------------------------
// Lagos Monopoly — BoardData
// ---------------------------------------------------------------------------
// Property groups mapped to Lagos districts by prestige:
//   Brown     → Agege / Mushin        (budget mainland)
//   LightBlue → Yaba / Ebute Metta   (student / tech belt)
//   Pink      → Surulere             (cultural heartbeat)
//   Orange    → Ikeja                (mainland capital)
//   Red       → Apapa / Festac       (port & heritage)
//   Yellow    → Lekki Phase 1        (new money island)
//   Green     → Ikoyi                (old money elite)
//   DarkBlue  → Victoria Island      (the apex)
//
// Railroads → Lagos bridges & transit (Carter, Eko, Third Mainland, BRT)
// Utilities  → EKEDC & Lagos Water Corporation
// Currency   → Nigerian Naira (₦)
// ---------------------------------------------------------------------------
abstract class BoardData {
  // ── Color group constants ─────────────────────────────────────────────
  static const Color agege        = Color(0xFF8B4513);
  static const Color yaba         = Color(0xFF4FC3F7);
  static const Color surulere     = Color(0xFFEC407A);
  static const Color ikeja        = Color(0xFFFFA726);
  static const Color apapa        = Color(0xFFEF5350);
  static const Color lekki        = Color(0xFFFFEE58);
  static const Color ikoyi        = Color(0xFF66BB6A);
  static const Color vi           = Color(0xFF1565C0);
  static const Color bridgeGray   = Color(0xFF78909C);
  static const Color utilityAmber = Color(0xFFFFD54F);

  // ── Board constants ───────────────────────────────────────────────────
  static const int    jailIndex      = 10;
  static const int    goToJailIndex  = 30;
  static const int    goIndex        = 0;
  static const int    goSalary       = 20000;
  static const int    jailFine       = 5000;
  static const int    boardSize      = 40;
  static const String currencySymbol = '₦';

  static List<Tile> buildBoard() => [
    // ── BOTTOM ROW (0–9) ─────────────────────────────────────────────
    const Tile(name: 'GO',                       type: TileType.corner),
    const Tile(name: 'Agege Market Rd',          type: TileType.property,  colorGroup: agege,        price: 6000,   baseRent: 200),
    const Tile(name: 'Community Chest',          type: TileType.community),
    const Tile(name: 'Mushin Road',              type: TileType.property,  colorGroup: agege,        price: 6000,   baseRent: 400),
    const Tile(name: 'LIRS Tax',                 type: TileType.tax,       price: 20000),
    const Tile(name: 'Carter Bridge',            type: TileType.railroad,  colorGroup: bridgeGray,   price: 20000,  baseRent: 2500),
    const Tile(name: 'Herbert Macaulay Way',     type: TileType.property,  colorGroup: yaba,         price: 10000,  baseRent: 600),
    const Tile(name: 'Chance',                   type: TileType.chance),
    const Tile(name: 'Iwaya Road',               type: TileType.property,  colorGroup: yaba,         price: 10000,  baseRent: 600),
    const Tile(name: 'Commercial Ave, Yaba',     type: TileType.property,  colorGroup: yaba,         price: 12000,  baseRent: 800),

    // ── LEFT COLUMN (10–19) ───────────────────────────────────────────
    const Tile(name: 'Jail / Just Visiting',     type: TileType.corner),
    const Tile(name: 'Bode Thomas Street',       type: TileType.property,  colorGroup: surulere,     price: 14000,  baseRent: 1000),
    const Tile(name: 'EKEDC (Electricity)',      type: TileType.utility,   colorGroup: utilityAmber, price: 15000,  baseRent: 0),
    const Tile(name: 'Adeniran Ogunsanya St',    type: TileType.property,  colorGroup: surulere,     price: 14000,  baseRent: 1000),
    const Tile(name: 'Ogunlana Drive',           type: TileType.property,  colorGroup: surulere,     price: 16000,  baseRent: 1200),
    const Tile(name: 'Eko Bridge',               type: TileType.railroad,  colorGroup: bridgeGray,   price: 20000,  baseRent: 2500),
    const Tile(name: 'Allen Avenue, Ikeja',      type: TileType.property,  colorGroup: ikeja,        price: 18000,  baseRent: 1400),
    const Tile(name: 'Community Chest',          type: TileType.community),
    const Tile(name: 'Toyin Street, Ikeja',      type: TileType.property,  colorGroup: ikeja,        price: 18000,  baseRent: 1400),
    const Tile(name: 'Adeniyi Jones Ave',        type: TileType.property,  colorGroup: ikeja,        price: 20000,  baseRent: 1600),

    // ── TOP ROW (20–29) ───────────────────────────────────────────────
    const Tile(name: 'Freedom Park',             type: TileType.corner),
    const Tile(name: 'Creek Road, Apapa',        type: TileType.property,  colorGroup: apapa,        price: 22000,  baseRent: 1800),
    const Tile(name: 'Chance',                   type: TileType.chance),
    const Tile(name: 'FESTAC Link Road',         type: TileType.property,  colorGroup: apapa,        price: 22000,  baseRent: 1800),
    const Tile(name: 'Ahmadu Bello Way',         type: TileType.property,  colorGroup: apapa,        price: 24000,  baseRent: 2000),
    const Tile(name: 'Third Mainland Bridge',    type: TileType.railroad,  colorGroup: bridgeGray,   price: 20000,  baseRent: 2500),
    const Tile(name: 'Lekki-Epe Expressway',     type: TileType.property,  colorGroup: lekki,        price: 26000,  baseRent: 2200),
    const Tile(name: 'Admiralty Way, Lekki',     type: TileType.property,  colorGroup: lekki,        price: 26000,  baseRent: 2200),
    const Tile(name: 'Lagos Water Corp',         type: TileType.utility,   colorGroup: utilityAmber, price: 15000,  baseRent: 0),
    const Tile(name: 'Chevron Drive, Lekki',     type: TileType.property,  colorGroup: lekki,        price: 28000,  baseRent: 2400),

    // ── RIGHT COLUMN (30–39) ──────────────────────────────────────────
    const Tile(name: 'LASTMA Checkpoint',        type: TileType.corner),
    const Tile(name: 'Awolowo Road, Ikoyi',      type: TileType.property,  colorGroup: ikoyi,        price: 30000,  baseRent: 2600),
    const Tile(name: 'Glover Road, Ikoyi',       type: TileType.property,  colorGroup: ikoyi,        price: 30000,  baseRent: 2600),
    const Tile(name: 'Community Chest',          type: TileType.community),
    const Tile(name: 'Bourdillon Road, Ikoyi',   type: TileType.property,  colorGroup: ikoyi,        price: 32000,  baseRent: 2800),
    const Tile(name: 'Lagos BRT Route',          type: TileType.railroad,  colorGroup: bridgeGray,   price: 20000,  baseRent: 2500),
    const Tile(name: 'Chance',                   type: TileType.chance),
    const Tile(name: 'Adeola Odeku St, VI',      type: TileType.property,  colorGroup: vi,           price: 35000,  baseRent: 3500),
    const Tile(name: 'Luxury Tax',               type: TileType.tax,       price: 7500),
    const Tile(name: 'Ozumba Mbadiwe Ave',       type: TileType.property,  colorGroup: vi,           price: 40000,  baseRent: 5000),
  ];

  // ── Card decks ─────────────────────────────────────────────────────────
  // Static, immutable card definitions. The controller keeps a per-deck draw
  // queue in GameState (card ids only) so cards serialise trivially; the deck
  // itself never changes, so it can live here as compile-time consts.
  // Board indices referenced by movement cards: Commercial Ave Yaba = 9,
  // Carter Bridge = 5, Ogunlana Drive = 14, Adeola Odeku St VI = 37.
  static const List<CardModel> chanceDeck = [
    CardModel(id: 'chance_advance_go', deck: CardDeck.chance,
        text: 'Advance to GO. Collect ₦20,000.', type: CardType.advanceToGo),
    CardModel(id: 'chance_advance_commercial', deck: CardDeck.chance,
        text: 'Advance to Commercial Ave, Yaba. If you pass GO, collect ₦20,000.',
        type: CardType.advanceToTile, targetIndex: 9),
    CardModel(id: 'chance_advance_ogunlana', deck: CardDeck.chance,
        text: 'Advance to Ogunlana Drive, Surulere. If you pass GO, collect ₦20,000.',
        type: CardType.advanceToTile, targetIndex: 14),
    CardModel(id: 'chance_nearest_utility', deck: CardDeck.chance,
        text: 'Advance to the nearest utility. If unowned, you may buy it. '
            'If owned, pay 10× the dice roll.',
        type: CardType.nearestUtility),
    CardModel(id: 'chance_nearest_railroad', deck: CardDeck.chance,
        text: 'Advance to the nearest railroad. Pay 2× rent if owned.',
        type: CardType.nearestRailroad),
    CardModel(id: 'chance_bank_dividend', deck: CardDeck.chance,
        text: 'The bank pays you a dividend of ₦5,000.',
        type: CardType.collect, amount: 5000),
    CardModel(id: 'chance_jail_free', deck: CardDeck.chance,
        text: 'Get Out of Jail Free. This card may be kept until needed.',
        type: CardType.getOutOfJailFree),
    CardModel(id: 'chance_back_3', deck: CardDeck.chance,
        text: 'Go back three spaces.', type: CardType.moveBack3),
    CardModel(id: 'chance_go_jail', deck: CardDeck.chance,
        text: 'Go directly to Jail. Do not pass GO, do not collect ₦20,000.',
        type: CardType.goToJail),
    CardModel(id: 'chance_general_repairs', deck: CardDeck.chance,
        text: 'You have been assessed for general repairs: ₦2,500 per house, '
            '₦10,000 per hotel.',
        type: CardType.streetRepairs, houseFee: 2500, hotelFee: 10000),
    CardModel(id: 'chance_poor_tax', deck: CardDeck.chance,
        text: 'Pay poor tax of ₦1,500.', type: CardType.pay, amount: 1500),
    CardModel(id: 'chance_trip_carter', deck: CardDeck.chance,
        text: 'Take a trip on Carter Bridge. Advance to Carter Bridge.',
        type: CardType.advanceToTile, targetIndex: 5),
    CardModel(id: 'chance_walk_adeola', deck: CardDeck.chance,
        text: 'Take a walk on Adeola Odeku St, VI. Advance to Adeola Odeku St.',
        type: CardType.advanceToTile, targetIndex: 37),
    CardModel(id: 'chance_chairman', deck: CardDeck.chance,
        text: 'You have been elected Chairman of the board. Pay each player ₦5,000.',
        type: CardType.playerTransfer, amount: 5000, paysEach: true),
    CardModel(id: 'chance_building_loan', deck: CardDeck.chance,
        text: 'Your building loan matures. Collect ₦15,000.',
        type: CardType.collect, amount: 15000),
    CardModel(id: 'chance_crossword', deck: CardDeck.chance,
        text: 'You have won a crossword competition. Collect ₦10,000.',
        type: CardType.collect, amount: 10000),
  ];

  static const List<CardModel> communityChestDeck = [
    CardModel(id: 'cc_advance_go', deck: CardDeck.communityChest,
        text: 'Advance to GO. Collect ₦20,000.', type: CardType.advanceToGo),
    CardModel(id: 'cc_bank_error', deck: CardDeck.communityChest,
        text: 'Bank error in your favour. Collect ₦20,000.',
        type: CardType.collect, amount: 20000),
    CardModel(id: 'cc_doctor_fee', deck: CardDeck.communityChest,
        text: 'Pay doctor\'s fees of ₦5,000.', type: CardType.pay, amount: 5000),
    CardModel(id: 'cc_stock_sale', deck: CardDeck.communityChest,
        text: 'From sale of stock you receive ₦5,000.',
        type: CardType.collect, amount: 5000),
    CardModel(id: 'cc_jail_free', deck: CardDeck.communityChest,
        text: 'Get Out of Jail Free. This card may be kept until needed.',
        type: CardType.getOutOfJailFree),
    CardModel(id: 'cc_go_jail', deck: CardDeck.communityChest,
        text: 'Go directly to Jail. Do not pass GO, do not collect ₦20,000.',
        type: CardType.goToJail),
    CardModel(id: 'cc_holiday_fund', deck: CardDeck.communityChest,
        text: 'Your holiday fund matures. Collect ₦10,000.',
        type: CardType.collect, amount: 10000),
    CardModel(id: 'cc_tax_refund', deck: CardDeck.communityChest,
        text: 'Income tax refund. Collect ₦2,000.',
        type: CardType.collect, amount: 2000),
    CardModel(id: 'cc_birthday', deck: CardDeck.communityChest,
        text: 'It is your birthday. Collect ₦1,000 from each player.',
        type: CardType.playerTransfer, amount: 1000, paysEach: false),
    CardModel(id: 'cc_life_insurance', deck: CardDeck.communityChest,
        text: 'Your life insurance matures. Collect ₦10,000.',
        type: CardType.collect, amount: 10000),
    CardModel(id: 'cc_hospital_fees', deck: CardDeck.communityChest,
        text: 'Pay hospital fees of ₦10,000.', type: CardType.pay, amount: 10000),
    CardModel(id: 'cc_school_fees', deck: CardDeck.communityChest,
        text: 'Pay school fees of ₦5,000.', type: CardType.pay, amount: 5000),
    CardModel(id: 'cc_consultancy', deck: CardDeck.communityChest,
        text: 'You have won a consultancy contract. Collect ₦2,500.',
        type: CardType.collect, amount: 2500),
    CardModel(id: 'cc_street_repairs', deck: CardDeck.communityChest,
        text: 'Street repairs: ₦4,000 per house, ₦11,500 per hotel.',
        type: CardType.streetRepairs, houseFee: 4000, hotelFee: 11500),
    CardModel(id: 'cc_beauty_contest', deck: CardDeck.communityChest,
        text: 'You won second prize in a beauty contest. Collect ₦1,000.',
        type: CardType.collect, amount: 1000),
    CardModel(id: 'cc_inherit', deck: CardDeck.communityChest,
        text: 'You inherit ₦10,000.', type: CardType.collect, amount: 10000),
  ];

  static CardModel? cardById(String id) {
    for (final c in chanceDeck) {
      if (c.id == id) return c;
    }
    for (final c in communityChestDeck) {
      if (c.id == id) return c;
    }
    return null;
  }
}
