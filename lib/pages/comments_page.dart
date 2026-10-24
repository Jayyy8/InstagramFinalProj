import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../data/sample_feed.dart";
import "../models/feed_models.dart";
import "../providers/feed_provider.dart";
import "../providers/social_providers.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "../widgets/gradient_avatar.dart";
import "../widgets/message_input_bar.dart";
import "../widgets/sub_page.dart";

class CommentsPage extends ConsumerStatefulWidget {
  final String postId;

  const CommentsPage({super.key, required this.postId});

  @override
  ConsumerState<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends ConsumerState<CommentsPage> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(FeedPost post) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    if (!post.remote) {
      ref.read(postActionsProvider).addLocalComment(post, text);
      _controller.clear();
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(commentsProvider(post.id).notifier).add(text);
      _controller.clear();
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _commentMenu(FeedPost post, FeedComment c) {
    final me = ref.read(currentUserIdProvider);
    final canDelete =
        c.id != null && (c.authorId == me || post.author?.id == me);
    if (!canDelete) return;
    showActionSheet(
      context,
      actions: [
        SheetAction(
          label: "Delete comment",
          icon: CupertinoIcons.delete,
          destructive: true,
          onTap: () => ref
              .read(commentsProvider(post.id).notifier)
              .delete(c.id!)
              .catchError((Object e) {
                if (mounted) showToast(context, errorText(e), error: true);
              }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(postProvider(widget.postId));
    final colors = AppColors.of(context);
    final myProfile = ref.watch(myProfileProvider).valueOrNull;

    if (post == null) {
      return const SubPage(
        title: "Comments",
        child: Center(child: Text("This post was removed.")),
      );
    }

    final AsyncValue<List<FeedComment>> comments = post.remote
        ? ref.watch(commentsProvider(post.id))
        : AsyncData(post.comments);

    // The caption is shown first, like Instagram.
    final header = post.caption.isEmpty
        ? null
        : FeedComment(
            author: post.authorName,
            avatarUrls: post.remote
                ? post.authorAvatar
                : channelAvatar(post.authorName),
            text: post.caption,
            createdAt: post.createdAt,
          );

    return SubPage(
      title: "Comments",
      safeBottom: true,
      child: Column(
        children: [
          Expanded(
            child: comments.when(
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (e, _) => Center(child: Text(errorText(e))),
              data: (list) {
                final all = [?header, ...list];
                if (all.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "No comments yet",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Start the conversation.",
                          style: TextStyle(color: colors.secondaryText),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: all.length,
                  itemBuilder: (context, i) {
                    final c = all[i];
                    final name = c.author ?? myProfile?.username ?? "you";
                    final avatar = c.author == null
                        ? myProfile?.avatarUrls
                        : c.avatarUrls;
                    return GestureDetector(
                      onLongPress: () => _commentMenu(post, c),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GradientAvatar(
                              name: name,
                              imageUrls: avatar,
                              size: 34,
                              ring: false,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: colors.text,
                                        ),
                                      ),
                                      if (c.createdAt != null) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          timeAgoShort(c.createdAt!),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.secondaryText,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    c.text,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colors.text,
                                    ),
                                  ),
                                  if (c != header) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      "Reply",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: colors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(height: 0.5, color: colors.separator),
          if (post.commentsOff)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Commenting has been turned off.",
                style: TextStyle(color: colors.secondaryText, fontSize: 14),
              ),
            )
          else
            MessageInputBar(
              controller: _controller,
              placeholder: "Add a comment for ${post.authorName}...",
              onSend: () => _send(post),
              leading: GradientAvatar(
                name: myProfile?.username ?? "",
                imageUrls: myProfile?.avatarUrls,
                size: 36,
                ring: false,
              ),
            ),
        ],
      ),
    );
  }
}
