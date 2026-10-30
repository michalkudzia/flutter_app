import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'game_core.dart';

void main() {
  // Konfiguracja tokena Mapbox przed uruchomieniem aplikacji
  MapboxOptions.setAccessToken(
    "pk.eyJ1IjoiYWRhbWRyIiwiYSI6ImNtdXZtdnZkajA3ZGEyd3F4emRnMTRrMzEifQ.bQGEH4h2WO2v3QCup-i60Q",
  );
  runApp(const TopoGameApp());
}

class TopoGameApp extends StatelessWidget {
  const TopoGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Topograficzna Gra Mapbox',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  TopoGuessGame game = TopoGuessGame();
  MapboxMap? mapboxMap;
  // Offset? _tapPosition;
  Offset? _pinScreenPosition; // Pozycja pikselowa szpilki na ekranie
  // double? _targetLat; // Zapisana szerokość geograficzna strzału
  // double? _targetLon; // Zapisana długość geograficzna strzału

  /*
  // Funkcja przeliczająca geolokalizację na piksele ekranu
  Future<void> _updatePinPosition() async {
    if (mapboxMap == null || _targetLat == null || _targetLon == null) return;

    final screenCoord = await mapboxMap!.pixelForCoordinate(
      Point(coordinates: Position(_targetLon!, _targetLat!)),
    );

    setState(() {
      _pinScreenPosition = Offset(screenCoord.x, screenCoord.y);
    });
  }
  */

  void _showGameOverDialog(int finalScore) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Koniec gry'),
          content: Text(
            'Gratulacje! Twój ostateczny wynik to: $finalScore punktów.',
          ),
          actions: [
            // Przycisk zamknięcia / wyjścia z aplikacji
            TextButton.icon(
              onPressed: _closeApp,
              icon: const Icon(Icons.exit_to_app, color: Colors.red),
              label: const Text(
                'Zakończ grę',
                style: TextStyle(color: Colors.red),
              ),
            ),
            // Przycisk restartu rozgrywki
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(); // Zamknij okno dialogowe
                setState(() {
                  game =
                      TopoGuessGame(); // Reset stanu gry poprzez nową instancję
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Zagraj ponownie'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // Funkcja pomocnicza do zamykania aplikacji / karty
  void _closeApp() {
    if (kIsWeb) {
      // Przeglądarka blokuje window.close(), więc wyświetlamy komunikat dla użytkownika
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Możesz teraz bezpiecznie zamknąć tę kartę przeglądarki krzyżykiem (x).',
          ),
          duration: Duration(seconds: 4),
          backgroundColor: Colors.blueGrey,
        ),
      );
    } else {
      // Dla wersji mobilnej (Android / iOS)
      SystemNavigator.pop();
    }
  }

  PointAnnotationManager? pointAnnotationManager;

  /*
  // Wywoływane po pełnym załadowaniu mapy Mapbox
  void _onMapCreated(MapboxMap controller) async {
    mapboxMap = controller;
    await controller.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(21.0122, 52.2297)),
        zoom: 11.0,
      ),
    );

    // Tworzymy menedżer adnotacji punktowych dla tej mapy
    pointAnnotationManager = await mapboxMap!.annotations
        .createPointAnnotationManager();
  }
  */

  /*
  // Wywoływane po pełnym załadowaniu mapy Mapbox
  void _onMapCreated(MapboxMap controller) async {
    mapboxMap = controller;

    // 1. Ustawienie startowe kamery na Warszawę
    await mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(21.0122, 52.2297)),
        zoom: 11.0,
      ),
    );

    // 2. Natywny listener kliknięć Mapboxa (działa płynnie na Web i nie blokuje przeglądarki)
    mapboxMap!.addInteraction(
      TapInteraction.onMap((context) async {
        final lat = context.point.coordinates.lat.toDouble();
        final lng = context.point.coordinates.lng.toDouble();

        setState(() {
          _targetLat = lat;
          _targetLon = lng;
        });

        // Przeliczamy współrzędne geograficzne na aktualne piksele ekranu
        await _updatePinPosition();

        // Wywołujemy logikę gry
        _makeGuess(lat, lng);
      }),
    );

    // 3. Aktualizacja pozycji szpilki podczas przesuwania lub zoomowania mapy
    mapboxMap!.camera.addCameraChangeListener((event) {
      if (_targetLat != null && _targetLon != null) {
        _updatePinPosition();
      }
    });
  }
  */

