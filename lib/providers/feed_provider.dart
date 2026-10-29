import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";

import "../data/sample_feed.dart";
import "../models/audience.dart";
import "../models/feed_models.dart";
import "../models/post_extras.dart";
import "../models/social_models.dart";
import "../services/social_repository.dart";
import "social_providers.dart";
import "supabase_providers.dart";

/// The logged-in user's email, or their ID if there is no email.
final authorProvider = Provider<String>((ref) {
  ref.watch(authStateProvider); // recompute when someone signs in or out
  final user = ref.watch(supabaseProvider).auth.currentUser;
  final email = user?.email;
  if (email != null && email.isNotEmpty) return email;
  return user?.id ?? "unknown";
});

// ─────────────────────────── Sample posts ───────────────────────────

/// Posts from the sample channels (NBA, football, news, docs). They are
/// kept on the phone only: likes, saves and comments are not uploaded.
class SamplePostsNotifier extends Notifier<List<FeedPost>> {
  @override
  List<FeedPost> build() {
    ref.watch(currentUserIdProvider); // fresh copy for each account
    return buildSamplePosts();
  }

  void update(String id, FeedPost Function(FeedPost) change) {
    state = [
      for (final p in state)
        if (p.id == id) change(p) else p,
    ];
  }

  void hide(String id) {
    state = state.where((p) => p.id != id).toList();
  }
}

final samplePostsProvider =
    NotifierProvider<SamplePostsNotifier, List<FeedPost>>(
      SamplePostsNotifier.new,
    );

// ─────────────────────────── Real posts ───────────────────────────

/// Every real post loaded anywhere in the app, by id. Lists (feed, profile
/// grids, explore) keep ids only, so a like shows up everywhere at once.
class PostCacheNotifier extends Notifier<Map<String, FeedPost>> {
  @override
  Map<String, FeedPost> build() {
    ref.watch(currentUserIdProvider);
    return {};
  }

  void upsertAll(Iterable<FeedPost> posts) {
    state = {...state, for (final p in posts) p.id: p};
  }

  void update(String id, FeedPost Function(FeedPost) change) {
    final post = state[id];
    if (post == null) return;
    state = {...state, id: change(post)};
  }

  void remove(String id) {
    state = {...state}..remove(id);
  }
}

final postCacheProvider =
    NotifierProvider<PostCacheNotifier, Map<String, FeedPost>>(
      PostCacheNotifier.new,
    );

/// Loads posts, stores them in the cache and returns their ids.
Future<List<String>> _cacheIds(Ref ref, Future<List<FeedPost>> load) async {
  final posts = await load;
  ref.read(postCacheProvider.notifier).upsertAll(posts);
  return [for (final p in posts) p.id];
}

/// Who reposted a post that is in your feed only because of that repost.
class FeedRepostersNotifier extends Notifier<Map<String, Profile>> {
  @override
  Map<String, Profile> build() => const {};

  void set(Map<String, Profile> reposters) => state = reposters;
}

final feedRepostersProvider =
    NotifierProvider<FeedRepostersNotifier, Map<String, Profile>>(
      FeedRepostersNotifier.new,
    );

/// Real posts for the home feed: you and the people you follow, plus what
/// they reposted ("username reposted"), newest first.
class HomeFeedNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return [];
    final following = await ref.watch(followingProvider.future);
    final repo = ref.read(repositoryProvider);
    final posts = await repo.homeFeed(following);

    // Reposts need Update 6 of schema.sql; without it the feed is as before.
    final reposts = await repo
        .followingReposts(following)
        .catchError((_) => <(String, Profile, DateTime)>[]);
    final have = {for (final p in posts) p.id};
    final reposters = <String, Profile>{};
    final when = <String, DateTime>{};
    for (final (postId, who, at) in reposts) {
      if (have.contains(postId) || reposters.containsKey(postId)) continue;
      reposters[postId] = who;
      when[postId] = at;
    }
    final reposted = await repo
        .postsByIds(reposters.keys)
        .catchError((_) => <FeedPost>[]);
    reposters.removeWhere((id, _) => !reposted.any((p) => p.id == id));

    final all = [...posts, ...reposted];
    DateTime time(FeedPost p) =>
        when[p.id] ?? p.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    all.sort((a, b) => time(b).compareTo(time(a)));
    ref.read(feedRepostersProvider.notifier).set(reposters);
    return _cacheIds(ref, Future.value(all));
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  void prepend(FeedPost post) {
    ref.read(postCacheProvider.notifier).upsertAll([post]);
    final ids = state.valueOrNull ?? [];
    state = AsyncData([post.id, ...ids.where((id) => id != post.id)]);
  }

  void removeId(String id) {
    final ids = state.valueOrNull;
    if (ids != null) state = AsyncData(ids.where((i) => i != id).toList());
  }
}

