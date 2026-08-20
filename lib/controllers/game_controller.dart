import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_state.dart';
import '../models/player.dart';
import '../models/tile.dart';
import '../models/card_model.dart';
import '../models/board_data.dart';

// ---------------------------------------------------------------------------
// GameController — StateNotifier
// All game logic lives here. UI calls methods; never touches state directly.
// ---------------------------------------------------------------------------
class GameController extends StateNotifier<GameState> {
  final Random _rng;

  // Name of the Income Tax space — it alone uses the dynamic 10%-vs-flat
  // calculation; the Luxury Tax space keeps its flat price.
  static const String _incomeTaxTileName = 'LIRS Tax';

  // Dice result of the roll currently animating; consumed by resolveRoll()
  // once the Flame board signals the dice/token animation is complete.
  int? _pendingDie1;
  int? _pendingDie2;

  // True while a jail escape by doubles is being resolved. Escaping jail via
  // doubles must NOT grant the usual extra turn (official rule), so landing
  // handlers check _grantExtraTurn instead of state.isDoubles directly.
  bool _jailEscapeNoExtraTurn = false;

  // Whether the current roll entitles the player to another turn: only a
  // genuine doubles roll does — never a doubles roll that merely escaped jail.
  bool get _grantExtraTurn => state.isDoubles && !_jailEscapeNoExtraTurn;

  // Safety valve for card chains: a movement card can land on another card
  // space, which draws another card, and so on. Depth is tracked per draw
  // and never allowed past this limit.
  static const int _cardChainDepthLimit = 5;
  int _cardChainDepth = 0;

  // Set when a card-triggered liquidation pivots the game to a debtor who is
  // NOT the current player (e.g. a transfer card another player couldn't
  // cover). Once the debt is settled the turn must resume from the player
  // who drew the card — this remembers that player's index.
  int? _resumeAfterCardIndex;

  // [random] is injectable so tests can drive deterministic rolls.
  GameController(List<Player> players, {Random? random})
      : _rng = random ?? Random(),
        super(GameState(
          players: players,
          board: BoardData.buildBoard(),
          currentPlayerIndex: 0,
          phase: GamePhase.waitingToRoll,
          message: '${players.first.name}\'s turn — roll the dice!',
        )) {
    _resetDecks();
  }

  // =========================================================================
  // PUBLIC API
  // =========================================================================

  // -------------------------------------------------------------------------
  // initPlayers() — called by the Lobby screen before navigating to the board.
  // Resets the entire game state with the lobby-selected player list.
  // -------------------------------------------------------------------------
  void initPlayers(List<Player> players) {
    _jailEscapeNoExtraTurn = false;
    _cardChainDepth = 0;
    _resumeAfterCardIndex = null;
    state = GameState(
      players: players,
      board: BoardData.buildBoard(),
      currentPlayerIndex: 0,
      phase: GamePhase.waitingToRoll,
      message: '${players.first.name}\'s turn — roll the dice!',
    );
    _resetDecks();
  }

  void rollDice() {
    if (state.phase != GamePhase.waitingToRoll) return;

    // A new roll begins a fresh turn sequence; any pending jail-escape
    // extra-turn suppression from a previous decision is no longer relevant.
    _jailEscapeNoExtraTurn = false;

    final die1 = _rng.nextInt(6) + 1;
    final die2 = _rng.nextInt(6) + 1;

    _pendingDie1 = die1;
    _pendingDie2 = die2;

    // Enter the animating phase: the Flame board plays the dice (and later
    // token) animation, then calls resolveRoll() via onRollAnimationComplete.
    state = state.copyWith(
      lastDie1: die1,
      lastDie2: die2,
      phase: GamePhase.animating,
      message: '${state.currentPlayer.name} rolled $die1+$die2 …',
    );
  }

  // Called by the UI once the roll animation has finished playing. Applies
  // the pending roll (move + landing evaluation) — never before the board
  // has visually finished showing the roll.
  void resolveRoll() {
    if (state.phase != GamePhase.animating) return;

    final die1 = _pendingDie1 ?? 0;
    final die2 = _pendingDie2 ?? 0;
    _pendingDie1 = null;
    _pendingDie2 = null;

    final roll = die1 + die2;
    final isDoubles = die1 == die2;
    final player = state.currentPlayer;

    if (player.isInJail) {
      _handleJailRoll(player, die1, die2, roll, isDoubles);
      return;
    }

    // Standard roll: track consecutive doubles. Jail rolls never count toward
    // this rule (they're handled above).
    final consecutiveDoubles = isDoubles ? state.consecutiveDoubles + 1 : 0;

    if (consecutiveDoubles >= 3) {
      // Third consecutive doubles — go directly to Jail: no movement, no
      // extra turn. _sendToJail resets the counter and clears the dice so
      // isDoubles reads false.
      _sendToJail(
        player,
        message: '${player.name} rolled doubles 3 times in a row — go to Jail!',
      );
      return;
    }

    state = state.copyWith(consecutiveDoubles: consecutiveDoubles);
    _movePlayer(player, roll);
  }

