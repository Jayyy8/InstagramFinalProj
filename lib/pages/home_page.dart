import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../navigation.dart";
import "../providers/chat_provider.dart";
import "../providers/social_providers.dart";
import "../theme/app_theme.dart";
import "../widgets/android_bars.dart";
import "../widgets/sub_page.dart";
import "activity_page.dart";
import "create_sheet.dart";
import "discover_people_page.dart";
import "new_message_page.dart";
import "settings_page.dart";
import "tabs/feed_tab.dart";
import "tabs/messages_tab.dart";
import "tabs/profile_tab.dart";
import "tabs/reels_tab.dart";
import "tabs/search_tab.dart";

/// The five tabs. The tab bar is native Liquid Glass on iOS 26+,
/// a Cupertino tab bar on older iPhones and a Material navigation bar on
/// Android.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // "Active now" in other people's inbox.
    if (state == AppLifecycleState.resumed) {
      ref.read(repositoryProvider).touchLastActive().catchError((_) {});
      ref.invalidate(conversationsProvider);
      ref.invalidate(activityProvider);
    }
  }

  Widget _wordmark(String text, {bool script = false}) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (script)
          Text(
            text,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              fontFamily: "Snell Roundhand",
              fontFamilyFallback: const [
                "Billabong",
                "Segoe Script",
                "cursive",
              ],
              color: colors.text,
              decoration: TextDecoration.none,
            ),
          )
        else
          Text(
            text,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.text,
              decoration: TextDecoration.none,
            ),
          ),
        const SizedBox(width: 4),
        Icon(CupertinoIcons.chevron_down, size: 14, color: colors.text),
      ],
    );
  }

  Widget _leadingPlus() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(40, 40),
      onPressed: () => showCreateSheet(context, ref),
      child: Icon(
        CupertinoIcons.add,
        size: 28,
        color: AppColors.of(context).text,
      ),
    );
  }

  /// Top bar per tab. [AdaptiveAppBar.appBar] is the flat Instagram bar
  /// used on Android; iPhones use the native / Cupertino bar.
  AdaptiveAppBar _appBar(String username, int notifications) {
    final heart = barAction(
      context,
      AppIcons.heart,
      label: "Notifications",
      badge: notifications,
      onPressed: () => push(context, const ActivityPage()),
    );
    final compose = barAction(
      context,
      AppIcons.compose,
      label: "New message",
      onPressed: () => push(context, const NewMessagePage()),
    );
    final discover = barAction(
      context,
      AppIcons.addPerson,
      label: "Discover people",
      onPressed: () => push(context, const DiscoverPeoplePage()),
    );
    final menu = barAction(
      context,
      AppIcons.menu,
      label: "Settings and activity",
      onPressed: () => push(context, const SettingsPage()),
    );

    AdaptiveAppBar bar({
      Widget? leading,
      String? title,
      Widget? titleWidget,
      List<AdaptiveAppBarAction> actions = const [],
      bool center = true,
    }) {
      return AdaptiveAppBar(
        leading: leading,
        title: title,
        titleWidget: titleWidget,
        actions: actions,
        appBar: IgTopBar.from(
          context,
          leading: leading ?? const SizedBox(width: 40),
          title: title,
          titleWidget: titleWidget,
          actions: actions,
          centerTitle: center,
        ),
      );
    }

    switch (_index) {
      case 0:
        return bar(
          leading: _leadingPlus(),
          titleWidget: _wordmark("Instagram", script: true),
          actions: [heart],
        );
      case 1:
        return bar(title: "Reels", center: false);
      case 2:
        return bar(titleWidget: _wordmark(username), actions: [compose]);
      case 3:
        return bar(title: "Search", center: false);
      default:
        return bar(
          leading: _leadingPlus(),
          titleWidget: _wordmark(username),
          actions: [discover, menu],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(inboxRealtimeProvider); // live inbox while signed in
    final unread = ref.watch(unreadChatsProvider);
    final me = ref.watch(myProfileProvider).valueOrNull;
    final username = me?.username ?? "";
    final avatar = me?.avatarUrl;

    final notifications = ref.watch(unseenActivityProvider);
    final colors = AppColors.of(context);

    final scaffold = AdaptiveScaffold(
      backgroundColor: colors.background,
      appBar: _appBar(username, notifications),
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        // Instagram's own icon-only bar on Android.
        bottomNavigationBar: IgBottomBar(
          selectedIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: [
            const IgTabItem(
              icon: CupertinoIcons.house,
              selectedIcon: CupertinoIcons.house_fill,
              label: "Home",
            ),
            const IgTabItem(
              icon: CupertinoIcons.play_rectangle,
              selectedIcon: CupertinoIcons.play_rectangle_fill,
              label: "Reels",
            ),
            IgTabItem(
              icon: CupertinoIcons.paperplane,
              selectedIcon: CupertinoIcons.paperplane_fill,
              label: "Messages",
              badge: unread,
            ),
            const IgTabItem(
              icon: CupertinoIcons.search,
              selectedIcon: CupertinoIcons.search,
              label: "Search",
            ),
            IgTabItem(
              icon: CupertinoIcons.person_crop_circle,
              selectedIcon: CupertinoIcons.person_crop_circle_fill,
              label: "Profile",
              avatar: me?.avatarUrls,
            ),
          ],
        ),
        selectedIndex: _index,
        onTap: (i) => setState(() => _index = i),
        // Black icons like Instagram on iPhone. On Android this color is
        // the Material indicator, so keep the default there.
        selectedItemColor: PlatformInfo.isIOS
            ? AppColors.of(context).text
            : null,
        items: [
          AdaptiveNavigationDestination(
            icon: AppIcons.home.nav,
            selectedIcon: AppIcons.homeFill.nav,
            label: "Home",
          ),
          AdaptiveNavigationDestination(
            icon: AppIcons.reels.nav,
            selectedIcon: AppIcons.reelsFill.nav,
            label: "Reels",
          ),
          AdaptiveNavigationDestination(
            icon: AppIcons.send.nav,
            selectedIcon: AppIcons.sendFill.nav,
            label: "Messages",
            badgeCount: unread > 0 ? unread : null,
          ),
          AdaptiveNavigationDestination(
            icon: AppIcons.search.nav,
            label: "Search",
          ),
          AdaptiveNavigationDestination(
            icon: avatar != null ? NetworkImage(avatar) : AppIcons.profile.nav,
            selectedIcon: avatar != null
                ? NetworkImage(avatar)
                : AppIcons.profileFill.nav,
            label: "Profile",
          ),
        ],
      ),
      body: PageColors(
        child: IndexedStack(
          index: _index,
          children: [
            const FeedTab(),
            ReelsTab(active: _index == 1),
            const MessagesTab(),
            const SearchTab(),
            const ProfileTab(),
          ],
        ),
      ),
    );

    // Android back button: other tabs go back to Home first, like Instagram.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) setState(() => _index = 0);
      },
      child: scaffold,
    );
  }
}
