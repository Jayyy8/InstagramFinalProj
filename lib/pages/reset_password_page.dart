import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/auth_controller.dart";
import "../widgets/auth_button.dart";
import "../widgets/auth_message.dart";
import "../widgets/auth_page.dart";
import "../widgets/auth_widgets.dart";

/// "Forgot password?" flow: email -> 8-digit code -> new password page.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _code = TextEditingController();
  bool _codeSent = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authControllerProvider.notifier).clear());
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!isValidEmail(email)) {
      setState(() => _localError = "Enter a valid email address.");
      return;
    }
    setState(() => _localError = null);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(email);
    if (ok && mounted) setState(() => _codeSent = true);
  }

  void _verify() {
    final digits = _code.text.replaceAll(RegExp(r"\D"), "");
    if (digits.length != 8) {
      setState(() => _localError = "Enter the 8-digit code from your email.");
      return;
    }
    setState(() => _localError = null);
    ref
        .read(authControllerProvider.notifier)
        .verifyRecoveryCode(_email.text, digits);
  }

  void _changeEmail() {
    _code.clear();
    ref.read(authControllerProvider.notifier).clear();
    setState(() {
      _codeSent = false;
      _localError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(authControllerProvider.notifier);
    final loading = ref.watch(authControllerProvider).loading;

    return AuthPage(
      icon: CupertinoIcons.lock_rotation,
      title: _codeSent ? "Enter your code" : "Forgot password?",
      subtitle: _codeSent
          ? "We sent an 8-digit code to ${_email.text.trim()}."
          : "Enter your email and we'll send you a code to reset your password.",
      showBack: true,
      step: _codeSent ? 1 : 0,
      children: [
        if (!_codeSent) ...[
          AuthField(
            controller: _email,
            placeholder: "Email",
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 18),
          AuthButton(
            label: loading ? "Sending..." : "Send reset code",
            icon: CupertinoIcons.paperplane,
            onTap: loading ? null : _sendCode,
          ),
        ] else ...[
          CodeInput(controller: _code),
          const SizedBox(height: 18),
          AuthButton(
            label: loading ? "Checking..." : "Verify code",
            icon: CupertinoIcons.checkmark_shield,
            onTap: loading ? null : _verify,
          ),
          const SizedBox(height: 10),
          ResendButton(
            label: "Resend code",
            onResend: () => controller.resetPassword(_email.text),
          ),
          const SizedBox(height: 10),
          AuthButton(
            label: "Change email",
            outlined: true,
            onTap: loading ? null : _changeEmail,
          ),
        ],
        if (_localError != null) ...[
          const SizedBox(height: 16),
          AuthNotice(message: _localError!, isError: true),
        ],
        const SizedBox(height: 16),
        const AuthMessage(),
        if (!_codeSent) ...[
          const SizedBox(height: 16),
          const OrDivider(),
          const SizedBox(height: 16),
          AuthButton(
            label: "Back to log in",
            outlined: true,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ],
    );
  }
}
