import 'package:material_ui/material_ui.dart' show BuildContext, StatelessWidget, Widget;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

typedef MapViewBuilder = Widget Function(
  CameraViewportState viewport,
  void Function(MapboxMap) onMapCreated,
  void Function(StyleLoadedEventData) onStyleLoaded,
);

Widget buildMapboxMapView(
  CameraViewportState viewport,
  void Function(MapboxMap) onMapCreated,
  void Function(StyleLoadedEventData) onStyleLoaded,
) {
  return MapboxMapView(
    viewport: viewport,
    onMapCreated: onMapCreated,
    onStyleLoaded: onStyleLoaded,
  );
}

final class MapboxMapView extends StatelessWidget {
  const MapboxMapView({
    required this.viewport,
    required this.onMapCreated,
    required this.onStyleLoaded,
    super.key,
  });

  final CameraViewportState viewport;
  final void Function(MapboxMap) onMapCreated;
  final void Function(StyleLoadedEventData) onStyleLoaded;

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      viewport: viewport,
      onMapCreated: onMapCreated,
      onStyleLoadedListener: onStyleLoaded,
    );
  }
}
