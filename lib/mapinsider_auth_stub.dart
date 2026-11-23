import 'auth_session.dart';

class MapInsiderAuth {
  Future<AuthSession?> restoreSession() async => null;
  Future<AuthSession> login() async => throw UnsupportedError('Auth0 is not supported on this platform.');
  Future<void> logout() async {}
}