  void buyProperty() {
    if (state.phase != GamePhase.landedOnProperty) return;

    final player = state.currentPlayer;
    final tile = state.currentTile;

    if (!tile.isBuyable || tile.isOwned) return;
    if (player.balance < tile.price) {
      state = state.copyWith(
        message: '${player.name} cannot afford ${tile.name}!',
      );
      return;
    }

    final updatedPlayer = player.copyWith(
      balance: player.balance - tile.price,
      ownedTileIndices: [...player.ownedTileIndices, player.position],
    );

    final updatedPlayers = _replacePlayers(updatedPlayer);
    final updatedBoard =
        _replaceTile(state.board, player.position, tile.copyWith(owner: updatedPlayer));
    state = state.copyWith(
      players: updatedPlayers,
      board: updatedBoard,
      phase: GamePhase.waitingToRoll,
      message:
          '${player.name} bought ${tile.name} for ${BoardData.currencySymbol}${_fmt(tile.price)}!',
    );

    if (!_grantExtraTurn) _advanceTurn(updatedPlayers);
  }

  void passProperty() {
    if (state.phase != GamePhase.landedOnProperty) return;
    final player = state.currentPlayer;
    state = state.copyWith(
      phase: GamePhase.waitingToRoll,
      message: '${player.name} passed on ${state.currentTile.name}.',
    );
    if (!_grantExtraTurn) _advanceTurn(state.players);
  }

  void payJailFine() {
    final player = state.currentPlayer;
    if (!player.isInJail) return;
    if (player.balance < BoardData.jailFine) {
      state = state.copyWith(
        message:
            '${player.name} cannot afford the ${BoardData.currencySymbol}${_fmt(BoardData.jailFine)} fine.',
      );
      return;
    }

    final updatedPlayer = player.copyWith(
      balance: player.balance - BoardData.jailFine,
      status: PlayerStatus.active,
      jailTurns: 0,
    );
    state = state.copyWith(
      players: _replacePlayers(updatedPlayer),
      phase: GamePhase.waitingToRoll,
      message:
          '${player.name} paid ${BoardData.currencySymbol}${_fmt(BoardData.jailFine)} and is free! Now roll.',
    );
  }

  // -------------------------------------------------------------------------
  // Mortgage / unmortgage / liquidation settlement
  // -------------------------------------------------------------------------

  // Mortgages a tile the current player owns for 50% of its face-value price.
  void mortgageProperty(int tileIndex) {
    if (state.phase != GamePhase.waitingToRoll &&
        state.phase != GamePhase.liquidating) {
      return;
    }
    final player = state.currentPlayer;
    final tile = state.board[tileIndex];
    if (!tile.isBuyable || tile.owner?.id != player.id) return;
    if (tile.isMortgaged) return;
    if (_hasBuildingsInGroup(tile)) return;

    final cash = tile.price ~/ 2;
    final updatedPlayer = player.copyWith(balance: player.balance + cash);
    final updatedPlayers = _replacePlayers(updatedPlayer);
    final updatedBoard = _replaceTile(
        state.board, tileIndex, tile.copyWith(isMortgaged: true));

    state = state.copyWith(
      players: updatedPlayers,
      board: updatedBoard,
      message:
          '${player.name} mortgaged ${tile.name} for ${BoardData.currencySymbol}${_fmt(cash)}.',
    );
  }

  // Unmortgages a tile for principal (50% of face value) + 10% interest fee
  // on the principal — 55% of the original price in total.
  void unmortgageProperty(int tileIndex) {
    if (state.phase != GamePhase.waitingToRoll &&
        state.phase != GamePhase.liquidating) {
      return;
    }
    final player = state.currentPlayer;
    final tile = state.board[tileIndex];
    if (!tile.isBuyable || tile.owner?.id != player.id) return;
    if (!tile.isMortgaged) return;

    final cost = (tile.price * 55) ~/ 100;
    if (player.balance < cost) {
      state = state.copyWith(
        message:
            '${player.name} cannot afford to unmortgage ${tile.name} '
            '(${BoardData.currencySymbol}${_fmt(cost)}).',
      );
      return;
    }

    final updatedPlayer = player.copyWith(balance: player.balance - cost);
    final updatedPlayers = _replacePlayers(updatedPlayer);
    final updatedBoard = _replaceTile(
        state.board, tileIndex, tile.copyWith(isMortgaged: false));

    state = state.copyWith(
      players: updatedPlayers,
      board: updatedBoard,
      message:
          '${player.name} unmortgaged ${tile.name} for ${BoardData.currencySymbol}${_fmt(cost)}.',
    );
  }

  // Settles the pending liquidation debt once the current player's cash
  // covers it, paying the creditor (or the bank) in full. A debt owed while
  // in jail can only be the turn-3 forced fine — settling it frees the player.
  void settleDebt() {
    if (state.phase != GamePhase.liquidating) return;
    final player = state.currentPlayer;
    final debt = state.pendingDebt;
    if (debt <= 0) return;

    if (player.balance < debt) {
      state = state.copyWith(
        message: '${player.name} still needs '
            '${BoardData.currencySymbol}${_fmt(debt - player.balance)} '
            '— mortgage more properties.',
      );
      return;
    }

    final freed = player.isInJail
        ? player.copyWith(
            balance: player.balance - debt,
            status: PlayerStatus.active,
            jailTurns: 0,
          )
        : player.copyWith(balance: player.balance - debt);

    var updatedPlayers = _replacePlayers(freed);
    final creditorId = state.debtCreditorId;
    if (creditorId != null) {
      final creditorIndex =
          updatedPlayers.indexWhere((p) => p.id == creditorId);
      if (creditorIndex >= 0) {
        final creditor = updatedPlayers[creditorIndex];
        updatedPlayers = _replacePlayerAt(
            updatedPlayers,
            creditorIndex,
            creditor.copyWith(balance: creditor.balance + debt));
      }
    }

    // A card action that caused this debt stays pending through the
    // liquidation; its modal appears once the debt is settled.
    final pendingCardId = state.drawnCardId;
    final pendingCard =
        pendingCardId == null ? null : BoardData.cardById(pendingCardId);

    state = state.copyWith(
      players: updatedPlayers,
      pendingDebt: 0,
      debtCreditorId: null,
      phase: GamePhase.waitingToRoll,
      showCardModal: pendingCard != null,
      cardResult: pendingCard == null ? null : _cardResultMessage(pendingCard),
      message:
          '${player.name} settled the ${BoardData.currencySymbol}${_fmt(debt)} debt!',
    );

    // A card action caused this debt — the card modal is now up and its
    // dismissal advances the turn (resuming the drawer when the debtor was
    // someone else). Otherwise advance right away.
    if (pendingCard != null) return;

    if (!_grantExtraTurn) _advanceTurn(updatedPlayers);
  }

