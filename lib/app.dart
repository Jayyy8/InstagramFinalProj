import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "pages/auth_gate.dart";
import "providers/theme_provider.dart";
import "theme/app_theme.dart";

/// [AdaptiveApp] renders native iOS 26 Liquid Glass on iOS 26+, classic
/// Cupertino on older iPhones and Material on Android.
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forced = ref.watch(themeProvider).brightness;

    const app = AdaptiveApp(
      title: "Instagram",
      cupertinoLightTheme: kLightTheme,
      cupertinoDarkTheme: kDarkTheme,
      builder: _androidTheme,
      home: AuthGate(),
    );

    // Dark mode on / off in Settings: report that brightness to the app
    // instead of the phone's, so every page and native control follows it.
    // The tree stays the same either way, so switching keeps open pages.
    return MediaQuery.fromView(
      view: View.of(context),
      child: Builder(
        builder: (context) {
          final data = MediaQuery.of(context);
          return MediaQuery(
            data: forced == null
                ? data
                : data.copyWith(platformBrightness: forced),
            child: app,
          );
        },
      ),
    );
  }
}

/// On Android the adaptive app is a MaterialApp with the default light
/// theme. Instagram's own colors (and every Cupertino widget) follow the
/// phone's dark mode instead, through this Cupertino theme.
Widget _androidTheme(BuildContext context, Widget? child) {
  if (PlatformInfo.isIOS) return child!;
  final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  return CupertinoTheme(
    data: dark ? kDarkTheme : kLightTheme,
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: child!,
    ),
  );
}
