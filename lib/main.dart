import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

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

class _MapScreenState extends State<MapScreen> {
  static const _londonPlacesSourceId = 'london-places-source';
  static const _londonPlacesLayerId = 'london-places-layer';

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  Uint8List? _markerImage;
  String _selectedCity = 'Londyn';

  Future<void> _selectCity(String city) async {
    final viewport = widget.cityViewports[city];
    if (viewport == null) {
      throw StateError('Brak konfiguracji viewportu dla miasta "$city".');
    }

    setState(() {
      _selectedCity = city;
    });

    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    await mapboxMap.flyTo(
      CameraOptions(center: viewport.center, zoom: viewport.zoom, bearing: viewport.bearing, pitch: viewport.pitch),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();

    debugPrint('PointAnnotationManager created: $_pointAnnotationManager');

    _markerImage = await _createMarkerImage();
    debugPrint('Marker image created with size: ${_markerImage?.lengthInBytes} bytes');
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

    final markerImage = _markerImage ?? await _createMarkerImage();
    _markerImage = markerImage;

    await mapboxMap.addImage(
      'custom-icon-id',
      1.0,
      StyleImage.bytes(markerImage),
    );

    final places = await _loadLondonPlaces();
    if (kIsWeb) {
      final geoJson = jsonEncode({
        'type': 'FeatureCollection',
        'features': places
            .map(
              (point) => {
                'type': 'Feature',
                'geometry': point.toJson(),
                'properties': <String, dynamic>{},
              },
            )
            .toList(),
      });

      final existingSource = await mapboxMap.getSource(_londonPlacesSourceId);
      if (existingSource is GeoJsonSource) {
        await existingSource.updateGeoJSON(geoJson);
      } else if (existingSource == null) {
        await mapboxMap.addSource(
          GeoJsonSource(id: _londonPlacesSourceId, data: geoJson),
        );
      } else {
        throw StateError('Źródło $_londonPlacesSourceId nie jest źródłem GeoJSON.');
      }

      if (!await mapboxMap.styleLayerExists(_londonPlacesLayerId)) {
        await mapboxMap.addLayer(
          SymbolLayer(
            id: _londonPlacesLayerId,
            sourceId: _londonPlacesSourceId,
            iconImage: 'custom-icon-id',
            iconAllowOverlap: true,
          ),
        );
      }
    } else {
      final annotationManager = _pointAnnotationManager;
      if (annotationManager == null) {
        throw StateError('PointAnnotationManager nie został zainicjalizowany.');
      }

      await annotationManager.setIconAllowOverlap(true);
      await annotationManager.createMulti(
        places
            .map(
              (point) => PointAnnotationOptions(
                geometry: point,
                image: markerImage,
                iconAnchor: IconAnchor.BOTTOM,
                iconSize: 0.7,
              ),
            )
            .toList(),
      );
    }
  }

  Future<List<Point>> _loadLondonPlaces() async {
    final decoded = jsonDecode(await rootBundle.loadString('assets/london.json'));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Plik london.json musi zawierać obiekt JSON.');
    }

    final categories = decoded['categories'];
    if (categories is! Map<String, dynamic>) {
      throw const FormatException('Plik london.json nie zawiera kategorii miejsc.');
    }

    final points = <Point>[];
    for (final entry in categories.entries) {
      final places = entry.value;
      if (places is! List) {
        throw FormatException('Kategoria "${entry.key}" musi być listą miejsc.');
      }

      for (var index = 0; index < places.length; index++) {
        final place = places[index];
        if (place is! Map<String, dynamic>) {
          throw FormatException('Miejsce $index w kategorii "${entry.key}" jest nieprawidłowe.');
        }

        final latitude = place['lat'];
        final longitude = place['lng'];
        if (latitude is! num || longitude is! num) {
          throw FormatException('Miejsce $index w kategorii "${entry.key}" nie ma poprawnych współrzędnych.');
        }

        points.add(
          Point(
            coordinates: Position(longitude.toDouble(), latitude.toDouble()),
          ),
        );
      }
    }

    return points;
  }

  // Adds a marker at a tapped location.
  Future<void> _addMarker(MapboxMap mapboxMap, Point point) async {
    final annotationManager = _pointAnnotationManager;
    final markerImage = _markerImage;
    debugPrint('Adding marker at position: $point');

    if (annotationManager == null || markerImage == null) return;

    // Check for Web platform if needed to branch logic
    if (kIsWeb) {
      final sourceId = "marker-source";
      GeoJsonSource? existingSource = await mapboxMap.getSource(sourceId) as GeoJsonSource?;

      debugPrint('Existing source | type: ${existingSource.runtimeType}, value: $existingSource');

      final geoJson = jsonEncode({
        'type': 'Feature',
        'geometry': point.toJson(),
        'properties': {},
      });

      if (existingSource != null) {
        await existingSource.updateGeoJSON(geoJson);
      } else {
        await mapboxMap.addSource(
          GeoJsonSource(id: sourceId, data: geoJson),
        );
        await mapboxMap.addLayer(SymbolLayer(id: sourceId, sourceId: sourceId, iconImage: "custom-icon-id"));
      }
    } else {
      // Mobile might still work with PointAnnotationManager
      await annotationManager.create(
        PointAnnotationOptions(geometry: point, image: markerImage, iconAnchor: IconAnchor.BOTTOM, iconSize: 0.7),
      );
    }
  }

  Future<Uint8List> _createMarkerImage() async {
    const size = 64.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final markerPaint = Paint()..color = Colors.red;
    final markerPath = Path()
      ..moveTo(32, 60)
      ..lineTo(16, 32)
      ..arcToPoint(const Offset(48, 32), radius: const Radius.circular(16), clockwise: false)
      ..close();

    debugPrint('Creating marker image with size: $size');

    canvas.drawPath(markerPath, markerPaint);
    canvas.drawCircle(const Offset(32, 25), 10, Paint()..color = Colors.white);

    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    debugPrint('Marker image created with dimensions: ${image.width}x${image.height}');
    debugPrint('Marker image created with size: ${byteData?.lengthInBytes} bytes');
    debugPrint('Marker image created with format: ${ui.ImageByteFormat.png}');
    debugPrint('Marker image created with color: ${markerPaint.color}');

    if (byteData == null) {
      throw StateError('Nie udało się wygenerować obrazu markera.');
    }
    return byteData.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MapInsider')),
      body: Column(
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
