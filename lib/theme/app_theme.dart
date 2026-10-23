import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";

/// Instagram blue (Follow / Log in buttons, links).
const Color kIgBlue = Color(0xFF0095F6);

/// Bubble color for messages you send.
const Color kIgMessageBlue = Color(0xFF3797F0);

/// Like / notification red.
const Color kIgRed = Color(0xFFFF3040);

/// Story ring colors (bottom-left to top-right).
const List<Color> kStoryRingColors = [
  Color(0xFFFEDA75),
  Color(0xFFFA7E1E),
  Color(0xFFD62976),
  Color(0xFF962FBF),
  Color(0xFF4F5BD5),
];

/// Close friends ring.
const Color kCloseFriendsGreen = Color(0xFF1BD760);

/// Colors that follow light / dark mode.
///
/// On Android the adaptive library renders Material widgets with the default
/// light theme, so everything here follows that brightness too.
class AppColors {
  final bool dark;

  const AppColors._(this.dark);

  static AppColors of(BuildContext context) =>
      AppColors._(CupertinoTheme.brightnessOf(context) == Brightness.dark);

  Color get background =>
      dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  Color get sheet => dark ? const Color(0xFF262626) : const Color(0xFFFFFFFF);
  Color get field => dark ? const Color(0xFF262626) : const Color(0xFFEFEFEF);
  Color get button => dark ? const Color(0xFF363636) : const Color(0xFFEFEFEF);
  Color get text => dark ? const Color(0xFFF5F5F5) : const Color(0xFF000000);
  Color get secondaryText =>
      dark ? const Color(0xFFA8A8A8) : const Color(0xFF737373);
  Color get separator =>
      dark ? const Color(0xFF262626) : const Color(0xFFDBDBDB);
  Color get theirBubble =>
      dark ? const Color(0xFF262626) : const Color(0xFFEFEFEF);
  Color get placeholder =>
      dark ? const Color(0xFF1C1C1E) : const Color(0xFFE9E9EE);
}

/// Cupertino themes handed to [AdaptiveApp].
const CupertinoThemeData kLightTheme = CupertinoThemeData(
  brightness: Brightness.light,
  primaryColor: kIgBlue,
  scaffoldBackgroundColor: Color(0xFFFFFFFF),
  barBackgroundColor: Color(0xF0FFFFFF),
);

const CupertinoThemeData kDarkTheme = CupertinoThemeData(
  brightness: Brightness.dark,
  primaryColor: kIgBlue,
  scaffoldBackgroundColor: Color(0xFF000000),
  barBackgroundColor: Color(0xF0000000),
);

/// An icon as an SF Symbol (iOS 26 native bars) and a Cupertino glyph
/// (iOS 18 and older, and Android).
class AppIcon {
  final String sf;
  final IconData glyph;

  const AppIcon(this.sf, this.glyph);

  /// The value [AdaptiveNavigationDestination.icon] expects on this device.
  Object get nav => PlatformInfo.isIOS26OrHigher() ? sf : glyph;
}

abstract final class AppIcons {
  static const home = AppIcon("house", CupertinoIcons.house);
  static const homeFill = AppIcon("house.fill", CupertinoIcons.house_fill);
  static const reels = AppIcon("play.rectangle", CupertinoIcons.play_rectangle);
  static const reelsFill = AppIcon(
    "play.rectangle.fill",
    CupertinoIcons.play_rectangle_fill,
  );
  static const send = AppIcon("paperplane", CupertinoIcons.paperplane);
  static const sendFill = AppIcon(
    "paperplane.fill",
    CupertinoIcons.paperplane_fill,
  );
  static const search = AppIcon("magnifyingglass", CupertinoIcons.search);
  static const profile = AppIcon(
    "person.crop.circle",
    CupertinoIcons.person_crop_circle,
  );
  static const profileFill = AppIcon(
    "person.crop.circle.fill",
    CupertinoIcons.person_crop_circle_fill,
  );
  static const add = AppIcon("plus", CupertinoIcons.add);
  static const heart = AppIcon("heart", CupertinoIcons.heart);
  static const compose = AppIcon(
    "square.and.pencil",
    CupertinoIcons.square_pencil,
  );
  static const menu = AppIcon("line.3.horizontal", CupertinoIcons.bars);
  static const more = AppIcon("ellipsis", CupertinoIcons.ellipsis);
  static const addPerson = AppIcon(
    "person.badge.plus",
    CupertinoIcons.person_add,
  );
  static const settings = AppIcon("gearshape", CupertinoIcons.settings);
}

/// Bottom space so content clears the floating iOS 26 tab bar.
/// Other platforms lay the tab bar out below the page, so they need none.
double bottomBarInset(BuildContext context) {
  if (PlatformInfo.isIOS26OrHigher()) {
    return MediaQuery.paddingOf(context).bottom + 64;
  }
  return 12;
}

/// Text style that also works on Android pages without a Material ancestor.
TextStyle baseTextStyle(BuildContext context) => TextStyle(
  color: AppColors.of(context).text,
  fontSize: 14,
  decoration: TextDecoration.none,
  fontWeight: FontWeight.w400,
);

/// Full screen page built without [AdaptiveScaffold] (story viewer, camera
/// style editors). Sets the text style and background those pages need.
class PlainPage extends StatelessWidget {
  final Widget child;
  final Color? background;

  const PlainPage({super.key, required this.child, this.background});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background ?? AppColors.of(context).background,
      child: DefaultTextStyle(style: baseTextStyle(context), child: child),
    );
  }
}
