import 'dart:math';

final class PlaceGuessResult {
  const PlaceGuessResult({
    required this.distanceMeters,
    required this.points,
    required this.totalScore,
  });

  final double distanceMeters;
  final int points;
  final int totalScore;
}

class TopoGuessGame {
  final double targetLat;
  final double targetLon;
  final String targetName;
  final Random _random;

  int score = 0;
  int attempts = 0;
  bool gameOver = false;
  List<String> log = [];

  TopoGuessGame({
    this.targetLat = 52.2297, // np. Pałac Kultury i Nauki w Warszawie
    this.targetLon = 21.0122,
    this.targetName = "Pałac Kultury i Nauki",
    Random? random,
  }) : _random = random ?? Random() {
    log.add("Rozpoczęto grę topograficzną z Mapbox!");
  }

  List<T> chooseRandomTargets<T>({
    required String category,
    required int count,
    required Map<String, String> categoryDataKeys,
    required Map<String, List<T>> placesByCategory,
  }) {
    final dataKey = categoryDataKeys[category];
    if (dataKey == null) {
      throw StateError('Nieznana kategoria miejsc "$category".');
    }

    final places = placesByCategory[dataKey];
    if (places == null || places.isEmpty) {
      throw StateError('Brak miejsc do odgadnięcia dla kategorii "$category".');
    }
    if (count < 1 || count > places.length) {
      throw RangeError.range(count, 1, places.length, 'count');
    }

    final shuffledPlaces = List<T>.of(places)..shuffle(_random);
    return shuffledPlaces.take(count).toList();
  }

  void reset() {
    score = 0;
    attempts = 0;
    gameOver = false;
    log = ["Rozpoczęto grę topograficzną z Mapbox!"];
  }

  PlaceGuessResult submitPlaceGuess({
    required double targetLat,
    required double targetLon,
    required double userLat,
    required double userLon,
    required Duration elapsed,
    required bool isFinalGuess,
  }) {
    attempts++;
    final distanceMeters = _calculateDistance(targetLat, targetLon, userLat, userLon);
    final distancePoints = max(0, (100 - (distanceMeters / 10)).round());
    final timeMultiplier = (1 - elapsed.inMilliseconds / 30000).clamp(0.0, 1.0);
    final points = (distancePoints * timeMultiplier).round();
    score += points;
    gameOver = isFinalGuess;

    final resultMsg = "Próba $attempts: Dystans to ${distanceMeters.toStringAsFixed(0)}m. Zdobyto: $points pkt.";
    log.add(resultMsg);

    return PlaceGuessResult(
      distanceMeters: distanceMeters,
      points: points,
      totalScore: score,
    );
  }

  Map<String, dynamic> submitGuess(double userLat, double userLon) {
    attempts++;
    double distanceMeters = _calculateDistance(targetLat, targetLon, userLat, userLon);

    // Punktacja: im bliżej celu, tym więcej punktów
    int points = max(0, (100 - (distanceMeters / 10)).round());
    score += points;

    String resultMsg = "Próba $attempts: Dystans to ${distanceMeters.toStringAsFixed(0)}m. Zdobyto: $points pkt.";
    log.add(resultMsg);

    if (distanceMeters < 50) {
      gameOver = true;
      log.add("Gratulacje! Cel został poprawnie zlokalizowany.");
    }

    return {
      "distance": distanceMeters,
      "points": points,
      "game_over": gameOver,
    };
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000; // promień Ziemi w metrach
    double phi1 = lat1 * pi / 180;
    double phi2 = lat2 * pi / 180;
    double deltaPhi = (lat2 - lat1) * pi / 180;
    double deltaLambda = (lon2 - lon1) * pi / 180;

    double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  Map<String, dynamic> getState() {
    return {
      "target_name": targetName,
      "score": score,
      "attempts": attempts,
      "game_over": gameOver,
      "log": log,
    };
  }
}
