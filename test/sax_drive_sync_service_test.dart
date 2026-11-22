import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sax_buddy/core/presentation/widgets/app_snackbar.dart';
import 'package:sax_buddy/features/drive_sync/data/desktop_oauth_client.dart';
import 'package:sax_buddy/features/drive_sync/data/sax_drive_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDesktopOAuthClient extends DesktopOAuthClient {
  _FakeDesktopOAuthClient({this.tokenToReturn = 'loopback-tok-1'});

  final String tokenToReturn;
  int interactiveCalls = 0;
  bool sessionActive = false;

  @override
  bool get hasSession => sessionActive;

  @override
  Future<void> loadSavedSession() async {}

  @override
  Future<String> signInInteractive({required List<String> scopes}) async {
    interactiveCalls++;
    sessionActive = true;
    return tokenToReturn;
  }

  @override
  Future<String?> getValidAccessToken() async =>
      sessionActive ? tokenToReturn : null;

  @override
  Future<void> clearSession() async {
    sessionActive = false;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android signIn authorizes Drive scopes without serverClientId',
      () async {
    var initCalls = 0;
    final promptFlags = <bool>[];
    String? clearedToken;

    final mockHttp = MockClient((request) async {
      if (request.url.path.endsWith('/drive/v3/about')) {
        return http.Response(
          jsonEncode({
            'user': {
              'displayName': 'Al Dave',
              'emailAddress': 'djaldave@gmail.com',
            },
          }),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('Not found', 404);
    });

    final service = SaxDriveSyncService.forTest(
      httpClient: mockHttp,
      androidInitFn: () async {
        initCalls++;
      },
      androidAuthorizeFn: (scopes, {required promptIfUnauthorized}) async {
        promptFlags.add(promptIfUnauthorized);
        if (!promptIfUnauthorized) return null;
        return GoogleSignInClientAuthorization(accessToken: 'android-tok-1');
      },
      androidSignOutFn: (token) async {
        clearedToken = token;
      },
    );

    await service.initialize();
    expect(initCalls, 1);
    expect(service.isSignedIn, isFalse);

    final ok = await service.signIn();
    expect(ok, isTrue);
    expect(promptFlags, [false, true]);
    expect(service.isSignedIn, isTrue);
    expect(service.profile?.email, 'djaldave@gmail.com');

    await service.signOut();
    expect(clearedToken, 'android-tok-1');
    expect(service.isSignedIn, isFalse);
  });

  test(
      'Android signIn automatically falls back to loopback OAuth on clientConfigurationError',
      () async {
    final fakeLoopback =
        _FakeDesktopOAuthClient(tokenToReturn: 'fallback-tok-7');
    final mockHttp = MockClient((request) async {
      if (request.url.path.endsWith('/drive/v3/about')) {
        return http.Response(
          jsonEncode({
            'user': {
              'displayName': 'Fallback User',
              'emailAddress': 'fallback@gmail.com',
            },
          }),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('Not found', 404);
    });

    final service = SaxDriveSyncService.forTest(
      desktopOAuth: fakeLoopback,
      httpClient: mockHttp,
      androidInitFn: () async {},
      androidAuthorizeFn: (scopes, {required promptIfUnauthorized}) async {
        if (!promptIfUnauthorized) return null;
        throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
          description: 'Developer error / SHA-1 mismatch (10)',
        );
      },
    );

    final ok = await service.signIn();
    expect(ok, isTrue);
    expect(fakeLoopback.interactiveCalls, 1);
    expect(service.isSignedIn, isTrue);
    expect(service.profile?.email, 'fallback@gmail.com');
    expect(
      AppSnackBar.sanitizeError(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: 'Canceled',
        ),
      ),
      'Sign-in was canceled.',
    );
  });
}
