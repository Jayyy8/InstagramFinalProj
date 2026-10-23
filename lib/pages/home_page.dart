import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../navigation.dart";
import "../providers/chat_provider.dart";
import "../providers/social_providers.dart";
import "../theme/app_theme.dart";
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

  AdaptiveAppBar _appBar(String username) {
    switch (_index) {
      case 0:
        return AdaptiveAppBar(
          leading: _leadingPlus(),
          titleWidget: _wordmark("Instagram", script: true),
          actions: [
            barAction(
              context,
              AppIcons.heart,
              label: "Notifications",
              onPressed: () => push(context, const ActivityPage()),
            ),
          ],
        );
      case 1:
        return const AdaptiveAppBar(title: "Reels");
      case 2:
        return AdaptiveAppBar(
          titleWidget: _wordmark(username),
          actions: [
            barAction(
              context,
              AppIcons.compose,
              label: "New message",
              onPressed: () => push(context, const NewMessagePage()),
            ),
          ],
        );
      case 3:
        return const AdaptiveAppBar(title: "Search");
      default:
        return AdaptiveAppBar(
          leading: _leadingPlus(),
          titleWidget: _wordmark(username),
          actions: [
            barAction(
              context,
              AppIcons.addPerson,
              label: "Discover people",
              onPressed: () => push(context, const DiscoverPeoplePage()),
            ),
            barAction(
              context,
              AppIcons.menu,
              label: "Settings and activity",
              onPressed: () => push(context, const SettingsPage()),
            ),
          ],
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

    return AdaptiveScaffold(
      appBar: _appBar(username),
      bottomNavigationBar: AdaptiveBottomNavigationBar(
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
      body: IndexedStack(
        index: _index,
        children: const [
          FeedTab(),
          ReelsTab(),
          MessagesTab(),
          SearchTab(),
          ProfileTab(),
        ],
      ),
    );
  }
}
