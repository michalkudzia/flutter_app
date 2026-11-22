import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'game_core.dart';
import 'guess_line_layer.dart';
import 'map_markers.dart';
import 'mapbox_map_view.dart';

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
  const MapConfigLoader({
    this.mapViewBuilder = buildMapboxMapView,
    super.key,
  });

  final MapViewBuilder mapViewBuilder;

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
        return MapScreen(
          cityViewports: config.cityViewports,
          mapViewBuilder: mapViewBuilder,
        );
      },
    );
  }
}

// Przykładowy docelowy widok mapy
class MapScreen extends StatefulWidget {
  const MapScreen({
    required this.cityViewports,
    this.mapViewBuilder = buildMapboxMapView,
    super.key,
  });

  final Map<String, CameraViewportState> cityViewports;
  final MapViewBuilder mapViewBuilder;

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
  final _game = TopoGuessGame();
  final _mapMarkers = MapMarkers();
  final _guessLineLayer = GuessLineLayer();
  Map<String, List<_Place>>? _placesByCategory;
  bool _isStyleLoaded = false;
  String _selectedCity = 'Londyn';
  String _selectedCategory = 'beginner';
  List<_Place> _remainingTargets = [];
  _Place? _selectedTarget;
  int _targetCount = 1;
  final _guessTimer = Stopwatch();
  bool _isSubmittingGuess = false;
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
    });
    await _startNewRound();

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
        unawaited(_handleMapTap(mapboxMap, context.point));
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
    await _startNewRound();
    await _renderSelectedPlaces();
  }

  Future<void> _selectCategory(String category) async {
    if (!_categoryDataKeys.containsKey(category)) {
      throw StateError('Nieznana kategoria miejsc "$category".');
    }

    final placesByCategory = _placesByCategory;
    final places = placesByCategory?[_categoryDataKeys[category]!];
    if (places != null && places.isEmpty) {
      throw StateError('Kategoria "$category" nie zawiera miejsc do odgadnięcia.');
    }

    setState(() => _selectedCategory = category);
    await _startNewRound();
    await _renderSelectedPlaces();
  }

  Future<void> _startNewRound({int? targetCount}) async {
    final placesByCategory = _placesByCategory;
    final places = placesByCategory?[_categoryDataKeys[_selectedCategory]!];
    if (placesByCategory == null || places == null || places.isEmpty) {
      _game.reset();
      _guessTimer
        ..stop()
        ..reset();
      setState(() {
        _remainingTargets = [];
        _selectedTarget = null;
        _targetCount = 1;
      });
      await _guessLineLayer.clear(_mapboxMap);
      return;
    }

    final count = (targetCount ?? _targetCount).clamp(1, places.length).toInt();
    final targets = _game.chooseRandomTargets(
      category: _selectedCategory,
      count: count,
      categoryDataKeys: _categoryDataKeys,
      placesByCategory: placesByCategory,
    );
    _game.reset();
    _guessTimer
      ..stop()
      ..reset()
      ..start();
    setState(() {
      _targetCount = count;
      _remainingTargets = targets;
      _selectedTarget = targets.first;
    });
    await _guessLineLayer.clear(_mapboxMap);
  }

  Future<void> _selectTarget(_Place target) async {
    setState(() => _selectedTarget = target);
    _guessTimer
      ..stop()
      ..reset()
      ..start();
    await _guessLineLayer.clear(_mapboxMap);
  }

  Future<void> _handleMapTap(MapboxMap mapboxMap, Point clickedPoint) async {
    final target = _selectedTarget;
    if (target == null || _isSubmittingGuess) return;

    setState(() => _isSubmittingGuess = true);
    try {
      final elapsed = _guessTimer.elapsed;
      await _mapMarkers.addTapMarker(mapboxMap, clickedPoint);
      _guessLineLayer.setClickedPoint(clickedPoint);
      await _guessLineLayer.update(mapboxMap, targetPoint: target.point);

      final isFinalGuess = _remainingTargets.length == 1;
      final result = _game.submitPlaceGuess(
        targetLat: target.point.coordinates.lat.toDouble(),
        targetLon: target.point.coordinates.lng.toDouble(),
        userLat: clickedPoint.coordinates.lat.toDouble(),
        userLon: clickedPoint.coordinates.lng.toDouble(),
        elapsed: elapsed,
        isFinalGuess: isFinalGuess,
      );
      final distanceKm = result.distanceMeters / 1000;
      final remainingTargets = _remainingTargets.where((place) => place != target).toList();

      if (!mounted) return;
      setState(() {
        _remainingTargets = remainingTargets;
        _selectedTarget = remainingTargets.isEmpty ? null : remainingTargets.first;
      });
      _guessTimer
        ..stop()
        ..reset();
      if (remainingTargets.isNotEmpty) _guessTimer.start();

      final message = remainingTargets.isEmpty
          ? 'Odległość: ${distanceKm.toStringAsFixed(2)} km • ${result.points} pkt. Wynik końcowy: ${result.totalScore} pkt.'
          : 'Odległość: ${distanceKm.toStringAsFixed(2)} km • Zdobyto: ${result.points} pkt.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isSubmittingGuess = false);
      } else {
        _isSubmittingGuess = false;
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final availablePlaceCount = _placesByCategory?[_categoryDataKeys[_selectedCategory]!]?.length ?? 0;

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
                          onChanged: _isSubmittingGuess
                              ? null
                              : (category) async {
                                  if (category != null) await _selectCategory(category);
                                },
                        ),
                        const SizedBox(height: 16),
                        Text('Number of places', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        DropdownButton<int>(
                          value: availablePlaceCount == 0 ? null : _targetCount,
                          isExpanded: true,
                          items: List.generate(
                            availablePlaceCount,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('${index + 1}'),
                            ),
                          ),
                          onChanged: availablePlaceCount == 0 || _isSubmittingGuess
                              ? null
                              : (count) async {
                                  if (count != null) await _startNewRound(targetCount: count);
                                },
                        ),
                        const SizedBox(height: 16),
                        Text('Place to guess', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        DropdownButton<_Place>(
                          value: _selectedTarget,
                          isExpanded: true,
                          items: _remainingTargets
                              .map(
                                (place) => DropdownMenuItem(
                                  value: place,
                                  child: Text(place.name, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: _isSubmittingGuess
                              ? null
                              : (place) async {
                                  if (place != null) await _selectTarget(place);
                                },
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
                              if (selected && !_isSubmittingGuess) await _selectCity(city);
                            },
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: widget.mapViewBuilder(
                        widget.cityViewports['Londyn']!,
                        _onMapCreated,
                        _onStyleLoaded,
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
  const MyApp({
    this.mapViewBuilder = buildMapboxMapView,
    super.key,
  });

  final MapViewBuilder mapViewBuilder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MapInsider',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), useMaterial3: true),
      // Ustawiamy nasz widok ładowania konfiguracji jako ekran startowy
      home: MapConfigLoader(mapViewBuilder: mapViewBuilder),
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
