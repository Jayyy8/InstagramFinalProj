import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Appearance chosen in Settings → Dark mode.
enum AppearanceMode { system, light, dark }

extension AppearanceModeX on AppearanceMode {
  String get label {
    switch (this) {
      case AppearanceMode.system:
        return "Use device settings";
      case AppearanceMode.light:
        return "Off";
      case AppearanceMode.dark:
        return "On";
    }
  }

  /// null = follow the phone.
  Brightness? get brightness {
    switch (this) {
      case AppearanceMode.system:
        return null;
      case AppearanceMode.light:
        return Brightness.light;
      case AppearanceMode.dark:
        return Brightness.dark;
    }
  }
}

class ThemeNotifier extends Notifier<AppearanceMode> {
  @override
  AppearanceMode build() => AppearanceMode.system;

  void set(AppearanceMode mode) => state = mode;
}

final themeProvider = NotifierProvider<ThemeNotifier, AppearanceMode>(
  ThemeNotifier.new,
);
