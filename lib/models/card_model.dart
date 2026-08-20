// ---------------------------------------------------------------------------
// CardModel — Chance & Community Chest cards
// ---------------------------------------------------------------------------
// Static, immutable card definitions. The two decks live in BoardData; the
// controller draws by card id and keeps a per-deck draw queue in GameState,
// so cards are trivially serializable (ids only) for save/load and networking.

enum CardDeck { chance, communityChest }

enum CardType {
  collect,          // Collect a fixed amount from the bank
  pay,              // Pay a fixed amount to the bank
  goToJail,         // Go directly to Jail — no GO, no salary
  advanceToGo,      // Advance to GO, collect the GO salary
  advanceToTile,    // Advance to a specific tile index (collect GO if passed)
  moveBack3,        // Move back exactly 3 spaces (never collects GO)
  nearestRailroad,  // Advance to the nearest railroad (2× rent if owned)
  nearestUtility,   // Advance to the nearest utility (10× dice if owned)
  getOutOfJailFree, // Held by the player until used (or sold, once trading exists)
  streetRepairs,    // Pay a fee per house / per hotel owned
  playerTransfer,   // Collect from — or pay — each other active player
}

class CardModel {
  final String id;
  final CardDeck deck;
  final String text;
  final CardType type;
  final int amount;        // Cash amount (×100 scale) for collect/pay/transfer
  final int? targetIndex;  // Board index for advanceToTile
  final int houseFee;      // streetRepairs: fee per house owned
  final int hotelFee;      // streetRepairs: fee per hotel owned
  final bool paysEach;     // playerTransfer: drawer pays each player (Chairman)

  const CardModel({
    required this.id,
    required this.deck,
    required this.text,
    required this.type,
    this.amount = 0,
    this.targetIndex,
    this.houseFee = 0,
    this.hotelFee = 0,
    this.paysEach = false,
  });
}