import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

Future<T?> showAdaptiveDialogOrSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext dialogContext) builder,
  double maxWidth = 600,
  double desktopMaxHeightFactor = 0.85,
  bool useFixedHeightOnDesktop = false,
  String? desktopTitle,
  IconData? desktopIcon,
}) {
  final size = MediaQuery.sizeOf(context);
  if (size.width >= 720) {
    final maxDialogHeight = math.min(size.height * desktopMaxHeightFactor, 760.0);
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxDialogHeight,
            ),
            child: SizedBox(
              width: math.min(maxWidth, size.width - 48),
              height: useFixedHeightOnDesktop ? maxDialogHeight : null,
              child: Dialog(
                insetPadding: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  mainAxisSize:
                      useFixedHeightOnDesktop ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    if (desktopTitle != null)
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 12, 10, 10),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          border: Border(
                            bottom: BorderSide(
                              color:
                                  colorScheme.outlineVariant.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (desktopIcon != null) ...[
                              Icon(desktopIcon, size: 20, color: colorScheme.primary),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Text(
                                desktopTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close (Esc)',
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                      ),
                    if (useFixedHeightOnDesktop)
                      Expanded(child: builder(ctx))
                    else
                      Flexible(child: builder(ctx)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => builder(ctx),
  );
}
