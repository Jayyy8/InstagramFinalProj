import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";

import "../models/audience.dart";
import "../models/social_models.dart";
import "../services/social_repository.dart";
import "supabase_providers.dart";

final repositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(ref.watch(supabaseProvider)),
);

/// The signed-in user's id (null when signed out).
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseProvider).auth.currentUser?.id;
});

// ─────────────────────────── Your profile ───────────────────────────

class MyProfileNotifier extends AsyncNotifier<Profile?> {
  SocialRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<Profile?> build() async {
    final id = ref.watch(currentUserIdProvider);
    if (id == null) return null;
    final profile = await _repo.myProfile();
    unawaited(_repo.touchLastActive().catchError((_) {}));
    return profile;
  }

  Future<void> save({
    required String username,
    required String fullName,
    required String bio,
  }) async {
    final updated = await _repo.updateProfile(
      username: username,
      fullName: fullName,
      bio: bio,
    );
    state = AsyncData(updated);
    ref.invalidate(profileProvider(updated.id));
  }

  Future<void> setAvatar(XFile photo) async {
    final url = await _repo.upload("avatars", photo);
    final updated = await _repo.updateProfile(avatarUrl: url);
    state = AsyncData(updated);
    ref.invalidate(profileProvider(updated.id));
  }

  Future<void> setPrivate(bool value) async {
    final updated = await _repo.updateProfile(isPrivate: value);
    state = AsyncData(updated);
  }
}

final myProfileProvider = AsyncNotifierProvider<MyProfileNotifier, Profile?>(
  MyProfileNotifier.new,
);

/// Any account by id.
final profileProvider = FutureProvider.autoDispose.family<Profile?, String>(
  (ref, id) => ref.watch(repositoryProvider).profile(id),
);

// ─────────────────────────── Follows ───────────────────────────

/// Ids of the accounts you follow. Follow / unfollow update it right away.
class FollowingNotifier extends AsyncNotifier<Set<String>> {
  SocialRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<Set<String>> build() async {
    final id = ref.watch(currentUserIdProvider);
    if (id == null) return {};
    return _repo.followingIds();
  }

  bool isFollowing(String id) => state.valueOrNull?.contains(id) ?? false;

  Future<void> toggle(String userId) async {
    final current = {...?state.valueOrNull};
    final following = current.contains(userId);
    if (following) {
      current.remove(userId);
    } else {
      current.add(userId);
    }
    state = AsyncData(current);
    try {
      if (following) {
        await _repo.unfollow(userId);
      } else {
        await _repo.follow(userId);
      }
    } catch (e) {
      // Undo on failure.
      ref.invalidateSelf();
      rethrow;
    } finally {
      ref.invalidate(profileStatsProvider(userId));
      final me = ref.read(currentUserIdProvider);
      if (me != null) ref.invalidate(profileStatsProvider(me));
    }
  }
}

final followingProvider = AsyncNotifierProvider<FollowingNotifier, Set<String>>(
  FollowingNotifier.new,
);

final profileStatsProvider = FutureProvider.autoDispose
    .family<({int posts, int followers, int following}), String>(
      (ref, id) => ref.watch(repositoryProvider).stats(id),
    );

final followersListProvider = FutureProvider.autoDispose
    .family<List<Profile>, String>(
      (ref, id) => ref.watch(repositoryProvider).followers(id),
    );

final followingListProvider = FutureProvider.autoDispose
    .family<List<Profile>, String>(
      (ref, id) => ref.watch(repositoryProvider).following(id),
    );

final userSearchProvider = FutureProvider.autoDispose
    .family<List<Profile>, String>((ref, query) async {
      // Wait a moment so we don't query on every keystroke.
      var cancelled = false;
      ref.onDispose(() => cancelled = true);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (cancelled) return [];
      return ref.watch(repositoryProvider).searchProfiles(query);
    });

final suggestedProfilesProvider = FutureProvider.autoDispose<List<Profile>>((
  ref,
) async {
  // Read once: people you follow from this list stay on it as "Following".
  final following = await ref.read(followingProvider.future);
  return ref.watch(repositoryProvider).suggestedProfiles(following);
});

final activityProvider = FutureProvider<List<ActivityItem>>(
  (ref) => ref.watch(repositoryProvider).activity(),
);

/// Time you last opened Notifications.
class ActivitySeenNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    return profile?.activitySeenAt ?? profile?.lastActiveAt;
  }

  void markSeen() {
    state = DateTime.now();
    ref.read(repositoryProvider).markActivitySeen().catchError((_) {});
  }
}

final activitySeenProvider = NotifierProvider<ActivitySeenNotifier, DateTime?>(
  ActivitySeenNotifier.new,
);

/// New likes, comments and followers since you last opened Notifications.
final unseenActivityProvider = Provider<int>((ref) {
  final items = ref.watch(activityProvider).valueOrNull ?? const [];
  final seen = ref.watch(activitySeenProvider);
  if (seen == null) return items.length;
  return items.where((a) => a.createdAt.isAfter(seen)).length;
});

/// Your Close Friends list (ids). Changes save right away.
class CloseFriendsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return {};
    return ref.read(repositoryProvider).closeFriendIds();
  }

  Future<void> toggle(String userId) async {
    final current = {...?state.valueOrNull};
    final add = !current.contains(userId);
    if (add) {
      current.add(userId);
    } else {
      current.remove(userId);
    }
    state = AsyncData(current);
    try {
      await ref.read(repositoryProvider).setCloseFriend(userId, add);
    } catch (_) {
      ref.invalidateSelf();
      rethrow;
    }
  }
}

final closeFriendsProvider =
    AsyncNotifierProvider<CloseFriendsNotifier, Set<String>>(
      CloseFriendsNotifier.new,
    );

/// The audience you picked last, offered first next time.
class LastAudienceNotifier extends Notifier<Audience> {
  @override
  Audience build() {
    ref.watch(currentUserIdProvider);
    return Audience.public;
  }

  void set(Audience audience) => state = audience;
}

final lastAudienceProvider = NotifierProvider<LastAudienceNotifier, Audience>(
  LastAudienceNotifier.new,
);
