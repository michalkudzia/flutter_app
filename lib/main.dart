import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'guess_line_layer.dart';
import 'map_markers.dart';

double calculateStraightLineDistanceKm(Point target, Point clickedPoint) {
  const earthRadiusKm = 6371.0088;
  final targetLatitude = target.coordinates.lat * math.pi / 180;
  final clickedLatitude = clickedPoint.coordinates.lat * math.pi / 180;
  final latitudeDelta = clickedLatitude - targetLatitude;
  final longitudeDelta = (clickedPoint.coordinates.lng - target.coordinates.lng) * math.pi / 180;

  final haversine =
      math.pow(math.sin(latitudeDelta / 2), 2) +
      math.cos(targetLatitude) * math.cos(clickedLatitude) * math.pow(math.sin(longitudeDelta / 2), 2);
  final normalizedHaversine = haversine.clamp(0.0, 1.0);

  return 2 * earthRadiusKm * math.asin(math.sqrt(normalizedHaversine));
}

void showStraightLineDistanceSnackbar({
  required BuildContext context,
  required Point target,
  required Point clickedPoint,
}) {
  final distanceKm = calculateStraightLineDistanceKm(target, clickedPoint);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('Odległość w linii prostej: ${distanceKm.toStringAsFixed(2)} km')),
    );
}

class _LoadedMapConfig {
  const _LoadedMapConfig({required this.token, required this.cityViewports});

  final String token;
  final Map<String, CameraViewportState> cityViewports;
}

Map<String, CameraViewportState> _decodeCityViewports(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Plik cityviewports.json musi zawierać obiekt JSON.');
  }

  final viewports = <String, CameraViewportState>{};
  for (final entry in decoded.entries) {
    final cityConfig = entry.value;
    if (cityConfig is! Map<String, dynamic>) {
      throw FormatException('Konfiguracja miasta "${entry.key}" musi być obiektem JSON.');
    }

    final center = cityConfig['center'];
    final zoom = cityConfig['zoom'];
    final bearing = cityConfig['bearing'];
    final pitch = cityConfig['pitch'];
    if (center is! Map<String, dynamic> ||
        center['lng'] is! num ||
        center['lat'] is! num ||
        zoom is! num ||
        bearing is! num ||
        pitch is! num) {
      throw FormatException('Konfiguracja miasta "${entry.key}" zawiera nieprawidłowe wartości.');
    }

    viewports[entry.key] = CameraViewportState(
      center: Point(
        coordinates: Position(
          (center['lng'] as num).toDouble(),
          (center['lat'] as num).toDouble(),
        ),
      ),
      zoom: zoom.toDouble(),
      bearing: bearing.toDouble(),
      pitch: pitch.toDouble(),
    );
  }

  if (!viewports.containsKey('Londyn')) {
    throw const FormatException('Plik cityviewports.json musi zawierać konfigurację miasta Londyn.');
  }

  return viewports;
}

class MapConfigLoader extends StatelessWidget {
  const MapConfigLoader({super.key});

  Future<_LoadedMapConfig> _loadMapConfig() async {
    final files = await Future.wait([
      rootBundle.loadString('assets/config.json'),
      rootBundle.loadString('assets/cityviewports.json'),
    ]);

    final decodedConfig = jsonDecode(files[0]);
    if (decodedConfig is! Map<String, dynamic>) {
      throw const FormatException('Plik config.json musi zawierać obiekt JSON.');
    }

    final token = decodedConfig['mapbox_access_token'] ?? '';
    if (token is! String) {
      throw const FormatException('Token Mapbox w config.json musi być tekstem.');
    }

    return _LoadedMapConfig(
      token: token,
      cityViewports: _decodeCityViewports(files[1]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LoadedMapConfig>(
      future: _loadMapConfig(),
      builder: (context, snapshot) {
        // 2. Stan: Dane się jeszcze ładują (Spinner)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 3. Stan: Wystąpił błąd podczas wczytywania
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Błąd ładowania konfiguracji: ${snapshot.error}')));
        }

        // 4. Stan: Sukces – dane zostały pobrane
        final config = snapshot.data;
        if (config == null || config.token.isEmpty) {
          return const Scaffold(body: Center(child: Text('Brak tokenu Mapbox w pliku konfiguracyjnym.')));
        }

        // 5. Zwracamy właściwy widok aplikacji, przekazując gotowy token
        return MapScreen(cityViewports: config.cityViewports);
      },
    );
  }
}

// Przykładowy docelowy widok mapy
class MapScreen extends StatefulWidget {
  const MapScreen({required this.cityViewports, super.key});

