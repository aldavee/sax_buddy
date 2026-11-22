import 'dart:convert';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:sax_buddy/core/config/auth_config.dart';
import 'package:sax_buddy/features/drive_sync/data/desktop_oauth_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BearerAuthClient extends http.BaseClient {
  _BearerAuthClient(this._token, [http.Client? inner])
      : _inner = inner ?? http.Client();

  final String _token;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }
}

class DriveAccountProfile {
  final String email;
  final String displayName;

  const DriveAccountProfile({
    required this.email,
    required this.displayName,
  });
}

class SaxDriveSyncService extends ChangeNotifier {
  SaxDriveSyncService._({
    DesktopOAuthClient? desktopOAuth,
    http.Client? httpClient,
    Future<void> Function()? androidInitFn,
    Future<GoogleSignInClientAuthorization?> Function(
      List<String> scopes, {
      required bool promptIfUnauthorized,
    })? androidAuthorizeFn,
    Future<void> Function(String? accessToken)? androidSignOutFn,
  }) : this._internal(
          desktopOAuth ?? DesktopOAuthClient(),
          httpClient,
          androidInitFn,
          androidAuthorizeFn,
          androidSignOutFn,
        );

  SaxDriveSyncService._internal(
    this._desktopOAuth,
    this._httpClient,
    this._androidInitFn,
    this._androidAuthorizeFn,
    this._androidSignOutFn,
  );

  @visibleForTesting
  factory SaxDriveSyncService.forTest({
    DesktopOAuthClient? desktopOAuth,
    http.Client? httpClient,
    Future<void> Function()? androidInitFn,
    Future<GoogleSignInClientAuthorization?> Function(
      List<String> scopes, {
      required bool promptIfUnauthorized,
    })? androidAuthorizeFn,
    Future<void> Function(String? accessToken)? androidSignOutFn,
  }) =>
      SaxDriveSyncService._(
        desktopOAuth: desktopOAuth,
        httpClient: httpClient,
        androidInitFn: androidInitFn,
        androidAuthorizeFn: androidAuthorizeFn,
        androidSignOutFn: androidSignOutFn,
      );

  static final SaxDriveSyncService instance = SaxDriveSyncService._();

  static const List<String> _desktopScopes = <String>[
    drive.DriveApi.driveFileScope,
    drive.DriveApi.driveReadonlyScope,
    'email',
    'profile',
  ];

  static const List<String> _androidScopes = <String>[
    drive.DriveApi.driveFileScope,
    drive.DriveApi.driveReadonlyScope,
  ];

  static const String _prefUserEmailKey = 'sax_buddy_drive_user_email_v1';
  static const String _prefUserNameKey = 'sax_buddy_drive_user_name_v1';

  static const String backupFolderName = 'Sax Buddy';
  static const String backupFileName = 'sax_buddy_backup.json';

  final DesktopOAuthClient _desktopOAuth;
  final http.Client? _httpClient;
  final Future<void> Function()? _androidInitFn;
  final Future<GoogleSignInClientAuthorization?> Function(
    List<String> scopes, {
    required bool promptIfUnauthorized,
  })? _androidAuthorizeFn;
  final Future<void> Function(String? accessToken)? _androidSignOutFn;
  GoogleSignInClientAuthorization? _androidAuth;
  DriveAccountProfile? _profile;
  Future<void>? _initFuture;
  DateTime? _lastSyncedAt;

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get isSignedIn => _profile != null;
  DriveAccountProfile? get profile => _profile;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  Future<void> initialize() => _initFuture ??= _doInitialize();

  Future<void> _doInitialize() async {
    if (_isDesktop) {
      await _desktopOAuth.loadSavedSession();
      try {
        final token = await _desktopOAuth.getValidAccessToken();
        if (token != null) {
          await _resolveProfileFromToken(token);
        }
      } catch (_) {}
      notifyListeners();
      return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _desktopOAuth.loadSavedSession();
      try {
        if (_androidInitFn != null) {
          await _androidInitFn();
        } else {
          await GoogleSignIn.instance.initialize(
            serverClientId: AuthConfig.serverClientId.isNotEmpty
                ? AuthConfig.serverClientId
                : null,
          );
        }
        final auth = await _authorizeAndroid(promptIfUnauthorized: false);
        if (auth != null) {
          _androidAuth = auth;
          await _resolveProfileFromToken(
            auth.accessToken,
            driveApiClient: _buildAndroidDriveHttpClient(auth),
          );
          notifyListeners();
          return;
        }
      } catch (_) {}

      try {
        final token = await _desktopOAuth.getValidAccessToken();
        if (token != null && token.isNotEmpty) {
          await _resolveProfileFromToken(token);
          notifyListeners();
        }
      } catch (_) {}
    }
  }

