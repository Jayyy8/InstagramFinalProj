import "dart:convert";
import "dart:math";

import "package:crypto/crypto.dart";
import "package:flutter/cupertino.dart";
import "package:flutter/foundation.dart"
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:sign_in_with_apple/sign_in_with_apple.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "supabase_providers.dart";

/// Where the browser sends the user back to the app after Apple login.
/// Must match the Android intent-filter and the Redirect URLs in Supabase.
const String kOAuthRedirectUrl = "io.supabase.oauthactivity://login-callback/";

/// UI state for auth actions: loading flag plus a message to display.
class AuthUiState {
  final bool loading;
  final String? message;
  final bool isError;

  const AuthUiState({this.loading = false, this.message, this.isError = false});
}

/// True while the user is in the middle of resetting a password
/// (code verified, new password not set yet).
class RecoveryModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final recoveryModeProvider = NotifierProvider<RecoveryModeNotifier, bool>(
  RecoveryModeNotifier.new,
);

class AuthController extends Notifier<AuthUiState> {
  SupabaseClient get _supabase => ref.read(supabaseProvider);

  @override
  AuthUiState build() => const AuthUiState();

  void clear() => state = const AuthUiState();

  Future<bool> _run(Future<void> Function() action, {String? success}) async {
    state = const AuthUiState(loading: true);
    try {
      await action();
      state = AuthUiState(message: success, isError: false);
      return true;
    } on AuthException catch (e) {
      state = AuthUiState(message: e.message, isError: true);
      return false;
    } catch (e) {
      state = AuthUiState(message: e.toString(), isError: true);
      return false;
    }
  }

  // Registration: step 1, create the account (a code is emailed)
  Future<bool> signUp(String email, String password) => _run(() async {
    await _supabase.auth.signUp(email: email.trim(), password: password);
  }, success: "Account created. Enter the code we emailed you.");

  // Registration: step 2, confirm the email with the code
  Future<bool> verifySignupCode(String email, String code) => _run(() async {
    await _supabase.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.signup,
    );
  });

  // Registration: resend the confirmation code
  Future<bool> resendSignupCode(String email) => _run(() async {
    await _supabase.auth.resend(type: OtpType.signup, email: email.trim());
  }, success: "New code sent. Check your email.");

  // Sign in with password
  Future<bool> signInWithPassword(String email, String password) =>
      _run(() async {
        await _supabase.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
      });

  // Sign in with OTP: step 1, send the code (registered emails only)
  Future<bool> sendOtp(String email) => _run(() async {
    await _supabase.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: false,
    );
  }, success: "Code sent. Check your email.");

  // Sign in with OTP: step 2, verify the code
  Future<bool> verifyOtp(String email, String code) => _run(() async {
    await _supabase.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.email,
    );
  });

  // Reset password: step 1, email a recovery code
  Future<bool> resetPassword(String email) => _run(() async {
    await _supabase.auth.resetPasswordForEmail(email.trim());
  }, success: "Reset code sent. Check your email.");

  // Reset password: step 2, verify the code from the email
  Future<bool> verifyRecoveryCode(String email, String code) async {
    // Set first so AuthGate shows the "new password" page instead of Home
    // as soon as the session is created.
    ref.read(recoveryModeProvider.notifier).set(true);
    final ok = await _run(() async {
      await _supabase.auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: OtpType.recovery,
      );
    });
    if (!ok) ref.read(recoveryModeProvider.notifier).set(false);
    return ok;
  }

  // Reset password: step 3, save the new password
  Future<bool> updatePassword(String newPassword) async {
    final ok = await _run(() async {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    });
    if (ok) ref.read(recoveryModeProvider.notifier).set(false);
    return ok;
  }

  /// Settings → Change password. Accounts that log in with a password must
  /// confirm the current one first; Apple / code-only accounts set one.
  Future<bool> changePassword({
    String? currentPassword,
    required String newPassword,
  }) => _run(() async {
    final email = _supabase.auth.currentUser?.email;
    if (currentPassword != null && email != null) {
      try {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: currentPassword,
        );
      } on AuthException {
        throw const AuthException("Your current password is incorrect.");
      }
    }
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }, success: "Your password has been changed.");

  /// True when the account was created with email + password.
  bool get hasPasswordLogin {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    final providers = user.appMetadata["providers"];
    if (providers is List) return providers.contains("email");
    return user.appMetadata["provider"] == "email";
  }

  // Leave the reset flow without setting a new password
  Future<void> cancelRecovery() async {
    ref.read(recoveryModeProvider.notifier).set(false);
    await _supabase.auth.signOut();
  }

  /// iPhone / Mac use Apple's native sign-in sheet.
  bool get _useNativeApple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  // Sign in with Apple
  Future<bool> signInWithApple() => _run(() async {
    if (_useNativeApple) {
      // Native flow (iOS / macOS)
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException("No identity token received from Apple.");
      }

      await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
    } else {
      // Web login through the browser (Android and others).
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kOAuthRedirectUrl,
      );
    }
  });

  // Print current user
  void printCurrentUser() {
    final user = _supabase.auth.currentUser;
    debugPrint("Current user: ${user?.toJson()}");
  }

  // Sign out
  Future<void> signOut() => _run(() => _supabase.auth.signOut());

  String _generateNonce([int length = 32]) {
    const charset =
        "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._";
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthUiState>(
  AuthController.new,
);
