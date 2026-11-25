import 'dart:io';

import 'package:auth0_flutter/auth0_flutter.dart';

import 'auth_session.dart';

class MapInsiderAuth {
  static const domain = 'michalq.eu.auth0.com';
  static const clientId = 'ptu5UJ6jy85W5ZfCrIeT6S2dVuCQTAu0';

  final Auth0 _auth0 = Auth0(domain, clientId);
  late final WindowsWebAuthentication _windowsAuth = _auth0.windowsWebAuthentication();

  Future<AuthSession?> restoreSession() async {
    if (Platform.isWindows) return null;
    if (!await _auth0.credentialsManager.hasValidCredentials()) return null;
    final credentials = await _auth0.credentialsManager.credentials();
    return _toSession(credentials);
  }

  Future<AuthSession?> login({
    required String email,
    required String password,
    String? nickname,
  }) async {
    final Credentials credentials;
    final parameters = <String, String>{'screen_hint': 'signup'};
    if (nickname != null) parameters['nickname'] = nickname;

    if (Platform.isWindows) {
      credentials = await _windowsAuth.login(
        appCustomURL: 'mapinsider://callback',
        scopes: const {'openid', 'profile', 'email', 'offline_access'},
        parameters: parameters,
      );
    } else {
      credentials = await _auth0
          .webAuthentication(scheme: 'https')
          .login(
            useHTTPS: true,
            scopes: const {'openid', 'profile', 'email', 'offline_access'},
            parameters: parameters,
          );
    }
    return _toSession(credentials);
  }

  Future<void> logout() async {
    if (Platform.isWindows) {
      await _windowsAuth.logout(appCustomURL: 'mapinsider://callback');
    } else {
      await _auth0.webAuthentication(scheme: 'https').logout(useHTTPS: true);
    }
  }

  AuthSession _toSession(Credentials credentials) {
    final user = credentials.user;
    return AuthSession(
      subject: user.sub,
      name: user.nickname ?? user.name ?? user.email ?? 'Użytkownik',
      email: user.email,
    );
  }
}
