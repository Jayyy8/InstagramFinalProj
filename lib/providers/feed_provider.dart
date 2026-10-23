import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";

import "../data/sample_feed.dart";
import "../models/feed_models.dart";
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

/// Real posts for the home feed: you and the people you follow.
class HomeFeedNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return [];
    final following = await ref.watch(followingProvider.future);
    final repo = ref.read(repositoryProvider);
    return _cacheIds(ref, repo.homeFeed(following));
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
    ...samples,
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

final explorePostIdsProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => _cacheIds(ref, ref.watch(repositoryProvider).explorePosts()),
);

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
  }) async {
    final post = await _repo.createPost(
      photos: photos,
      caption: caption,
      location: location,
    );
    _ref.read(homeFeedProvider.notifier).prepend(post);
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
