import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:sax_buddy/core/config/auth_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class DesktopOAuthTokens {
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;

  const DesktopOAuthTokens({
    required this.accessToken,
    required this.expiresAt,
    this.refreshToken,
  });

  bool get isExpiringSoon =>
      DateTime.now().toUtc().isAfter(expiresAt.subtract(const Duration(seconds: 60)));

  Map<String, dynamic> toJson() => <String, dynamic>{
        'accessToken': accessToken,
        if (refreshToken != null && refreshToken!.isNotEmpty)
          'refreshToken': refreshToken,
        'expiresAtMillis': expiresAt.toUtc().millisecondsSinceEpoch,
      };

  static DesktopOAuthTokens? fromJson(Map<String, dynamic> json) {
    final access = json['accessToken']?.toString().trim();
    final expiresMillis = json['expiresAtMillis'];
    if (access == null || access.isEmpty || expiresMillis is! num) {
      return null;
    }
    return DesktopOAuthTokens(
      accessToken: access,
      refreshToken: json['refreshToken']?.toString().trim(),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        expiresMillis.toInt(),
        isUtc: true,
      ),
    );
  }
}

class DesktopOAuthClient {
  static const String prefsKey = 'sax_buddy_desktop_oauth_v1';

  final http.Client _httpClient;
  final Future<bool> Function(Uri url) _launchUrl;
  final Future<SharedPreferences> Function() _prefsProvider;
  final String _clientId;
  final String _clientSecret;

  DesktopOAuthTokens? _tokens;
  Future<String>? _refreshInFlight;

  DesktopOAuthClient({
    http.Client? httpClient,
    Future<bool> Function(Uri url)? launchUrlFn,
    Future<SharedPreferences> Function()? prefsProvider,
    String? clientId,
    String? clientSecret,
  })  : _httpClient = httpClient ?? http.Client(),
        _launchUrl = launchUrlFn ??
            ((Uri url) => launchUrl(url, mode: LaunchMode.externalApplication)),
        _prefsProvider = prefsProvider ?? SharedPreferences.getInstance,
        _clientId = (clientId != null && clientId.trim().isNotEmpty)
            ? clientId.trim()
            : _resolveClientId(),
        _clientSecret = (clientSecret != null && clientSecret.trim().isNotEmpty)
            ? clientSecret.trim()
            : _resolveClientSecret();

  static Map<String, String>? _cachedDotEnv;

  static Map<String, String> _loadLocalDotEnv() {
    if (_cachedDotEnv != null) return _cachedDotEnv!;
    final map = <String, String>{};
    try {
      final envFile = File('.env');
      if (envFile.existsSync()) {
        for (final raw in envFile.readAsLinesSync()) {
          final line = raw.trim();
          if (line.isEmpty || line.startsWith('#') || !line.contains('=')) {
            continue;
          }
          final idx = line.indexOf('=');
          final key = line.substring(0, idx).trim();
          var val = line.substring(idx + 1).trim();
          if ((val.startsWith('"') && val.endsWith('"')) ||
              (val.startsWith("'") && val.endsWith("'"))) {
            val = val.substring(1, val.length - 1);
          }
          if (key.isNotEmpty && val.isNotEmpty) {
            map[key] = val;
          }
        }
      }
    } catch (_) {}
    _cachedDotEnv = map;
    return map;
  }

  static String _resolveClientId() {
    if (AuthConfig.desktopClientId.trim().isNotEmpty) {
      return AuthConfig.desktopClientId.trim();
    }
    final fromEnv = _loadLocalDotEnv()['GOOGLE_DESKTOP_CLIENT_ID']?.trim();
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return AuthConfig.effectiveDesktopClientId;
  }

  static String _resolveClientSecret() {
    if (AuthConfig.desktopClientSecret.trim().isNotEmpty) {
      return AuthConfig.desktopClientSecret.trim();
    }
    final fromEnv = _loadLocalDotEnv()['GOOGLE_DESKTOP_CLIENT_SECRET']?.trim();
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return '';
  }

  bool get hasSession => _tokens != null;

  Future<void> loadSavedSession() async {
    try {
      final prefs = await _prefsProvider();
      final raw = prefs.getString(prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _tokens = DesktopOAuthTokens.fromJson(decoded);
      }
    } catch (_) {}
  }

  Future<void> clearSession() async {
    _tokens = null;
    try {
      final prefs = await _prefsProvider();
      await prefs.remove(prefsKey);
    } catch (_) {}
  }

  Future<void> _saveSession(DesktopOAuthTokens tokens) async {
    _tokens = tokens;
    try {
      final prefs = await _prefsProvider();
      await prefs.setString(prefsKey, jsonEncode(tokens.toJson()));
    } catch (_) {}
  }