  static bool _shouldFallbackToLoopbackOAuth(Object error) {
    if (error is GoogleSignInException) {
      return error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError ||
          error.code == GoogleSignInExceptionCode.uiUnavailable;
    }
    final lower = error.toString().toLowerCase();
    return lower.contains('clientconfigurationerror') ||
        lower.contains('providerconfigurationerror') ||
        lower.contains('developer_error') ||
        RegExp(r'(?:apiexception:\s*|\b)10:\s').hasMatch(lower);
  }

  Future<bool> signIn() async {
    await initialize();
    if (_isDesktop) {
      final token =
          await _desktopOAuth.signInInteractive(scopes: _desktopScopes);
      await _resolveProfileFromToken(token);
      notifyListeners();
      return _profile != null;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final auth = await _authorizeAndroid(promptIfUnauthorized: true);
        if (auth == null) return false;
        _androidAuth = auth;
        await _resolveProfileFromToken(
          auth.accessToken,
          driveApiClient: _buildAndroidDriveHttpClient(auth),
        );
        notifyListeners();
        return _profile != null;
      } catch (e) {
        if (!_shouldFallbackToLoopbackOAuth(e)) {
          rethrow;
        }
        final token =
            await _desktopOAuth.signInInteractive(scopes: _desktopScopes);
        await _resolveProfileFromToken(token);
        notifyListeners();
        return _profile != null;
      }
    }

