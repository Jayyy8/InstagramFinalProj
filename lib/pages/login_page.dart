import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/auth_controller.dart";
import "../theme/app_theme.dart";
import "../widgets/android_bars.dart";
import "../widgets/auth_button.dart";
import "../widgets/auth_message.dart";
import "../widgets/auth_widgets.dart";
import "otp_page.dart";
import "register_page.dart";
import "reset_password_page.dart";

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  String? _localError;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authControllerProvider.notifier).clear());
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _push(Widget page) {
    ref.read(authControllerProvider.notifier).clear();
    setState(() => _localError = null);
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => page));
  }

  void _login() {
    final email = _email.text.trim();
    if (!isValidEmail(email)) {
      setState(() => _localError = "Enter a valid email address.");
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _localError = "Enter your password.");
      return;
    }
    setState(() => _localError = null);
    ref
        .read(authControllerProvider.notifier)
        .signInWithPassword(email, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(authControllerProvider.notifier);
    final loading = ref.watch(authControllerProvider).loading;

    return AdaptiveScaffold(
      backgroundColor: AppColors.of(context).background,
      body: PageColors(
        child: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 440,
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // ───── TOP: language, logo, form ─────
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 20),
                              const Center(
                                child: Text(
                                  "English (US)",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 44),
                              const Center(child: AuthLogo(size: 52)),
                              const SizedBox(height: 40),
                              AuthField(
                                controller: _email,
                                placeholder: "Email",
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 12),
                              PasswordField(controller: _password),
                              const SizedBox(height: 16),
                              AuthButton(
                                label: loading ? "Logging in..." : "Log in",
                                onTap: loading ? null : _login,
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: CupertinoButton(
                                  onPressed: () =>
                                      _push(const ResetPasswordPage()),
                                  child: const Text(
                                    "Forgot password?",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              if (_localError != null) ...[
                                const SizedBox(height: 14),
                                AuthNotice(
                                  message: _localError!,
                                  isError: true,
                                ),
                              ],
                              const SizedBox(height: 20),
                              const OrDivider(),
                              const SizedBox(height: 20),
                              AuthButton(
                                label: "Log in with a code",
                                icon: CupertinoIcons.number,
                                outlined: true,
                                onTap: loading
                                    ? null
                                    : () => _push(const OtpPage()),
                              ),
                              const SizedBox(height: 12),
                              AuthButton(
                                label: "Log in with Apple",
                                icon: CupertinoIcons.person_crop_circle,
                                outlined: true,
                                onTap: loading
                                    ? null
                                    : () => controller.signInWithApple(),
                              ),
                              const SizedBox(height: 16),
                              const AuthMessage(),
                            ],
                          ),

                          // ───── BOTTOM: create account ─────
                          Padding(
                            padding: const EdgeInsets.only(top: 28, bottom: 20),
                            child: Column(
                              children: [
                                AuthButton(
                                  label: "Create new account",
                                  outlined: true,
                                  onTap: loading
                                      ? null
                                      : () => _push(const RegisterPage()),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  "∞ Meta",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
