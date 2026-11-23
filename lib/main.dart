import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'mapinsider_game.dart';
import 'guess_line_layer.dart';
import 'map_markers.dart';
import 'mapbox_map_view.dart';
import 'mapinsider_ui.dart';
import 'auth_gate.dart';
import 'auth_session.dart';

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

class MapConfigLoader extends StatefulWidget {
  const MapConfigLoader({
    this.mapViewBuilder = buildMapboxMapView,
    this.session,
    this.onLogin,
    this.onLogout,
    this.isAuthenticating = false,
    this.authError,
    super.key,
  });

  final MapViewBuilder mapViewBuilder;
  final AuthSession? session;
  final Future<void> Function()? onLogin;
  final Future<void> Function()? onLogout;
  final bool isAuthenticating;
  final String? authError;

  @override
  State<MapConfigLoader> createState() => _MapConfigLoaderState();
}

class _MapConfigLoaderState extends State<MapConfigLoader> {
  late final Future<_LoadedMapConfig> _mapConfig = _loadMapConfig();

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
      future: _mapConfig,
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
          mapViewBuilder: widget.mapViewBuilder,
          session: widget.session,
          onLogin: widget.onLogin,
          onLogout: widget.onLogout,
          isAuthenticating: widget.isAuthenticating,
          authError: widget.authError,
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
    this.session,
    this.onLogin,
    this.onLogout,
    this.isAuthenticating = false,
    this.authError,
    super.key,
  });

  final Map<String, CameraViewportState> cityViewports;
  final MapViewBuilder mapViewBuilder;
  final AuthSession? session;
  final Future<void> Function()? onLogin;
  final Future<void> Function()? onLogout;
  final bool isAuthenticating;
  final String? authError;

  @override
  State<MapScreen> createState() => _MapScreenState();
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
  Map<String, List<MapPlace>>? _placesByCategory;
  bool _isStyleLoaded = false;
  String _selectedCity = 'Londyn';
  Set<String> _selectedCategories = {'beginner'};
  List<MapPlace> _remainingTargets = [];
  MapPlace? _selectedTarget;
  int _targetCount = TopoGuessGame.initialTargetCount;
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
    final places = _placesForSelectedCategories(placesByCategory, city: city);
    if (_selectedCategories.isNotEmpty && places.isEmpty) {
      throw StateError(
        'Brak miejsc do odgadnięcia dla wybranych kategorii "${_selectedCategories.join(', ')}" w mieście "$city".',
      );
    }

    setState(() {
      _selectedCity = city;
      _placesByCategory = placesByCategory;
    });
    await _prepareNewRound();

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
    await _prepareNewRound();
    await _renderSelectedPlaces();
  }

  Future<void> _toggleCategory(String category, bool selected) async {
    if (!_categoryDataKeys.containsKey(category)) {
      throw StateError('Nieznana kategoria miejsc "$category".');
    }

    final categories = Set<String>.of(_selectedCategories);
    if (selected) {
      categories.add(category);
    } else {
      categories.remove(category);
    }
    setState(() => _selectedCategories = categories);
    await _prepareNewRound();
    await _renderSelectedPlaces();
  }

  List<MapPlace> _placesForSelectedCategories(
    Map<String, List<MapPlace>>? placesByCategory, {
    required String city,
  }) {
    if (placesByCategory == null) return [];

    final places = <MapPlace>[];
    for (final category in _selectedCategories) {
      final dataKey = _categoryDataKeys[category];
      if (dataKey == null) {
        throw StateError('Nieznana kategoria miejsc "$category".');
      }

      final categoryPlaces = placesByCategory[dataKey];
      if (categoryPlaces == null) {
        throw StateError('Plik dla miasta "$city" nie zawiera kategorii "$dataKey".');
      }
      places.addAll(categoryPlaces);
    }
    return places;
  }

  Future<void> _prepareNewRound({int? targetCount}) async {
    final targets = _game.startNewRound(
      categories: _selectedCategories,
      targetCount: targetCount ?? _targetCount,
      categoryDataKeys: _categoryDataKeys,
      placesByCategory: _placesByCategory,
    );

    _guessTimer
      ..stop()
      ..reset();
    if (targets.isNotEmpty) _guessTimer.start();

    setState(() {
      _targetCount = targets.isEmpty ? 1 : targets.length;
      _remainingTargets = targets;
      _selectedTarget = targets.isEmpty ? null : targets.first;
    });
    await _guessLineLayer.clear(_mapboxMap);
  }

  Future<void> _selectTarget(MapPlace target) async {
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
    if (mapboxMap == null) return;
    final places = _placesForSelectedCategories(_placesByCategory, city: _selectedCity);

    await _mapMarkers.renderPlaces(
      mapboxMap,
      places.map((place) => place.point).toList(),
    );
  }

  Future<Map<String, List<MapPlace>>> _loadCityPlaces(String city) async {
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

    final placesByCategory = <String, List<MapPlace>>{};
    for (final entry in categories.entries) {
      final places = entry.value;
      if (places is! List) {
        throw FormatException('Kategoria "${entry.key}" musi być listą miejsc.');
      }

      final categoryPlaces = <MapPlace>[];
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
          MapPlace(
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
    final availablePlaceCount = _placesForSelectedCategories(_placesByCategory, city: _selectedCity).length;
    return MapInsiderUi(
      cityViewports: widget.cityViewports,
      mapViewBuilder: widget.mapViewBuilder,
      categoryKeys: _categoryDataKeys.keys,
      selectedCategories: _selectedCategories,
      availablePlaceCount: availablePlaceCount,
      targetCount: _targetCount,
      remainingTargets: _remainingTargets,
      selectedTarget: _selectedTarget,
      isSubmittingGuess: _isSubmittingGuess,
      selectedCity: _selectedCity,
      onToggleCategory: _toggleCategory,
      onPrepareNewRound: _prepareNewRound,
      onSelectTarget: _selectTarget,
      onSelectCity: _selectCity,
      onMapCreated: _onMapCreated,
      onStyleLoaded: _onStyleLoaded,
      session: widget.session,
      onLogin: widget.onLogin,
      onLogout: widget.onLogout,
      isAuthenticating: widget.isAuthenticating,
      authError: widget.authError,
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
      home: AuthGate(
        gameBuilder:
            ({
              required AuthSession? session,
              required Future<void> Function() onLogin,
              required Future<void> Function() onLogout,
              required bool isAuthenticating,
              required String? authError,
              required Key gameKey,
            }) => MapConfigLoader(
              key: gameKey,
              mapViewBuilder: mapViewBuilder,
              session: session,
              onLogin: onLogin,
              onLogout: session == null ? null : onLogout,
              isAuthenticating: isAuthenticating,
              authError: authError,
            ),
      ),
    );
  }
}

Future<String> getMapboxAccessToken() async {
  // Asynchroniczne wczytanie tokenu z pliku JSON w assets
  String accessToken = "";
  try {
    final String jsonString = await rootBundle.loadString('assets/config.json');
    final Map<String, dynamic> config = jsonDecode(jsonString);
    accessToken = config['mapbox_access_token'] ?? '';
  } catch (e) {
    debugPrint("Błąd wczytywania pliku konfiguracyjnego: $e");
  }
  return accessToken;
}

void main() async {
  // Inicjalizacje platformowe Fluttera (wymagane przed operacjami asynchronicznymi w main)
  WidgetsFlutterBinding.ensureInitialized();
  final String accessToken = await getMapboxAccessToken();
  debugPrint("Access Token: $accessToken");
  // Pass your access token to MapboxOptions so you can load a map
  MapboxOptions.setAccessToken(accessToken);
  runApp(const MyApp());
}
