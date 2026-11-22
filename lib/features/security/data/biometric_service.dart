import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricAuthResult {
  final bool success;
  final String? errorMessage;

  const BiometricAuthResult({
    required this.success,
    this.errorMessage,
  });
}

class BiometricService {
  BiometricService._({
    LocalAuthentication? auth,
    this._isEmulatorDetector,
    MethodChannel? platformChannel,
  })  : _auth = auth ?? LocalAuthentication(),
        _platformChannel = platformChannel ??
            const MethodChannel('com.aldavelabs.sax_buddy/app_updater');

  static BiometricService instance = BiometricService._();

  @visibleForTesting
  static void resetForTesting({
    LocalAuthentication? auth,
    Future<bool> Function()? isEmulatorDetector,
    MethodChannel? platformChannel,
  }) {
    instance = BiometricService._(
      auth: auth,
      isEmulatorDetector: isEmulatorDetector,
      platformChannel: platformChannel,
    );
  }

  static const String prefKeyEnabled = 'sax_buddy_biometric_enabled_v1';

  final LocalAuthentication _auth;
  final Future<bool> Function()? _isEmulatorDetector;
  final MethodChannel _platformChannel;

  final ValueNotifier<bool> isEmulatorNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isSupportedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isEnabledNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isLockedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<List<BiometricType>> availableBiometricsNotifier =
      ValueNotifier<List<BiometricType>>(<BiometricType>[]);

  bool _isInitialized = false;
  bool _isAuthenticating = false;

  bool get isInitialized => _isInitialized;
  bool get isAuthenticating => _isAuthenticating;
  bool get isEmulator => isEmulatorNotifier.value;
  bool get isSupported => isSupportedNotifier.value;
  bool get isEnabled => isEnabledNotifier.value;
  bool get isLocked => isLockedNotifier.value;

  Future<bool> checkIsEmulator() async {
    if (_isEmulatorDetector != null) {
      try {
        return await _isEmulatorDetector();
      } catch (_) {
        return false;
      }
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return false;
    }
    try {
      return await _platformChannel.invokeMethod<bool>('isEmulator') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> initialize() async {
    final emulator = await checkIsEmulator();
    isEmulatorNotifier.value = emulator;
    if (emulator) {
      isSupportedNotifier.value = false;
      availableBiometricsNotifier.value = <BiometricType>[];
      isEnabledNotifier.value = false;
      isLockedNotifier.value = false;
      _isInitialized = true;
      return;
    }

    bool supported = false;
    List<BiometricType> biometrics = <BiometricType>[];
    try {
      final isDeviceSupported = await _auth.isDeviceSupported();
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      biometrics = await _auth.getAvailableBiometrics();
      supported = isDeviceSupported || canCheckBiometrics || biometrics.isNotEmpty;
    } catch (_) {
      supported = false;
    }

    isSupportedNotifier.value = supported;
    availableBiometricsNotifier.value = biometrics;

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(prefKeyEnabled) ?? false;
    isEnabledNotifier.value = supported && enabled;
    isLockedNotifier.value = supported && enabled;
    _isInitialized = true;
  }

  Future<void> setEnabled(bool enabled) async {
    if (isEmulatorNotifier.value || !isSupportedNotifier.value) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKeyEnabled, enabled);
    isEnabledNotifier.value = enabled;
    if (!enabled) {
      isLockedNotifier.value = false;
    }
  }

  void lockApp() {
    if (isEmulatorNotifier.value) return;
    if (isEnabledNotifier.value && isSupportedNotifier.value) {
      isLockedNotifier.value = true;
    }
  }

  void unlockApp() {
    isLockedNotifier.value = false;
  }

  Future<BiometricAuthResult> authenticate({
    String reason = 'Authenticate to access Sax Buddy',
  }) async {
    if (isEmulatorNotifier.value) {
      isLockedNotifier.value = false;
      return const BiometricAuthResult(success: true);
    }
    if (_isAuthenticating) {
      return const BiometricAuthResult(
        success: false,
        errorMessage: 'Authentication already in progress.',
      );
    }
    _isAuthenticating = true;
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (didAuthenticate) {
        isLockedNotifier.value = false;
        return const BiometricAuthResult(success: true);
      }
      return const BiometricAuthResult(
        success: false,
        errorMessage: 'Authentication canceled or failed.',
      );
    } on PlatformException catch (e) {
      return BiometricAuthResult(
        success: false,
        errorMessage: e.message ?? 'Biometric authentication failed.',
      );
    } catch (e) {
      return BiometricAuthResult(
        success: false,
        errorMessage: e.toString(),
      );
    } finally {
      _isAuthenticating = false;
    }
  }
}
