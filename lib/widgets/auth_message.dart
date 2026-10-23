import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/auth_controller.dart";

/// A short message shown as plain text (no box).
class AuthNotice extends StatelessWidget {
  final String message;
  final bool isError;

  /// Overrides the default red / green color.
  final Color? color;

  const AuthNotice({
    super.key,
    required this.message,
    this.isError = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.3,
            color:
                color ??
                (isError
                    ? CupertinoColors.destructiveRed
                    : CupertinoColors.activeGreen),
          ),
        ),
      ),
    );
  }
}

/// Shows the loading / success / error state from the controller.
class AuthMessage extends ConsumerWidget {
  const AuthMessage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(authControllerProvider);

    if (ui.loading) {
      return const AuthNotice(
        message: "Please wait...",
        color: CupertinoColors.systemGrey,
      );
    }
    if (ui.message == null) return const SizedBox.shrink();

    return AuthNotice(message: ui.message!, isError: ui.isError);
  }
}
