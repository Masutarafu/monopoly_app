import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_state.dart';
import '../models/player.dart';
import '../models/tile.dart';
import '../models/board_data.dart';

// ---------------------------------------------------------------------------
// GameController — StateNotifier
// All game logic lives here. UI calls methods; never touches state directly.
// ---------------------------------------------------------------------------
class GameController extends StateNotifier<GameState> {
  final Random _rng = Random();

  GameController(List<Player> players)
      : super(GameState(
          players: players,
          board: BoardData.buildBoard(),
          currentPlayerIndex: 0,
          phase: GamePhase.waitingToRoll,
          message: '${players.first.name}\'s turn — roll the dice!',
        ));

  // =========================================================================
  // PUBLIC API
  // =========================================================================

  // -------------------------------------------------------------------------
  // initPlayers() — called by the Lobby screen before navigating to the board.
  // Resets the entire game state with the lobby-selected player list.
  // -------------------------------------------------------------------------
  void initPlayers(List<Player> players) {
    state = GameState(
      players: players,
      board: BoardData.buildBoard(),
      currentPlayerIndex: 0,
      phase: GamePhase.waitingToRoll,
      message: '${players.first.name}\'s turn — roll the dice!',
    );
  }

  void rollDice() {
    if (state.phase != GamePhase.waitingToRoll) return;

    final die1 = _rng.nextInt(6) + 1;
    final die2 = _rng.nextInt(6) + 1;
    final roll = die1 + die2;
    final isDoubles = die1 == die2;

    final player = state.currentPlayer;

    if (player.isInJail) {
      _handleJailRoll(player, die1, die2, roll, isDoubles);
      return;
    }

    state = state.copyWith(lastDie1: die1, lastDie2: die2);
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
    tile.owner = updatedPlayer;

    final updatedPlayers = _replacePlayers(updatedPlayer);
    state = state.copyWith(
      players: updatedPlayers,
      phase: GamePhase.waitingToRoll,
      message:
          '${player.name} bought ${tile.name} for ${BoardData.currencySymbol}${_fmt(tile.price)}!',
    );

    if (!state.isDoubles) _advanceTurn(updatedPlayers);
  }

  void passProperty() {
    if (state.phase != GamePhase.landedOnProperty) return;
    final player = state.currentPlayer;
    state = state.copyWith(
      phase: GamePhase.waitingToRoll,
      message: '${player.name} passed on ${state.currentTile.name}.',
    );
    if (!state.isDoubles) _advanceTurn(state.players);
  }

  void payJailFine() {
    final player = state.currentPlayer;
    if (!player.isInJail || player.balance < 5000) return;

    final updatedPlayer = player.copyWith(
      balance: player.balance - 5000,
      status: PlayerStatus.active,
      jailTurns: 0,
    );
    state = state.copyWith(
      players: _replacePlayers(updatedPlayer),
      phase: GamePhase.waitingToRoll,
      message:
          '${player.name} paid ${BoardData.currencySymbol}5,000 and is free! Now roll.',
    );
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

    state = state.copyWith(
      players: updatedPlayers,
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
      case TileType.community:
        state = state.copyWith(
          phase: GamePhase.waitingToRoll,
          message: '${player.name} drew a card (coming soon).',
        );
        if (!state.isDoubles) _advanceTurn(state.players);
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
      if (!state.isDoubles) _advanceTurn(state.players);
      return;
    }

    final rent = tile.currentRent;
    final payer = player.copyWith(balance: player.balance - rent);
    final ownerIndex = state.players.indexWhere((p) => p.id == tile.owner!.id);
    final owner = state.players[ownerIndex];
    final updatedOwner = owner.copyWith(balance: owner.balance + rent);

    var updatedPlayers = _replacePlayers(payer);
    updatedPlayers = _replacePlayerAt(updatedPlayers, ownerIndex, updatedOwner);
    tile.owner = updatedOwner;

    state = state.copyWith(
      players: updatedPlayers,
      phase: GamePhase.waitingToRoll,
      message:
          '${player.name} paid ${BoardData.currencySymbol}${_fmt(rent)} rent to ${owner.name} for ${tile.name}.',
    );

    if (payer.balance < 0) {
      _declareBankruptcy(payer);
      return;
    }
    if (!state.isDoubles) _advanceTurn(updatedPlayers);
  }

