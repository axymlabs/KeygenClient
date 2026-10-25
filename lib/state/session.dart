import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/demo.dart';
import '../api/keygen_client.dart';

enum AuthState { loading, signedOut, signedIn }

/// Holds the server connection and login, remembered between runs.
class Session extends ChangeNotifier {
  static const _secure = FlutterSecureStorage();
  static const _kUrl = 'serverUrl';
  static const _kAccount = 'account';
  static const _kEmail = 'email';
  static const _kToken = 'token';

  AuthState state = AuthState.loading;
  String serverUrl = '';
  String account = '';
  String email = '';
  KeygenClient? client;
  Resource? user;
  bool _demo = false;

  KeygenClient get api => client!;

  static String normalizeUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) return url;
    if (!url.contains('://')) {
      final local = RegExp(r'^(localhost|127\.|10\.|192\.168\.|0\.0\.0\.0)');
      url = '${local.hasMatch(url) ? 'http' : 'https'}://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Future<String?> _readToken(SharedPreferences prefs) async {
    try {
      final t = await _secure.read(key: _kToken);
      if (t != null && t.isNotEmpty) {
        await prefs.remove(_kToken);
        return t;
      }
    } catch (_) {}
    // Migrate older builds once; never continue using a plaintext token.
    final legacy = prefs.getString(_kToken);
    if (legacy == null || legacy.isEmpty) return null;
    try {
      await _writeToken(prefs, legacy);
      return legacy;
    } on ApiException {
      return null;
    } finally {
      await prefs.remove(_kToken);
    }
  }

  Future<void> _writeToken(SharedPreferences prefs, String? token) async {
    if (token == null) {
      await prefs.remove(_kToken);
      try {
        await _secure.delete(key: _kToken);
      } catch (_) {
        throw ApiException(
            'Could not remove the saved access token. Please try signing out again.');
      }
      return;
    }
    var stored = false;
    try {
      await _secure.write(key: _kToken, value: token);
      stored = await _secure.read(key: _kToken) == token;
    } catch (_) {}
    await prefs.remove(_kToken);
    if (!stored) {
      throw ApiException(
          'Secure storage is unavailable. Your access token was not saved. '
          'Check that this app is correctly signed and try again.');
    }
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    serverUrl = prefs.getString(_kUrl) ?? '';
    account = prefs.getString(_kAccount) ?? '';
    email = prefs.getString(_kEmail) ?? '';
    final token = await _readToken(prefs);

    if (serverUrl.isEmpty || token == null) {
      state = AuthState.signedOut;
      notifyListeners();
      return;
    }
    client = KeygenClient(baseUrl: serverUrl, account: account, token: token);
    try {
      user = await client!.me();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        try {
          await _writeToken(prefs, null);
        } on ApiException {
          // An invalid token must not leave startup stuck on the loading screen.
        }
        client = null;
        state = AuthState.signedOut;
        notifyListeners();
        return;
      }
      // Offline or server hiccup: stay signed in, screens show their own errors.
    }
    state = AuthState.signedIn;
    notifyListeners();
  }

  Future<void> signIn({
    required String url,
    required String account,
    required String email,
    required String password,
  }) async {
    final c = KeygenClient(baseUrl: normalizeUrl(url), account: account.trim());
    final token = await c.createToken(email.trim(), password);
    c.token = token;
    await _establish(c, email.trim());
  }

  Future<void> signInWithToken({
    required String url,
    required String account,
    required String token,
  }) async {
    final c = KeygenClient(
        baseUrl: normalizeUrl(url),
        account: account.trim(),
        token: token.trim());
    await _establish(c, '');
  }

  Future<void> _establish(KeygenClient c, String email) async {
    final me = await c.me(); // validates the token
    final prefs = await SharedPreferences.getInstance();
    await _writeToken(prefs, c.token);
    await prefs.setString(_kUrl, c.baseUrl);
    await prefs.setString(_kAccount, c.account);
    await prefs.setString(_kEmail, email);
    client = c;
    _demo = false;
    user = me;
    serverUrl = c.baseUrl;
    account = c.account;
    this.email = email;
    state = AuthState.signedIn;
    notifyListeners();
  }

  /// Sample data, nothing is saved or sent anywhere.
  Future<void> startDemo() async {
    final c = KeygenClient(
        baseUrl: 'https://demo.keygen.example',
        account: 'acme',
        token: 'demo',
        httpClient: demoHttpClient());
    user = await c.me();
    _demo = true;
    client = c;
    serverUrl = c.baseUrl;
    account = c.account;
    email = 'demo@keygen.example';
    state = AuthState.signedIn;
    notifyListeners();
  }

  /// Signs out but remembers the server so the next login is quick.
  Future<void> signOut({bool forgetConnection = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_demo || forgetConnection) await _writeToken(prefs, null);
    client = null;
    user = null;
    if (forgetConnection) {
      for (final key in [_kUrl, _kAccount, _kEmail]) {
        await prefs.remove(key);
      }
      serverUrl = '';
      account = '';
      email = '';
    } else if (_demo) {
      serverUrl = prefs.getString(_kUrl) ?? '';
      account = prefs.getString(_kAccount) ?? '';
      email = prefs.getString(_kEmail) ?? '';
    }
    _demo = false;
    state = AuthState.signedOut;
    notifyListeners();
  }
}
