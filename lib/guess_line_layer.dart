import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:material_ui/material_ui.dart' show Color, Colors;
import 'package:logging/logging.dart' show Level;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

final class GuessLineLayer {
  static const _sourceId = 'guess-line-source';
  static const _lineLayerId = 'guess-line-layer';
  static const _pointsLayerId = 'guess-line-points-layer';

  bool _isStyleLoaded = false;

  Future<void> onStyleLoaded(MapboxMap mapboxMap) async {
    _isStyleLoaded = false;
    await _ensureLayers(mapboxMap);
    _isStyleLoaded = true;
  }

  Future<void> clear(MapboxMap? mapboxMap) async {
    if (mapboxMap == null || !_isStyleLoaded) return;
    await update(mapboxMap);
  }

  Future<void> update(
    MapboxMap? mapboxMap, {
    Point? clickedPoint,
    Point? targetPoint,
  }) async {
    if (mapboxMap == null || !_isStyleLoaded) return;

    final source = await mapboxMap.getSource(_sourceId);
    if (source is! GeoJsonSource) {
      throw StateError('Źródło $_sourceId nie jest źródłem GeoJSON.');
    }

    final clicked = clickedPoint?.coordinates;
    final target = targetPoint?.coordinates;
    final layerExists = await mapboxMap.styleLayerExists(_lineLayerId);
    final dynamicData = await source.dynamicData;

    debugPrint(
      '[guess-line] clicked=(${clicked?.lng}, ${clicked?.lat}), '
      'target=(${target?.lng}, ${target?.lat}), '
      'layerExists=$layerExists, dynamicData=$dynamicData',
    );

    final features = clickedPoint == null || targetPoint == null
        ? <Map<String, dynamic>>[]
        : [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [clickedPoint.coordinates.lng, clickedPoint.coordinates.lat],
                  [targetPoint.coordinates.lng, targetPoint.coordinates.lat],
                ],
              },
              'properties': <String, dynamic>{},
            },
          ];
    debugPrint('[guess-line] features=${features.length}');

    await source.updateGeoJSON(
      jsonEncode({'type': 'FeatureCollection', 'features': features}),
    );

    developer.log(
      'GeoJSON updated with ${features.length} features.',
      name: 'guess-line',
      level: Level.INFO.value,
      stackTrace: StackTrace.current,
    );

    for (final property in ['visibility', 'line-color', 'line-width', 'line-opacity']) {
      final value = await mapboxMap.getStyleLayerProperty(_lineLayerId, property);
      debugPrint('[guess-line] $property=${value.value}');
    }

    final layerSource = await mapboxMap.getStyleLayerProperty(_lineLayerId, 'source');
    final layerType = await mapboxMap.getStyleLayerProperty(_lineLayerId, 'type');
    final sourceData = await mapboxMap.getStyleSourceProperty(_sourceId, 'data');

    debugPrint('[guess-line] layer source=${layerSource.value}, type=${layerType.value}');
    debugPrint('[guess-line] source data=${sourceData.value}');
  }

  Future<void> _ensureLayers(MapboxMap mapboxMap) async {
    final existingSource = await mapboxMap.getSource(_sourceId);
    if (existingSource == null) {
      await mapboxMap.addSource(
        GeoJsonSource(
          id: _sourceId,
          data: jsonEncode({'type': 'FeatureCollection', 'features': []}),
        ),
      );
    } else if (existingSource is! GeoJsonSource) {
      throw StateError('Źródło $_sourceId nie jest źródłem GeoJSON.');
    }

    if (await mapboxMap.styleLayerExists(_lineLayerId)) {
      await mapboxMap.removeStyleLayer(_lineLayerId);
    }
    if (await mapboxMap.styleLayerExists(_pointsLayerId)) {
      await mapboxMap.removeStyleLayer(_pointsLayerId);
    }
    await mapboxMap.addLayer(
      LineLayer(
        id: _lineLayerId,
        sourceId: _sourceId,
        lineCap: LineCap.ROUND,
        lineColor: const Color(0xFF0066CC).toARGB32(),
        lineJoin: LineJoin.ROUND,
        lineWidth: 4,
      ),
    );
    await mapboxMap.addLayer(
      CircleLayer(
        id: _pointsLayerId,
        sourceId: _sourceId,
        circleRadius: 9,
        circleColorExpression: const [
          'match',
          ['get', 'label'],
          'A',
          '#2a9d8f',
          'B',
          '#e76f51',
          '#000000',
        ],
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2,
      ),
    );

    final source = await mapboxMap.getSource(_sourceId);
    if (source is! GeoJsonSource) {
      throw StateError('Źródło $_sourceId nie jest źródłem GeoJSON.');
    }
  }
}