  void _handleTax(Player player, Tile tile) {
    final updatedPlayer = player.copyWith(balance: player.balance - tile.price);
    final updatedPlayers = _replacePlayers(updatedPlayer);

    state = state.copyWith(
      players: updatedPlayers,
      phase: GamePhase.waitingToRoll,
      message:
          '${player.name} paid ${BoardData.currencySymbol}${_fmt(tile.price)} — ${tile.name}.',
    );

    if (updatedPlayer.balance < 0) {
      _declareBankruptcy(updatedPlayer);
      return;
    }
    if (!state.isDoubles) _advanceTurn(updatedPlayers);
  }

  void _handleCorner(Player player, int position) {
    if (position == BoardData.goToJailIndex) {
      final jailed = player.copyWith(
        position: BoardData.jailIndex,
        status: PlayerStatus.inJail,
        jailTurns: 0,
      );
      final updated = _replacePlayers(jailed);
      state = state.copyWith(
        players: updated,
        phase: GamePhase.waitingToRoll,
        message: '${player.name} — LASTMA got you! Go to Jail.',
      );
      _advanceTurn(updated);
    } else {
      state = state.copyWith(phase: GamePhase.waitingToRoll);
      if (!state.isDoubles) _advanceTurn(state.players);
    }
  }

  void _handleJailRoll(
      Player player, int die1, int die2, int roll, bool isDoubles) {
    state = state.copyWith(lastDie1: die1, lastDie2: die2);
    if (isDoubles) {
      final freed = player.copyWith(status: PlayerStatus.active, jailTurns: 0);
      state = state.copyWith(
        players: _replacePlayers(freed),
        message: '${player.name} rolled doubles and escaped jail!',
      );
      _movePlayer(freed, roll);
      return;
    }
    final newJailTurns = player.jailTurns + 1;
    if (newJailTurns >= 3) {
      final freed = player.copyWith(
        balance: player.balance - 5000,
        status: PlayerStatus.active,
        jailTurns: 0,
      );
      state = state.copyWith(
        players: _replacePlayers(freed),
        message:
            '${player.name} paid ${BoardData.currencySymbol}5,000 fine after 3 turns in jail.',
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

  void _declareBankruptcy(Player player) {
    final bankrupt = player.copyWith(status: PlayerStatus.bankrupt);
    final updatedPlayers = _replacePlayers(bankrupt);
    final remaining = updatedPlayers.where((p) => !p.isBankrupt).toList();

    if (remaining.length == 1) {
      state = state.copyWith(
        players: updatedPlayers,
        phase: GamePhase.gameOver,
        message: '🏆 ${remaining.first.name} wins Lagos!',
      );
      return;
    }

    state = state.copyWith(
      players: updatedPlayers,
      phase: GamePhase.waitingToRoll,
      message: '${player.name} is bankrupt and eliminated!',
    );
    _advanceTurn(updatedPlayers);
  }

  void _advanceTurn(List<Player> players) {
    final total = players.length;

    // Walk forward one step at a time until we land on an active player.
    // Using a for loop with a known bound avoids the off-by-one that caused
    // the skipped-player bug with 5+ players.
    int next = state.currentPlayerIndex;
    for (int i = 0; i < total; i++) {
      next = (next + 1) % total;
      if (!players[next].isBankrupt) break;
    }

    state = state.copyWith(
      currentPlayerIndex: next,
      phase: GamePhase.waitingToRoll,
      message: '${players[next].name}\'s turn — roll the dice!',
    );
  }

  List<Player> _replacePlayers(Player updated) =>
      state.players.map((p) => p.id == updated.id ? updated : p).toList();

  List<Player> _replacePlayerAt(
          List<Player> players, int index, Player updated) =>
      [
        for (int i = 0; i < players.length; i++)
          i == index ? updated : players[i]
      ];

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
// ---------------------------------------------------------------------------
final gameBridgeProvider = StreamProvider<GameState>((ref) {
  final controller = StreamController<GameState>.broadcast();
  ref.listen<GameState>(gameControllerProvider, (_, next) {
    controller.add(next);
  });
  ref.onDispose(controller.close);
  return controller.stream;
});
