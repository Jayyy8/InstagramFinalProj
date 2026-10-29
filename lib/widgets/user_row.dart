import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/social_models.dart";
import "../providers/social_providers.dart";
import "../theme/app_theme.dart";
import "dialogs.dart";
import "follow_button.dart";
import "gradient_avatar.dart";
import "post_actions.dart";

/// Avatar, username and name, with a Follow button (search results,
/// follower lists, suggestions).
class UserRow extends ConsumerWidget {
  final Profile profile;
  final bool showFollow;
  final VoidCallback? onTap;
  final Widget? trailing;

  const UserRow({
    super.key,
    required this.profile,
    this.showFollow = true,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final me = ref.watch(currentUserIdProvider);
    final following = (ref.watch(followingProvider).valueOrNull ?? const {})
        .contains(profile.id);

    return GestureDetector(
      onTap: onTap ?? () => openProfile(context, profile),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            GradientAvatar(
              name: profile.username,
              imageUrls: profile.avatarUrls,
              size: 50,
              ring: false,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: colors.text,
                          ),
                        ),
                      ),
                      if (profile.verified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          CupertinoIcons.checkmark_seal_fill,
                          size: 13,
                          color: kIgBlue,
                          semanticLabel: "Verified",
                        ),
                      ],
                    ],
                  ),
                  if (profile.fullName.isNotEmpty)
                    Text(
                      profile.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.secondaryText,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (showFollow && profile.id != me)
              FollowButton(
                following: following,
                onTap: () => ref
                    .read(followingProvider.notifier)
                    .toggle(profile.id)
                    .catchError((Object e) {
                      if (context.mounted) {
                        showToast(context, errorText(e), error: true);
                      }
                    }),
              ),
          ],
        ),
      ),
    );
  }
}
