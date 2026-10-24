import "package:flutter/cupertino.dart";

import "../models/audience.dart";
import "../navigation.dart";
import "../pages/close_friends_page.dart";
import "../theme/app_theme.dart";
import "dialogs.dart";

/// Sheet listing every audience; returns the one chosen (null = cancelled).
Future<Audience?> showAudiencePicker(
  BuildContext context, {
  required Audience current,
  String title = "Who can see this?",
}) {
  return showIgSheet<Audience>(
    context,
    builder: (sheetContext) {
      final colors = AppColors.of(sheetContext);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
          ),
          Container(height: 0.5, color: colors.separator),
          for (final a in Audience.values)
            Semantics(
              button: true,
              selected: a == current,
              label: "${a.label}. ${a.description}",
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(sheetContext).pop(a),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      AudienceBadge(audience: a, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
                              ),
                            ),
                            Text(
                              a.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.secondaryText,
                              ),
                            ),
                            if (a == Audience.closeFriends)
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  push(context, const CloseFriendsPage());
                                },
                                child: const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    "Edit list",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: kIgBlue,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        a == current
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.circle,
                        color: a == current ? kIgBlue : colors.secondaryText,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      );
    },
  );
}

/// Round icon for an audience (green star for Close Friends, like
/// Instagram).
class AudienceBadge extends StatelessWidget {
  final Audience audience;
  final double size;

  const AudienceBadge({super.key, required this.audience, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final close = audience == Audience.closeFriends;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: close ? kCloseFriendsGreen : colors.button,
      ),
      child: Icon(
        close ? CupertinoIcons.star_fill : audience.icon,
        size: size * 0.5,
        color: close ? const Color(0xFFFFFFFF) : colors.text,
      ),
    );
  }
}

/// "Audience  Followers ›" row for the new post / note screens.
class AudienceRow extends StatelessWidget {
  final Audience audience;
  final ValueChanged<Audience> onChanged;

  const AudienceRow({
    super.key,
    required this.audience,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      label: "Audience: ${audience.label}",
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          final picked = await showAudiencePicker(context, current: audience);
          if (picked != null) onChanged(picked);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(audience.icon, color: colors.text, size: 22),
              const SizedBox(width: 10),
              Text(
                "Audience",
                style: TextStyle(fontSize: 15, color: colors.text),
              ),
              const Spacer(),
              Text(
                audience.label,
                style: TextStyle(fontSize: 15, color: colors.secondaryText),
              ),
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 16,
                color: colors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
