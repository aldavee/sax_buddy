import 'package:material_ui/material_ui.dart';
import 'package:sax_buddy/core/presentation/navigation/adaptive_page_route.dart';
import 'package:sax_buddy/core/theme/theme_service.dart';
import 'package:sax_buddy/features/sax/presentation/home_screen.dart';
import 'package:sax_buddy/features/security/presentation/biometric_lock_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ThemeService.instance.initialize();
  runApp(const SaxBuddyApp());
}

class SaxBuddyApp extends StatelessWidget {
  const SaxBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFD97706),
      primary: const Color(0xFFB45309),
      secondary: const Color(0xFF4338CA),
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFF59E0B),
      primary: const Color(0xFFFBBF24),
      secondary: const Color(0xFF818CF8),
      brightness: Brightness.dark,
    );

    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) => MaterialApp(
        title: 'Sax Buddy',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeService.instance.themeMode,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: lightScheme,
          scaffoldBackgroundColor: const Color(0xFFFDFBF7),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.windows: DesktopFadePageTransitionsBuilder(),
              TargetPlatform.linux: DesktopFadePageTransitionsBuilder(),
              TargetPlatform.macOS: DesktopFadePageTransitionsBuilder(),
            },
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: darkScheme,
          scaffoldBackgroundColor: const Color(0xFF0C1021),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.windows: DesktopFadePageTransitionsBuilder(),
              TargetPlatform.linux: DesktopFadePageTransitionsBuilder(),
              TargetPlatform.macOS: DesktopFadePageTransitionsBuilder(),
            },
          ),
        ),
        home: const BiometricLockGate(
          child: HomeScreen(),
        ),
      ),
    );
  }
}
