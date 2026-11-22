import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

bool isDesktopLayoutContext(BuildContext context, {double breakpoint = 840}) {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    return MediaQuery.sizeOf(context).width >= 600;
  }
  return MediaQuery.sizeOf(context).width >= breakpoint;
}

class DesktopFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const DesktopFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fade = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final scale = Tween<double>(begin: 0.985, end: 1.0).animate(fade);
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(scale: scale, child: child),
    );
  }
}

PageRoute<T> adaptivePageRoute<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool fullscreenDialog = false,
}) {
  if (isDesktopLayoutContext(context, breakpoint: 720)) {
    return PageRouteBuilder<T>(
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      transitionDuration: const Duration(milliseconds: 160),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (ctx, animation, secondaryAnimation) => builder(ctx),
      transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scale = Tween<double>(begin: 0.985, end: 1.0).animate(fade);
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
  }
  return MaterialPageRoute<T>(
    builder: builder,
    settings: settings,
    fullscreenDialog: fullscreenDialog,
  );
}
