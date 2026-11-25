# Copilot Instructions

## Project

MapInsider is a Flutter app for a map-based place guessing game. The app is configured for Android, iOS, Linux, macOS, Windows, and web, and is deployed as a web app through GitHub Pages.

## Build, analysis, and tests

- Install dependencies: `flutter pub get`
- Run the app on a connected device or emulator: `flutter run`
- Run the web app locally: `flutter run -d chrome`
- Run static analysis: `flutter analyze`
- Run all tests: `flutter test`
- Run one test file: `flutter test test/mapinsider_game_test.dart`
- Run one named test: `flutter test test/mapinsider_game_test.dart --plain-name "startNewRound combines places from selected categories"`
- Release web build: `flutter build web --release`
- GitHub Pages web build uses: `flutter build web --release --base-href "/<repository-name>/"`
- The analyzer excludes platform-specific source directories in `analysis_options.yaml`; Dart app code and tests are formatted with a 130-column page width.

The existing VS Code launch configurations are in `.vscode/launch.json`, including Chrome, Edge, profile, and desktop targets.

## Architecture

- `lib/main.dart` is the composition root. It initializes Flutter, loads `assets/config.json`, sets the Mapbox access token, and creates `MyApp`.
- `AuthGate` owns authentication state and wraps the game UI. `MapConfigLoader` loads Mapbox and city viewport configuration before creating `MapScreen`.
- `MapScreen` owns the round state: selected city and categories, available and remaining targets, active target, timing, and map submission handling.
- `MapInsiderUi` is the presentational sidebar/map shell. It receives callbacks and state from `MapScreen`; map rendering details stay outside this widget.
- `TopoGuessGame` in `lib/mapinsider_game.dart` is the framework-independent scoring and round-selection model. It combines category places, shuffles targets, calculates Haversine distances, and applies the 30-second time multiplier.
- Mapbox interaction is split between `mapbox_map_view.dart`, `map_markers.dart`, and `guess_line_layer.dart`. `MapboxMapView` adapts `MapWidget` callbacks to the app's injected `MapViewBuilder`.
- Auth implementations are selected by `lib/mapinsider_auth.dart` through Dart conditional imports:
  - web: `mapinsider_auth_web.dart`
  - native/mobile/desktop: `mapinsider_auth_native.dart`
  - unsupported/stub fallback: `mapinsider_auth_stub.dart`

## Assets and configuration

- `assets/config.json` supplies the Mapbox access token.
- `assets/cityviewports.json` supplies camera viewports. The loader currently requires a `Londyn` viewport.
- City place data is stored in `assets/<city>.json`. `MapScreen` explicitly maps city names to filenames and loads the selected city's `categories` object at runtime.
- Category identifiers differ by layer: UI keys are `beginner`, `advanced`, and `expert`, while JSON category keys are Polish names such as `poczatkujacy`, `zaawansowany`, and `ekspert`. `_categoryDataKeys` in `MapScreen` is the mapping between them.
- Adding a city requires keeping the city name aligned across `cityviewports.json`, `_cityDataFiles`, and the runtime `_loadCityPlaces` data shape.

## Repository conventions

- Keep model logic separate from Flutter widgets. Add deterministic game behavior to `TopoGuessGame` and keep Mapbox-specific behavior in the map helper classes.
- Preserve `MapViewBuilder` injection; widget tests use it to replace the real Mapbox map with a lightweight widget.
- Use `_citySelectionVersion`-style mounted/version guards for asynchronous city/style loading when a stale request could update state after a newer city selection.
- Mapbox setup differs on web and native platforms. Follow the existing split:
  - web uses GeoJSON sources/layers and `updateGeoJSON`;
  - native uses point annotation managers and `createMulti`.
- Auth state should remain in `AuthGate` and be passed into `MapScreen`/`MapInsiderUi` through the existing callback and `AuthSession` parameters.
- City JSON and UI text are predominantly Polish. Match existing terminology rather than translating labels inconsistently.
- The app uses `package:material_ui/material_ui.dart` for widgets in some files alongside standard Flutter APIs.
