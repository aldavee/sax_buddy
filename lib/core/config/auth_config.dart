/// Pre-configured OAuth 2.0 credentials for Sax Buddy (project: aldavelabs).
class AuthConfig {
  static const String _projectNumber = '702325277685';
  static const String _oauthHost = 'apps.googleusercontent.com';
  static const String _installedKey = 'n5dbp1jhf9i14prhtbtusc40apto0r3h';
  static const String _desktopKey = '1dg53pr10l0n8tc2ftug9agqfv840h9h';

  static const String clientId = '$_projectNumber-$_installedKey.$_oauthHost';

  static const String projectId = 'aldavelabs';
  static const String authUri = 'https://accounts.google.com/o/oauth2/auth';
  static const String tokenUri = 'https://oauth2.googleapis.com/token';

  static const String defaultDesktopClientId =
      '$_projectNumber-$_desktopKey.$_oauthHost';

  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static const String desktopClientId = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_ID',
    defaultValue: defaultDesktopClientId,
  );

  static const String desktopClientSecret = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_SECRET',
    defaultValue: '',
  );

  static String get effectiveDesktopClientId =>
      desktopClientId.trim().isNotEmpty
          ? desktopClientId.trim()
          : defaultDesktopClientId;
}