    throw UnsupportedError('Google Drive sign-in is not supported on this platform.');
  }

  Future<void> signOut() async {
    if (_isDesktop) {
      await _desktopOAuth.clearSession();
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _desktopOAuth.clearSession();
      final token = _androidAuth?.accessToken;
      _androidAuth = null;
      if (_androidSignOutFn != null) {
        try {
          await _androidSignOutFn(token);
        } catch (_) {}
      } else {
        if (token != null && token.isNotEmpty) {
          try {
            await GoogleSignIn.instance.authorizationClient
                .clearAuthorizationToken(accessToken: token);
          } catch (_) {}
        }
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {}
      }
    }
    _profile = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefUserEmailKey);
      await prefs.remove(_prefUserNameKey);
    } catch (_) {}
    notifyListeners();
  }

  http.Client _buildAndroidDriveHttpClient(
    GoogleSignInClientAuthorization auth,
  ) {
    if (_httpClient != null) {
      return _BearerAuthClient(auth.accessToken, _httpClient);
    }
    return auth.authClient(scopes: _androidScopes);
  }

  Future<void> _resolveProfileFromToken(
    String token, {
    http.Client? driveApiClient,
  }) async {
    String email = '';
    String name = '';

    try {
      final client = driveApiClient ?? _BearerAuthClient(token, _httpClient);
      final about = await drive.DriveApi(client).about.get(
        $fields: 'user(displayName,emailAddress)',
      );
      email = (about.user?.emailAddress ?? '').trim();
      name = (about.user?.displayName ?? '').trim();
    } catch (_) {}

    if (email.isEmpty) {
      try {
        final client = _httpClient ?? http.Client();
        try {
          final resp = await client
              .get(
                Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
                headers: {'Authorization': 'Bearer $token'},
              )
              .timeout(const Duration(seconds: 12));
          if (resp.statusCode == 200) {
            final json = jsonDecode(resp.body) as Map<String, dynamic>;
            email = (json['email'] ?? '').toString().trim();
            name = (json['name'] ?? email).toString().trim();
          }
        } finally {
          if (_httpClient == null) client.close();
        }
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (email.isNotEmpty) {
        final resolvedName = name.isNotEmpty ? name : email;
        await prefs.setString(_prefUserEmailKey, email);
        await prefs.setString(_prefUserNameKey, resolvedName);
        _profile = DriveAccountProfile(email: email, displayName: resolvedName);
        return;
      }
      final cachedEmail = prefs.getString(_prefUserEmailKey) ?? '';
      final cachedName = prefs.getString(_prefUserNameKey) ?? '';
      if (cachedEmail.isNotEmpty) {
        _profile = DriveAccountProfile(
          email: cachedEmail,
          displayName: cachedName.isNotEmpty ? cachedName : cachedEmail,
        );
        return;
      }
    } catch (_) {}

    _profile ??= const DriveAccountProfile(
      email: 'Google Account',
      displayName: 'Google Account',
    );
  }

  Future<GoogleSignInClientAuthorization?> _authorizeAndroid({
    required bool promptIfUnauthorized,
  }) {
    if (_androidAuthorizeFn != null) {
      return _androidAuthorizeFn(
        _androidScopes,
        promptIfUnauthorized: promptIfUnauthorized,
      );
    }
    if (promptIfUnauthorized) {
      return GoogleSignIn.instance.authorizationClient
          .authorizeScopes(_androidScopes);
    }
    return GoogleSignIn.instance.authorizationClient
        .authorizationForScopes(_androidScopes);
  }

  Future<GoogleSignInClientAuthorization?> _getAndroidAuth({
    bool promptIfUnauthorized = false,
  }) async {
    var auth = await _authorizeAndroid(promptIfUnauthorized: false);
    auth ??= _androidAuth;
    if (auth == null && promptIfUnauthorized) {
      auth = await _authorizeAndroid(promptIfUnauthorized: true);
    }
    if (auth != null) {
      _androidAuth = auth;
    }
    return auth;
  }

  Future<Map<String, String>?> getAuthHeaders() async {
    if (_isDesktop) {
      final token = await _desktopOAuth.getValidAccessToken();
      if (token == null) return null;
      return {'Authorization': 'Bearer $token'};
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (_desktopOAuth.hasSession) {
        final token = await _desktopOAuth.getValidAccessToken();
        if (token != null && token.isNotEmpty) {
          return {'Authorization': 'Bearer $token'};
        }
      }
      final auth = await _getAndroidAuth();
      final token = auth?.accessToken;
      if (token == null || token.isEmpty) return null;
      return {'Authorization': 'Bearer $token'};
    }
    return null;
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    if (_isDesktop) {
      final token = await _desktopOAuth.getValidAccessToken();
      if (token == null) return null;
      return drive.DriveApi(_BearerAuthClient(token, _httpClient));
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (_profile == null && _androidAuth == null && !_desktopOAuth.hasSession) {
        return null;
      }
      if (_desktopOAuth.hasSession) {
        final token = await _desktopOAuth.getValidAccessToken();
        if (token != null && token.isNotEmpty) {
          return drive.DriveApi(_BearerAuthClient(token, _httpClient));
        }
      }
      try {
        final auth = await _getAndroidAuth(promptIfUnauthorized: true);
        if (auth != null) {
          return drive.DriveApi(_buildAndroidDriveHttpClient(auth));
        }
      } catch (e) {
        if (!_shouldFallbackToLoopbackOAuth(e)) {
          rethrow;
        }
      }
      final token = await _desktopOAuth.getValidAccessToken();
      if (token != null && token.isNotEmpty) {
        return drive.DriveApi(_BearerAuthClient(token, _httpClient));
      }
      return null;
    }
    return null;
  }

  Future<String> _ensureBackupFolderId(drive.DriveApi api) async {
    const query =
        "name = '$backupFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final list = await api.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id,name)',
    );
    final existing = list.files;
    if (existing != null && existing.isNotEmpty && existing.first.id != null) {
      return existing.first.id!;
    }
    final folder = drive.File()
      ..name = backupFolderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder, $fields: 'id');
    return created.id!;
  }

  Future<String?> downloadBackupJson() async {
    final api = await _getDriveApi();
    if (api == null) return null;
    final folderId = await _ensureBackupFolderId(api);
    final list = await api.files.list(
      q: "name = '$backupFileName' and '$folderId' in parents and trashed = false",
      spaces: 'drive',
      $fields: 'files(id,name,modifiedTime)',
    );
    final files = list.files;
    if (files == null || files.isEmpty || files.first.id == null) {
      return null;
    }
    final media = await api.files.get(
      files.first.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  Future<void> uploadBackupJson(String jsonContent) async {
    final api = await _getDriveApi();
    if (api == null) {
      throw StateError('Not signed in to Google Drive.');
    }
    final folderId = await _ensureBackupFolderId(api);
    final list = await api.files.list(
      q: "name = '$backupFileName' and '$folderId' in parents and trashed = false",
      spaces: 'drive',
      $fields: 'files(id,name)',
    );
    final bytes = utf8.encode(jsonContent);
    final media = drive.Media(Stream.value(bytes), bytes.length);

    final existing = list.files;
    if (existing != null && existing.isNotEmpty && existing.first.id != null) {
      await api.files.update(
        drive.File()..name = backupFileName,
        existing.first.id!,
        uploadMedia: media,
      );
    } else {
      await api.files.create(
        drive.File()
          ..name = backupFileName
          ..mimeType = 'application/json'
          ..parents = [folderId],
        uploadMedia: media,
      );
    }
    _lastSyncedAt = DateTime.now();
    notifyListeners();
  }

  Future<String?> readReleaseManifestText({
    String? manifestFileId,
    String? folderId,
  }) async {
    final api = await _getDriveApi();
    if (api == null) return null;
    try {
      String? targetId = manifestFileId?.trim();
      if ((targetId == null || targetId.isEmpty) &&
          folderId != null &&
          folderId.trim().isNotEmpty) {
        final list = await api.files.list(
          q: "name = 'latest_release.json' and '${folderId.trim()}' in parents and trashed = false",
          $fields: 'files(id)',
        );
        targetId = list.files?.firstOrNull?.id;
      }
      if (targetId == null || targetId.isEmpty) return null;
      final media = await api.files.get(
        targetId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }
      return utf8.decode(bytes);
    } on SocketException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
