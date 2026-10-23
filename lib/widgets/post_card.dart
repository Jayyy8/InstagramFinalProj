import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../data/sample_feed.dart";

import "../models/feed_models.dart";
import "../navigation.dart";
import "../pages/story_viewer_page.dart";
import "../providers/feed_provider.dart";
import "../providers/social_providers.dart";
import "../providers/story_provider.dart";
import "../theme/app_theme.dart";
import "dialogs.dart";
import "feed_image.dart";
import "follow_button.dart";
import "gradient_avatar.dart";
import "post_actions.dart";

/// One post in the feed, laid out like Instagram:
/// header, photo carousel, action row with counts, caption, comments, time.
class PostCard extends ConsumerStatefulWidget {
  final FeedPost post;

  const PostCard({super.key, required this.post});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _heart = false;
  bool _expanded = false;
  int _page = 0;

  void _doubleTap(FeedPost post) {
    _guard(ref.read(postActionsProvider).like(post));
    setState(() => _heart = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _heart = false);
    });
  }

  void _guard(Future<void> action) {
    action.catchError((Object e) {
      if (mounted) showToast(context, errorText(e), error: true);
    });
  }

  void _openAuthor(FeedPost post) {
    final author = post.author;
    if (author == null) return;
    final story = ref.read(storyOfUserProvider(author.id));
    if (story != null) {
      pushFullscreen(context, StoryViewerPage(groups: [story]));
    } else {
      openProfile(context, author);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the post itself so likes / saves made elsewhere show up here.
    final post = ref.watch(postProvider(widget.post.id)) ?? widget.post;
    final colors = AppColors.of(context);
    final me = ref.watch(currentUserIdProvider);
    final actions = ref.read(postActionsProvider);
    final mine = post.author?.id == me;

    final bool following;
    if (post.remote) {
      final ids = ref.watch(followingProvider).valueOrNull ?? const {};
      following = ids.contains(post.author!.id);
    } else {
      following = ref
          .watch(followedChannelsProvider)
          .contains(post.channel!.handle);
    }

    final story = post.remote
        ? ref.watch(storyOfUserProvider(post.author!.id))
        : null;
    final seen = ref.watch(seenStoriesProvider);

    final secondary = TextStyle(fontSize: 12, color: colors.text);
    final photos = post.photos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ───── Header ─────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _openAuthor(post),
                child: GradientAvatar(
                  name: post.authorName,
                  imageUrls: post.remote
                      ? post.authorAvatar
                      : channelAvatar(post.authorName),
                  size: 34,
                  ring: story != null,
                  seen: story != null && groupSeen(story, seen),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (post.author != null) openProfile(context, post.author!);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.text,
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
                        ],
                      ),
                      if (!mine && !following && !post.remote)
                        Text("Suggested for you", style: secondary)
                      else if (post.location.isNotEmpty)
                        Text(
                          post.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: secondary,
                        ),
                    ],
                  ),
                ),
              ),
              if (!mine && !following) ...[
                FollowButton(
                  following: false,
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
                ),
                const SizedBox(width: 2),
              ],
              IgIconButton(
                icon: CupertinoIcons.ellipsis,
                size: 20,
                semanticLabel: "More",
                onTap: () => showPostMenu(context, ref, post),
              ),
            ],
          ),
        ),

        // ───── Photos (double tap to like, swipe for more) ─────
        GestureDetector(
          onDoubleTap: () => _doubleTap(post),
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photos.length <= 1)
                  FeedImage(urls: post.cover)
                else
                  PageView.builder(
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => FeedImage(urls: photos[i]),
                  ),
                if (photos.length > 1)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xB3000000),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${_page + 1}/${photos.length}",
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                IgnorePointer(
                  child: Center(
                    child: AnimatedScale(
                      scale: _heart ? 1.0 : 0.4,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      child: AnimatedOpacity(
                        opacity: _heart ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          CupertinoIcons.heart_fill,
                          size: 100,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ───── Actions with counts ─────
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 4, 0),
          child: Row(
            children: [
              _CountAction(
                icon: post.liked
                    ? CupertinoIcons.heart_fill
                    : CupertinoIcons.heart,
                color: post.liked ? kIgRed : null,
                count: post.likes,
                label: post.liked ? "Unlike" : "Like",
                onTap: () => _guard(actions.toggleLike(post)),
              ),
              _CountAction(
                icon: CupertinoIcons.chat_bubble,
                count: post.totalComments,
                label: "Comment",
                onTap: () => openComments(context, post),
              ),
              _CountAction(
                icon: CupertinoIcons.arrow_2_squarepath,
                count: post.remote ? 0 : post.baseLikes ~/ 68,
                label: "Repost",
                onTap: () => showToast(context, "Reposted to your followers"),
              ),
              _CountAction(
                icon: CupertinoIcons.paperplane,
                count: post.remote ? 0 : post.baseLikes ~/ 16,
                label: "Share",
                onTap: () => sharePost(context, ref, post),
              ),
              const Spacer(),
              if (photos.length > 1) _Dots(count: photos.length, index: _page),
              const Spacer(),
              IgIconButton(
                icon: post.saved
                    ? CupertinoIcons.bookmark_fill
                    : CupertinoIcons.bookmark,
                size: 24,
                semanticLabel: "Save",
                onTap: () => _guard(actions.toggleSave(post)),
              ),
            ],
          ),
        ),

        // ───── Caption, comments, time ─────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.caption.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: "${post.authorName} ",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: post.caption),
                      ],
                    ),
                    maxLines: _expanded ? null : 2,
                    overflow: _expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: colors.text),
                  ),
                ),
              if (post.totalComments > 0) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => openComments(context, post),
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    post.totalComments == 1
                        ? "View 1 comment"
                        : "View all ${post.totalComments} comments",
                    style: TextStyle(fontSize: 14, color: colors.secondaryText),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                post.timeAgo,
                style: TextStyle(fontSize: 12, color: colors.secondaryText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

/// Icon with the number next to it ("♡ 71.5K").
class _CountAction extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _CountAction({
    required this.icon,
    required this.count,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      minimumSize: const Size(36, 36),
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: color ?? colors.text,
            semanticLabel: label,
          ),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Text(
              compactCount(count),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;

  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == index ? kIgBlue : colors.separator,
            ),
          ),
      ],
    );
  }
}
