import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/auth_controller.dart";
import "../theme/app_theme.dart";
import "../widgets/auth_message.dart";
import "../widgets/auth_widgets.dart";
import "../widgets/dialogs.dart";
import "../widgets/sub_page.dart";

/// Settings → Change password.
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _localError;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
    Future.microtask(() => ref.read(authControllerProvider.notifier).clear());
  }

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save(bool needsCurrent) async {
    if (needsCurrent && _current.text.isEmpty) {
      setState(() => _localError = "Enter your current password.");
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _localError = "Password must be at least 6 characters.");
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _localError = "Passwords do not match.");
      return;
    }
    if (needsCurrent && _password.text == _current.text) {
      setState(() => _localError = "Choose a password you haven't used here.");
      return;
    }
    setState(() => _localError = null);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .changePassword(
          currentPassword: needsCurrent ? _current.text : null,
          newPassword: _password.text,
        );
    if (ok && mounted) {
      _current.clear();
      _password.clear();
      _confirm.clear();
      await showInfo(
        context,
        title: "Password changed",
        message: "Use your new password the next time you log in.",
      );
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final controller = ref.read(authControllerProvider.notifier);
    final loading = ref.watch(authControllerProvider).loading;
    final needsCurrent = controller.hasPasswordLogin;

    return SubPage(
      title: "Change password",
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Text(
              needsCurrent
                  ? "Your password must be at least 6 characters and should include a combination of numbers, letters and special characters (!\$@%)."
                  : "Your account uses Apple or email codes to log in. Set a password to also log in with your email and password.",
              style: TextStyle(color: colors.secondaryText, height: 1.35),
            ),
            const SizedBox(height: 20),
            if (needsCurrent) ...[
              PasswordField(
                controller: _current,
                placeholder: "Current password",
              ),
              const SizedBox(height: 12),
            ],
            PasswordField(controller: _password, placeholder: "New password"),
            PasswordStrength(password: _password.text),
            const SizedBox(height: 12),
            PasswordField(
              controller: _confirm,
              placeholder: "Re-type new password",
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: AdaptiveButton(
                label: loading ? "Saving..." : "Change password",
                color: kIgBlue,
                size: AdaptiveButtonSize.large,
                enabled: !loading,
                minSize: const Size(double.infinity, 48),
                onPressed: () => _save(needsCurrent),
              ),
            ),
            if (_localError != null) ...[
              const SizedBox(height: 16),
              AuthNotice(message: _localError!, isError: true),
            ],
            const SizedBox(height: 12),
            const AuthMessage(),
          ],
        ),
      ),
    );
  }
}
