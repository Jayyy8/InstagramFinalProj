import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../data/sample_feed.dart";

import "../../models/feed_models.dart";
import "../../providers/feed_provider.dart";
import "../../providers/social_providers.dart";
import "../../theme/app_theme.dart";
import "../../widgets/dialogs.dart";
import "../../widgets/feed_image.dart";
import "../../widgets/follow_button.dart";
import "../../widgets/gradient_avatar.dart";
import "../../widgets/post_actions.dart";

/// Full-screen vertical pager over the feed posts.
class ReelsTab extends ConsumerWidget {
  const ReelsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(feedProvider);

    if (posts.isEmpty) {
      return const Center(child: Text("Nothing to show yet."));
    }

    return ColoredBox(
      color: const Color(0xFF000000),
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: posts.length,
        itemBuilder: (context, index) =>
            _ReelPage(key: ValueKey(posts[index].id), post: posts[index]),
      ),
    );
  }
}

class _ReelPage extends ConsumerStatefulWidget {
  final FeedPost post;

  const _ReelPage({super.key, required this.post});

  @override
  ConsumerState<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends ConsumerState<_ReelPage> {
  bool _heart = false;

  void _guard(Future<void> f) => f.catchError((Object e) {
    if (mounted) showToast(context, errorText(e), error: true);
  });

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final actions = ref.read(postActionsProvider);
    final bottom = bottomBarInset(context);
    const white = Color(0xFFFFFFFF);
    final me = ref.watch(currentUserIdProvider);
    final followingIds = ref.watch(followingProvider).valueOrNull ?? const {};
    final channels = ref.watch(followedChannelsProvider);
    final following = post.remote
        ? followingIds.contains(post.author!.id)
        : channels.contains(post.channel!.handle);

    Widget side(
      IconData icon,
      String text,
      VoidCallback onTap, {
      Color? color,
    }) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: color ?? white, size: 30),
              const SizedBox(height: 4),
              Text(
                text,
                style: const TextStyle(
                  color: white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onDoubleTap: () {
        _guard(actions.like(post));
        setState(() => _heart = true);
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => _heart = false);
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          FeedImage(urls: post.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xB3000000)],
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                opacity: _heart ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  CupertinoIcons.heart_fill,
                  size: 110,
                  color: white,
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: bottom + 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                side(
                  post.liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  compactCount(post.likes),
                  () => _guard(actions.toggleLike(post)),
                  color: post.liked ? kIgRed : null,
                ),
                side(
                  CupertinoIcons.chat_bubble,
                  compactCount(post.totalComments),
                  () => openComments(context, post),
                ),
                side(
                  CupertinoIcons.arrow_2_squarepath,
                  compactCount(post.remote ? 0 : post.baseLikes ~/ 68),
                  () => showToast(context, "Reposted to your followers"),
                ),
                side(
                  CupertinoIcons.paperplane,
                  compactCount(post.remote ? 0 : post.baseLikes ~/ 16),
                  () => sharePost(context, ref, post),
                ),
                side(
                  post.saved
                      ? CupertinoIcons.bookmark_fill
                      : CupertinoIcons.bookmark,
                  "",
                  () => _guard(actions.toggleSave(post)),
                ),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 78,
            bottom: bottom + 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: post.author == null
                          ? null
                          : () => openProfile(context, post.author!),
                      child: GradientAvatar(
                        name: post.authorName,
                        imageUrls: post.remote
                            ? post.authorAvatar
                            : channelAvatar(post.authorName),
                        size: 32,
                        ring: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        post.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (post.verified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        size: 13,
                        color: kIgBlue,
                      ),
                    ],
                    if (post.author?.id != me && !following) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          if (post.remote) {
                            _guard(
                              ref
                                  .read(followingProvider.notifier)
                                  .toggle(post.author!.id),
                            );
                          } else {
                            ref
                                .read(followedChannelsProvider.notifier)
                                .toggle(post.channel!.handle);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: white),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "Follow",
                            style: TextStyle(
                              color: white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  post.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: white, fontSize: 14),
                ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            top: MediaQuery.paddingOf(context).top + 4,
            child: IgIconButton(
              icon: CupertinoIcons.camera,
              color: white,
              onTap: () =>
                  showToast(context, "Use \"Your story\" to share a video"),
            ),
          ),
        ],
      ),
    );
  }
}
