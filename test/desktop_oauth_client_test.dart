import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sax_buddy/core/config/auth_config.dart';
import 'package:sax_buddy/features/drive_sync/data/desktop_oauth_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AuthConfig defaults desktop client ID to the Desktop OAuth client', () {
    expect(
      AuthConfig.effectiveDesktopClientId,
      AuthConfig.defaultDesktopClientId,
    );
    expect(AuthConfig.effectiveDesktopClientId, isNot(AuthConfig.clientId));
  });

  test('DesktopOAuthClient ignores /favicon.ico and exchanges code with secret',
      () async {
    Map<String, String>? tokenRequestBody;
    int? faviconStatus;
    int? callbackStatus;

    final mockHttp = MockClient((request) async {
      if (request.url.toString() == AuthConfig.tokenUri) {
        tokenRequestBody = Uri.splitQueryString(request.body);
        return http.Response(
          jsonEncode({
            'access_token': 'access-123',
            'refresh_token': 'refresh-456',
            'expires_in': 3600,
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    final client = DesktopOAuthClient(
      httpClient: mockHttp,
      clientId: AuthConfig.defaultDesktopClientId,
      clientSecret: 'test-desktop-secret',
      launchUrlFn: (uri) async {
        final redirectUri = Uri.parse(uri.queryParameters['redirect_uri']!);
        final state = uri.queryParameters['state']!;

        unawaited(Future<void>(() async {
          final ioClient = HttpClient();
          try {
            final favReq = await ioClient.getUrl(
              redirectUri.replace(path: '/favicon.ico'),
            );
            final favResp = await favReq.close();
            faviconStatus = favResp.statusCode;
            await favResp.drain<void>();

            final cbReq = await ioClient.getUrl(
              redirectUri.replace(
                queryParameters: {'code': 'auth-code-789', 'state': state},
              ),
            );
            final cbResp = await cbReq.close();
            callbackStatus = cbResp.statusCode;
            await cbResp.drain<void>();
          } finally {
            ioClient.close(force: true);
          }
        }));
        return true;
      },
    );

    final token = await client.signInInteractive(scopes: const ['email']);
    expect(faviconStatus, HttpStatus.noContent);
    expect(callbackStatus, HttpStatus.ok);
    expect(token, 'access-123');
    expect(client.hasSession, isTrue);
    expect(tokenRequestBody?['client_id'], AuthConfig.defaultDesktopClientId);
    expect(tokenRequestBody?['client_secret'], 'test-desktop-secret');
    expect(tokenRequestBody?['code'], 'auth-code-789');
  });
}
