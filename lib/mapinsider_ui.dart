import 'package:material_ui/material_ui.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'auth_session.dart';
import 'mapbox_map_view.dart';

class MapPlace {
  const MapPlace({required this.name, required this.point});

  final String name;
  final Point point;
}

class MapInsiderUi extends StatefulWidget {
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
  final Future<void> Function({
    required String email,
    required String password,
    String? nickname,
  })?
  onLogin;
  final Future<void> Function()? onLogout;
  final bool isAuthenticating;
  final String? authError;

  @override
  State<MapInsiderUi> createState() => _MapInsiderUiState();
}

class _MapInsiderUiState extends State<MapInsiderUi> {
  final _loginFormKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _showLoginFields = false;
  bool _showRegistration = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (_loginFormKey.currentState?.validate() != true) return;
    await widget.onLogin?.call(
      email: _loginController.text.trim(),
      password: _passwordController.text,
    );
  }

  Future<void> _submitRegistration() async {
    if (_loginFormKey.currentState?.validate() != true) return;
    await widget.onLogin?.call(
      email: _loginController.text.trim(),
      password: _passwordController.text,
      nickname: _nicknameController.text.trim(),
    );
  }

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
                        if (widget.session == null) ...[
                          if (!_showLoginFields)
                            FilledButton.icon(
                              onPressed: widget.isAuthenticating || widget.onLogin == null
                                  ? null
                                  : () => setState(() => _showLoginFields = true),
                              icon: widget.isAuthenticating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.login),
                              label: const Text('Zaloguj'),
                            )
                          else ...[
                            Form(
                              key: _loginFormKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _loginController,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.username,
                                      AutofillHints.email,
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Użytkownik/Email',
                                    ),
                                    validator: (value) {
                                      if (value?.trim().isEmpty != false) {
                                        return 'Podaj użytkownika lub email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    textInputAction: _showRegistration ? TextInputAction.next : TextInputAction.done,
                                    autofillHints: const [AutofillHints.password],
                                    decoration: const InputDecoration(labelText: 'Hasło'),
                                    validator: (value) {
                                      if (value?.isEmpty != false) return 'Podaj hasło';
                                      return null;
                                    },
                                    onFieldSubmitted: (_) {
                                      if (!_showRegistration) _submitLogin();
                                    },
                                  ),
                                  if (_showRegistration) ...[
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _nicknameController,
                                      maxLength: 30,
                                      textInputAction: TextInputAction.done,
                                      decoration: const InputDecoration(
                                        labelText: 'Nazwa użytkownika',
                                        hintText: 'Np. Mapownik',
                                      ),
                                      validator: (value) {
                                        final nickname = value?.trim() ?? '';
                                        if (nickname.isEmpty) {
                                          return 'Podaj nazwę użytkownika';
                                        }
                                        if (nickname.length < 2) {
                                          return 'Nazwa musi mieć co najmniej 2 znaki';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: widget.isAuthenticating || widget.onLogin == null
                                  ? null
                                  : _showRegistration
                                  ? _submitRegistration
                                  : _submitLogin,
                              icon: widget.isAuthenticating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.login),
                              label: Text(_showRegistration ? 'Zarejestruj' : 'Zaloguj'),
                            ),
                            TextButton(
                              onPressed: widget.isAuthenticating
                                  ? null
                                  : () => setState(
                                      () => _showRegistration = !_showRegistration,
                                    ),
                              child: Text(
                                _showRegistration ? 'Masz konto? Zaloguj' : 'Nie masz konta? Zarejestruj',
                              ),
                            ),
                          ],
                        ] else ...[
                          Text(
                            widget.session!.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (widget.session!.email != null)
                            Text(
                              widget.session!.email!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          OutlinedButton.icon(
                            onPressed: widget.isAuthenticating ? null : widget.onLogout,
                            icon: widget.isAuthenticating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.logout),
                            label: const Text('Wyloguj'),
                          ),
                        ],
                        if (widget.authError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.authError!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ],
                        const Divider(height: 24),
                        Text('Category', style: Theme.of(context).textTheme.titleMedium),
                        for (final category in widget.categoryKeys)
                          CheckboxListTile(
                            title: Text(category),
                            value: widget.selectedCategories.contains(category),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: widget.isSubmittingGuess
                                ? null
                                : (selected) async {
                                    if (selected != null) {
                                      await widget.onToggleCategory(category, selected);
                                    }
                                  },
                          ),
                        const SizedBox(height: 16),
                        Text('Number of places', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        DropdownButton<int>(
                          value: widget.availablePlaceCount == 0 ? null : widget.targetCount,
                          isExpanded: true,
                          items: List.generate(
                            widget.availablePlaceCount,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('${index + 1}'),
                            ),
                          ),
                          onChanged: widget.availablePlaceCount == 0 || widget.isSubmittingGuess
                              ? null
                              : (count) async {
                                  if (count != null) {
                                    await widget.onPrepareNewRound(targetCount: count);
                                  }
                                },
                        ),
                        const SizedBox(height: 16),
                        Text('Place to guess', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        DropdownButton<MapPlace>(
                          value: widget.selectedTarget,
                          isExpanded: true,
                          items: widget.remainingTargets
                              .map(
                                (place) => DropdownMenuItem(
                                  value: place,
                                  child: Text(place.name, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: widget.isSubmittingGuess
                              ? null
                              : (place) async {
                                  if (place != null) await widget.onSelectTarget(place);
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
                            selected: widget.selectedCity == city,
                            onSelected: (selected) async {
                              if (selected && !widget.isSubmittingGuess) {
                                await widget.onSelectCity(city);
                              }
                            },
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: widget.mapViewBuilder(
                        widget.cityViewports['Londyn']!,
                        (map) => widget.onMapCreated(map),
                        (data) => widget.onStyleLoaded(data),
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