  // -------------------------------------------------------------------------
  // Card pipeline — public API
  // -------------------------------------------------------------------------

  // Dismisses the drawn-card modal. Movement cards defer their landing
  // evaluation until here, so this is the single choke point where a card's
  // consequences fully resolve before the turn advances.
  void dismissCard() {
    if (!state.showCardModal) return;

    final card = state.drawnCardId == null
        ? null
        : BoardData.cardById(state.drawnCardId!);
    final isJailFree = card?.type == CardType.getOutOfJailFree;

    // Get-Out-of-Jail-Free cards stay with the player until used; every other
    // card returns to the bottom of its deck once acknowledged.
    if (card != null && !isJailFree) _returnCardToDeck(card.deck, card.id);

    if (_cardChainDepth > 0) _cardChainDepth--;

    final landingIndex = state.pendingLandingIndex;
    final turnEnd = state.pendingTurnEnd;
    final player = state.currentPlayer;

    state = state.copyWith(
      showCardModal: false,
      clearDrawnCard: true,
      clearCardResult: true,
      clearPendingLandingIndex: true,
      pendingTurnEnd: false,
    );

    // The card action may have ended the game or pivoted into liquidation
    // while the modal was up — do not advance in those cases.
    if (state.phase == GamePhase.gameOver ||
        state.phase == GamePhase.liquidating) {
      return;
    }

    if (landingIndex != null) {
      _evaluateLanding(player, state.board[landingIndex], landingIndex);
      // The nearest-railroad / nearest-utility rent boost is consumed (or
      // wasted) by the landing evaluation — always reset it afterwards.
      state = state.copyWith(pendingRentModifier: PendingRentModifier.none);
      return;
    }

    if (turnEnd || !_grantExtraTurn) {
      _advanceTurn(state.players, fromIndex: _takeResumeIndex());
    }
  }

  // Uses a held "Get Out of Jail Free" card to escape jail for free.
  void useJailFreeCard() {
    if (state.phase != GamePhase.waitingToRoll) return;
    final player = state.currentPlayer;
    if (!player.isInJail || player.heldJailFreeCards.isEmpty) return;

    final cardId = player.heldJailFreeCards.first;
    final card = BoardData.cardById(cardId);
    if (card == null) return;

    final freed = player.copyWith(
      status: PlayerStatus.active,
      jailTurns: 0,
      heldJailFreeCards: player.heldJailFreeCards
          .where((id) => id != cardId)
          .toList(),
    );
    state = state.copyWith(
      players: _replacePlayers(freed),
      phase: GamePhase.waitingToRoll,
      message:
          '${player.name} used a "Get Out of Jail Free" card and is free! Now roll.',
    );
    // The used card returns to the bottom of its deck.
    _returnCardToDeck(card.deck, cardId);
  }

  // =========================================================================
  // PRIVATE HELPERS
  // =========================================================================

  void _movePlayer(Player player, int roll) {
    final oldPosition = player.position;
    final newPosition = (oldPosition + roll) % BoardData.boardSize;
    final passedGo =
        newPosition < oldPosition || newPosition == BoardData.goIndex;
    final newBalance = player.balance + (passedGo ? BoardData.goSalary : 0);

    final movedPlayer =
        player.copyWith(position: newPosition, balance: newBalance);
    final updatedPlayers = _replacePlayers(movedPlayer);
    final tile = state.board[newPosition];

    final passedGoMsg = passedGo
        ? ' (collected ${BoardData.currencySymbol}${_fmt(BoardData.goSalary)} passing GO!)'
        : '';

    // Interim emission: the position diff is what drives the token slide on
    // the Flame board, so this state MUST NOT claim phase == animating —
    // otherwise the board treats it as another roll and re-triggers the dice
    // instead of sliding the token. phase is corrected by _evaluateLanding
    // in the very next emission (landedOnProperty / waitingToRoll / advance).
    state = state.copyWith(
      players: updatedPlayers,
      phase: GamePhase.waitingToRoll,
      message:
          '${player.name} rolled ${state.lastDie1}+${state.lastDie2}=${roll} '
          '— landed on ${tile.name}$passedGoMsg',
    );

    _evaluateLanding(movedPlayer, tile, newPosition);
  }

  void _evaluateLanding(Player player, Tile tile, int position) {
    switch (tile.type) {
      case TileType.property:
      case TileType.railroad:
      case TileType.utility:
        _handleBuyableOrRent(player, tile);
        break;
      case TileType.tax:
        _handleTax(player, tile);
        break;
      case TileType.corner:
        _handleCorner(player, position);
        break;
      case TileType.chance:
        _drawCard(player, CardDeck.chance);
        break;
      case TileType.community:
        _drawCard(player, CardDeck.communityChest);
        break;
    }
  }

