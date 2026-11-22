import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:sax_buddy/features/drive_sync/data/sax_drive_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum AppUpdateStatus {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  readyToInstall,
  installing,
  permissionRequired,
  error,
}

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.tagName,
    required this.version,
    required this.name,
    required this.notes,
    required this.downloadUrl,
    required this.fileName,
    required this.fileSizeBytes,
    this.fallbackDownloadUrl,
    this.publishedAt,
    this.source = 'Google Drive',
    this.gdriveFileId,
    this.sha256,
  });

  final String tagName;
  final String version;
  final String name;
  final String notes;
  final String downloadUrl;
  final String? fallbackDownloadUrl;
  final String fileName;
  final int fileSizeBytes;
  final DateTime? publishedAt;
  final String source;
  final String? gdriveFileId;
  final String? sha256;

  String get formattedSize {
    if (fileSizeBytes <= 0) return 'Package';
    final mb = fileSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class AppUpdateService extends ChangeNotifier {
  AppUpdateService({
    http.Client? httpClient,
    MethodChannel? channel,
    String? initialVersion,
    SharedPreferences? prefs,
  })  : _httpClient = httpClient ?? http.Client(),
        _channel = channel ??
            const MethodChannel('com.aldavelabs.sax_buddy/app_updater'),
        _currentVersion = initialVersion ?? defaultAppVersion,
        _injectedPrefs = prefs;

  static const String defaultAppVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0+1',
  );
  static const String defaultGdriveReleaseFolderId = String.fromEnvironment(
    'GDRIVE_RELEASE_FOLDER_ID',
    defaultValue: '',
  );
  static const String defaultGdriveManifestFileId = String.fromEnvironment(
    'GDRIVE_MANIFEST_FILE_ID',
    defaultValue: '',
  );
  static const String defaultGdriveApiKey = String.fromEnvironment(
    'GDRIVE_API_KEY',
    defaultValue: '',
  );
  static const String releasePortalBaseUrl = String.fromEnvironment(
    'RELEASE_PORTAL_URL',
    defaultValue: 'https://saxbuddy.aldavelabs.com',
  );
  static const String githubReleasesUrl =
      'https://api.github.com/repos/aldavee/sax_buddy/releases?per_page=5';

  static const String prefCustomManifestKey = 'sax_buddy_manifest_id_v1';

  static final AppUpdateService instance = AppUpdateService();

  final http.Client _httpClient;
  final MethodChannel _channel;
  final SharedPreferences? _injectedPrefs;

  String _currentVersion;
  List<String> _supportedAbis = const ['arm64-v8a'];
  String? _cacheDirPath;
  bool _initialized = false;
  String? _customManifestId;

  AppUpdateStatus _status = AppUpdateStatus.idle;
  AppReleaseInfo? _latestRelease;
  double _downloadProgress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _downloadedFilePath;
  String? _errorMessage;
  DateTime? _lastCheckedAt;

  String get currentVersion => _currentVersion;
  String get displayCurrentVersion =>
      _currentVersion.startsWith('v') ? _currentVersion : 'v$_currentVersion';
  AppUpdateStatus get status => _status;
  AppReleaseInfo? get latestRelease => _latestRelease;
  double get downloadProgress => _downloadProgress;
  int get downloadedBytes => _downloadedBytes;
  int get totalBytes => _totalBytes;
  String? get downloadedFilePath => _downloadedFilePath;
  String get errorMessageOrEmpty => _errorMessage ?? '';
  String? get errorMessage => _errorMessage;
  DateTime? get lastCheckedAt => _lastCheckedAt;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = _injectedPrefs ?? await SharedPreferences.getInstance();
      _customManifestId = prefs.getString(prefCustomManifestKey);
    } catch (_) {}

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final info = await _channel.invokeMapMethod<String, dynamic>('getAppVersion');
        if (info != null) {
          final full = info['fullVersion']?.toString();
          if (full != null && full.isNotEmpty) _currentVersion = full;
          final abis = info['abis'];
          if (abis is List) {
            _supportedAbis = abis.map((e) => e.toString()).toList();
          }
          _cacheDirPath = info['cacheDir']?.toString();
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setCustomManifestId(String? value) async {
    final clean = value?.trim() ?? '';
    _customManifestId = clean.isEmpty ? null : clean;
    try {
      final prefs = _injectedPrefs ?? await SharedPreferences.getInstance();
      if (_customManifestId == null) {
        await prefs.remove(prefCustomManifestKey);
      } else {
        await prefs.setString(prefCustomManifestKey, _customManifestId!);
      }
    } catch (_) {}
    notifyListeners();
  }

  static int compareVersions(String a, String b) {
    final pa = _parseVersion(a);
    final pb = _parseVersion(b);
    for (var i = 0; i < 3; i++) {
      if (pa.parts[i] != pb.parts[i]) {
        return pa.parts[i].compareTo(pb.parts[i]);
      }
    }
    return pa.build.compareTo(pb.build);
  }

  static ({List<int> parts, int build}) _parseVersion(String raw) {
    var clean = raw.trim();
    if (clean.startsWith('v') || clean.startsWith('V')) {
      clean = clean.substring(1);
    }
    final plusIdx = clean.indexOf('+');
    var build = 0;
    if (plusIdx != -1) {
      build = int.tryParse(clean.substring(plusIdx + 1).trim()) ?? 0;
      clean = clean.substring(0, plusIdx);
    }
    final segs = clean.split('.');
    final parts = <int>[
      segs.isNotEmpty ? (int.tryParse(segs[0]) ?? 0) : 0,
      segs.length > 1 ? (int.tryParse(segs[1]) ?? 0) : 0,
      segs.length > 2 ? (int.tryParse(segs[2]) ?? 0) : 0,
    ];
    return (parts: parts, build: build);
  }

  Future<void> checkForUpdate({bool silent = false}) async {
    await initialize();
    if (!silent || _status == AppUpdateStatus.idle) {
      _status = AppUpdateStatus.checking;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      AppReleaseInfo? release = await _checkFromGoogleDriveManifest();
      release ??= await _checkFromReleasePortal();
      release ??= await _checkFromGitHub();

      _lastCheckedAt = DateTime.now();
      if (release == null) {
        _status = AppUpdateStatus.upToDate;
        notifyListeners();
        return;
      }

      _latestRelease = release;
      final cmp = compareVersions(release.version, _currentVersion);
      _status = cmp > 0 ? AppUpdateStatus.updateAvailable : AppUpdateStatus.upToDate;
      notifyListeners();
    } catch (e) {
      if (!silent) {
        _status = AppUpdateStatus.error;
        _errorMessage = e.toString();
        notifyListeners();
      } else {
        _status = AppUpdateStatus.idle;
        notifyListeners();
      }
    }
  }

  Future<AppReleaseInfo?> _checkFromGoogleDriveManifest() async {
    final manifestId = (_customManifestId?.isNotEmpty == true)
        ? _customManifestId!
        : defaultGdriveManifestFileId.trim();
    final folderId = defaultGdriveReleaseFolderId.trim();
    if (manifestId.isEmpty && folderId.isEmpty) return null;

    String? rawText;
    if (SaxDriveSyncService.instance.isSignedIn) {
      rawText = await SaxDriveSyncService.instance.readReleaseManifestText(
        manifestFileId: manifestId,
        folderId: folderId,
      );
    }
    if (rawText == null && manifestId.isNotEmpty) {
      final apiKey = defaultGdriveApiKey.trim();
      final uri = apiKey.isNotEmpty
          ? Uri.parse(
              'https://www.googleapis.com/drive/v3/files/$manifestId?alt=media&key=$apiKey',
            )
          : Uri.parse(
              'https://drive.google.com/uc?export=download&id=$manifestId',
            );
      try {
        final resp = await _httpClient.get(uri).timeout(const Duration(seconds: 12));
        if (resp.statusCode == 200 && resp.body.trim().startsWith('{')) {
          rawText = resp.body;
        }
      } catch (_) {}
    }

    if (rawText == null) return null;
    final decoded = jsonDecode(rawText);
    if (decoded is! Map<String, dynamic>) return null;
    final latest = decoded['latest'] is Map<String, dynamic>
        ? decoded['latest'] as Map<String, dynamic>
        : decoded;
    return _parseManifestRelease(latest, source: 'Google Drive');
  }

  Future<AppReleaseInfo?> _checkFromReleasePortal() async {
    try {
      final resp = await _httpClient
          .get(
            Uri.parse('$releasePortalBaseUrl/api/releases?limit=5'),
            headers: const {'User-Agent': 'SaxBuddy-Updater/1.0'},
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) return null;
      final list = decoded['releases'];
      if (list is! List || list.isEmpty) return null;
      final first = list.first;
      if (first is! Map<String, dynamic>) return null;
      return _parseManifestRelease(first, source: 'Release Portal');
    } catch (_) {
      return null;
    }
  }

  Future<AppReleaseInfo?> _checkFromGitHub() async {
    try {
      final resp = await _httpClient
          .get(
            Uri.parse(githubReleasesUrl),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      if (decoded is! List || decoded.isEmpty) return null;
      final first = decoded.first as Map<String, dynamic>;
      final tag = (first['tag_name'] ?? 'v1.0.0+1').toString();
      final assets = (first['assets'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final picked = _pickAssetForPlatform(assets.map((a) => {
            'name': a['name'],
            'size': a['size'],
            'download_url': a['browser_download_url'],
          }).toList());
      if (picked == null) return null;
      return AppReleaseInfo(
        tagName: tag,
        version: tag.startsWith('v') ? tag.substring(1) : tag,
        name: (first['name'] ?? 'Sax Buddy $tag').toString(),
        notes: (first['body'] ?? '').toString(),
        downloadUrl: picked['download_url'].toString(),
        fileName: picked['name'].toString(),
        fileSizeBytes: (picked['size'] as num?)?.toInt() ?? 0,
        publishedAt: DateTime.tryParse(first['published_at']?.toString() ?? ''),
        source: 'GitHub Releases',
      );
    } catch (_) {
      return null;
    }
  }

  AppReleaseInfo? _parseManifestRelease(
    Map<String, dynamic> map, {
    required String source,
  }) {
    final tag = (map['tag'] ?? map['tag_name'] ?? '').toString().trim();
    final version = (map['version'] ?? (tag.startsWith('v') ? tag.substring(1) : tag))
        .toString()
        .trim();
    if (version.isEmpty) return null;

    final apks = (map['apks'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
    final desktop =
        (map['desktop_builds'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];

    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux);
    final candidates = isDesktop ? desktop : apks;
    final picked = _pickAssetForPlatform(candidates) ??
        (map['apk'] is Map<String, dynamic> ? map['apk'] as Map<String, dynamic> : null);
    if (picked == null) return null;

    final url = (picked['direct_url'] ??
            picked['download_url'] ??
            picked['portal_download_url'] ??
            '')
        .toString()
        .trim();
    if (url.isEmpty) return null;

    return AppReleaseInfo(
      tagName: tag.isNotEmpty ? tag : 'v$version',
      version: version,
      name: (map['name'] ?? 'Sax Buddy $version').toString(),
      notes: (map['notes'] ?? '').toString(),
      downloadUrl: url,
      fallbackDownloadUrl: picked['fallback_url']?.toString(),
      fileName: (picked['name'] ?? 'sax-buddy-$version').toString(),
      fileSizeBytes: (picked['size'] as num?)?.toInt() ?? 0,
      publishedAt: DateTime.tryParse(map['published_at']?.toString() ?? ''),
      source: source,
      gdriveFileId: picked['file_id']?.toString(),
      sha256: picked['sha256']?.toString(),
    );
  }

  Map<String, dynamic>? _pickAssetForPlatform(List<Map<String, dynamic>> assets) {
    if (assets.isEmpty) return null;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return assets.firstWhere(
        (a) => (a['name'] ?? '').toString().toLowerCase().endsWith('.msi'),
        orElse: () => assets.firstWhere(
          (a) => (a['name'] ?? '').toString().toLowerCase().contains('windows'),
          orElse: () => assets.first,
        ),
      );
    }
    for (final abi in _supportedAbis) {
      final match = assets.where((a) {
        final name = (a['name'] ?? '').toString().toLowerCase();
        final assetAbi = (a['abi'] ?? '').toString().toLowerCase();
        return assetAbi == abi.toLowerCase() || name.contains(abi.toLowerCase());
      }).firstOrNull;
      if (match != null) return match;
    }
    return assets.first;
  }

  Future<void> downloadAndInstallUpdate() async {
    final release = _latestRelease;
    if (release == null) return;

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      await launchUrl(
        Uri.parse(release.downloadUrl),
        mode: LaunchMode.externalApplication,
      );
      return;
    }

    _status = AppUpdateStatus.downloading;
    _downloadProgress = 0.0;
    _downloadedBytes = 0;
    _totalBytes = release.fileSizeBytes;
    _errorMessage = null;
    notifyListeners();

    try {
      final cacheDir = _cacheDirPath ?? Directory.systemTemp.path;
      final updatesDir = Directory('$cacheDir/updates');
      if (!updatesDir.existsSync()) updatesDir.createSync(recursive: true);

      final outFile = File('${updatesDir.path}/${release.fileName}');
      final request = http.Request('GET', Uri.parse(release.downloadUrl));
      final headers = await SaxDriveSyncService.instance.getAuthHeaders();
      if (headers != null) request.headers.addAll(headers);

      final streamed = await _httpClient.send(request);
      if (streamed.statusCode >= 400) {
        throw Exception('Download failed (HTTP ${streamed.statusCode}).');
      }

      _totalBytes = streamed.contentLength ?? release.fileSizeBytes;
      final sink = outFile.openWrite();
      try {
        await for (final chunk in streamed.stream) {
          sink.add(chunk);
          _downloadedBytes += chunk.length;
          if (_totalBytes > 0) {
            _downloadProgress = (_downloadedBytes / _totalBytes).clamp(0.0, 1.0);
          }
          notifyListeners();
        }
      } finally {
        await sink.close();
      }

      if (release.sha256 != null && release.sha256!.isNotEmpty) {
        final digest = sha256.convert(await outFile.readAsBytes()).toString();
        if (digest.toLowerCase() != release.sha256!.toLowerCase()) {
          await outFile.delete();
          throw Exception('APK checksum mismatch.');
        }
      }

      _downloadedFilePath = outFile.path;
      _status = AppUpdateStatus.installing;
      notifyListeners();

      final result = await _channel.invokeMethod<String>('installApk', {
        'filePath': outFile.path,
      });
      if (result == 'PERMISSION_REQUIRED') {
        _status = AppUpdateStatus.permissionRequired;
      } else if (result == 'SIGNATURE_CONFLICT') {
        _status = AppUpdateStatus.error;
        _errorMessage = 'APK signing key does not match installed app.';
      } else {
        _status = AppUpdateStatus.readyToInstall;
      }
      notifyListeners();
    } catch (e) {
      _status = AppUpdateStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
