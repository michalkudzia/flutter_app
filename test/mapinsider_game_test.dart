import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapinsider_flutter_app/mapinsider_game.dart';

void main() {
  test('chooseRandomTargets returns the requested number without duplicates', () {
    final game = TopoGuessGame(random: Random(1));

    final targets = game.chooseRandomTargets(
      category: 'beginner',
      count: 3,
      categoryDataKeys: {'beginner': 'basic'},
      placesByCategory: {
        'basic': ['one', 'two', 'three', 'four'],
      },
    );

    expect(targets, hasLength(3));
    expect(targets.toSet(), hasLength(3));
    expect(
      () => game.chooseRandomTargets(
        category: 'beginner',
        count: 5,
        categoryDataKeys: {'beginner': 'basic'},
        placesByCategory: {
          'basic': ['one', 'two', 'three', 'four'],
        },
      ),
      throwsRangeError,
    );
  });

  test('startNewRound resets game state and clamps count to available places', () {
    final game = TopoGuessGame(random: Random(1));
    game.submitGuess(0, 0);

    final targets = game.startNewRound(
      categories: ['beginner'],
      targetCount: 3,
      categoryDataKeys: {'beginner': 'basic'},
      placesByCategory: {
        'basic': ['one', 'two'],
      },
    );

    expect(targets, hasLength(2));
    expect(game.score, 0);
    expect(game.attempts, 0);
    expect(game.gameOver, isFalse);
    expect(game.log, hasLength(1));
  });

  test('startNewRound combines places from selected categories', () {
    final game = TopoGuessGame(random: Random(1));
    const placesByCategory = {
      'basic': ['one', 'two'],
      'advanced': ['three', 'four'],
    };

    final targets = game.startNewRound(
      categories: ['beginner', 'advanced'],
      targetCount: 4,
      categoryDataKeys: {'beginner': 'basic', 'advanced': 'advanced'},
      placesByCategory: placesByCategory,
    );

    expect(targets, hasLength(4));
    expect(targets.toSet(), placesByCategory.values.expand((places) => places).toSet());
  });

  test('startNewRound returns no targets when no categories are selected', () {
    final game = TopoGuessGame(random: Random(1));

    final targets = game.startNewRound(
      categories: [],
      targetCount: 1,
      categoryDataKeys: {'beginner': 'basic'},
      placesByCategory: {
        'basic': ['one'],
      },
    );

    expect(targets, isEmpty);
  });

  test('startNewRound resets game state when no places are available', () {
    final game = TopoGuessGame(random: Random(1));
    game.submitGuess(0, 0);

    final targets = game.startNewRound(
      categories: ['beginner'],
      targetCount: 1,
      categoryDataKeys: {'beginner': 'basic'},
      placesByCategory: null,
    );

    expect(targets, isEmpty);
    expect(game.score, 0);
    expect(game.attempts, 0);
    expect(game.gameOver, isFalse);
    expect(game.log, hasLength(1));
  });

  test('submitPlaceGuess reduces points to zero after 30 seconds', () {
    final game = TopoGuessGame(random: Random(1));

    final onTime = game.submitPlaceGuess(
      targetLat: 0,
      targetLon: 0,
      userLat: 0,
      userLon: 0,
      elapsed: Duration.zero,
      isFinalGuess: false,
    );
    final halfway = game.submitPlaceGuess(
      targetLat: 0,
      targetLon: 0,
      userLat: 0,
      userLon: 0,
      elapsed: const Duration(seconds: 15),
      isFinalGuess: false,
    );
    final late = game.submitPlaceGuess(
      targetLat: 0,
      targetLon: 0,
      userLat: 0,
      userLon: 0,
      elapsed: const Duration(seconds: 30),
      isFinalGuess: true,
    );

    expect(onTime.points, 100);
    expect(halfway.points, 50);
    expect(late.points, 0);
    expect(late.totalScore, 150);
    expect(game.gameOver, isTrue);
  });
}