  void _handleBuyableOrRent(Player player, Tile tile) {
    if (!tile.isOwned) {
      state = state.copyWith(phase: GamePhase.landedOnProperty);
      return;
    }
    if (tile.owner!.id == player.id) {
      state = state.copyWith(
        phase: GamePhase.waitingToRoll,
        message: '${player.name} owns ${tile.name} — no rent due.',
      );
      if (!_grantExtraTurn) _advanceTurn(state.players);
      return;
    }

    final ownerId = tile.owner!.id;
    final ownedCount = (tile.type == TileType.railroad ||
            tile.type == TileType.utility)
        ? _ownedCountOfType(ownerId, tile.type)
        : 0;
    var rent = tile.currentRentFor(
      rollTotal: state.lastRollTotal,
      ownedCount: ownedCount,
    );
    // A "nearest railroad / utility" card may boost the rent for this landing.
    rent = _applyRentModifier(rent);
    final payer = player.copyWith(balance: player.balance - rent);
    final ownerIndex = state.players.indexWhere((p) => p.id == ownerId);
    final owner = state.players[ownerIndex];
    final updatedOwner = owner.copyWith(balance: owner.balance + rent);

    // Cash cannot cover the rent: enter the liquidation flow instead of
    // instantly bankrupting, provided the player can mortgage enough assets.
    if (payer.balance < 0) {
      _handleUnpayableDebt(player, rent, creditor: updatedOwner);
      return;
    }

    var updatedPlayers = _replacePlayers(payer);
    updatedPlayers = _replacePlayerAt(updatedPlayers, ownerIndex, updatedOwner);
    final updatedBoard = _replaceTile(
        state.board, player.position, tile.copyWith(owner: updatedOwner));

    state = state.copyWith(
      players: updatedPlayers,
      board: updatedBoard,
      phase: GamePhase.waitingToRoll,
      message:
          '${player.name} paid ${BoardData.currencySymbol}${_fmt(rent)} rent to ${owner.name} for ${tile.name}.',
    );

    if (!_grantExtraTurn) _advanceTurn(updatedPlayers);
  }

  void _handleTax(Player player, Tile tile) {
    final tax = _taxFor(player, tile);
    final updatedPlayer = player.copyWith(balance: player.balance - tax);

    // Same liquidation gate as rent: only deduct when the cash is there.
    if (updatedPlayer.balance < 0) {
      _handleUnpayableDebt(player, tax);
      return;
    }

    final updatedPlayers = _replacePlayers(updatedPlayer);

    state = state.copyWith(
      players: updatedPlayers,
      phase: GamePhase.waitingToRoll,
      message:
          '${player.name} paid ${BoardData.currencySymbol}${_fmt(tax)} — ${tile.name}.',
    );

    if (!_grantExtraTurn) _advanceTurn(updatedPlayers);
  }

  // Income Tax (LIRS) is the GREATER of the flat rate (₦20,000) or 10% of the
  // player's net worth (cash + total face value of owned properties). Other
  // tax spaces (Luxury Tax) keep their flat price.
  int _taxFor(Player player, Tile tile) {
    if (tile.name != _incomeTaxTileName) return tile.price;
    final netWorth = player.balance +
        player.ownedTileIndices.fold<int>(
            0, (sum, idx) => sum + state.board[idx].price);
    final tenPercent = netWorth ~/ 10;
    return tenPercent > tile.price ? tenPercent : tile.price;
  }

  void _handleCorner(Player player, int position) {
    if (position == BoardData.goToJailIndex) {
      _sendToJail(player,
          message: '${player.name} — LASTMA got you! Go to Jail.');
    } else {
      state = state.copyWith(phase: GamePhase.waitingToRoll);
      if (!_grantExtraTurn) _advanceTurn(state.players);
    }
  }

  // Sends a player to Jail: reposition to the Jail corner, mark as inJail,
  // reset the turn-sequence counters, clear the dice (isDoubles → false),
  // and end their turn immediately. When [advance] is false (card-driven
  // imprisonment), the turn ends via the card modal instead of here.
  void _sendToJail(Player player,
      {required String message, bool advance = true, CardModel? card}) {
    final jailed = player.copyWith(
      position: BoardData.jailIndex,
      status: PlayerStatus.inJail,
      jailTurns: 0,
    );
    final updated = _replacePlayers(jailed);
    state = state.copyWith(
      players: updated,
      consecutiveDoubles: 0,
      lastDie1: 0,
      lastDie2: 0,
      phase: GamePhase.waitingToRoll,
      pendingTurnEnd: !advance || state.pendingTurnEnd || !_grantExtraTurn,
      message: message,
    );
    if (card != null) {
      // The card modal acknowledges the imprisonment; its dismissal advances.
      _showCard(card);
      return;
    }
    _advanceTurn(updated);
  }

