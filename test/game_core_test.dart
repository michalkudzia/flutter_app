import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapinsider_flutter_app/game_core.dart';

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
