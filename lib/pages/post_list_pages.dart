import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/feed_models.dart";
import "../models/social_models.dart";
import "../navigation.dart";
import "../providers/feed_provider.dart";
import "../providers/social_providers.dart";
import "../providers/story_provider.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "../widgets/feed_image.dart";
import "../widgets/post_grid.dart";
import "../widgets/sub_page.dart";
import "story_viewer_page.dart";

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: colors.text),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings → Saved. Real saved posts plus saved sample posts.
class SavedPostsPage extends ConsumerWidget {
  const SavedPostsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(savedPostIdsProvider);
    final samples = ref
        .watch(samplePostsProvider)
        .where((p) => p.saved)
        .toList();

    return SubPage(
      title: "Saved",
      child: ids.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text(errorText(e))),
        data: (list) {
          final List<FeedPost> posts = [
            ...postsFor(ref, list).where((p) => p.saved),
            ...samples,
          ];
          if (posts.isEmpty) {
            return const _EmptyState(
              icon: CupertinoIcons.bookmark,
              title: "Save",
              text: "Save photos and videos that you want to see again.",
            );
          }
          return PostGrid(posts: posts);
        },
      ),
    );
  }
}

/// Settings → Your activity → posts you liked.
class LikedPostsPage extends ConsumerWidget {
  const LikedPostsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(likedPostIdsProvider);
    final samples = ref
        .watch(samplePostsProvider)
        .where((p) => p.liked)
        .toList();

    return SubPage(
      title: "Likes",
      child: ids.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text(errorText(e))),
        data: (list) {
          final List<FeedPost> posts = [
            ...postsFor(ref, list).where((p) => p.liked),
            ...samples,
          ];
          if (posts.isEmpty) {
            return const _EmptyState(
              icon: CupertinoIcons.heart,
              title: "No likes yet",
              text: "Posts you like will appear here.",
            );
          }
          return PostGrid(posts: posts);
        },
      ),
    );
  }
}

/// Settings → Archive: all your stories, including expired ones.
class StoryArchivePage extends ConsumerWidget {
  const StoryArchivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).valueOrNull;

    return SubPage(
      title: "Stories archive",
      child: FutureBuilder<List<StorySlide>>(
        future: ref.read(repositoryProvider).storyArchive(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(errorText(snapshot.error!)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CupertinoActivityIndicator());
          }
          final slides = snapshot.data!;
          if (slides.isEmpty) {
            return const _EmptyState(
              icon: CupertinoIcons.arrow_counterclockwise_circle,
              title: "No stories yet",
              text:
                  "Your stories stay here after they disappear from your profile.",
            );
          }
          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 1.5,
              crossAxisSpacing: 1.5,
              childAspectRatio: 9 / 16,
            ),
            itemCount: slides.length,
            itemBuilder: (context, i) {
              final s = slides[i];
              return GestureDetector(
                onTap: () {
                  ref.read(seenStoriesProvider.notifier).addAll([s.id]);
                  pushFullscreen(
                    context,
                    StoryViewerPage(
                      groups: [
                        StoryGroup(
                          key: "archive_${s.id}",
                          username: profile?.username ?? "",
                          avatarUrls: profile?.avatarUrls,
                          profile: profile,
                          isMine: true,
                          slides: [s],
                        ),
                      ],
                    ),
                  );
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (s.isVideo)
                      const ColoredBox(
                        color: Color(0xFF262626),
                        child: Icon(
                          CupertinoIcons.play_fill,
                          color: Color(0xFFFFFFFF),
                          size: 32,
                        ),
                      )
                    else
                      FeedImage(urls: s.imageUrls),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xE6FFFFFF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "${s.createdAt.day}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Color(0xFF000000),
                              ),
                            ),
                            Text(
                              const [
                                "Jan",
                                "Feb",
                                "Mar",
                                "Apr",
                                "May",
                                "Jun",
                                "Jul",
                                "Aug",
                                "Sep",
                                "Oct",
                                "Nov",
                                "Dec",
                              ][s.createdAt.month - 1],
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF000000),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