  void _handleJailRoll(
      Player player, int die1, int die2, int roll, bool isDoubles) {
    // Interim emission: same rule as _movePlayer — the Flame board must not
    // see phase == animating here or it would re-roll the dice instead of
    // processing the resolved roll.
    state = state.copyWith(
      lastDie1: die1,
      lastDie2: die2,
      phase: GamePhase.waitingToRoll,
    );
    if (isDoubles) {
      final freed = player.copyWith(status: PlayerStatus.active, jailTurns: 0);
      state = state.copyWith(
        players: _replacePlayers(freed),
        message: '${player.name} rolled doubles and escaped jail!',
      );
      // Escaping jail via doubles moves the token but does NOT grant the usual
      // extra turn — suppress it so landing handlers advance the turn.
      _jailEscapeNoExtraTurn = true;
      _movePlayer(freed, roll);
      return;
    }
    final newJailTurns = player.jailTurns + 1;
    if (newJailTurns >= 3) {
      if (player.balance < BoardData.jailFine) {
        // Cannot cover the mandatory fine — either mortgage assets or go
        // bankrupt; never push the player into negative cash.
        _handleUnpayableDebt(player, BoardData.jailFine);
        return;
      }
      final freed = player.copyWith(
        balance: player.balance - BoardData.jailFine,
        status: PlayerStatus.active,
        jailTurns: 0,
      );
      state = state.copyWith(
        players: _replacePlayers(freed),
        message:
            '${player.name} paid ${BoardData.currencySymbol}${_fmt(BoardData.jailFine)} fine after 3 turns in jail.',
      );
      _movePlayer(freed, roll);
    } else { 
      final stillJailed = player.copyWith(jailTurns: newJailTurns);
      state = state.copyWith(
        players: _replacePlayers(stillJailed),
        phase: GamePhase.waitingToRoll,
        message:
            '${player.name} didn\'t roll doubles (turn $newJailTurns/3 in jail).',
      );
      _advanceTurn(_replacePlayers(stillJailed));
    }
  }

  // A debt the player's cash cannot cover. If liquidating their holdings
  // (cash + 50% mortgage value of unmortgaged properties) can still satisfy
  // the debt, the player enters the liquidation phase and must mortgage
  // assets until they can settle it — otherwise they go bankrupt.
  //
  // [card] is set when a card action caused the debt: the card stays pending
  // through the liquidation and its modal appears once the debt is settled.
  // When the debtor is not the current player (a transfer card another
  // player couldn't cover), the game pivots to the debtor and remembers to
  // resume the drawer's turn afterwards.
  void _handleUnpayableDebt(Player player, int debt,
      {Player? creditor, CardModel? card}) {
    if (player.balance + _mortgageValueOf(player) < debt) {
      _declareBankruptcy(player, creditor: creditor, card: card);
      return;
    }

    final debtorIndex = state.players.indexWhere((p) => p.id == player.id);
    if (debtorIndex != state.currentPlayerIndex) {
      _resumeAfterCardIndex = state.currentPlayerIndex;
    }

    state = state.copyWith(
      currentPlayerIndex: debtorIndex,
      phase: GamePhase.liquidating,
      pendingDebt: debt,
      debtCreditorId: creditor?.id,
      drawnCardId: card?.id,
      message: '${player.name} owes ${BoardData.currencySymbol}${_fmt(debt)} '
          'but has only ${BoardData.currencySymbol}${_fmt(player.balance)} in '
          'cash — mortgage properties to raise the rest.',
    );
  }

  // Total cash the player can raise by mortgaging every unmortgaged holding:
  // 50% of each property's face-value price.
  int _mortgageValueOf(Player player) {
    var total = 0;
    for (final idx in player.ownedTileIndices) {
      final tile = state.board[idx];
      if (!tile.isMortgaged) total += tile.price ~/ 2;
    }
    return total;
  }

  // Buildings do not exist yet (housing is a later task), so no property can
  // currently have buildings blocking its mortgage.
  bool _hasBuildingsInGroup(Tile tile) => false;

  void _declareBankruptcy(Player player, {Player? creditor, CardModel? card}) {
    // A card that caused this bankruptcy is done: return it to its deck
    // (unless the player had drawn a Get-Out-of-Jail-Free card — those were
    // never removed from the deck in the first place). Any Jail-Free cards
    // the bankrupt player was holding go back too, so the deck never shrinks.
    if (card != null && card.type != CardType.getOutOfJailFree) {
      _returnCardToDeck(card.deck, card.id);
    }
    for (final heldId in player.heldJailFreeCards) {
      final held = BoardData.cardById(heldId);
      if (held != null) _returnCardToDeck(held.deck, heldId);
    }

    // Strip the bankrupt player of every holding: a dead player must never
    // retain property ownership or collect rent. Holdings are transferred to
    // the creditor when one exists (rent payment) or released back to the
    // bank (tax / forced fine).
    final holdings = player.ownedTileIndices;

    final bankrupt = player.copyWith(
      status: PlayerStatus.bankrupt,
      ownedTileIndices: [],
    );
    var updatedPlayers = _replacePlayers(bankrupt);

    Player? creditorSnapshot;
    if (creditor != null && holdings.isNotEmpty) {
      final creditorIndex =
          updatedPlayers.indexWhere((p) => p.id == creditor.id);
      creditorSnapshot = creditor.copyWith(
        ownedTileIndices: [...creditor.ownedTileIndices, ...holdings],
      );
      updatedPlayers =
          _replacePlayerAt(updatedPlayers, creditorIndex, creditorSnapshot);
    }

    var board = state.board;
    for (final idx in holdings) {
      final tile = board[idx];
      board = _replaceTile(
        board,
        idx,
        creditorSnapshot == null
            ? tile.copyWith(clearOwner: true)
            : tile.copyWith(owner: creditorSnapshot),
      );
    }

    final remaining = updatedPlayers.where((p) => !p.isBankrupt).toList();

    if (remaining.length == 1) {
      state = state.copyWith(
        players: updatedPlayers,
        board: board,
        phase: GamePhase.gameOver,
        showCardModal: false,
        clearDrawnCard: true,
        clearCardResult: true,
        clearPendingLandingIndex: true,
        pendingTurnEnd: false,
        message: '🏆 ${remaining.first.name} wins Lagos!',
      );
      return;
    }

    state = state.copyWith(
      players: updatedPlayers,
      board: board,
      phase: GamePhase.waitingToRoll,
      showCardModal: false,
      clearDrawnCard: true,
      clearCardResult: true,
      clearPendingLandingIndex: true,
      pendingTurnEnd: false,
      message: '${player.name} is bankrupt and eliminated!',
    );
    _advanceTurn(updatedPlayers, fromIndex: _takeResumeIndex());
  }