  String _randomUrlSafe(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _extractOAuthError(http.Response resp) {
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map) {
        final desc = decoded['error_description']?.toString().trim();
        final err = decoded['error']?.toString().trim();
        if (desc != null && desc.isNotEmpty) return desc;
        if (err != null && err.isNotEmpty) return err;
      }
    } catch (_) {}
    return resp.body.trim();
  }

  Future<String> signInInteractive({required List<String> scopes}) async {
    final codeVerifier = _randomUrlSafe(64);
    final codeChallenge = base64UrlEncode(
      sha256.convert(utf8.encode(codeVerifier)).bytes,
    ).replaceAll('=', '');
    final state = _randomUrlSafe(24);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://127.0.0.1:${server.port}';
    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': _clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': scopes.join(' '),
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'access_type': 'offline',
      'prompt': 'consent',
    });

    try {
      final launched = await _launchUrl(authUri);
      if (!launched) {
        throw Exception('Could not open system browser for Google Sign-In.');
      }

      String? authCode;
      await for (final request in server.timeout(const Duration(minutes: 3))) {
        if (request.uri.path == '/favicon.ico') {
          request.response.statusCode = HttpStatus.noContent;
          await request.response.close();
          continue;
        }
        final params = request.uri.queryParameters;
        if (params['state'] != state) {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..headers.contentType = ContentType.html
            ..write('<html><body><h3>Invalid OAuth state.</h3></body></html>');
          await request.response.close();
          continue;
        }
        if (params.containsKey('error')) {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write(
              '<html><body><h2>Sign-in canceled or failed.</h2><p>You may close this tab.</p></body></html>',
            );
          await request.response.close();
          throw Exception('sign_in_canceled: ${params['error']}');
        }
        authCode = params['code'];
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write(
            '<html><body style="font-family:sans-serif;text-align:center;padding:48px;">'
            '<h2>Sax Buddy Authorized</h2>'
            '<p>You can close this browser tab and return to Sax Buddy.</p>'
            '</body></html>',
          );
        await request.response.close();
        break;
      }

      if (authCode == null || authCode.isEmpty) {
        throw Exception('No authorization code returned from Google.');
      }

      final body = <String, String>{
        'code': authCode,
        'client_id': _clientId,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
        'code_verifier': codeVerifier,
      };
      if (_clientSecret.isNotEmpty) {
        body['client_secret'] = _clientSecret;
      }

      final tokenResp = await _httpClient
          .post(
            Uri.parse(AuthConfig.tokenUri),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: body,
          )
          .timeout(const Duration(seconds: 25));

      if (tokenResp.statusCode != 200) {
        final detail = _extractOAuthError(tokenResp);
        throw Exception(
          detail.isNotEmpty
              ? 'Token exchange failed (${tokenResp.statusCode}): $detail'
              : 'Token exchange failed (${tokenResp.statusCode}).',
        );
      }
      final json = jsonDecode(tokenResp.body) as Map<String, dynamic>;
      final accessToken = (json['access_token'] ?? '').toString().trim();
      final refreshToken = json['refresh_token']?.toString().trim();
      final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
      if (accessToken.isEmpty) {
        throw Exception('OAuth response did not contain an access token.');
      }
      await _saveSession(
        DesktopOAuthTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
        ),
      );
      return accessToken;
    } finally {
      await server.close(force: true);
    }
  }

  Future<String?> getValidAccessToken() async {
    final current = _tokens;
    if (current == null) return null;
    if (!current.isExpiringSoon) return current.accessToken;
    final refreshToken = current.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await clearSession();
      return null;
    }
    if (_refreshInFlight != null) return _refreshInFlight!;
    _refreshInFlight = _refreshAccessToken(refreshToken);
    try {
      return await _refreshInFlight!;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<String> _refreshAccessToken(String refreshToken) async {
    final body = <String, String>{
      'client_id': _clientId,
      'refresh_token': refreshToken,
      'grant_type': 'refresh_token',
    };
    if (_clientSecret.isNotEmpty) {
      body['client_secret'] = _clientSecret;
    }
    final resp = await _httpClient
        .post(
          Uri.parse(AuthConfig.tokenUri),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: body,
        )
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      if (resp.statusCode == 400 || resp.statusCode == 401) {
        await clearSession();
      }
      final detail = _extractOAuthError(resp);
      throw Exception(
        detail.isNotEmpty
            ? 'Failed to refresh Google OAuth token (${resp.statusCode}): $detail'
            : 'Failed to refresh Google OAuth token (${resp.statusCode}).',
      );
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final accessToken = (json['access_token'] ?? '').toString().trim();
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    if (accessToken.isEmpty) {
      await clearSession();
      throw Exception('Refreshed token missing access_token.');
    }
    await _saveSession(
      DesktopOAuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      ),
    );
    return accessToken;
  }
}