  final Map<String, CameraViewportState> cityViewports;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _Place {
  const _Place({required this.name, required this.point});

  final String name;
  final Point point;
}

class _MapScreenState extends State<MapScreen> {
  static const _cityDataFiles = {
    'Warszawa': 'warszawa.json',
    'Paryż': 'paris.json',
    'Londyn': 'london.json',
    'Chicago': 'chicago.json',
    'Bombaj': 'mumbai.json',
    'Tokio': 'tokio.json',
    'Meksyk': 'mexico.json',
  };
  static const _categoryDataKeys = {
    'beginner': 'poczatkujacy',
    'advanced': 'zaawansowany',
    'expert': 'ekspert',
  };

  MapboxMap? _mapboxMap;
  final _mapMarkers = MapMarkers();
  final _guessLineLayer = GuessLineLayer();
  Map<String, List<_Place>>? _placesByCategory;
  bool _isStyleLoaded = false;
  final math.Random _random = math.Random();
  String _selectedCity = 'Londyn';
  String _selectedCategory = 'beginner';
  _Place? _targetPlace;
  Point? _lastClickedPoint;
  int _citySelectionVersion = 0;

  Future<void> _selectCity(String city) async {
    final viewport = widget.cityViewports[city];
    if (viewport == null) {
      throw StateError('Brak konfiguracji viewportu dla miasta "$city".');
    }

    final requestVersion = ++_citySelectionVersion;
    final placesByCategory = await _loadCityPlaces(city);
    if (!mounted || requestVersion != _citySelectionVersion) return;
    final places = placesByCategory[_categoryDataKeys[_selectedCategory]!];
    if (places == null || places.isEmpty) {
      throw StateError('Brak miejsc do odgadnięcia dla kategorii "$_selectedCategory" w mieście "$city".');
    }

    setState(() {
      _selectedCity = city;
      _placesByCategory = placesByCategory;
      _targetPlace = places[_random.nextInt(places.length)];
    });
    await _clearGuessLine();

    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    if (_isStyleLoaded) {
      await _renderSelectedPlaces();
    }
    await mapboxMap.flyTo(
      CameraOptions(center: viewport.center, zoom: viewport.zoom, bearing: viewport.bearing, pitch: viewport.pitch),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await _mapMarkers.onMapCreated(mapboxMap);
    mapboxMap.addInteraction(
      TapInteraction.onMap((context) {
        unawaited(_addMarker(mapboxMap, context.point));
      }),
    );

    if (_selectedCity != 'Londyn') {
      await _selectCity(_selectedCity);
    }
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;
    _isStyleLoaded = false;

    await _mapMarkers.onStyleLoaded(mapboxMap);
    await _guessLineLayer.onStyleLoaded(mapboxMap);

    _isStyleLoaded = true;
    final requestVersion = ++_citySelectionVersion;
    final city = _selectedCity;
    final placesByCategory = await _loadCityPlaces(city);
    if (!mounted || requestVersion != _citySelectionVersion) return;
    _placesByCategory = placesByCategory;
    _chooseRandomTarget(_selectedCategory);
    await _renderSelectedPlaces();
  }

  Future<void> _selectCategory(String category) async {
    if (!_categoryDataKeys.containsKey(category)) {
      throw StateError('Nieznana kategoria miejsc "$category".');
    }

    final places = _placesByCategory?[_categoryDataKeys[category]!];
    if (places != null && places.isEmpty) {
      throw StateError('Kategoria "$category" nie zawiera miejsc do odgadnięcia.');
    }

    setState(() {
      _selectedCategory = category;
      _targetPlace = places == null ? null : places[_random.nextInt(places.length)];
    });

    await _clearGuessLine();
    await _renderSelectedPlaces();
  }

  void _chooseRandomTarget(String category) {
    final dataKey = _categoryDataKeys[category];
    if (dataKey == null) {
      throw StateError('Nieznana kategoria miejsc "$category".');
    }

    final places = _placesByCategory?[dataKey];
    if (places == null || places.isEmpty) {
      throw StateError('Brak miejsc do odgadnięcia dla kategorii "$category".');
    }

    setState(() {
      _targetPlace = places[_random.nextInt(places.length)];
      _lastClickedPoint = null;
    });
  }

  Future<void> _clearGuessLine() async {
    _lastClickedPoint = null;
    await _guessLineLayer.clear(_mapboxMap);
  }

  Future<void> _updateGuessLine() async {
    await _guessLineLayer.update(
      _mapboxMap,
      clickedPoint: _lastClickedPoint,
      targetPoint: _targetPlace?.point,
    );
  }

  Future<void> _renderSelectedPlaces() async {
    final mapboxMap = _mapboxMap;
    final placesByCategory = _placesByCategory;
    if (mapboxMap == null || placesByCategory == null) return;

    final dataKey = _categoryDataKeys[_selectedCategory]!;
    final places = placesByCategory[dataKey];
    if (places == null) {
      throw StateError('Plik dla miasta "$_selectedCity" nie zawiera kategorii "$dataKey".');
    }

    await _mapMarkers.renderPlaces(
      mapboxMap,
      places.map((place) => place.point).toList(),
    );
  }

  Future<Map<String, List<_Place>>> _loadCityPlaces(String city) async {
    final dataFile = _cityDataFiles[city];
    if (dataFile == null) {
      throw StateError('Brak zestawu miejsc dla miasta "$city".');
    }

    final decoded = jsonDecode(await rootBundle.loadString('assets/$dataFile'));
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Plik $dataFile musi zawierać obiekt JSON.');
    }

    final categories = decoded['categories'];
    if (categories is! Map<String, dynamic>) {
      throw FormatException('Plik $dataFile nie zawiera kategorii miejsc.');
    }

    final placesByCategory = <String, List<_Place>>{};
    for (final entry in categories.entries) {
      final places = entry.value;
      if (places is! List) {
        throw FormatException('Kategoria "${entry.key}" musi być listą miejsc.');
      }

      final categoryPlaces = <_Place>[];
      for (var index = 0; index < places.length; index++) {
        final place = places[index];
        if (place is! Map<String, dynamic>) {
          throw FormatException('Miejsce $index w kategorii "${entry.key}" jest nieprawidłowe.');
        }

        final name = place['name'];
        final latitude = place['lat'];
        final longitude = place['lng'];
        if (name is! String || latitude is! num || longitude is! num) {
          throw FormatException('Miejsce $index w kategorii "${entry.key}" ma nieprawidłową nazwę lub współrzędne.');
        }

        categoryPlaces.add(
          _Place(
            name: name,
            point: Point(
              coordinates: Position(longitude.toDouble(), latitude.toDouble()),
            ),
          ),
        );
      }
      placesByCategory[entry.key] = categoryPlaces;
    }

    return placesByCategory;
  }

