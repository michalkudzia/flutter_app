import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:material_ui/material_ui.dart' show Colors, Offset, Paint, Path, Radius;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

final class MapMarkers {
  static const _placesSourceId = 'city-places-source';
  static const _placesLayerId = 'city-places-layer';
  static const _tapMarkerSourceId = 'marker-source';
  static const _tapMarkerLayerId = 'marker-source';
  static const _markerImageId = 'custom-icon-id';

  PointAnnotationManager? _tapMarkerManager;
  PointAnnotationManager? _placeMarkerManager;
  Uint8List? _markerImage;

  Future<void> onMapCreated(MapboxMap mapboxMap) async {
    if (!kIsWeb) {
      _tapMarkerManager = await mapboxMap.annotations.createPointAnnotationManager();
      _placeMarkerManager = await mapboxMap.annotations.createPointAnnotationManager();
    }

    _markerImage = await _createMarkerImage();
  }

  Future<void> onStyleLoaded(MapboxMap mapboxMap) async {
    final markerImage = _markerImage ?? await _createMarkerImage();
    _markerImage = markerImage;

    await mapboxMap.addImage(
      _markerImageId,
      1.0,
      StyleImage.bytes(markerImage),
    );
  }

  Future<void> addTapMarker(MapboxMap mapboxMap, Point point) async {
    final markerImage = _markerImage;
    if (markerImage == null) {
      throw StateError('Obraz markera nie został jeszcze utworzony.');
    }

    if (kIsWeb) {
      final existingSource = await mapboxMap.getSource(_tapMarkerSourceId);
      if (existingSource is GeoJsonSource) {
        await existingSource.updateGeoJSON(
          jsonEncode({
            'type': 'Feature',
            'geometry': point.toJson(),
            'properties': {},
          }),
        );
      } else if (existingSource == null) {
        await mapboxMap.addSource(
          GeoJsonSource(
            id: _tapMarkerSourceId,
            data: jsonEncode({
              'type': 'Feature',
              'geometry': point.toJson(),
              'properties': {},
            }),
          ),
        );
        await mapboxMap.addLayer(
          SymbolLayer(
            id: _tapMarkerLayerId,
            sourceId: _tapMarkerSourceId,
            iconImage: _markerImageId,
          ),
        );
      } else {
        throw StateError('Źródło $_tapMarkerSourceId nie jest źródłem GeoJSON.');
      }
      return;
    }

    final annotationManager = _tapMarkerManager;
    if (annotationManager == null) {
      throw StateError('Menedżer markerów nie został zainicjalizowany.');
    }

    await annotationManager.create(
      PointAnnotationOptions(
        geometry: point,
        image: markerImage,
        iconAnchor: IconAnchor.BOTTOM,
        iconSize: 0.7,
      ),
    );
  }

  Future<void> renderPlaces(
    MapboxMap mapboxMap,
    List<Point> places,
  ) async {
    final markerImage = _markerImage;
    if (markerImage == null) {
      throw StateError('Obraz markera nie został jeszcze utworzony.');
    }

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

      final existingSource = await mapboxMap.getSource(_placesSourceId);
      if (existingSource is GeoJsonSource) {
        await existingSource.updateGeoJSON(geoJson);
      } else if (existingSource == null) {
        await mapboxMap.addSource(
          GeoJsonSource(id: _placesSourceId, data: geoJson),
        );
      } else {
        throw StateError('Źródło $_placesSourceId nie jest źródłem GeoJSON.');
      }

      if (!await mapboxMap.styleLayerExists(_placesLayerId)) {
        await mapboxMap.addLayer(
          SymbolLayer(
            id: _placesLayerId,
            sourceId: _placesSourceId,
            iconImage: _markerImageId,
            iconAllowOverlap: true,
          ),
        );
      }
      return;
    }

    final annotationManager = _placeMarkerManager;
    if (annotationManager == null) {
      throw StateError('Menedżer markerów miejsc nie został zainicjalizowany.');
    }

    await annotationManager.deleteAll();
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
}
