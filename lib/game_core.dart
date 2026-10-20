import 'dart:math';

class TopoGuessGame {
  final double targetLat;
  final double targetLon;
  final String targetName;
  
  int score = 0;
  int attempts = 0;
  bool gameOver = false;
  List<String> log = [];

  TopoGuessGame({
    this.targetLat = 52.2297, // np. Pałac Kultury i Nauki w Warszawie
    this.targetLon = 21.0122,
    this.targetName = "Pałac Kultury i Nauki",
  }) {
    log.add("Rozpoczęto grę topograficzną z Mapbox!");
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

    double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
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