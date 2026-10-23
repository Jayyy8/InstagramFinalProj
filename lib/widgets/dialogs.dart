import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";

import "../theme/app_theme.dart";

/// Simple message with an OK button (native alert on every platform).
Future<void> showInfo(
  BuildContext context, {
  required String title,
  String? message,
}) {
  return AdaptiveAlertDialog.show(
    context: context,
    title: title,
    message: message,
    actions: [
      AlertAction(
        title: "OK",
        style: AlertActionStyle.primary,
        onPressed: () {},
      ),
    ],
  );
}

/// Asks before doing something. The dialog closes itself before
/// [onConfirm] runs.
Future<void> confirmAction(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  required VoidCallback onConfirm,
  bool destructive = true,
}) {
  return AdaptiveAlertDialog.show(
    context: context,
    title: title,
    message: message,
    actions: [
      AlertAction(
        title: "Cancel",
        style: AlertActionStyle.cancel,
        onPressed: () {},
      ),
      AlertAction(
        title: confirmLabel,
        style: destructive
            ? AlertActionStyle.destructive
            : AlertActionStyle.primary,
        onPressed: onConfirm,
      ),
    ],
  );
}

/// Short banner (top on iOS, snackbar on Android).
void showToast(BuildContext context, String message, {bool error = false}) {
  AdaptiveSnackBar.show(
    context,
    message: message,
    type: error ? AdaptiveSnackBarType.error : AdaptiveSnackBarType.info,
  );
}

/// A readable message for an exception.
String errorText(Object error) {
  final text = error.toString();
  final match = RegExp(r"message: ([^,)]+)").firstMatch(text);
  if (match != null) return match.group(1)!;
  return text.replaceFirst("Exception: ", "");
}

class SheetAction {
  final String label;
  final IconData? icon;
  final bool destructive;
  final VoidCallback onTap;

  const SheetAction({
    required this.label,
    required this.onTap,
    this.icon,
    this.destructive = false,
  });
}

/// List of options sliding up from the bottom.
Future<void> showActionSheet(
  BuildContext context, {
  String? title,
  String? message,
  required List<SheetAction> actions,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      title: title == null ? null : Text(title),
      message: message == null ? null : Text(message),
      actions: [
        for (final a in actions)
          CupertinoActionSheetAction(
            isDestructiveAction: a.destructive,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              a.onTap();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (a.icon != null) ...[
                  Icon(
                    a.icon,
                    size: 20,
                    color: a.destructive
                        ? CupertinoColors.destructiveRed
                        : CupertinoColors.activeBlue,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(a.label),
              ],
            ),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: const Text("Cancel"),
      ),
    ),
  );
}

/// Instagram-style bottom sheet: rounded top, grabber, keyboard aware.
Future<T?> showIgSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double? heightFactor,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (sheetContext) => SheetFrame(
      heightFactor: heightFactor,
      child: Builder(builder: builder),
    ),
  );
}

class SheetFrame extends StatelessWidget {
  final Widget child;
  final double? heightFactor;

  const SheetFrame({super.key, required this.child, this.heightFactor});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final media = MediaQuery.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: colors.secondaryText.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        if (heightFactor != null) Expanded(child: child) else child,
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        width: double.infinity,
        height: heightFactor == null ? null : media.size.height * heightFactor!,
        decoration: BoxDecoration(
          color: colors.sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.only(bottom: media.padding.bottom),
        child: DefaultTextStyle(style: baseTextStyle(context), child: content),
      ),
    );
  }
}
