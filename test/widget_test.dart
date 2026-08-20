// Smoke tests for the Lagos Monopoly app.
//
// The previous version of this file was a leftover Flutter template test
// (a counter app) that did not compile: it imported 'package:monopoly_app'
// although the package is named 'simple_monopoly', and referenced a 'MyApp'
// class that does not exist in this codebase.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:simple_monopoly/main.dart';

void main() {
  testWidgets('Lobby renders with two default players', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LagosMonopolyApp()));

    expect(find.text('LAGOS MONOPOLY'), findsOneWidget);
    expect(find.text('Player 1'), findsOneWidget);
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.text('🚀  Start Game'), findsOneWidget);
  });

  testWidgets('Add player inserts a new player card', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LagosMonopolyApp()));

    await tester.tap(find.text('+ Add Player'));
    await tester.pump();

    expect(find.text('Player 3'), findsOneWidget);
  });

  testWidgets('Clearing a name disables the start button', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LagosMonopolyApp()));

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();

    expect(find.text('Enter all names'), findsOneWidget);
    expect(find.text('🚀  Start Game'), findsNothing);
  });

  testWidgets('Starting a game navigates to the board', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LagosMonopolyApp()));

    await tester.tap(find.text('🚀  Start Game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // The control panel below the Flame board shows the roll button while
    // the game is waiting for the current player to roll.
    expect(find.text('🎲  Roll Dice'), findsOneWidget);
  });

  testWidgets('Rolling animates, then resolves the landing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LagosMonopolyApp()));

    await tester.tap(find.text('🚀  Start Game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('🎲  Roll Dice'));
    await tester.pump();

    // During the animation phase the roll button must be hidden.
    expect(find.text('🎲  Roll Dice'), findsNothing);

    // Let the dice tumble (1.0s roll + 0.35s settle) finish, then the token
    // slide (0.6s) that the resolution emits.
    await tester.pump(const Duration(milliseconds: 1650));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 700));

    // The roll has been resolved: the game is either waiting for the next
    // roll (roll button back) or waiting for a buy/pass decision.
    final rollButton = find.text('🎲  Roll Dice');
    final buyButton = find.textContaining('Buy');
    expect(rollButton.evaluate().isNotEmpty || buyButton.evaluate().isNotEmpty,
        isTrue);
  });
}
