import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/feed_models.dart";
import "../models/social_models.dart";
import "../navigation.dart";
import "../providers/social_providers.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "../widgets/feed_image.dart";
import "../widgets/follow_button.dart";
import "../widgets/gradient_avatar.dart";
import "../widgets/post_actions.dart";
import "../widgets/sub_page.dart";
import "post_detail_page.dart";

/// Notifications (heart icon): new followers, likes and comments.
class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  /// Items newer than this are listed under "New".
  late final DateTime? _seenBefore = ref.read(activitySeenProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(activityProvider);
      ref.read(activitySeenProvider.notifier).markSeen();
    });
  }

  bool _isNew(ActivityItem a) =>
      _seenBefore == null || a.createdAt.isAfter(_seenBefore);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final items = ref.watch(activityProvider);
    final following = ref.watch(followingProvider).valueOrNull ?? const {};

    String verb(ActivityItem a) {
      switch (a.kind) {
        case "follow":
          return "started following you.";
        case "like":
          return "liked your post.";
        default:
          return "commented: ${a.text ?? ''}";
      }
    }

    return SubPage(
      title: "Notifications",
      child: items.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text(errorText(e))),
        data: (list) => CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                ref.invalidate(activityProvider);
                await ref.read(activityProvider.future);
              },
            ),
            if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.heart,
                          size: 56,
                          color: colors.text,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Activity on your posts",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "When someone likes or comments on one of your posts, or follows you, you'll see it here.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SliverList.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final a = list[i];
                final fresh = _isNew(a);
                final header = i == 0 || _isNew(list[i - 1]) != fresh;
                final row = GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (a.postId != null) {
                      push(context, PostDetailPage(postId: a.postId!));
                    } else {
                      openProfile(context, a.actor);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => openProfile(context, a.actor),
                          child: GradientAvatar(
                            name: a.actor.username,
                            imageUrls: a.actor.avatarUrls,
                            size: 44,
                            ring: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: "${a.actor.username} ",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(text: verb(a)),
                                TextSpan(
                                  text: " ${timeAgoShort(a.createdAt)}",
                                  style: TextStyle(color: colors.secondaryText),
                                ),
                              ],
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, color: colors.text),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (a.kind == "follow")
                          FollowButton(
                            following: following.contains(a.actor.id),
                            followsYou: true,
                            onTap: () => ref
                                .read(followingProvider.notifier)
                                .toggle(a.actor.id)
                                .catchError((Object e) {
                                  if (context.mounted) {
                                    showToast(
                                      context,
                                      errorText(e),
                                      error: true,
                                    );
                                  }
                                }),
                          )
                        else if (a.postImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: FeedImage(urls: [a.postImage!]),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (header)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Text(
                          fresh ? "New" : "Earlier",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.text,
                          ),
                        ),
                      ),
                    ColoredBox(
                      color: fresh
                          ? kIgBlue.withValues(alpha: 0.08)
                          : const Color(0x00000000),
                      child: row,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
