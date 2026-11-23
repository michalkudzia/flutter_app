import 'package:material_ui/material_ui.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'auth_session.dart';
import 'mapbox_map_view.dart';

class MapPlace {
  const MapPlace({required this.name, required this.point});

  final String name;
  final Point point;
}

class MapInsiderUi extends StatelessWidget {
  const MapInsiderUi({
    required this.cityViewports,
    required this.mapViewBuilder,
    required this.categoryKeys,
    required this.selectedCategories,
    required this.availablePlaceCount,
    required this.targetCount,
    required this.remainingTargets,
    required this.selectedTarget,
    required this.isSubmittingGuess,
    required this.selectedCity,
    required this.onToggleCategory,
    required this.onPrepareNewRound,
    required this.onSelectTarget,
    required this.onSelectCity,
    required this.onMapCreated,
    required this.onStyleLoaded,
    this.session,
    this.onLogin,
    this.onLogout,
    this.isAuthenticating = false,
    this.authError,
    super.key,
  });

  final Map<String, CameraViewportState> cityViewports;
  final MapViewBuilder mapViewBuilder;
  final Iterable<String> categoryKeys;
  final Set<String> selectedCategories;
  final int availablePlaceCount;
  final int targetCount;
  final List<MapPlace> remainingTargets;
  final MapPlace? selectedTarget;
  final bool isSubmittingGuess;
  final String selectedCity;
  final Future<void> Function(String category, bool selected) onToggleCategory;
  final Future<void> Function({int? targetCount}) onPrepareNewRound;
  final Future<void> Function(MapPlace place) onSelectTarget;
  final Future<void> Function(String city) onSelectCity;
  final Future<void> Function(MapboxMap map) onMapCreated;
  final Future<void> Function(StyleLoadedEventData data) onStyleLoaded;
  final AuthSession? session;
  final Future<void> Function()? onLogin;
  final Future<void> Function()? onLogout;
  final bool isAuthenticating;
  final String? authError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MapInsider'),
      ),
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
                        if (session == null)
                          OutlinedButton.icon(
                            onPressed: isAuthenticating || onLogin == null ? null : onLogin,
                            icon: isAuthenticating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.login),
                            label: const Text('Zaloguj'),
                          )
                        else ...[
                          OutlinedButton.icon(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Profil'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(session!.name),
                                    if (session!.email != null) Text(session!.email!),
                                    const SizedBox(height: 8),
                                    SelectableText(session!.subject),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Zamknij'),
                                  ),
                                ],
                              ),
                            ),
                            icon: const Icon(Icons.person_outline),
                            label: const Text('Profil'),
                          ),
                          OutlinedButton.icon(
                            onPressed: isAuthenticating ? null : onLogout,
                            icon: isAuthenticating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.logout),
                            label: const Text('Wyloguj'),
                          ),
                        ],
                        if (authError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            authError!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ],
                        const Divider(height: 24),
                        Text('Category', style: Theme.of(context).textTheme.titleMedium),
                        for (final category in categoryKeys)
                          CheckboxListTile(
                            title: Text(category),
                            value: selectedCategories.contains(category),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: isSubmittingGuess
                                ? null
                                : (selected) async {
                                    if (selected != null) await onToggleCategory(category, selected);
                                  },
                          ),
                        const SizedBox(height: 16),
                        Text('Number of places', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        DropdownButton<int>(
                          value: availablePlaceCount == 0 ? null : targetCount,
                          isExpanded: true,
                          items: List.generate(
                            availablePlaceCount,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('${index + 1}'),
                            ),
                          ),
                          onChanged: availablePlaceCount == 0 || isSubmittingGuess
                              ? null
                              : (count) async {
                                  if (count != null) await onPrepareNewRound(targetCount: count);
                                },
                        ),
                        const SizedBox(height: 16),
                        Text('Place to guess', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        DropdownButton<MapPlace>(
                          value: selectedTarget,
                          isExpanded: true,
                          items: remainingTargets
                              .map(
                                (place) => DropdownMenuItem(
                                  value: place,
                                  child: Text(place.name, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: isSubmittingGuess
                              ? null
                              : (place) async {
                                  if (place != null) await onSelectTarget(place);
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
                        itemCount: cityViewports.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final city = cityViewports.keys.elementAt(index);
                          return ChoiceChip(
                            label: Text(city),
                            selected: selectedCity == city,
                            onSelected: (selected) async {
                              if (selected && !isSubmittingGuess) await onSelectCity(city);
                            },
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: mapViewBuilder(
                        cityViewports['Londyn']!,
                        (map) => onMapCreated(map),
                        (data) => onStyleLoaded(data),
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
