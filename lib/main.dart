import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[APP] main() rozpoczęte');
  
  MapboxOptions.setAccessToken(
    const String.fromEnvironment('ACCESS_TOKEN', defaultValue: 'pk.eyJ1IjoiYWRhbWRyIiwiYSI6ImNtdXZtdnZkajA3ZGEyd3F4emRnMTRrMzEifQ.bQGEH4h2WO2v3QCup-i60Q'),
  );

  runApp(const MyApp());
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MapWidget();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('[UI] MyApp.build() wywołane');
    return MaterialApp(
      title: 'Warszawa da się lubić',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  MapboxMap? _mapboxMap;
  Offset? _pinScreenPosition;
  late final Widget _cachedMapWidget;
  int _clickCount = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('[STATE] GameScreen.initState() - tworzenie zcacheowanego MapWidget');
    _cachedMapWidget = MapWidget(
      onMapCreated: _onMapCreated,
    );
  }

  void _onMapCreated(MapboxMap controller) async {
    debugPrint('[MAPBOX] _onMapCreated() wywołane przez kontroler');
    _mapboxMap = controller;

    try {
      await _mapboxMap!.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(21.0122, 52.2297)),
          zoom: 11.0,
        ),
      );
      debugPrint('[MAPBOX] Kamera początkowa ustawiona pomyślnie');
    } catch (e) {
      debugPrint('[MAPBOX ERROR] Błąd ustawiania kamery: $e');
    }

    try {
      _mapboxMap!.addInteraction(
        TapInteraction.onMap((context) {
          _clickCount++;
          debugPrint('[INTERACTION] Kliknięcie #$_clickCount | Ekran: ${context.touchPosition} | Geo: ${context.point.coordinates}');
          
          final double lng = context.point.coordinates.lng.toDouble();
          final double lat = context.point.coordinates.lat.toDouble();
          
          final double x = context.touchPosition.x;
          final double y = context.touchPosition.y;

          setState(() {
            _pinScreenPosition = Offset(x, y);
          });
          debugPrint('[UI] setState wykonane, nowa pozycja szpilki: $_pinScreenPosition');

          _makeGuess(lat, lng);
        }),
      );
      debugPrint('[MAPBOX] TapInteraction zarejestrowana pomyślnie');
    } catch (e) {
      debugPrint('[MAPBOX ERROR] Błąd rejestracji interakcji: $e');
    }
  }

  void _makeGuess(double lat, double lng) {
    debugPrint('[GAME] _makeGuess przetworzone dla współrzędnych: lat=$lat, lng=$lng');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[UI] GameScreen.build() wywołane (stan szpilki: $_pinScreenPosition)');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Warszawa da się lubić'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                _cachedMapWidget,
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
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              alignment: Alignment.center,
              child: const Text(
                'Kliknij na mapie, aby wskazać szukane miejsce w Warszawie.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}