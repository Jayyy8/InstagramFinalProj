import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";

import "../theme/app_theme.dart";
import "android_bars.dart";

/// Pushed page with the platform's own top bar and back button:
/// Liquid Glass toolbar on iOS 26+, Cupertino bar on older iPhones,
/// Instagram's flat Android bar on Android.
class SubPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<AdaptiveAppBarAction>? actions;
  final Widget? titleWidget;

  /// Keep content above the home indicator (pages with an input at the
  /// bottom). Lists usually scroll behind it instead.
  final bool safeBottom;

  const SubPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.titleWidget,
    this.safeBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      backgroundColor: AppColors.of(context).background,
      appBar: AdaptiveAppBar(
        title: title,
        titleWidget: titleWidget,
        actions: actions,
        appBar: IgTopBar.from(
          context,
          title: title,
          titleWidget: titleWidget,
          actions: actions,
        ),
      ),
      body: PageColors(
        child: SafeArea(bottom: safeBottom, child: child),
      ),
    );
  }
}

/// Icon button for a top bar: SF Symbol on iOS 26+, an icon in the text
/// color elsewhere (the Cupertino bar would tint it blue otherwise).
AdaptiveAppBarAction barAction(
  BuildContext context,
  AppIcon icon, {
  required String label,
  required VoidCallback onPressed,
  int badge = 0,
}) {
  return AdaptiveAppBarAction(
    iosSymbol: icon.sf,
    icon: icon.glyph,
    iconWidget: Badged(
      count: badge,
      child: Icon(icon.glyph, size: 26, color: AppColors.of(context).text),
    ),
    // The native iOS 26 bar can't draw a badge: tint the icon red instead.
    tintColor: badge != 0 ? kIgRed : null,
    label: label,
    onPressed: onPressed,
  );
}
