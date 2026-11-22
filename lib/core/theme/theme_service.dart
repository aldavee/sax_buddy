import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and broadcasts the user's selected [ThemeMode] across Sax Buddy.
class ThemeService extends ChangeNotifier {
  ThemeService._();

  static final ThemeService instance = ThemeService._();
  static const String prefsKey = 'sax_buddy_theme_mode_v1';

  ThemeMode _themeMode = ThemeMode.system;
  bool _initialized = false;

  ThemeMode get themeMode => _themeMode;
  bool get isInitialized => _initialized;

  String get modeLabel => switch (_themeMode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System',
      };

  IconData get modeIcon => switch (_themeMode) {
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
        ThemeMode.system => Icons.brightness_auto_rounded,
      };

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final parsed = _parseThemeMode(prefs.getString(prefsKey));
      if (parsed != _themeMode) {
        _themeMode = parsed;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode && _initialized) return;
    _themeMode = mode;
    _initialized = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, mode.name);
    } catch (_) {}
  }

  Future<ThemeMode> cycleThemeMode() async {
    final next = switch (_themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await setThemeMode(next);
    return next;
  }

  static ThemeMode _parseThemeMode(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  @visibleForTesting
  void resetForTest([ThemeMode mode = ThemeMode.system]) {
    _themeMode = mode;
    _initialized = false;
    notifyListeners();
  }
}
