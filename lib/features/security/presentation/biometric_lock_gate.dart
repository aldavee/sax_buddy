import 'package:material_ui/material_ui.dart';
import 'package:sax_buddy/core/presentation/widgets/adaptive_overlay.dart';
import 'package:sax_buddy/core/presentation/widgets/app_snackbar.dart';
import 'package:sax_buddy/features/app_update/presentation/app_version_checker_card.dart';
import 'package:sax_buddy/features/security/data/biometric_service.dart';

class BiometricLockGate extends StatefulWidget {
  final Widget child;

  const BiometricLockGate({
    super.key,
    required this.child,
  });

  static Future<void> showSettingsSheet(BuildContext context) async {
    final service = BiometricService.instance;
    if (!service.isInitialized) {
      await service.initialize();
    }
    if (!context.mounted) return;

    await showAdaptiveDialogOrSheet<void>(
      context: context,
      maxWidth: 480,
      desktopTitle: 'Security & App Lock',
      desktopIcon: Icons.fingerprint_rounded,
      builder: (_) => const _BiometricSettingsSheet(),
    );
  }

  @override
  State<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends State<BiometricLockGate>
    with WidgetsBindingObserver {
  final BiometricService _biometricService = BiometricService.instance;
  bool _isInitializing = true;
  bool _wasInBackground = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initBiometrics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initBiometrics() async {
    await _biometricService.initialize();
    if (!mounted) return;
    setState(() => _isInitializing = false);
    if (_biometricService.isLocked) {
      _triggerUnlock();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_biometricService.isEmulator) return;
    if (state == AppLifecycleState.paused) {
      if (!_biometricService.isAuthenticating) {
        _wasInBackground = true;
        _biometricService.lockApp();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasInBackground) {
        _wasInBackground = false;
        if (_biometricService.isEnabled && _biometricService.isSupported) {
          _biometricService.lockApp();
          _triggerUnlock();
        }
      }
    }
  }

  Future<void> _triggerUnlock() async {
    if (_biometricService.isEmulator || _biometricService.isAuthenticating) return;
    setState(() => _errorMessage = null);
    final res = await _biometricService.authenticate(
      reason: 'Unlock Sax Buddy',
    );
    if (!mounted) return;
    if (!res.success) {
      setState(() => _errorMessage = res.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _biometricService.isLockedNotifier,
      builder: (context, isLocked, _) {
        if (!isLocked) return widget.child;
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 44,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Sax Buddy Locked',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Verify your identity to access your practice studio & repertoire.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.error, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _triggerUnlock,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('Unlock'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BiometricSettingsSheet extends StatelessWidget {
  const _BiometricSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final service = BiometricService.instance;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: service.isEnabledNotifier,
              builder: (context, enabled, _) {
                final supported = service.isSupported && !service.isEmulator;
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    Icons.fingerprint_rounded,
                    color: cs.primary,
                  ),
                  title: const Text('Biometric / Device Lock'),
                  subtitle: Text(
                    service.isEmulator
                        ? 'Disabled automatically on Android emulators'
                        : (supported
                            ? 'Require fingerprint, face, or device PIN on startup'
                            : 'Biometric authentication is unavailable on this device'),
                  ),
                  value: enabled,
                  onChanged: supported
                      ? (val) async {
                          if (val) {
                            final auth = await service.authenticate(
                              reason: 'Confirm identity to enable App Lock',
                            );
                            if (!auth.success) {
                              if (context.mounted) {
                                AppSnackBar.show(
                                  context,
                                  auth.errorMessage ?? 'Verification failed',
                                  backgroundColor: cs.error,
                                );
                              }
                              return;
                            }
                          }
                          await service.setEnabled(val);
                          if (context.mounted) {
                            AppSnackBar.show(
                              context,
                              val
                                  ? 'Biometric App Lock enabled'
                                  : 'Biometric App Lock disabled',
                            );
                          }
                        }
                      : null,
                );
              },
            ),
            const Divider(height: 24),
            const AppVersionCheckerCard(autoCheckOnInit: true),
          ],
        ),
      ),
    );
  }
}
