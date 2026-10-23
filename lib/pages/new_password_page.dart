import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/auth_controller.dart";
import "../widgets/auth_button.dart";
import "../widgets/auth_message.dart";
import "../widgets/auth_page.dart";
import "../widgets/auth_widgets.dart";

/// Shown after the recovery code is verified.
class NewPasswordPage extends ConsumerStatefulWidget {
  const NewPasswordPage({super.key});

  @override
  ConsumerState<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends ConsumerState<NewPasswordPage> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _localError;

  @override
  void initState() {
    super.initState();
    _password.addListener(_refresh);
    Future.microtask(() => ref.read(authControllerProvider.notifier).clear());
  }

  @override
  void dispose() {
    _password.removeListener(_refresh);
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (_password.text.length < 6) {
      setState(() => _localError = "Password must be at least 6 characters.");
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _localError = "Passwords do not match.");
      return;
    }
    setState(() => _localError = null);
    await ref
        .read(authControllerProvider.notifier)
        .updatePassword(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(authControllerProvider.notifier);
    final loading = ref.watch(authControllerProvider).loading;

    return AuthPage(
      icon: CupertinoIcons.lock_shield,
      title: "Create a new password",
      subtitle: "Choose a strong password you haven't used before.",
      children: [
        PasswordField(controller: _password, placeholder: "New password"),
        PasswordStrength(password: _password.text),
        const SizedBox(height: 12),
        PasswordField(controller: _confirm, placeholder: "Confirm password"),
        const SizedBox(height: 18),
        AuthButton(
          label: loading ? "Saving..." : "Update password",
          icon: CupertinoIcons.lock_rotation,
          onTap: loading ? null : _save,
        ),
        const SizedBox(height: 10),
        AuthButton(
          label: "Cancel",
          outlined: true,
          onTap: loading ? null : () => controller.cancelRecovery(),
        ),
        if (_localError != null) ...[
          const SizedBox(height: 16),
          AuthNotice(message: _localError!, isError: true),
        ],
        const SizedBox(height: 16),
        const AuthMessage(),
      ],
    );
  }
}