  /*
  // Wywoływane po pełnym załadowaniu mapy Mapbox
  void _onMapCreated(MapboxMap controller) async {
    mapboxMap = controller;

    // 1. Ustawienie startowe kamery na Warszawę
    await mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(21.0122, 52.2297)),
        zoom: 11.0,
      ),
    );

    // 2. Natywny listener kliknięć Mapboxa (bezpieczny dla Web, nie blokuje pętli zdarzeń)
    mapboxMap!.addOnMapClickListener(
      MyMapClickListener(
        onMapClicked: (coordinate) async {
          final double lng = coordinate.coordinates[0].toDouble();
          final double lat = coordinate.coordinates[1].toDouble();

          setState(() {
            _targetLat = lat;
            _targetLon = lng;
          });

          // Przeliczamy pozycję szpilki na ekranie
          await _updatePinPosition();

          // Wywołujemy logikę gry
          _makeGuess(lat, lng);
        },
      ),
    );
  }*/

  /*
  // Wywoływane po pełnym załadowaniu mapy Mapbox
  void _onMapCreated(MapboxMap controller) async {
    mapboxMap = controller;

    // 1. Ustawienie startowe kamery na Warszawę
    await mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(21.0122, 52.2297)),
        zoom: 11.0,
      ),
    );

    // 2. Nowoczesne API interakcji (stabilne na Webie, nie blokuje przeglądarki)
    mapboxMap!.addInteraction(
      TapInteraction.onMap((context) {
        final double lng = context.point.coordinates.lng.toDouble();
        final double lat = context.point.coordinates.lat.toDouble();

        // Współrzędne ekranowe w pikselach dostajemy bezpośrednio z contextu!
        final double x = context.touchPosition.x;
        final double y = context.touchPosition.y;

        setState(() {
          _targetLat = lat;
          _targetLon = lng;
          _pinScreenPosition = Offset(
            x,
            y,
          ); // Od razu ustawiamy szpilkę pod palcem/myszką
        });

        // Wywołujemy logikę gry
        _makeGuess(lat, lng);
      }),
    );
  }
  */

