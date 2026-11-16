import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show Point, Position;
import 'package:mapinsider_flutter_app/main.dart' show calculateStraightLineDistanceKm;

void main() {
  test('returns zero for the same point', () {
    final point = Point(coordinates: Position(-0.1276, 51.5072));

    expect(calculateStraightLineDistanceKm(point, point), 0);
  });

  test('calculates the great-circle distance between London and Paris', () {
    final london = Point(coordinates: Position(-0.1276, 51.5072));
    final paris = Point(coordinates: Position(2.3522, 48.8566));

    expect(calculateStraightLineDistanceKm(london, paris), closeTo(343.6, 1));
  });
}
