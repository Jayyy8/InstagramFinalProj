import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../navigation.dart";
import "../providers/social_providers.dart";
import "../providers/theme_provider.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "../widgets/logout_dialog.dart";
import "../widgets/sub_page.dart";
import "account_center_page.dart";
import "change_password_page.dart";
import "developer_info_page.dart";
import "discover_people_page.dart";
import "post_list_pages.dart";

class _Row {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _Row(this.icon, this.title, {this.value, this.onTap, this.trailing});
}

/// "Settings and activity" (menu icon on your profile).
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _chooseAppearance() {
    final current = ref.read(themeProvider);
    showActionSheet(
      context,
      title: "Dark mode",
      actions: [
        for (final mode in AppearanceMode.values)
          SheetAction(
            label: mode == current ? "✓ ${mode.label}" : mode.label,
            onTap: () => ref.read(themeProvider.notifier).set(mode),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final appearance = ref.watch(themeProvider);
    final q = _search.text.trim().toLowerCase();

    final sections = <(String, List<_Row>)>[
      (
        "Your account",
        [
          _Row(
            CupertinoIcons.person_crop_circle,
            "Accounts Center",
            onTap: () => push(context, const AccountCenterPage()),
          ),
          _Row(
            CupertinoIcons.lock,
            "Change password",
            onTap: () => push(context, const ChangePasswordPage()),
          ),
        ],
      ),
      (
        "How you use Instagram",
        [
          _Row(
            CupertinoIcons.bookmark,
            "Saved",
            onTap: () => push(context, const SavedPostsPage()),
          ),
          _Row(
            CupertinoIcons.arrow_counterclockwise_circle,
            "Archive",
            onTap: () => push(context, const StoryArchivePage()),
          ),
          _Row(
            CupertinoIcons.heart,
            "Your activity",
            onTap: () => push(context, const LikedPostsPage()),
          ),
          _Row(
            CupertinoIcons.person_add,
            "Follow and invite friends",
            onTap: () => push(context, const DiscoverPeoplePage()),
          ),
        ],
      ),
      (
        "Who can see your content",
        [
          _Row(
            CupertinoIcons.lock_shield,
            "Private account",
            trailing: AdaptiveSwitch(
              value: profile?.isPrivate ?? false,
              onChanged: (v) => ref
                  .read(myProfileProvider.notifier)
                  .setPrivate(v)
                  .catchError((Object e) {
                    if (context.mounted) {
                      showToast(context, errorText(e), error: true);
                    }
                  }),
            ),
          ),
        ],
      ),
      (
        "Your app and media",
        [
          // Android draws Material controls with the light theme, so the
          // dark mode switch is offered on iPhone only.
          if (PlatformInfo.isIOS)
            _Row(
              CupertinoIcons.moon,
              "Dark mode",
              value: appearance.label,
              onTap: _chooseAppearance,
            ),
          _Row(
            CupertinoIcons.device_phone_portrait,
            "Device",
            value: PlatformInfo.platformDescription,
          ),
        ],
      ),
      (
        "More info and support",
        [
          _Row(
            CupertinoIcons.person_3,
            "Developer info",
            onTap: () => push(context, const DeveloperInfoPage()),
          ),
          _Row(
            CupertinoIcons.info_circle,
            "About",
            onTap: () => showInfo(
              context,
              title: "Instagram Replica",
              message:
                  "Version 1.0.0\nA class project built with Flutter, Supabase and adaptive_platform_ui. Not affiliated with Instagram or Meta.",
            ),
          ),
        ],
      ),
      (
        "Login",
        [
          _Row(
            CupertinoIcons.person_badge_plus,
            "Add account",
            onTap: () => showInfo(
              context,
              title: "Add account",
              message: "Log out first, then log in with the other account.",
            ),
          ),
          _Row(
            CupertinoIcons.square_arrow_left,
            "Log out${profile == null ? '' : ' ${profile.username}'}",
            onTap: () => confirmLogout(context, ref),
          ),
        ],
      ),
    ];

    return SubPage(
      title: "Settings and activity",
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: CupertinoSearchTextField(
              controller: _search,
              placeholder: "Search",
              style: TextStyle(color: colors.text),
              backgroundColor: colors.field,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          for (final (title, rows) in sections)
            ...() {
              final visible = rows
                  .where((r) => q.isEmpty || r.title.toLowerCase().contains(q))
                  .toList();
              if (visible.isEmpty) return const <Widget>[];
              return [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.secondaryText,
                    ),
                  ),
                ),
                for (final r in visible)
                  AdaptiveListTile(
                    leading: Icon(
                      r.icon,
                      color: r.title.startsWith("Log out")
                          ? CupertinoColors.destructiveRed
                          : colors.text,
                    ),
                    title: Text(
                      r.title,
                      style: TextStyle(
                        fontSize: 15,
                        color: r.title.startsWith("Log out")
                            ? CupertinoColors.destructiveRed
                            : colors.text,
                      ),
                    ),
                    trailing:
                        r.trailing ??
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (r.value != null)
                              Text(
                                r.value!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.secondaryText,
                                ),
                              ),
                            if (r.onTap != null) ...[
                              const SizedBox(width: 6),
                              Icon(
                                CupertinoIcons.chevron_forward,
                                size: 16,
                                color: colors.secondaryText,
                              ),
                            ],
                          ],
                        ),
                    hideBottomDivider: true,
                    onTap: r.onTap,
                  ),
              ];
            }(),
        ],
      ),
    );
  }
}
