import "package:flutter/cupertino.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/feed_models.dart";
import "../models/social_models.dart";
import "../navigation.dart";
import "../pages/comments_page.dart";
import "../pages/profile_page.dart";
import "../providers/chat_provider.dart";
import "../providers/feed_provider.dart";
import "../providers/social_providers.dart";
import "../theme/app_theme.dart";
import "dialogs.dart";
import "gradient_avatar.dart";

void openComments(BuildContext context, FeedPost post) {
  push(context, CommentsPage(postId: post.id));
}

void openProfile(BuildContext context, Profile profile) {
  push(context, ProfilePage(userId: profile.id, initial: profile));
}

/// Link that identifies a post (copied by "Copy link").
String postLink(FeedPost post) =>
    post.remote ? "instagram-replica://p/${post.id}" : post.cover.first;

Future<void> copyPostLink(BuildContext context, FeedPost post) async {
  await Clipboard.setData(ClipboardData(text: postLink(post)));
  if (context.mounted) showToast(context, "Link copied");
}

/// "Share" sheet: send the post to people you follow, or copy the link.
void sharePost(BuildContext context, WidgetRef ref, FeedPost post) {
  showIgSheet<void>(
    context,
    heightFactor: 0.6,
    builder: (_) => _ShareSheet(post: post),
  );
}

class _ShareSheet extends ConsumerStatefulWidget {
  final FeedPost post;

  const _ShareSheet({required this.post});

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final Set<String> _sent = {};
  final Set<String> _sending = {};

  Future<void> _send(Profile to) async {
    final post = widget.post;
    setState(() => _sending.add(to.id));
    try {
      await sendDirect(
        ref,
        to: to.id,
        contextType: "post_share",
        contextText: "${post.authorName}: ${post.caption}",
        contextMediaUrl: post.cover.isEmpty ? null : post.cover.first,
      );
      if (mounted) setState(() => _sent.add(to.id));
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _sending.remove(to.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final me = ref.watch(currentUserIdProvider);
    final people = me == null
        ? const AsyncValue<List<Profile>>.data([])
        : ref.watch(followingListProvider(me));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            "Share",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
        ),
        Expanded(
          child: people.when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (e, _) => Center(child: Text(errorText(e))),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "Follow people to send them posts.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.secondaryText),
                    ),
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.72,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final p = list[i];
                  final sent = _sent.contains(p.id);
                  final sending = _sending.contains(p.id);
                  return GestureDetector(
                    onTap: sent || sending ? null : () => _send(p),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            GradientAvatar(
                              name: p.username,
                              imageUrls: p.avatarUrls,
                              size: 72,
                              ring: false,
                            ),
                            if (sent || sending)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: kIgBlue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.sheet,
                                      width: 2,
                                    ),
                                  ),
                                  child: sending
                                      ? const CupertinoActivityIndicator(
                                          radius: 6,
                                          color: Color(0xFFFFFFFF),
                                        )
                                      : const Icon(
                                          CupertinoIcons.checkmark_alt,
                                          size: 14,
                                          color: Color(0xFFFFFFFF),
                                        ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.displayName,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: colors.text),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(height: 0.5, color: colors.separator),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareOption(
                icon: CupertinoIcons.link,
                label: "Copy link",
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await copyPostLink(context, widget.post);
                  navigator.pop();
                },
              ),
              _ShareOption(
                icon: CupertinoIcons.add_circled,
                label: "Add to story",
                onTap: () {
                  Navigator.of(context).pop();
                  showInfo(
                    context,
                    title: "Add to story",
                    message:
                        "Open the camera from \"Your story\" to share a photo or video.",
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.button,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colors.text),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, color: colors.text)),
        ],
      ),
    );
  }
}

/// The "⋯" menu of a post.
void showPostMenu(BuildContext context, WidgetRef ref, FeedPost post) {
  final me = ref.read(currentUserIdProvider);
  final actions = ref.read(postActionsProvider);
  final mine = post.author?.id == me;
  final following = post.remote
      ? ref.read(followingProvider.notifier).isFollowing(post.author!.id)
      : ref.read(followedChannelsProvider).contains(post.channel?.handle);

  showActionSheet(
    context,
    actions: [
      SheetAction(
        label: post.saved ? "Remove from saved" : "Save",
        icon: post.saved
            ? CupertinoIcons.bookmark_fill
            : CupertinoIcons.bookmark,
        onTap: () => actions.toggleSave(post),
      ),
      SheetAction(
        label: "Copy link",
        icon: CupertinoIcons.link,
        onTap: () => copyPostLink(context, post),
      ),
      if (!mine && following)
        SheetAction(
          label: "Unfollow",
          icon: CupertinoIcons.person_badge_minus,
          onTap: () {
            if (post.remote) {
              ref.read(followingProvider.notifier).toggle(post.author!.id);
            } else {
              ref
                  .read(followedChannelsProvider.notifier)
                  .toggle(post.channel!.handle);
            }
          },
        ),
      if (!mine)
        SheetAction(
          label: "Not interested",
          icon: CupertinoIcons.eye_slash,
          onTap: () => actions.hide(post),
        ),
      if (mine)
        SheetAction(
          label: "Delete",
          icon: CupertinoIcons.delete,
          destructive: true,
          onTap: () => confirmAction(
            context,
            title: "Delete post?",
            message: "You won't be able to restore this post.",
            confirmLabel: "Delete",
            onConfirm: () async {
              try {
                await actions.delete(post);
              } catch (e) {
                if (context.mounted) {
                  showToast(context, errorText(e), error: true);
                }
              }
            },
          ),
        ),
    ],
  );
}
