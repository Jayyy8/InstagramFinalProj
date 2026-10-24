import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";

import "../data/sample_feed.dart";
import "../models/audience.dart";
import "../models/feed_models.dart";
import "../models/social_models.dart";
import "social_providers.dart";

/// Story ids you have opened. Real ones are also saved to Supabase.
class SeenStoriesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(currentUserIdProvider);
    return {};
  }

  void addAll(Iterable<String> ids) {
    final next = {...state, ...ids};
    if (next.length != state.length) state = next;
  }

  void markSeen(StorySlide slide) {
    if (state.contains(slide.id)) return;
    state = {...state, slide.id};
    if (slide.remote) {
      ref.read(repositoryProvider).markStoryViewed(slide.id).catchError((_) {});
    }
  }
}

final seenStoriesProvider = NotifierProvider<SeenStoriesNotifier, Set<String>>(
  SeenStoriesNotifier.new,
);

/// Sample channel stories, as story groups.
List<StoryGroup> sampleStoryGroups() {
  final start = DateTime.now().subtract(const Duration(hours: 3));
  Music? songOf(StoryTopic topic) {
    final s = topic.song;
    if (s == null) return null;
    return Music(title: s[0], artist: s[1], previewUrl: s[2], artworkUrl: s[3]);
  }

  return [
    for (final topic in kStoryTopics)
      StoryGroup(
        key: topic.id,
        username: topic.channel.handle,
        avatarUrls: topic.photos.first,
        verified: topic.channel.verified,
        slides: [
          for (int i = 0; i < topic.photos.length; i++)
            StorySlide(
              id: "${topic.id}_$i",
              imageUrls: topic.photos[i],
              createdAt: start.add(Duration(minutes: 20 * i)),
              music: songOf(topic),
              durationMs: topic.song != null ? 10000 : 5000,
            ),
        ],
      ),
  ];
}

/// Real story groups: yours first, then people you follow (unseen first).
class StoriesNotifier extends AsyncNotifier<List<StoryGroup>> {
  @override
  Future<List<StoryGroup>> build() async {
    final me = ref.watch(currentUserIdProvider);
    if (me == null) return [];
    final following = await ref.watch(followingProvider.future);
    final repo = ref.read(repositoryProvider);
    final groups = await repo.storyGroups([me, ...following]);

    final ids = [
      for (final g in groups)
        for (final s in g.slides) s.id,
    ];
    final viewed = await repo.viewedStoryIds(ids);
    ref.read(seenStoriesProvider.notifier).addAll(viewed);
    return groups;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> add({
    required XFile file,
    required bool video,
    required List<StoryOverlay> overlays,
    required int durationMs,
    String? location,
    Music? music,
    Audience audience = Audience.public,
  }) async {
    await ref
        .read(repositoryProvider)
        .createStory(
          file: file,
          video: video,
          overlays: overlays,
          durationMs: durationMs,
          location: location,
          music: music,
          audience: audience,
        );
    await refresh();
  }

  Future<void> setAudience(String storyId, Audience audience) async {
    await ref.read(repositoryProvider).setStoryAudience(storyId, audience);
    await refresh();
  }

  Future<void> delete(String storyId) async {
    await ref.read(repositoryProvider).deleteStory(storyId);
    await refresh();
  }
}

final storiesProvider =
    AsyncNotifierProvider<StoriesNotifier, List<StoryGroup>>(
      StoriesNotifier.new,
    );

/// Your own story group (null when you have no active story).
final myStoryProvider = Provider<StoryGroup?>((ref) {
  final groups = ref.watch(storiesProvider).valueOrNull ?? const [];
  for (final g in groups) {
    if (g.isMine) return g;
  }
  return null;
});

/// Active story group of any account (for avatar rings on profiles/posts).
final storyOfUserProvider = Provider.family<StoryGroup?, String>((ref, id) {
  final groups = ref.watch(storiesProvider).valueOrNull ?? const [];
  for (final g in groups) {
    if (g.key == id) return g;
  }
  return null;
});

bool groupSeen(StoryGroup group, Set<String> seen) =>
    group.slides.every((s) => seen.contains(s.id));

/// What the stories row shows after "Your story": people you follow with
/// unseen stories, then seen ones, then the sample channels.
final storyRowProvider = Provider<List<StoryGroup>>((ref) {
  final seen = ref.watch(seenStoriesProvider);
  final real = (ref.watch(storiesProvider).valueOrNull ?? const [])
      .where((g) => !g.isMine)
      .toList();
  final unseen = real.where((g) => !groupSeen(g, seen)).toList();
  final watched = real.where((g) => groupSeen(g, seen)).toList();
  final samples = sampleStoryGroups();
  final sampleUnseen = samples.where((g) => !groupSeen(g, seen));
  final sampleSeen = samples.where((g) => groupSeen(g, seen));
  return [...unseen, ...watched, ...sampleUnseen, ...sampleSeen];
});
