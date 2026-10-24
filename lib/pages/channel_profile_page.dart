import "package:flutter/cupertino.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../data/sample_feed.dart";
import "../models/feed_models.dart";
import "../navigation.dart";
import "../providers/chat_provider.dart";
import "../providers/feed_provider.dart";
import "../providers/story_provider.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "../widgets/follow_button.dart";
import "../widgets/gradient_avatar.dart";
import "../widgets/post_grid.dart";
import "../widgets/sub_page.dart";
import "chat_page.dart";
import "story_viewer_page.dart";

/// Opens the profile of a sample channel (NBA, football, news, docs).
void openChannel(BuildContext context, String handle) {
  push(context, ChannelProfilePage(handle: handle));
}

/// Profile of a sample channel: avatar with story ring, counts, bio,
/// Follow / Message and its posts grid. Following is kept on the phone.
class ChannelProfilePage extends ConsumerStatefulWidget {
  final String handle;

  const ChannelProfilePage({super.key, required this.handle});

  @override
  ConsumerState<ChannelProfilePage> createState() => _ChannelProfilePageState();
}

class _ChannelProfilePageState extends ConsumerState<ChannelProfilePage> {
  int _tab = 0;

  /// Sample group chat that belongs to this channel, if any.
  ChatThread? get _thread {
    const byHandle = {
      "hoops.daily": "nba",
      "matchday.live": "football",
      "worldnews.now": "news",
    };
    final id = byHandle[widget.handle];
    for (final t in kChatThreads) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final handle = widget.handle;
    final info = kChannelInfo[handle];
    final posts = ref.watch(channelPostsProvider(handle));
    final following = ref.watch(followedChannelsProvider).contains(handle);
    final seen = ref.watch(seenStoriesProvider);
    final story = sampleStoryGroups()
        .where((g) => g.username == handle)
        .firstOrNull;
    final followers = (info?.followers ?? 0) + (following ? 1 : 0);

    Widget stat(String value, String label) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 14, color: colors.text)),
      ],
    );

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: story == null
                    ? null
                    : () => pushFullscreen(
                        context,
                        StoryViewerPage(groups: [story]),
                      ),
                child: GradientAvatar(
                  name: handle,
                  imageUrls: channelAvatar(handle),
                  size: 88,
                  ring: story != null,
                  seen: story != null && groupSeen(story, seen),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            info?.name ?? handle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          CupertinoIcons.checkmark_seal_fill,
                          size: 14,
                          color: kIgBlue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        stat(formatCount(posts.length), "posts"),
                        stat(compactCount(followers), "followers"),
                        stat(compactCount(info?.following ?? 0), "following"),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (info != null) ...[
            Text(
              info.category,
              style: TextStyle(fontSize: 14, color: colors.secondaryText),
            ),
            const SizedBox(height: 2),
            Text(info.bio, style: TextStyle(fontSize: 14, color: colors.text)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FollowButton(
                  following: following,
                  expand: true,
                  onTap: () => ref
                      .read(followedChannelsProvider.notifier)
                      .toggle(handle),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: IgButton(
                  label: "Message",
                  expand: true,
                  onTap: () {
                    final thread = _thread;
                    if (thread != null) {
                      push(context, LocalChatPage(thread: thread));
                    } else {
                      showInfo(
                        context,
                        title: info?.name ?? handle,
                        message: "This account doesn't accept messages.",
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
              IgButton(
                label: "",
                icon: CupertinoIcons.person_add,
                onTap: () =>
                    ref.read(followedChannelsProvider.notifier).toggle(handle),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );

    final tabs = Row(
      children: [
        for (final (i, icon) in [
          (0, CupertinoIcons.square_grid_3x2),
          (1, CupertinoIcons.play_rectangle),
          (2, CupertinoIcons.person_crop_square),
        ])
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _tab == i ? colors.text : const Color(0x00000000),
                      width: 1.2,
                    ),
                  ),
                ),
                child: Icon(
                  icon,
                  color: _tab == i ? colors.text : colors.secondaryText,
                ),
              ),
            ),
          ),
      ],
    );

    final List<FeedPost> shown = switch (_tab) {
      0 => posts,
      1 => posts.where((p) => p.isVideo).toList(),
      _ => const [],
    };

    return SubPage(
      title: handle,
      actions: [
        barAction(
          context,
          AppIcons.more,
          label: "More",
          onPressed: () => showActionSheet(
            context,
            title: handle,
            actions: [
              SheetAction(
                label: "Copy profile URL",
                icon: CupertinoIcons.link,
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: "instagram-replica://u/$handle"),
                  );
                  showToast(context, "Link copied");
                },
              ),
            ],
          ),
        ),
      ],
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: header),
          SliverToBoxAdapter(child: tabs),
          if (shown.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: Text(
                    _tab == 1 ? "No reels yet" : "No photos",
                    style: TextStyle(color: colors.secondaryText),
                  ),
                ),
              ),
            )
          else
            SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 1.5,
                crossAxisSpacing: 1.5,
                childAspectRatio: 3 / 4,
              ),
              itemCount: shown.length,
              itemBuilder: (context, i) => PostTile(post: shown[i]),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}
