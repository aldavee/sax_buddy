import 'package:material_ui/material_ui.dart';

class AppSnackBar {
  static DateTime? _lastShownTime;
  static String? _lastMessage;

  static String sanitizeError(dynamic error) {
    if (error == null) return 'An unexpected error occurred.';
    var raw = error.toString().trim();
    raw = raw.replaceFirst(
      RegExp(
          r'^(Exception|Error|PlatformException|ClientException|HttpException):\s*'),
      '',
    );
    final lower = raw.toLowerCase();
    if (lower.contains('sign_in_canceled') ||
        lower.contains('canceled by user') ||
        lower.contains('googlesigninexceptioncode.canceled') ||
        RegExp(r'(?:apiexception:\s*|\b)16:\s').hasMatch(lower) ||
        raw.contains('12501')) {
      return 'Sign-in was canceled.';
    }
    if (lower.contains('clientconfigurationerror') ||
        lower.contains('providerconfigurationerror') ||
        lower.contains('developer_error') ||
        RegExp(r'(?:apiexception:\s*|\b)10:\s').hasMatch(lower)) {
      return 'Google Sign-In client config error (check OAuth SHA-1).';
    }
    if (raw.contains('403') || lower.contains('forbidden')) {
      return 'Access denied or Drive permissions required.';
    }
    if (raw.contains('404') || lower.contains('not found')) {
      return 'Requested file or release was not found.';
    }
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused')) {
      return 'Network error. Please check your internet connection.';
    }
    if (lower.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (raw.length > 90) {
      raw = '${raw.substring(0, 87)}...';
    }
    return raw.isNotEmpty ? raw : 'An unexpected error occurred.';
  }

  static void show(
    BuildContext context,
    String message, {
    IconData? icon,
    Color? backgroundColor,
    Duration duration = const Duration(milliseconds: 2200),
    SnackBarAction? action,
  }) {
    final now = DateTime.now();
    if (_lastMessage == message &&
        _lastShownTime != null &&
        now.difference(_lastShownTime!) < const Duration(milliseconds: 1400)) {
      return;
    }
    _lastMessage = message;
    _lastShownTime = now;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: action,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