  // Adds a marker at a tapped location.
  Future<void> _addMarker(MapboxMap mapboxMap, Point point) async {
    debugPrint('Adding marker at position: $point');

    final targetPlace = _targetPlace;
    if (targetPlace != null) {
      showStraightLineDistanceSnackbar(
        context: context,
        target: targetPlace.point,
        clickedPoint: point,
      );
    }
    _lastClickedPoint = point;

    await _mapMarkers.addTapMarker(mapboxMap, point);

    await _updateGuessLine();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MapInsider')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sidebarWidth = constraints.maxWidth < 600 ? 160.0 : 240.0;
          return Row(
            children: [
              SizedBox(
                width: sidebarWidth,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Category', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'beginner', child: Text('beginner')),
                            DropdownMenuItem(value: 'advanced', child: Text('advanced')),
                            DropdownMenuItem(value: 'expert', child: Text('expert')),
                          ],
                          onChanged: (category) async {
                            if (category != null) await _selectCategory(category);
                          },
                        ),
                        const SizedBox(height: 24),
                        Text('Place to guess', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(_targetPlace?.name ?? 'Loading place...'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.cityViewports.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final city = widget.cityViewports.keys.elementAt(index);
                          return ChoiceChip(
                            label: Text(city),
                            selected: _selectedCity == city,
                            onSelected: (selected) async {
                              if (selected) await _selectCity(city);
                            },
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: MapWidget(
                        viewport: widget.cityViewports['Londyn']!,
                        onMapCreated: _onMapCreated,
                        onStyleLoadedListener: _onStyleLoaded,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MapInsider',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), useMaterial3: true),
      // Ustawiamy nasz widok ładowania konfiguracji jako ekran startowy
      home: const MapConfigLoader(),
    );
  }
}

void main() async {
  // 1. Inicjalizacje platformowe Fluttera (wymagane przed operacjami asynchronicznymi w main)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Asynchroniczne wczytanie tokenu z pliku JSON w assets
  String accessToken = "";
  try {
    final String jsonString = await rootBundle.loadString('assets/config.json');
    final Map<String, dynamic> config = jsonDecode(jsonString);
    accessToken = config['mapbox_access_token'] ?? '';
  } catch (e) {
    debugPrint("Błąd wczytywania pliku konfiguracyjnego: $e");
  }

  // Pass your access token to MapboxOptions so you can load a map
  debugPrint("Access Token: $accessToken");
  MapboxOptions.setAccessToken(accessToken);

  runApp(const MyApp());
}