  void _advanceTurn(List<Player> players, {int? fromIndex}) {
    // The turn is ending — any pending jail-escape suppression is stale.
    _jailEscapeNoExtraTurn = false;
    final total = players.length;

    // Walk forward one step at a time until we land on an active player.
    // Using a for loop with a known bound avoids the off-by-one that caused
    // the skipped-player bug with 5+ players.
    int next = fromIndex ?? state.currentPlayerIndex;
    for (int i = 0; i < total; i++) {
      next = (next + 1) % total;
      if (!players[next].isBankrupt) break;
    }

    state = state.copyWith(
      currentPlayerIndex: next,
      consecutiveDoubles: 0,
      phase: GamePhase.waitingToRoll,
      message: '${players[next].name}\'s turn — roll the dice!',
    );
  }

  // =========================================================================
  // CARD PIPELINE — private helpers
  // =========================================================================

  // Consumes the remembered "resume the drawer's turn" index, if any.
  int? _takeResumeIndex() {
    final idx = _resumeAfterCardIndex;
    _resumeAfterCardIndex = null;
    return idx;
  }

  // Deals fresh shuffled decks into the state (minus any Jail-Free cards
  // currently held by players, so they can't be re-drawn while held).
  void _resetDecks() {
    state = state.copyWith(
      chanceDeckQueue: _shuffledCardIds(BoardData.chanceDeck, _heldJailFreeIds()),
      communityDeckQueue:
          _shuffledCardIds(BoardData.communityChestDeck, _heldJailFreeIds()),
      pendingRentModifier: PendingRentModifier.none,
    );
  }

  List<String> _shuffledCardIds(List<CardModel> deck, List<String> excludedIds) {
    final ids = deck
        .where((c) => !excludedIds.contains(c.id))
        .map((c) => c.id)
        .toList()
      ..shuffle(_rng);
    return ids;
  }

  List<String> _heldJailFreeIds() =>
      state.players.expand((p) => p.heldJailFreeCards).toList();

  // Puts a card back at the bottom of its deck queue.
  void _returnCardToDeck(CardDeck deck, String cardId) {
    final queue = deck == CardDeck.chance
        ? List<String>.from(state.chanceDeckQueue)
        : List<String>.from(state.communityDeckQueue);
    queue.add(cardId);
    state = deck == CardDeck.chance
        ? state.copyWith(chanceDeckQueue: queue)
        : state.copyWith(communityDeckQueue: queue);
  }

  // Draws the top card of a deck: pops its id from the queue (reshuffling the
  // deck first when it runs out) and executes the card's action.
  void _drawCard(Player player, CardDeck deck) {
    _cardChainDepth++;
    if (_cardChainDepth > _cardChainDepthLimit) {
      _cardChainDepth = 0;
      _endCardChain(player);
      return;
    }

    final deckCards = deck == CardDeck.chance
        ? BoardData.chanceDeck
        : BoardData.communityChestDeck;

    var queue = deck == CardDeck.chance
        ? List<String>.from(state.chanceDeckQueue)
        : List<String>.from(state.communityDeckQueue);
    if (queue.isEmpty) queue = _shuffledCardIds(deckCards, _heldJailFreeIds());

    final cardId = queue.removeAt(0);
    state = deck == CardDeck.chance
        ? state.copyWith(chanceDeckQueue: queue)
        : state.copyWith(communityDeckQueue: queue);

    final card = BoardData.cardById(cardId);
    if (card == null) {
      _returnCardToDeck(deck, cardId);
      _endCardChain(player);
      return;
    }

    _executeCardAction(player, card);
  }

  // Safety valve: a runaway card chain ends the turn without looping forever.
  void _endCardChain(Player player) {
    state = state.copyWith(
      phase: GamePhase.waitingToRoll,
      message: '${player.name} drew a card.',
    );
    if (!_grantExtraTurn) _advanceTurn(state.players);
  }

  void _executeCardAction(Player player, CardModel card) {
    switch (card.type) {
      case CardType.collect:
        _grantCash(player, card);
        break;
      case CardType.pay:
        _payToBank(player, card);
        break;
      case CardType.advanceToGo:
        _relocatePlayer(player, BoardData.goIndex,
            collectGo: true, card: card);
        break;
      case CardType.advanceToTile:
        _relocatePlayer(player, card.targetIndex!,
            collectGo: true, card: card);
        break;
      case CardType.moveBack3:
        _relocatePlayer(
            player,
            (player.position - 3 + BoardData.boardSize) % BoardData.boardSize,
            collectGo: false,
            card: card);
        break;
      case CardType.goToJail:
        _sendToJail(player,
            advance: false,
            card: card,
            message:
                '${player.name} drew "${card.text}" — go directly to Jail!');
        break;
      case CardType.nearestRailroad:
        state = state.copyWith(
            pendingRentModifier: PendingRentModifier.doubleRent);
        _relocatePlayer(player, _nearestRailroad(player.position),
            collectGo: true, card: card);
        break;
      case CardType.nearestUtility:
        state = state.copyWith(
            pendingRentModifier: PendingRentModifier.utilityTenDice);
        _relocatePlayer(player, _nearestUtility(player.position),
            collectGo: true, card: card);
        break;
      case CardType.getOutOfJailFree:
        _grantJailFreeCard(player, card);
        break;
      case CardType.streetRepairs:
        _chargeForBuildings(player, card);
        break;
      case CardType.playerTransfer:
        _executePlayerTransfer(player, card);
        break;
    }
  }

