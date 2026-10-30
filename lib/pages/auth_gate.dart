import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:oauth_activity/pages/account_setup_page.dart";
import "package:oauth_activity/pages/home_page.dart";
import "package:oauth_activity/pages/login_page.dart";
import "package:oauth_activity/pages/new_password_page.dart";
import "package:oauth_activity/providers/auth_controller.dart";
import "package:oauth_activity/providers/social_providers.dart";
import "package:oauth_activity/providers/supabase_providers.dart";

/// Home when signed in, Login when signed out, the account setup for a new
/// account that hasn't finished it, and the new-password page while a
/// password reset is in progress.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Close any pushed pages (Register, OTP, Reset, Settings) when the user
    // signs in or out. Other auth events (token refresh, password change)
    // keep the current page.
    ref.listen(authStateProvider, (previous, next) {
      final wasIn = previous?.valueOrNull?.session != null;
      final isIn = next.valueOrNull?.session != null;
      if (wasIn != isIn) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    final authState = ref.watch(authStateProvider);
    final client = ref.watch(supabaseProvider);
    final recovering = ref.watch(recoveryModeProvider);

    final session =
        authState.valueOrNull?.session ?? client.auth.currentSession;

    if (session != null && recovering) return const NewPasswordPage();
    if (session == null) return const LoginPage();
    // A new account fills in its name, birthday and username first.
    final profile = ref.watch(myProfileProvider).valueOrNull;
    if (profile != null && !profile.setupDone) {
      return AccountSetupPage(key: ValueKey(profile.id), profile: profile);
    }
    return const HomePage();
  }
}
