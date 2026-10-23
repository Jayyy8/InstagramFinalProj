import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../navigation.dart";
import "../providers/social_providers.dart";
import "../providers/supabase_providers.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "../widgets/sub_page.dart";
import "change_password_page.dart";
import "edit_profile_page.dart";

String _formatTime(String? iso) {
  final date = DateTime.tryParse(iso ?? "")?.toLocal();
  if (date == null) return "-";
  String two(int n) => n.toString().padLeft(2, "0");
  return "${date.year}-${two(date.month)}-${two(date.day)} "
      "${two(date.hour)}:${two(date.minute)}";
}

/// Settings → Accounts Center: personal details and password.
class AccountCenterPage extends ConsumerWidget {
  const AccountCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final user = ref.watch(supabaseProvider).auth.currentUser;
    final profile = ref.watch(myProfileProvider).valueOrNull;

    Widget row(String label, String value, {VoidCallback? onTap}) {
      return AdaptiveListTile(
        title: Text(label, style: TextStyle(color: colors.text, fontSize: 15)),
        subtitle: Text(
          value,
          style: TextStyle(color: colors.secondaryText, fontSize: 13),
        ),
        trailing: onTap == null
            ? null
            : Icon(
                CupertinoIcons.chevron_forward,
                size: 16,
                color: colors.secondaryText,
              ),
        onTap: onTap,
      );
    }

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.secondaryText,
        ),
      ),
    );

    return SubPage(
      title: "Accounts Center",
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          header("Profile"),
          row(
            profile?.displayName ?? "-",
            "Instagram · ${profile?.username ?? '-'}",
            onTap: () => push(context, const EditProfilePage()),
          ),
          header("Personal details"),
          row("Email", user?.email ?? "-"),
          row(
            "User ID",
            user?.id ?? "-",
            onTap: user == null
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: user.id));
                    showToast(context, "User ID copied");
                  },
          ),
          row("Login method", "${user?.appMetadata['provider'] ?? '-'}"),
          row("Email confirmed", user?.emailConfirmedAt != null ? "Yes" : "No"),
          row("Account created", _formatTime(user?.createdAt)),
          row("Last log in", _formatTime(user?.lastSignInAt)),
          header("Password and security"),
          row(
            "Change password",
            "Update the password you use to log in",
            onTap: () => push(context, const ChangePasswordPage()),
          ),
        ],
      ),
    );
  }
}
