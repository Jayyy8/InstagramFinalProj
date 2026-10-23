import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/auth_controller.dart";
import "dialogs.dart";

void confirmLogout(BuildContext context, WidgetRef ref) {
  final controller = ref.read(authControllerProvider.notifier);

  confirmAction(
    context,
    title: "Log out of your account?",
    message: "You will need to log in again.",
    confirmLabel: "Log out",
    onConfirm: () => controller.signOut(),
  );
}