  void _grantCash(Player player, CardModel card) {
    final updated = player.copyWith(balance: player.balance + card.amount);
    state = state.copyWith(
      players: _replacePlayers(updated),
      message: '${player.name} collected ${BoardData.currencySymbol}${_fmt(card.amount)} '
          '— "${card.text}".',
    );
    _showCard(card);
  }

  void _payToBank(Player player, CardModel card) {
    final updated = player.copyWith(balance: player.balance - card.amount);
    if (updated.balance < 0) {
      // Same liquidation gate as rent: only deduct when the cash is there.
      _handleUnpayableDebt(player, card.amount, card: card);
      return;
    }
    state = state.copyWith(
      players: _replacePlayers(updated),
      message: '${player.name} paid ${BoardData.currencySymbol}${_fmt(card.amount)} '
          '— "${card.text}".',
    );
    _showCard(card);
  }

  // Moves a player to [targetIndex] without evaluating the landing — the
  // landing is deferred to the card modal dismissal via pendingLandingIndex.
  // [collectGo] also awards the GO salary when GO is crossed (or reached).
  void _relocatePlayer(Player player, int targetIndex,
      {required bool collectGo, required CardModel card}) {
    final passedGo =
        targetIndex < player.position || targetIndex == BoardData.goIndex;
    var balance = player.balance;
    var goMsg = '';
    if (collectGo && passedGo) {
      balance += BoardData.goSalary;
      goMsg =
          ' (collected ${BoardData.currencySymbol}${_fmt(BoardData.goSalary)} passing GO!)';
    }

    final moved = player.copyWith(position: targetIndex, balance: balance);
    state = state.copyWith(
      players: _replacePlayers(moved),
      pendingLandingIndex: targetIndex,
      pendingTurnEnd: !_grantExtraTurn,
      message:
          '${player.name} moved to ${state.board[targetIndex].name}$goMsg.',
    );
    _showCard(card);
  }

  int _nearestRailroad(int position) {
    const railroadIndices = [5, 15, 25, 35];
    var best = railroadIndices.first;
    var bestDist = BoardData.boardSize;
    for (final idx in railroadIndices) {
      final dist = (idx - position + BoardData.boardSize) % BoardData.boardSize;
      if (dist < bestDist) {
        bestDist = dist;
        best = idx;
      }
    }
    return best;
  }

  int _nearestUtility(int position) {
    const utilityIndices = [12, 28];
    var best = utilityIndices.first;
    var bestDist = BoardData.boardSize;
    for (final idx in utilityIndices) {
      final dist = (idx - position + BoardData.boardSize) % BoardData.boardSize;
      if (dist < bestDist) {
        bestDist = dist;
        best = idx;
      }
    }
    return best;
  }

  void _grantJailFreeCard(Player player, CardModel card) {
    final updated = player.copyWith(
      heldJailFreeCards: [...player.heldJailFreeCards, card.id],
    );
    state = state.copyWith(
      players: _replacePlayers(updated),
      message: '${player.name} got a "Get Out of Jail Free" card — keep it for later!',
    );
    _showCard(card);
  }

  // Street repairs charge per house / per hotel owned. Housing does not exist
  // yet, so the fee is always zero — kept as a separate action so the card
  // text and flow are already correct when buildings arrive.
  void _chargeForBuildings(Player player, CardModel card) {
    state = state.copyWith(
      message:
          '${player.name} owns no buildings — no repair fee for "${card.text}".',
    );
    _showCard(card);
  }

  // Cash flows between the drawer and every other active player.
  //   paysEach=true  → drawer pays each player (e.g. Chairman)
  //   paysEach=false → each player pays the drawer (e.g. Birthday)
  void _executePlayerTransfer(Player player, CardModel card) {
    final others = state.activePlayers.where((p) => p.id != player.id).toList();
    if (others.isEmpty) {
      _showCard(card);
      return;
    }

    var updatedPlayers = List<Player>.from(state.players);
    final perPlayer = card.amount;

    if (card.paysEach) {
      final total = perPlayer * others.length;
      if (player.balance < total) {
        // The drawer can't cover the payments — liquidate them. With multiple
        // recipients the debt simplifies to the bank (a rare edge case).
        state = state.copyWith(players: updatedPlayers);
        _handleUnpayableDebt(player, total,
            card: card,
            creditor: others.length == 1 ? others.first : null);
        return;
      }
      final drawerIndex =
          updatedPlayers.indexWhere((p) => p.id == player.id);
      updatedPlayers = _replacePlayerAt(
          updatedPlayers,
          drawerIndex,
          player.copyWith(balance: player.balance - total));
      for (final o in others) {
        final idx = updatedPlayers.indexWhere((p) => p.id == o.id);
        updatedPlayers = _replacePlayerAt(
            updatedPlayers, idx, o.copyWith(balance: o.balance + perPlayer));
      }
    } else {
      var total = 0;
      for (final o in others) {
        if (o.balance < perPlayer) {
          // This payer can't cover their share — liquidate them.
          state = state.copyWith(players: updatedPlayers);
          _handleUnpayableDebt(o, perPlayer, card: card, creditor: player);
          return;
        }
        final idx = updatedPlayers.indexWhere((p) => p.id == o.id);
        updatedPlayers = _replacePlayerAt(
            updatedPlayers, idx, o.copyWith(balance: o.balance - perPlayer));
        total += perPlayer;
      }
      final drawerIndex =
          updatedPlayers.indexWhere((p) => p.id == player.id);
      updatedPlayers = _replacePlayerAt(
          updatedPlayers,
          drawerIndex,
          player.copyWith(balance: player.balance + total));
    }

    state = state.copyWith(
      players: updatedPlayers,
      message: '${player.name} ${card.paysEach ? 'paid' : 'collected'} '
          '${BoardData.currencySymbol}${_fmt(perPlayer)} each — "${card.text}".',
    );
    _showCard(card);
  }