final homeFeedProvider = AsyncNotifierProvider<HomeFeedNotifier, List<String>>(
  HomeFeedNotifier.new,
);

/// The full feed: real posts first, then the sample channels.
final feedProvider = Provider<List<FeedPost>>((ref) {
  final ids = ref.watch(homeFeedProvider).valueOrNull ?? const [];
  final cache = ref.watch(postCacheProvider);
  final samples = ref.watch(samplePostsProvider);
  return [
    for (final id in ids)
      if (cache[id] != null) cache[id]!,
    ...samples.where((p) => p.showInFeed),
  ];
});

/// Reels header: "Reels" (for you) or "Friends".
enum ReelsMode { forYou, friends }

class ReelsModeNotifier extends Notifier<ReelsMode> {
  @override
  ReelsMode build() => ReelsMode.forYou;

  void set(ReelsMode mode) => state = mode;
}

final reelsModeProvider = NotifierProvider<ReelsModeNotifier, ReelsMode>(
  ReelsModeNotifier.new,
);

/// Topics picked in the Reels filter (empty = everything).
class ReelTopicsNotifier extends Notifier<Set<FeedCategory>> {
  @override
  Set<FeedCategory> build() => {};

  void toggle(FeedCategory c) {
    final next = {...state};
    if (!next.remove(c)) next.add(c);
    state = next;
  }

  void clear() => state = {};
}

final reelTopicsProvider =
    NotifierProvider<ReelTopicsNotifier, Set<FeedCategory>>(
      ReelTopicsNotifier.new,
    );

/// Reels: videos only. "Friends" shows videos of people you follow;
/// "Reels" (for you) adds other public videos and the sample channels'
/// reels, filtered by the topics you picked.
final reelsProvider = Provider<List<FeedPost>>((ref) {
  final mode = ref.watch(reelsModeProvider);
  final topics = ref.watch(reelTopicsProvider);
  final cache = ref.watch(postCacheProvider);
  final following = ref.watch(homeFeedProvider).valueOrNull ?? const [];
  final friends = [
    for (final id in following)
      if (cache[id] != null && cache[id]!.isVideo) cache[id]!,
  ];
  if (mode == ReelsMode.friends) return friends;

  final seen = {for (final p in friends) p.id};
  final explore = ref.watch(explorePostIdsProvider).valueOrNull ?? const [];
  final others = [
    for (final id in explore)
      if (cache[id] != null && cache[id]!.isVideo && !seen.contains(id))
        cache[id]!,
  ];
  final samples = ref
      .watch(samplePostsProvider)
      .where(
        (p) =>
            p.isVideo &&
            (topics.isEmpty ||
                (p.category != null && topics.contains(p.category))),
      );
  return [...friends, ...others, ...samples];
});

/// Posts of a sample channel, for its profile grid.
final channelPostsProvider = Provider.family<List<FeedPost>, String>((
  ref,
  handle,
) {
  return [
    for (final p in ref.watch(samplePostsProvider))
      if (p.channel?.handle == handle) p,
  ];
});

/// True until the first load of the feed finishes (shows the skeleton).
final feedLoadingProvider = Provider<bool>((ref) {
  final feed = ref.watch(homeFeedProvider);
  return feed.isLoading && !feed.hasValue;
});

final userPostIdsProvider = FutureProvider.autoDispose
    .family<List<String>, String>(
      (ref, userId) =>
          _cacheIds(ref, ref.watch(repositoryProvider).userPosts(userId)),
    );

final explorePostIdsProvider = FutureProvider<List<String>>(
  (ref) => _cacheIds(ref, ref.watch(repositoryProvider).explorePosts()),
);

