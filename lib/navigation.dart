import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";

/// Page transition that matches the phone: iOS slide (with swipe back) on
/// iPhone, fade-and-rise on Android.
Route<T> adaptiveRoute<T>(Widget page, {bool fullscreenDialog = false}) {
  if (PlatformInfo.isIOS) {
    return CupertinoPageRoute<T>(
      builder: (_) => page,
      fullscreenDialog: fullscreenDialog,
    );
  }
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    fullscreenDialog: fullscreenDialog,
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.fastOutSlowIn,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

Future<T?> push<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(adaptiveRoute<T>(page));

/// Full screen media (stories, story camera): fades in over everything.
Future<T?> pushFullscreen<T>(BuildContext context, Widget page) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    PageRouteBuilder<T>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (context, animation, secondary, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    ),
  );
}
