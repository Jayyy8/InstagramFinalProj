import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../providers/feed_provider.dart";
import "../../providers/notes_provider.dart";
import "../../providers/social_providers.dart";
import "../../providers/story_provider.dart";
import "../../theme/app_theme.dart";
import "../../widgets/feed_skeleton.dart";
import "../../widgets/post_card.dart";
import "../../widgets/stories_row.dart";

/// Home feed: stories, then posts of people you follow (and yours),
/// then the sample channels.
class FeedTab extends ConsumerWidget {
  const FeedTab({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(followingProvider);
    ref.invalidate(myProfileProvider);
    ref.invalidate(notesProvider);
    await Future.wait([
      ref.read(homeFeedProvider.notifier).refresh(),
      ref.read(storiesProvider.notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(feedLoadingProvider);
    final posts = ref.watch(feedProvider);
    final reposters = ref.watch(feedRepostersProvider);
    final colors = AppColors.of(context);

    // Shimmering placeholders while the feed loads.
    if (loading) return const FeedSkeleton();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: () => _refresh(ref)),
          const SliverToBoxAdapter(child: StoriesRow()),
          SliverToBoxAdapter(
            child: Container(
              height: 0.5,
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              color: colors.separator,
            ),
          ),
          if (posts.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text("No posts yet. Tap + to share one.")),
            ),
          SliverList.builder(
            itemCount: posts.length,
            itemBuilder: (context, i) => PostCard(
              key: ValueKey(posts[i].id),
              post: posts[i],
              repostedBy: reposters[posts[i].id],
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: bottomBarInset(context))),
        ],
      ),
    );
  }
}
