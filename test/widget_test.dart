// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.
//

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show CameraViewportState, Point, Position;
import 'package:mapinsider_flutter_app/main.dart';

void main() {
  testWidgets('Map screen builds with an injected map view', (WidgetTester tester) async {
    final viewport = CameraViewportState(
      center: Point(coordinates: Position(0, 0)),
      zoom: 1,
      bearing: 0,
      pitch: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          cityViewports: {'Londyn': viewport},
          mapViewBuilder: (viewport, onMapCreated, onStyleLoaded) {
            return const SizedBox(key: ValueKey('fake-map'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byKey(const ValueKey('fake-map')), findsOneWidget);
    expect(find.text('Number of places'), findsOneWidget);
    expect(find.text('Zaloguj'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(3));
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile).first).value, isTrue);
  });
}
