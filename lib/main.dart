import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'game_core.dart';

void main() {
  // Konfiguracja tokena Mapbox przed uruchomieniem aplikacji
  MapboxOptions.setAccessToken("TWÓJ_MAPBOX_ACCESS_TOKEN");
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
  final TopoGuessGame game = TopoGuessGame();
  MapboxMap? mapboxMap;

  void _onMapCreated(MapboxMap map) {
    mapboxMap = map;
    map.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(21.0122, 52.2297)),
        zoom: 13.0,
      ),
    );
  }

  void _makeGuess(double lat, double lon) {
    setState(() {
      final result = game.submitGuess(lat, lon);
      if (result['game_over']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cel odnaleziony! Wynik końcowy: ${game.score}')),
        );
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
      ),
      body: Column(
        children: [
          // Widget mapy Mapbox zajmujący górną część ekranu
          Expanded(
            flex: 2,
            child: MapWidget(
              key: const ValueKey("mapWidget"),
              onMapCreated: _onMapCreated,
            ),
          ),
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _makeGuess(52.2297, 21.0122),
                    child: const Text('Sprawdź strzał w centrum (PKiN)'),
                  ),
                  const SizedBox(height: 8),
                  const Text('Dziennik rozgrywki:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: ListView.builder(
                      itemCount: log.length,
                      itemBuilder: (context, index) {
                        return Text('- ${log[log.length - 1 - index]}', style: const TextStyle(fontSize: 13));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}