  // Applies the rent boost set by a "nearest railroad / utility" card.
  int _applyRentModifier(int rent) {
    switch (state.pendingRentModifier) {
      case PendingRentModifier.doubleRent:
        return rent * 2;
      case PendingRentModifier.utilityTenDice:
        return state.lastRollTotal * 1000;
      case PendingRentModifier.none:
        return rent;
    }
  }

  // Raises the card modal. The drawn card is remembered in state so the modal
  // survives a serialization round-trip mid-turn.
  void _showCard(CardModel card) {
    state = state.copyWith(
      showCardModal: true,
      drawnCardId: card.id,
      cardResult: _cardResultMessage(card),
    );
  }

  String _cardResultMessage(CardModel card) {
    switch (card.type) {
      case CardType.goToJail:
        return 'Go directly to Jail — do not pass GO.';
      case CardType.advanceToGo:
        return 'Advance to GO and collect '
            '${BoardData.currencySymbol}${_fmt(BoardData.goSalary)}.';
      case CardType.advanceToTile:
        return 'Advance to ${state.board[card.targetIndex!].name}.';
      case CardType.moveBack3:
        return 'Move back three spaces.';
      case CardType.nearestRailroad:
        return 'Advance to the nearest railroad — pay 2× rent if owned.';
      case CardType.nearestUtility:
        return 'Advance to the nearest utility — pay 10× the dice roll if owned.';
      case CardType.getOutOfJailFree:
        return 'Keep this card until you need it.';
      case CardType.collect:
        return 'Collect ${BoardData.currencySymbol}${_fmt(card.amount)} from the bank.';
      case CardType.pay:
        return 'Pay ${BoardData.currencySymbol}${_fmt(card.amount)} to the bank.';
      case CardType.streetRepairs:
        return 'Pay ${BoardData.currencySymbol}${_fmt(card.houseFee)} per house '
            'and ${BoardData.currencySymbol}${_fmt(card.hotelFee)} per hotel.';
      case CardType.playerTransfer:
        return card.paysEach
            ? 'Pay ${BoardData.currencySymbol}${_fmt(card.amount)} to each player.'
            : 'Collect ${BoardData.currencySymbol}${_fmt(card.amount)} from each player.';
    }
  }

  List<Player> _replacePlayers(Player updated) =>
      state.players.map((p) => p.id == updated.id ? updated : p).toList();

  // How many tiles of a given type a single owner holds — drives railroad
  // and utility rent scaling. Includes the tile the player just landed on.
  int _ownedCountOfType(String ownerId, TileType type) =>
      state.board.where((t) => t.type == type && t.owner?.id == ownerId).length;

  List<Player> _replacePlayerAt(
          List<Player> players, int index, Player updated) =>
      [
        for (int i = 0; i < players.length; i++)
          i == index ? updated : players[i]
      ];

  // Tiles are immutable — an ownership change swaps in a new Tile instance
  // instead of mutating the existing one, so every old GameState snapshot
  // keeps its own pristine board.
  List<Tile> _replaceTile(List<Tile> board, int index, Tile updated) =>
      [for (int i = 0; i < board.length; i++) i == index ? updated : board[i]];

  /// Format large numbers with commas: 20000 → "20,000"
  String _fmt(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------
final gameControllerProvider =
    StateNotifierProvider<GameController, GameState>((ref) {
  final players = [
    Player(
        id: 'player_1',
        name: 'Player 1',
        tokenColor: const Color(0xFFE53935),
        balance: 150000),
    Player(
        id: 'player_2',
        name: 'Player 2',
        tokenColor: const Color(0xFF1E88E5),
        balance: 150000),
  ];
  return GameController(players);
});

// ---------------------------------------------------------------------------
// gameBridgeProvider — exposes a Stream<GameState> for the Flame layer.
//
// Architecture note: Flame has no knowledge of Riverpod. Instead of coupling
// them directly, this provider converts the StateNotifier into a broadcast
// stream. LagosGameBoard subscribes to this stream and updates its components
// whenever game state changes — keeping both layers fully decoupled.
//
// The stream replays the current GameState to every new listener so a fresh
// Flame board always starts from the live game state (not a blank board).
// ---------------------------------------------------------------------------
final gameBridgeProvider = Provider<Stream<GameState>>((ref) {
  late final StreamController<GameState> controller;
  controller = StreamController<GameState>.broadcast(
    onListen: () {
      // Replay the current state for every newly attached listener. Without
      // this, a fresh Flame board subscribes AFTER initPlayers() has already
      // run and would never see the current game state — leaving the board
      // blank until the first roll.
      if (!controller.isClosed) {
        controller.add(ref.read(gameControllerProvider));
      }
    },
  );
  ref.listen<GameState>(gameControllerProvider, (_, next) {
    if (!controller.isClosed) controller.add(next);
  });
  ref.onDispose(controller.close);
  return controller.stream;
});
