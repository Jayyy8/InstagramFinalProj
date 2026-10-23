import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/social_models.dart";
import "../navigation.dart";
import "../pages/story_create_page.dart";
import "../pages/story_viewer_page.dart";
import "../providers/social_providers.dart";
import "../providers/story_provider.dart";
import "../theme/app_theme.dart";
import "gradient_avatar.dart";

/// "Your story" followed by the stories of people you follow, then the
/// sample channels.
class StoriesRow extends ConsumerWidget {
  const StoriesRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myProfileProvider).valueOrNull;
    final mine = ref.watch(myStoryProvider);
    final groups = ref.watch(storyRowProvider);
    final seen = ref.watch(seenStoriesProvider);

    void addStory() => pushFullscreen(context, const StoryCreatePage());

    void open(List<StoryGroup> list, int index) => pushFullscreen(
      context,
      StoryViewerPage(groups: list, initialIndex: index),
    );

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: groups.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _StoryItem(
              label: "Your story",
              dim: true,
              onTap: mine == null ? addStory : () => open([mine], 0),
              avatar: GradientAvatar(
                name: me?.username ?? "",
                imageUrls: me?.avatarUrls,
                size: 80,
                ring: mine != null,
                seen: mine != null && groupSeen(mine, seen),
                showPlus: true,
                onPlus: addStory,
              ),
            );
          }

          final group = groups[index - 1];
          return _StoryItem(
            label: group.username,
            dim: groupSeen(group, seen),
            onTap: () => open(groups, index - 1),
            avatar: GradientAvatar(
              name: group.username,
              size: 80,
              imageUrls: group.avatarUrls,
              seen: groupSeen(group, seen),
            ),
          );
        },
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  final String label;
  final Widget avatar;
  final VoidCallback onTap;
  final bool dim;

  const _StoryItem({
    required this.label,
    required this.avatar,
    required this.onTap,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(height: 6),
          SizedBox(
            width: 82,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: dim ? colors.secondaryText : colors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
