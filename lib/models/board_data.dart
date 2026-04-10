import 'package:flutter/material.dart';
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
  static const int    boardSize      = 40;
  static const String currencySymbol = '₦';

  static List<Tile> buildBoard() => [
    // ── BOTTOM ROW (0–9) ─────────────────────────────────────────────
    Tile(name: 'GO',                       type: TileType.corner),
    Tile(name: 'Agege Market Rd',          type: TileType.property,  colorGroup: agege,        price: 6000,   baseRent: 200),
    Tile(name: 'Community Chest',          type: TileType.community),
    Tile(name: 'Mushin Road',              type: TileType.property,  colorGroup: agege,        price: 6000,   baseRent: 400),
    Tile(name: 'LIRS Tax',                 type: TileType.tax,       price: 20000),
    Tile(name: 'Carter Bridge',            type: TileType.railroad,  colorGroup: bridgeGray,   price: 20000,  baseRent: 2500),
    Tile(name: 'Herbert Macaulay Way',     type: TileType.property,  colorGroup: yaba,         price: 10000,  baseRent: 600),
    Tile(name: 'Chance',                   type: TileType.chance),
    Tile(name: 'Iwaya Road',               type: TileType.property,  colorGroup: yaba,         price: 10000,  baseRent: 600),
    Tile(name: 'Commercial Ave, Yaba',     type: TileType.property,  colorGroup: yaba,         price: 12000,  baseRent: 800),

    // ── LEFT COLUMN (10–19) ───────────────────────────────────────────
    Tile(name: 'Jail / Just Visiting',     type: TileType.corner),
    Tile(name: 'Bode Thomas Street',       type: TileType.property,  colorGroup: surulere,     price: 14000,  baseRent: 1000),
    Tile(name: 'EKEDC (Electricity)',      type: TileType.utility,   colorGroup: utilityAmber, price: 15000,  baseRent: 0),
    Tile(name: 'Adeniran Ogunsanya St',    type: TileType.property,  colorGroup: surulere,     price: 14000,  baseRent: 1000),
    Tile(name: 'Ogunlana Drive',           type: TileType.property,  colorGroup: surulere,     price: 16000,  baseRent: 1200),
    Tile(name: 'Eko Bridge',               type: TileType.railroad,  colorGroup: bridgeGray,   price: 20000,  baseRent: 2500),
    Tile(name: 'Allen Avenue, Ikeja',      type: TileType.property,  colorGroup: ikeja,        price: 18000,  baseRent: 1400),
    Tile(name: 'Community Chest',          type: TileType.community),
    Tile(name: 'Toyin Street, Ikeja',      type: TileType.property,  colorGroup: ikeja,        price: 18000,  baseRent: 1400),
    Tile(name: 'Adeniyi Jones Ave',        type: TileType.property,  colorGroup: ikeja,        price: 20000,  baseRent: 1600),

    // ── TOP ROW (20–29) ───────────────────────────────────────────────
    Tile(name: 'Freedom Park',             type: TileType.corner),
    Tile(name: 'Creek Road, Apapa',        type: TileType.property,  colorGroup: apapa,        price: 22000,  baseRent: 1800),
    Tile(name: 'Chance',                   type: TileType.chance),
    Tile(name: 'FESTAC Link Road',         type: TileType.property,  colorGroup: apapa,        price: 22000,  baseRent: 1800),
    Tile(name: 'Ahmadu Bello Way',         type: TileType.property,  colorGroup: apapa,        price: 24000,  baseRent: 2000),
    Tile(name: 'Third Mainland Bridge',    type: TileType.railroad,  colorGroup: bridgeGray,   price: 20000,  baseRent: 2500),
    Tile(name: 'Lekki-Epe Expressway',     type: TileType.property,  colorGroup: lekki,        price: 26000,  baseRent: 2200),
    Tile(name: 'Admiralty Way, Lekki',     type: TileType.property,  colorGroup: lekki,        price: 26000,  baseRent: 2200),
    Tile(name: 'Lagos Water Corp',         type: TileType.utility,   colorGroup: utilityAmber, price: 15000,  baseRent: 0),
    Tile(name: 'Chevron Drive, Lekki',     type: TileType.property,  colorGroup: lekki,        price: 28000,  baseRent: 2400),

    // ── RIGHT COLUMN (30–39) ──────────────────────────────────────────
    Tile(name: 'LASTMA Checkpoint',        type: TileType.corner),
    Tile(name: 'Awolowo Road, Ikoyi',      type: TileType.property,  colorGroup: ikoyi,        price: 30000,  baseRent: 2600),
    Tile(name: 'Glover Road, Ikoyi',       type: TileType.property,  colorGroup: ikoyi,        price: 30000,  baseRent: 2600),
    Tile(name: 'Community Chest',          type: TileType.community),
    Tile(name: 'Bourdillon Road, Ikoyi',   type: TileType.property,  colorGroup: ikoyi,        price: 32000,  baseRent: 2800),
    Tile(name: 'Lagos BRT Route',          type: TileType.railroad,  colorGroup: bridgeGray,   price: 20000,  baseRent: 2500),
    Tile(name: 'Chance',                   type: TileType.chance),
    Tile(name: 'Adeola Odeku St, VI',      type: TileType.property,  colorGroup: vi,           price: 35000,  baseRent: 3500),
    Tile(name: 'Luxury Tax',               type: TileType.tax,       price: 7500),
    Tile(name: 'Ozumba Mbadiwe Ave',       type: TileType.property,  colorGroup: vi,           price: 40000,  baseRent: 5000),
  ];
}