  void _onMapCreated(MapboxMap controller) async {
    mapboxMap = controller;

    // 1. Ustawienie startowe kamery na Warszawę
    await mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(21.0122, 52.2297)),
        zoom: 11.0,
      ),
    );

    mapboxMap!.addInteraction(
      TapInteraction.onMap((context) {
        final double lng = context.point.coordinates.lng.toDouble();
        final double lat = context.point.coordinates.lat.toDouble();

        final double x = context.touchPosition.x;
        final double y = context.touchPosition.y;

        // Aktualizujemy tylko pozycję szpilki w UI
        setState(() {
          _pinScreenPosition = Offset(x, y);
        });

        // Przekazujemy współrzędne bezpośrednio do logiki gry
        _makeGuess(lat, lng);
      }),
    );
  }

  Future<void> _addPlayerMarker(double lat, double lon) async {
    // Jeśli uruchomiono w przeglądarce, pomijamy menedżer adnotacji,
    // ponieważ Mapbox Web jeszcze go nie wspiera.
    if (kIsWeb) {
      return;
    }

    if (pointAnnotationManager != null) {
      // Usunięcie poprzednich markerów, aby na mapie został tylko aktualny strzał
      await pointAnnotationManager!.deleteAll();

      // Utworzenie opcji nowego punktu
      final options = PointAnnotationOptions(
        // Pamiętaj: najpierw lon, potem lat!
        geometry: Point(coordinates: Position(lon, lat)),
        // Jeśli masz własną grafikę markera w katalogu assets, możesz ją tu wskazać:
        iconImage: "assets/marker_pin.png",
      );

      // Dodanie markera do menedżera
      await pointAnnotationManager!.create(options);
    }
  }

  // Logika sprawdzenia odpowiedzi w grze
  void _makeGuess(double lat, double lon) {
    // Rysujemy marker w miejscu kliknięcia
    _addPlayerMarker(lat, lon);

    setState(() {
      // Przekazujemy kliknięty punkt do logiki gry (TopoGuessGame)
      final result = game.submitGuess(lat, lon);

      // Sprawdzamy, czy grę zakończono lub czy zwrócono wynik
      final double distance = result['distance'] ?? 0.0;
      final int earnedPoints = result['points'] ?? 0;
      final bool isGameOver = result['game_over'] ?? false;

      // Wyświetlamy graczowi informację o odległości i punkciach
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Odległość: ${distance.toStringAsFixed(1)} km | Punkty: +$earnedPoints',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: earnedPoints > 50 ? Colors.green : Colors.orange,
        ),
      );

      // Jeśli to był ostatni punkt w grze, pokazujemy okno podsumowania
      if (isGameOver) {
        _showGameOverDialog(game.score);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = game.getState();
    final log = state['log'] as List<String>;

    return Scaffold(
      appBar: AppBar(
        title: Text('Gra Topograficzna | Punkty: ${state['score']}'),
        actions: [
          // Przycisk zamknięcia w prawym rogu paska
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _closeApp,
            tooltip: 'Koniec gry',
          ),
        ],
      ),
      body: Column(
        children: [
          // Górny panel (np. treść pytania, aktualny wynik)
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Text('Zgadnij lokalizację...'), // Twój widget z pytaniem
          ),
          // Widget mapy Mapbox

          Expanded(
            flex: 2,
            child: Stack(
              children: [
                // Czysty MapWidget bez zewnętrznych gesture detectorów
                MapWidget(onMapCreated: _onMapCreated),

                // Szpilka pozycjonowana na bieżąco względem mapy
                if (_pinScreenPosition != null)
                  Positioned(
                    left: _pinScreenPosition!.dx - 20,
                    top: _pinScreenPosition!.dy - 40,
                    child: const IgnorePointer(
                      child: Icon(
                        Icons.location_pin,
                        size: 40,
                        color: Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          /*
          Expanded(
            flex: 2, // jeśli jest w Column/Row i chcesz kontrolować proporcje
            child: Stack(
              children: [
                // 1. Spód stacka: GestureDetector owijający MapWidget
                GestureDetector(
                  onTapDown: (details) async {
                    final screenCoordinate = ScreenCoordinate(
                      x: details.localPosition.dx,
                      y: details.localPosition.dy,
                    );

                    final point = await mapboxMap!.coordinateForPixel(
                      screenCoordinate,
                    );
                    final double longitude = (point.coordinates[0] as num)
                        .toDouble();
                    final double latitude = (point.coordinates[1] as num)
                        .toDouble();

                    // Zapisujemy pozycję kliknięcia do wyświetlenia ikony w Stack
                    setState(() {
                      _tapPosition = details.localPosition;
                    });

                    _makeGuess(latitude, longitude);
                  },
                  child: MapWidget(onMapCreated: _onMapCreated),
                ),

                // 2. Wierzch stacka: Szpilka pojawiająca się w miejscu kliknięcia
                if (_tapPosition != null)
                  Positioned(
                    left: _tapPosition!.dx - 20,
                    top: _tapPosition!.dy - 40,
                    child: const IgnorePointer(
                      child: Icon(
                        Icons.location_pin,
                        size: 40,
                        color: Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          */

          // Panel dolny ze statystykami i sterowaniem
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Szukany obiekt: ${state['target_name']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _makeGuess(52.2297, 21.0122),
                    child: const Text('Sprawdź strzał w centrum (PKiN)'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dziennik rozgrywki:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: log.length,
                      itemBuilder: (context, index) {
                        // Poprawiona składnia wyświetlania logów od najnowszego
                        return Text(
                          '- ${log[log.length - 1 - index]}',
                          style: const TextStyle(fontSize: 13),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Przycisk kończący na dole panelu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showGameOverDialog(game.score),
                      icon: const Icon(Icons.flag),
                      label: const Text('Podsumuj grę'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showGameOverDialog(game.score),
              icon: const Icon(Icons.flag),
              label: const Text('Podsumuj grę'),
            ),
          ),
        ],
      ),
    );
  }
}
