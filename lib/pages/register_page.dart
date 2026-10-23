import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/auth_controller.dart";
import "../widgets/auth_button.dart";
import "../widgets/auth_message.dart";
import "../widgets/auth_page.dart";
import "../widgets/auth_widgets.dart";

/// Registration: form -> 8-digit email code -> signed in.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final TextEditingController _code = TextEditingController();

  String? _localError;
  bool _codeSent = false;

  @override
  void initState() {
    super.initState();
    _password.addListener(_refresh);
    Future.microtask(() => ref.read(authControllerProvider.notifier).clear());
  }

  @override
  void dispose() {
    _password.removeListener(_refresh);
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _code.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _register() async {
    final email = _email.text.trim();
    if (!isValidEmail(email)) {
      setState(() => _localError = "Enter a valid email address.");
      return;
    }
    if (_password.text.length < 6) {
      setState(
        () => _localError = "Use at least 6 characters for the password.",
      );
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _localError = "Passwords do not match.");
      return;
    }
    setState(() => _localError = null);

    final ok = await ref
        .read(authControllerProvider.notifier)
        .signUp(email, _password.text);
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
        .verifySignupCode(_email.text, digits);
  }

  void _changeDetails() {
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

    // ───── Step 2: enter the code ─────
    if (_codeSent) {
      return AuthPage(
        icon: CupertinoIcons.mail,
        title: "Confirm your email",
        subtitle: "We sent an 8-digit code to ${_email.text.trim()}.",
        showBack: true,
        step: 1,
        children: [
          CodeInput(controller: _code),
          const SizedBox(height: 18),
          AuthButton(
            label: loading ? "Checking..." : "Verify email",
            icon: CupertinoIcons.checkmark_shield,
            onTap: loading ? null : _verify,
          ),
          const SizedBox(height: 10),
          ResendButton(
            label: "Resend code",
            onResend: () => controller.resendSignupCode(_email.text),
          ),
          const SizedBox(height: 10),
          AuthButton(
            label: "Change email",
            outlined: true,
            onTap: loading ? null : _changeDetails,
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

    // ───── Step 1: the form ─────
    return AuthPage(
      icon: CupertinoIcons.person_add,
      title: "Create account",
      subtitle: "Sign up to see photos and stories from the channels you love.",
      showBack: true,
      step: 0,
      children: [
        AuthField(
          controller: _email,
          placeholder: "Email",
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        PasswordField(controller: _password),
        PasswordStrength(password: _password.text),
        const SizedBox(height: 12),
        PasswordField(controller: _confirm, placeholder: "Confirm password"),
        const SizedBox(height: 18),
        AuthButton(
          label: loading ? "Creating account..." : "Sign up",
          icon: CupertinoIcons.person_add,
          onTap: loading ? null : _register,
        ),
        const SizedBox(height: 14),
        const Text(
          "By signing up, you agree to our Terms and Privacy Policy.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
        ),
        if (_localError != null) ...[
          const SizedBox(height: 16),
          AuthNotice(message: _localError!, isError: true),
        ],
        const SizedBox(height: 16),
        const AuthMessage(),
        const SizedBox(height: 16),
        const OrDivider(),
        const SizedBox(height: 16),
        AuthButton(
          label: "I already have an account",
          outlined: true,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