/// Posts (real or sample) you reposted; the repost button toggles them.
class MyRepostsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return {};
    // Without Update 6 of schema.sql nothing is reposted yet.
    return ref
        .read(repositoryProvider)
        .myRepostIds()
        .catchError((_) => <String>{});
  }

  Future<void> toggle(String postId) async {
    final now = state.valueOrNull ?? <String>{};
    final on = !now.contains(postId);
    state = AsyncData(on ? {...now, postId} : ({...now}..remove(postId)));
    try {
      await ref.read(repositoryProvider).setRepost(postId, on);
      final me = ref.read(currentUserIdProvider);
      if (me != null) ref.invalidate(userRepostIdsProvider(me));
    } catch (_) {
      state = AsyncData(now);
      rethrow;
    }
  }
}

final myRepostsProvider = AsyncNotifierProvider<MyRepostsNotifier, Set<String>>(
  MyRepostsNotifier.new,
);

/// An account's reposts for its profile tab: real ones are loaded into the
/// cache, sample ones come from the sample feed (see [postProvider]).
final userRepostIdsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, userId) async {
      final repo = ref.watch(repositoryProvider);
      final ids = await repo.repostIds(userId);
      final posts = await repo.postsByIds(ids);
      ref.read(postCacheProvider.notifier).upsertAll(posts);
      return ids;
    });

final savedPostIdsProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => _cacheIds(ref, ref.watch(repositoryProvider).savedPosts()),
);

final likedPostIdsProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => _cacheIds(ref, ref.watch(repositoryProvider).likedPosts()),
);

/// A post by id, real or sample.
final postProvider = Provider.family<FeedPost?, String>((ref, id) {
  final cached = ref.watch(postCacheProvider)[id];
  if (cached != null) return cached;
  for (final p in ref.watch(samplePostsProvider)) {
    if (p.id == id) return p;
  }
  return null;
});

/// Turns ids into posts, skipping any that were deleted.
List<FeedPost> postsFor(WidgetRef ref, List<String> ids) {
  final cache = ref.watch(postCacheProvider);
  return [
    for (final id in ids)
      if (cache[id] != null) cache[id]!,
  ];
}

// ─────────────────────────── Post actions ───────────────────────────

/// Like, save, comment, delete: real posts go to Supabase (the screen
/// updates first, then the change is saved), sample posts stay local.
class PostActions {
  final Ref _ref;

  PostActions(this._ref);

  SocialRepository get _repo => _ref.read(repositoryProvider);

  void _change(FeedPost post, FeedPost Function(FeedPost) change) {
    if (post.remote) {
      _ref.read(postCacheProvider.notifier).update(post.id, change);
    } else {
      _ref.read(samplePostsProvider.notifier).update(post.id, change);
    }
  }

  FeedPost? _current(FeedPost post) => _ref.read(postProvider(post.id));

  Future<void> toggleLike(FeedPost post) async {
    final now = _current(post) ?? post;
    final like = !now.liked;
    _change(now, (p) => p.copyWith(liked: like));
    if (!now.remote) return;
    try {
      await _repo.setLike(now.id, like);
    } catch (_) {
      _change(now, (p) => p.copyWith(liked: !like));
      rethrow;
    }
  }

  Future<void> like(FeedPost post) async {
    final now = _current(post) ?? post;
    if (!now.liked) await toggleLike(now);
  }

  Future<void> toggleSave(FeedPost post) async {
    final now = _current(post) ?? post;
    final save = !now.saved;
    _change(now, (p) => p.copyWith(saved: save));
    if (!now.remote) return;
    try {
      await _repo.setSaved(now.id, save);
      _ref.invalidate(savedPostIdsProvider);
    } catch (_) {
      _change(now, (p) => p.copyWith(saved: !save));
      rethrow;
    }
  }

  /// Sample posts only: real comments go through [commentsProvider].
  void addLocalComment(FeedPost post, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _change(
      post,
      (p) => p.copyWith(
        comments: [
          ...p.comments,
          FeedComment(text: t, createdAt: DateTime.now()),
        ],
      ),
    );
  }

