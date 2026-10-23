import "package:flutter/cupertino.dart";

import "../theme/app_theme.dart";

/// Small rounded Instagram button: blue ("Follow") or grey ("Following",
/// "Edit profile", "Message").
class IgButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final double height;
  final IconData? icon;
  final bool expand;

  const IgButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.height = 32,
    this.icon,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final Color fill = primary ? kIgBlue : colors.button;
    final Color text = primary ? const Color(0xFFFFFFFF) : colors.text;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: text),
          if (label.isNotEmpty) const SizedBox(width: 6),
        ],
        if (label.isNotEmpty)
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
      ],
    );

    return CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      minimumSize: Size(height, height),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: onTap == null ? fill.withValues(alpha: 0.5) : fill,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}

/// "Follow" / "Following" button.
class FollowButton extends StatelessWidget {
  final bool following;
  final VoidCallback onTap;
  final bool followsYou;
  final bool expand;

  const FollowButton({
    super.key,
    required this.following,
    required this.onTap,
    this.followsYou = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    return IgButton(
      label: following ? "Following" : (followsYou ? "Follow back" : "Follow"),
      primary: !following,
      expand: expand,
      onTap: onTap,
    );
  }
}

/// Plain icon button (feed actions, app bars drawn by hand).
class IgIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final double size;
  final String? semanticLabel;

  const IgIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.size = 26,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.all(4),
      minimumSize: Size(size + 8, size + 8),
      onPressed: onTap,
      child: Icon(
        icon,
        size: size,
        color: color ?? AppColors.of(context).text,
        semanticLabel: semanticLabel,
      ),
    );
  }
}
