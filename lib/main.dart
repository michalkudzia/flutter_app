import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:web/web.dart' as web;
import 'game_core.dart';

void main() {
  // Konfiguracja tokena Mapbox przed uruchomieniem aplikacji
  MapboxOptions.setAccessToken("pk.eyJ1IjoiYWRhbWRyIiwiYSI6ImNtdXZtdnZkajA3ZGEyd3F4emRnMTRrMzEifQ.bQGEH4h2WO2v3QCup-i60Q");
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

  // Funkcja pomocnicza do zamykania aplikacji / karty
  void _closeApp() {
    if (kIsWeb) {
      web.window.close();
    } else {
      SystemNavigator.pop();
    }
  }

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
                      onPressed: _closeApp,
                      icon: const Icon(Icons.close),
                      label: const Text('Zakończ i zamknij'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
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
