// Serialization + immutability tests for the game models.
//
// These guard the refactor that made every model a plain-data value object:
//   - Player / Tile / GameState round-trip through toJson()/fromJson()
//   - buying a property replaces tiles instead of mutating them in place,
//     so prior GameState snapshots always stay pristine (required for
//     save/load, pass-and-play and network sync).

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:simple_monopoly/models/game_state.dart';
import 'package:simple_monopoly/models/player.dart';
import 'package:simple_monopoly/models/tile.dart';
import 'package:simple_monopoly/models/board_data.dart';
import 'package:simple_monopoly/controllers/game_controller.dart';

void main() {
  group('Player JSON', () {
    test('round-trips all fields including token color', () {
      final p = Player(
        id: 'player_1',
        name: 'Akin',
        tokenColor: const Color(0xFFE53935),
        position: 12,
        balance: 130000,
        status: PlayerStatus.inJail,
        jailTurns: 2,
        ownedTileIndices: [1, 3, 6],
      );

      final decoded = Player.fromJson(p.toJson());

      expect(decoded.id, p.id);
      expect(decoded.name, p.name);
      expect(decoded.tokenColor, const Color(0xFFE53935));
      expect(decoded.position, 12);
      expect(decoded.balance, 130000);
      expect(decoded.status, PlayerStatus.inJail);
      expect(decoded.jailTurns, 2);
      expect(decoded.ownedTileIndices, [1, 3, 6]);
    });
  });

  group('Tile JSON', () {
    test('round-trips a fresh buyable tile', () {
      final t = BoardData.buildBoard()[1];

      final decoded = Tile.fromJson(t.toJson());

      expect(decoded.name, t.name);
      expect(decoded.type, TileType.property);
      expect(decoded.colorGroup, BoardData.agege);
      expect(decoded.price, t.price);
      expect(decoded.baseRent, t.baseRent);
      expect(decoded.isOwned, isFalse);
    });

    test('round-trips an owned tile with its owner player', () {
      final owner = Player(id: 'p1', name: 'Bola', tokenColor: Colors.red);
      final t = const Tile(
        name: 'Test Street',
        type: TileType.property,
        price: 10000,
        baseRent: 500,
      ).copyWith(owner: owner);

      final decoded = Tile.fromJson(t.toJson());

      expect(decoded.isOwned, isTrue);
      expect(decoded.owner!.id, 'p1');
      expect(decoded.owner!.name, 'Bola');
      expect(decoded.owner!.tokenColor.toARGB32(), Colors.red.toARGB32());
      expect(decoded.currentRent, 500);
    });
  });

  group('GameState JSON', () {
    test('round-trips a fresh board', () {
      final state = GameState(
        players: [
          Player(id: 'p1', name: 'A', tokenColor: Colors.red),
          Player(id: 'p2', name: 'B', tokenColor: Colors.blue),
        ],
        board: BoardData.buildBoard(),
        currentPlayerIndex: 1,
        phase: GamePhase.waitingToRoll,
        lastDie1: 3,
        lastDie2: 4,
        message: "B's turn — roll the dice!",
      );

      final decoded = GameState.fromJson(state.toJson());

      expect(decoded.players.length, 2);
      expect(decoded.board.length, 40);
      expect(decoded.currentPlayerIndex, 1);
      expect(decoded.phase, GamePhase.waitingToRoll);
      expect(decoded.lastRollTotal, 7);
      expect(decoded.message, state.message);
      expect(decoded.board[1].colorGroup, BoardData.agege);
      expect(decoded.board[30].name, 'LASTMA Checkpoint');
    });
  });

  group('Controller ownership immutability', () {
    test('buying a property replaces the tile without mutating prior state',
        () {
      final controller = GameController(
        [
          Player(
              id: 'p1',
              name: 'Akin',
              tokenColor: Colors.red,
              position: 6,
              balance: 150000),
          Player(
              id: 'p2',
              name: 'Bola',
              tokenColor: Colors.blue,
              balance: 150000),
        ],
        random: Random(42),
      );

      // Roll until a player lands on an unowned property (seeded RNG makes
      // this deterministic).
      var guard = 0;
      while (controller.state.phase != GamePhase.landedOnProperty &&
          guard < 200) {
        if (controller.state.phase == GamePhase.waitingToRoll) {
          controller.rollDice();
        }
        controller.resolveRoll();
        guard++;
      }
      expect(
        controller.state.phase,
        GamePhase.landedOnProperty,
        reason: 'seeded rolls should eventually land on an unowned property',
      );

      final landedIndex = controller.state.currentPlayer.position;
      final buyerId = controller.state.currentPlayer.id;
      final preBuy = controller.state;

      controller.buyProperty();

      final postBuy = controller.state;
      expect(postBuy.board[landedIndex].isOwned, isTrue);
      expect(postBuy.board[landedIndex].owner!.id, buyerId);
      // The previous snapshot kept its pristine, unowned board.
      expect(preBuy.board[landedIndex].isOwned, isFalse);

      // The full post-buy snapshot round-trips through JSON.
      final decoded = GameState.fromJson(postBuy.toJson());
      expect(decoded.board[landedIndex].owner!.id, buyerId);
      expect(decoded.board[landedIndex].owner!.ownedTileIndices,
          contains(landedIndex));
      expect(
        decoded.players.firstWhere((p) => p.id == buyerId).balance,
        postBuy.players.firstWhere((p) => p.id == buyerId).balance,
      );
    });
  });
}
