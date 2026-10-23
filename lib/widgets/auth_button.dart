import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";

import "../theme/app_theme.dart";

const Color kAuthBlue = kIgBlue;

/// Full-width button for the login and sign-up pages.
/// Native on iOS 26+, Cupertino on older iPhones, Material on Android.
/// [outlined] = false -> blue (primary action)
/// [outlined] = true  -> bordered (secondary action)
class AuthButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool outlined;
  final double height;

  const AuthButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.outlined = false,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final Color textColor = outlined ? colors.text : const Color(0xFFFFFFFF);

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    return SizedBox(
      width: double.infinity,
      height: height,
      child: AdaptiveButton.child(
        onPressed: onTap ?? () {},
        enabled: onTap != null,
        style: outlined
            ? AdaptiveButtonStyle.bordered
            : AdaptiveButtonStyle.filled,
        color: outlined ? colors.button : kIgBlue,
        size: AdaptiveButtonSize.large,
        borderRadius: BorderRadius.circular(height / 2),
        minSize: Size(double.infinity, height),
        child: child,
      ),
    );
  }
}

/// The "OR" separator between the main login and the other login methods.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final line = Expanded(
      child: Container(height: 0.5, color: colors.separator),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "OR",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.secondaryText,
            ),
          ),
        ),
        line,
      ],
    );
  }
}
