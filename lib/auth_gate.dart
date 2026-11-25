import 'package:material_ui/material_ui.dart';

import 'auth_session.dart';
import 'mapinsider_auth.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.gameBuilder,
    super.key,
  });

  final Widget Function({
    required AuthSession? session,
    required Future<void> Function({
      required String email,
      required String password,
      String? nickname,
    })
    onLogin,
    required Future<void> Function() onLogout,
    required bool isAuthenticating,
    required String? authError,
    required Key gameKey,
  })
  gameBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = MapInsiderAuth();
  AuthSession? _session;
  bool _isAuthenticating = false;
  String? _authError;
  int _gameVersion = 0;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final session = await _auth.restoreSession();
      if (!mounted) return;
      if (session != null) setState(() => _session = session);
    } catch (error) {
      if (!mounted) return;
      setState(() => _authError = error.toString());
    }
  }

  Future<void> _login({
    required String email,
    required String password,
    String? nickname,
  }) async {
    setState(() {
      _isAuthenticating = true;
      _authError = null;
    });
    try {
      final session = await _auth.login(
        email: email,
        password: password,
        nickname: nickname,
      );
      if (!mounted || session == null) return;
      setState(() {
        _session = session;
        _isAuthenticating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _authError = error.toString();
        _isAuthenticating = false;
      });
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isAuthenticating = true;
      _authError = null;
    });
    try {
      await _auth.logout();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _authError = error.toString();
        _isAuthenticating = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _session = null;
      _isAuthenticating = false;
      _gameVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.gameBuilder(
      session: _session,
      onLogin: _login,
      onLogout: _logout,
      isAuthenticating: _isAuthenticating,
      authError: _authError,
      gameKey: ValueKey(_gameVersion),
    );
  }
}
