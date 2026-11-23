import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:auth0_flutter/auth0_flutter_web.dart';

import 'auth_session.dart';

class MapInsiderAuth {
  static const domain = 'michalq.eu.auth0.com';
  static const clientId = 'ptu5UJ6jy85W5ZfCrIeT6S2dVuCQTAu0';

  final Auth0Web _auth0 = Auth0Web(domain, clientId);

  Future<AuthSession?> restoreSession() async {
    final credentials = await _auth0.onLoad(
      cacheLocation: CacheLocation.localStorage,
      scopes: const {'openid', 'profile', 'email'},
    );
    return credentials == null ? null : _toSession(credentials);
  }

  Future<AuthSession> login() async {
    final credentials = await _auth0.loginWithPopup(
      scopes: const {'openid', 'profile', 'email'},
    );
    return _toSession(credentials);
  }

  Future<void> logout() async {
    await _auth0.logout();
  }

  AuthSession _toSession(Credentials credentials) {
    final user = credentials.user;
    return AuthSession(
      subject: user.sub,
      name: user.name ?? user.nickname ?? user.email ?? 'Użytkownik',
      email: user.email,
    );
  }
}
