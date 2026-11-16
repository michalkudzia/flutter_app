import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

final Map<String, CameraViewportState> cityViewports = {
  'Warszawa': CameraViewportState(
    center: Point(coordinates: Position(21.0122, 52.2297)),
    zoom: 10,
    bearing: 0,
    pitch: 0,
  ),
  'Paryż': CameraViewportState(center: Point(coordinates: Position(2.3522, 48.8566)), zoom: 10, bearing: 0, pitch: 0),
  'Londyn': CameraViewportState(center: Point(coordinates: Position(-0.1276, 51.5072)), zoom: 10, bearing: 0, pitch: 0),
  'Chicago': CameraViewportState(
    center: Point(coordinates: Position(-87.6298, 41.8781)),
    zoom: 10,
    bearing: 0,
    pitch: 0,
  ),
  'Bombaj': CameraViewportState(center: Point(coordinates: Position(72.8777, 19.0760)), zoom: 10, bearing: 0, pitch: 0),
  'Tokio': CameraViewportState(center: Point(coordinates: Position(139.6917, 35.6895)), zoom: 10, bearing: 0, pitch: 0),
  'Meksyk': CameraViewportState(
    center: Point(coordinates: Position(-99.1332, 19.4326)),
    zoom: 10,
    bearing: 0,
    pitch: 0,
  ),
};

class MapConfigLoader extends StatelessWidget {
  const MapConfigLoader({super.key});

  // Metoda zwracająca Future z naszym tokenem
  Future<String> _loadMapboxToken() async {
    final String jsonString = await rootBundle.loadString('assets/config.json');
    final Map<String, dynamic> config = jsonDecode(jsonString);
    return config['mapbox_access_token'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _loadMapboxToken(), // 1. Przekazujemy operację asynchroniczną
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
        final token = snapshot.data;
        if (token == null || token.isEmpty) {
          return const Scaffold(body: Center(child: Text('Brak tokenu Mapbox w pliku konfiguracyjnym.')));
        }

        // 5. Zwracamy właściwy widok aplikacji, przekazując gotowy token
        return const MapScreen();
      },
    );
  }
}

// Przykładowy docelowy widok mapy
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  Uint8List? _markerImage;
  String _selectedCity = 'Londyn';

  Future<void> _selectCity(String city) async {
    setState(() {
      _selectedCity = city;
    });

    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    final viewport = cityViewports[city]!;
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
  }

  // Instead of using PointAnnotationManager, add a layer directly
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
              itemCount: cityViewports.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final city = cityViewports.keys.elementAt(index);
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
              viewport: cityViewports['Londyn']!,
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
