import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";

import "../theme/app_theme.dart";
import "feed_image.dart";

/// Instagram's Android top bar: flat, same color as the page, with a back
/// arrow and a left-aligned title on pushed pages. Handed to
/// [AdaptiveAppBar.appBar], which the adaptive scaffold uses on Android only.
class IgTopBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? leading;
  final Widget? title;
  final List<Widget> actions;
  final bool centerTitle;

  /// Show a back arrow when the page can go back (and [leading] is null).
  final bool automaticBack;

  const IgTopBar({
    super.key,
    this.leading,
    this.title,
    this.actions = const [],
    this.centerTitle = false,
    this.automaticBack = true,
  });

  /// Bar built from an [AdaptiveAppBar]'s title and actions.
  factory IgTopBar.from(
    BuildContext context, {
    String? title,
    Widget? titleWidget,
    Widget? leading,
    List<AdaptiveAppBarAction>? actions,
    bool centerTitle = false,
  }) {
    final colors = AppColors.of(context);
    return IgTopBar(
      leading: leading,
      centerTitle: centerTitle,
      title:
          titleWidget ??
          (title == null || title.isEmpty
              ? null
              : Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                    decoration: TextDecoration.none,
                  ),
                )),
      actions: [
        for (final a in actions ?? const <AdaptiveAppBarAction>[])
          a.title != null
              ? CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: a.onPressed,
                  child: Text(
                    a.title!,
                    style: const TextStyle(
                      color: kIgBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                )
              : BarIcon(
                  icon:
                      a.iconWidget ??
                      Icon(a.icon ?? CupertinoIcons.circle, color: colors.text),
                  onTap: a.onPressed,
                  label: a.label,
                ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final canPop = Navigator.of(context).canPop();
    final Widget? lead =
        leading ??
        (automaticBack && canPop
            ? BarIcon(
                icon: Icon(CupertinoIcons.arrow_left, color: colors.text),
                label: "Back",
                onTap: () => Navigator.of(context).maybePop(),
              )
            : null);

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: IconTheme(
            data: IconThemeData(color: colors.text, size: 26),
            child: DefaultTextStyle(
              style: baseTextStyle(context),
              child: Stack(
                children: [
                  Row(
                    children: [
                      SizedBox(width: lead == null ? 16 : 4),
                      ?lead,
                      if (lead != null) const SizedBox(width: 8),
                      Expanded(
                        child: centerTitle
                            ? const SizedBox.shrink()
                            : Align(
                                alignment: Alignment.centerLeft,
                                child: title,
                              ),
                      ),
                      ...actions,
                      const SizedBox(width: 6),
                    ],
                  ),
                  if (centerTitle && title != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: false,
                        child: Center(child: title),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon button for [IgTopBar].
class BarIcon extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;
  final String? label;

  const BarIcon({
    super.key,
    required this.icon,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(44, 44),
        onPressed: onTap,
        child: icon,
      ),
    );
  }
}

/// Red count bubble or dot drawn over an icon (notifications, unread chats).
class Badged extends StatelessWidget {
  final Widget child;

  /// 0 = nothing, -1 = dot only.
  final int count;

  const Badged({super.key, required this.child, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return child;
    final colors = AppColors.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: count < 0 ? 0 : -7,
          top: count < 0 ? null : -6,
          bottom: count < 0 ? -7 : null,
          left: count < 0 ? 0 : null,
          child: Center(
            child: count < 0
                ? Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: kIgRed,
                      shape: BoxShape.circle,
                    ),
                  )
                : Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: kIgRed,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: colors.background, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count > 9 ? "9+" : "$count",
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class IgTabItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
  final List<String>? avatar;

  const IgTabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge = 0,
    this.avatar,
  });
}

/// Instagram's Android tab bar: icons only, a soft pill behind the selected
/// tab, red badges. Handed to [AdaptiveBottomNavigationBar.bottomNavigationBar]
/// (Android only).
class IgBottomBar extends StatelessWidget {
  final List<IgTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const IgBottomBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selectedIndex,
                    label: items[i].label,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 58,
                          height: 38,
                          decoration: BoxDecoration(
                            color: i == selectedIndex
                                ? colors.button
                                : const Color(0x00000000),
                            borderRadius: BorderRadius.circular(19),
                          ),
                          alignment: Alignment.center,
                          child: Badged(
                            count: items[i].badge,
                            child: items[i].avatar != null
                                ? Container(
                                    width: 28,
                                    height: 28,
                                    padding: const EdgeInsets.all(1.5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: i == selectedIndex
                                            ? colors.text
                                            : const Color(0x00000000),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: FeedImage(urls: items[i].avatar!),
                                    ),
                                  )
                                : Icon(
                                    i == selectedIndex
                                        ? items[i].selectedIcon
                                        : items[i].icon,
                                    size: 27,
                                    color: colors.text,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page body text and icon colors that follow light / dark mode. The
/// Material scaffold on Android would otherwise force black text.
class PageColors extends StatelessWidget {
  final Widget child;

  const PageColors({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DefaultTextStyle.merge(
      style: TextStyle(color: colors.text),
      child: IconTheme.merge(
        data: IconThemeData(color: colors.text),
        child: child,
      ),
    );
  }
}