  /// Votes on a poll; tapping your own answer again takes the vote back.
  Future<void> vote(FeedPost post, int option) async {
    final now = _current(post) ?? post;
    final before = now.myVote;
    final next = before == option ? null : option;
    List<int> counts(FeedPost p) {
      final c = p.pollVotes.isEmpty ? List.filled(4, 0) : List.of(p.pollVotes);
      if (before != null) c[before] = (c[before] - 1).clamp(0, 1 << 30);
      if (next != null) c[next]++;
      return c;
    }

    _change(now, (p) => p.copyWith(pollVotes: counts(p), myVote: () => next));
    if (!now.remote) return;
    try {
      await _repo.votePoll(now.id, next);
    } catch (_) {
      _change(
        now,
        (p) => p.copyWith(pollVotes: now.pollVotes, myVote: () => before),
      );
      rethrow;
    }
  }

  /// Changes who can see one of your posts.
  Future<void> setAudience(FeedPost post, Audience audience) async {
    final before = post.audience;
    _change(post, (p) => p.copyWith(audience: audience));
    try {
      await _repo.setPostAudience(post.id, audience);
    } catch (_) {
      _change(post, (p) => p.copyWith(audience: before));
      rethrow;
    }
  }

  void hide(FeedPost post) {
    if (post.remote) {
      _ref.read(homeFeedProvider.notifier).removeId(post.id);
    } else {
      _ref.read(samplePostsProvider.notifier).hide(post.id);
    }
  }

  Future<void> delete(FeedPost post) async {
    await _repo.deletePost(post.id);
    _ref.read(homeFeedProvider.notifier).removeId(post.id);
    _ref.read(postCacheProvider.notifier).remove(post.id);
    _ref.invalidate(userPostIdsProvider(post.author!.id));
    _ref.invalidate(profileStatsProvider(post.author!.id));
  }

  Future<FeedPost> create({
    required List<XFile> photos,
    required String caption,
    required String location,
    XFile? video,
    Audience audience = Audience.public,
    Music? music,
    MusicSticker? musicSticker,
    List<PostText> texts = const [],
    PostEdits? edits,
    XFile? videoOverlay,
    Poll? poll,
    String? prompt,
    List<PostTag> tags = const [],
    PostLink? link,
    bool aiLabel = false,
    bool hideLikes = false,
    bool commentsOff = false,
    bool profileOnly = false,
  }) async {
    final post = await _repo.createPost(
      photos: photos,
      caption: caption,
      location: location,
      video: video,
      audience: audience,
      music: music,
      musicSticker: musicSticker,
      texts: texts,
      edits: edits,
      videoOverlay: videoOverlay,
      poll: poll,
      prompt: prompt,
      tags: tags,
      link: link,
      aiLabel: aiLabel,
      hideLikes: hideLikes,
      commentsOff: commentsOff,
      profileOnly: profileOnly,
    );
    if (!post.profileOnly) {
      _ref.read(homeFeedProvider.notifier).prepend(post);
    }
    _ref.invalidate(userPostIdsProvider(post.author!.id));
    _ref.invalidate(profileStatsProvider(post.author!.id));
    return post;
  }
}

final postActionsProvider = Provider<PostActions>((ref) => PostActions(ref));

/// Comments of a real post.
class CommentsNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<FeedComment>, String> {
  @override
  Future<List<FeedComment>> build(String postId) =>
      ref.read(repositoryProvider).comments(postId);

  Future<void> add(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await ref.read(repositoryProvider).addComment(arg, t);
    ref
        .read(postCacheProvider.notifier)
        .update(arg, (p) => p.copyWith(commentCount: p.commentCount + 1));
    ref.invalidateSelf();
    await future;
  }

  Future<void> delete(String commentId) async {
    await ref.read(repositoryProvider).deleteComment(commentId);
    ref
        .read(postCacheProvider.notifier)
        .update(
          arg,
          (p) => p.copyWith(
            commentCount: p.commentCount > 0 ? p.commentCount - 1 : 0,
          ),
        );
    ref.invalidateSelf();
  }
}

final commentsProvider = AsyncNotifierProvider.autoDispose
    .family<CommentsNotifier, List<FeedComment>, String>(CommentsNotifier.new);

// ─────────────────────────── Sample channels ───────────────────────────

/// Sample channels the user follows (by handle). Kept on the phone.
class FollowNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(currentUserIdProvider);
    return {};
  }

  void toggle(String handle) {
    final next = {...state};
    if (!next.remove(handle)) next.add(handle);
    state = next;
  }
}

final followedChannelsProvider = NotifierProvider<FollowNotifier, Set<String>>(
  FollowNotifier.new,
);
