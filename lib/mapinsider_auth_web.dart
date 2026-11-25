import 'dart:convert';

import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:auth0_flutter/auth0_flutter_web.dart';
import 'package:http/http.dart' as http;

import 'auth_session.dart';

class MapInsiderAuth {
  static const domain = 'michalq.eu.auth0.com';
  static const clientId = 'ptu5UJ6jy85W5ZfCrIeT6S2dVuCQTAu0';
  static const connection = 'Username-Password-Authentication';

  final Auth0Web _auth0 = Auth0Web(domain, clientId);

  Future<AuthSession?> restoreSession() async {
    final credentials = await _auth0.onLoad(
      cacheLocation: CacheLocation.localStorage,
      scopes: const {'openid', 'profile', 'email'},
    );
    return credentials == null ? null : _toSession(credentials);
  }

  Future<AuthSession?> login({
    required String email,
    required String password,
    String? nickname,
  }) async {
    if (nickname != null) {
      await _signup(email: email, password: password, nickname: nickname);
    }

    final tokenResponse = await http.post(
      Uri.https(domain, '/oauth/token'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'grant_type': 'http://auth0.com/oauth/grant-type/password-realm',
        'client_id': clientId,
        'username': email,
        'password': password,
        'realm': connection,
        'scope': 'openid profile email',
      }),
    );

    final tokenBody = jsonDecode(tokenResponse.body);
    if (tokenResponse.statusCode < 200 || tokenResponse.statusCode >= 300) {
      throw StateError(_authError(tokenBody));
    }
    if (tokenBody is! Map<String, dynamic>) {
      throw const FormatException('Nieprawidłowa odpowiedź Auth0.');
    }

    final accessToken = tokenBody['access_token'];
    if (accessToken is! String) {
      throw StateError('Auth0 nie zwrócił access token.');
    }

    final profileResponse = await http.get(
      Uri.https(domain, '/userinfo'),
      headers: {'authorization': 'Bearer $accessToken'},
    );
    final profile = jsonDecode(profileResponse.body);
    if (profileResponse.statusCode < 200 || profileResponse.statusCode >= 300) {
      throw StateError(_authError(profile));
    }
    if (profile is! Map<String, dynamic>) {
      throw const FormatException('Nieprawidłowa odpowiedź profilu Auth0.');
    }

    return AuthSession(
      subject: profile['sub'] as String? ?? '',
      name: profile['name'] as String? ?? profile['nickname'] as String? ?? profile['email'] as String? ?? 'Użytkownik',
      email: profile['email'] as String?,
    );
  }

  Future<void> _signup({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final response = await http.post(
      Uri.https(domain, '/dbconnections/signup'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'client_id': clientId,
        'email': email,
        'password': password,
        'connection': connection,
        'username': nickname,
        'user_metadata': {'nickname': nickname},
      }),
    );

    final body = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_authError(body));
    }
  }

  String _authError(Object? body) {
    if (body is Map<String, dynamic>) {
      return body['description'] as String? ??
          body['error_description'] as String? ??
          body['error'] as String? ??
          'Operacja Auth0 nie powiodła się.';
    }
    return 'Operacja Auth0 nie powiodła się.';
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
