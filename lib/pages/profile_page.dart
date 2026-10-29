import "package:flutter/cupertino.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/feed_models.dart";
import "../models/social_models.dart";
import "../navigation.dart";
import "../providers/feed_provider.dart";
import "../providers/notes_provider.dart";
import "../providers/social_providers.dart";
import "../providers/story_provider.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "../widgets/follow_button.dart";
import "../widgets/gradient_avatar.dart";
import "../widgets/post_grid.dart";
import "../widgets/sub_page.dart";
import "chat_page.dart";
import "discover_people_page.dart";
import "edit_profile_page.dart";
import "follow_list_page.dart";
import "note_sheets.dart";
import "share_profile_page.dart";
import "story_create_page.dart";
import "story_viewer_page.dart";

/// Someone's profile, pushed from a post, search or a chat.
class ProfilePage extends ConsumerWidget {
  final String userId;
  final Profile? initial;

  const ProfilePage({super.key, required this.userId, this.initial});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider(userId)).valueOrNull ?? initial;
    return SubPage(
      title: profile?.username ?? "",
      actions: [
        barAction(
          context,
          AppIcons.more,
          label: "More",
          onPressed: () => showActionSheet(
            context,
            title: profile?.username,
            actions: [
              SheetAction(
                label: "Copy profile URL",
                icon: CupertinoIcons.link,
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: "instagram-replica://u/${profile?.username}",
                    ),
                  );
                  showToast(context, "Link copied");
                },
              ),
            ],
          ),
        ),
      ],
      child: ProfileView(userId: userId, initial: initial),
    );
  }
}

/// Header, buttons and posts grid. Used by the Profile tab and [ProfilePage].
class ProfileView extends ConsumerStatefulWidget {
  final String userId;
  final Profile? initial;

  const ProfileView({super.key, required this.userId, this.initial});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  int _tab = 0;

  Future<void> _refresh() async {
    ref.invalidate(profileProvider(widget.userId));
    ref.invalidate(profileStatsProvider(widget.userId));
    ref.invalidate(userPostIdsProvider(widget.userId));
    ref.invalidate(userRepostIdsProvider(widget.userId));
    if (widget.userId == ref.read(currentUserIdProvider)) {
      ref.invalidate(myProfileProvider);
    }
    await ref.read(userPostIdsProvider(widget.userId).future);
  }

  void _toggleFollow(Profile profile, bool following) {
    Future<void> run() => ref
        .read(followingProvider.notifier)
        .toggle(profile.id)
        .catchError((Object e) {
          if (mounted) showToast(context, errorText(e), error: true);
        });

    if (!following) {
      run();
      return;
    }
    showActionSheet(
      context,
      title: profile.username,
      actions: [SheetAction(label: "Unfollow", destructive: true, onTap: run)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final me = ref.watch(currentUserIdProvider);
    final isMe = widget.userId == me;

    final Profile? profile = isMe
        ? ref.watch(myProfileProvider).valueOrNull
        : (ref.watch(profileProvider(widget.userId)).valueOrNull ??
              widget.initial);
    final stats = ref.watch(profileStatsProvider(widget.userId)).valueOrNull;
    final postIds =
        ref.watch(userPostIdsProvider(widget.userId)).valueOrNull ?? const [];
    final posts = postsFor(ref, postIds);
    final story = ref.watch(storyOfUserProvider(widget.userId));
    final seen = ref.watch(seenStoriesProvider);
    final following = (ref.watch(followingProvider).valueOrNull ?? const {})
        .contains(widget.userId);

    Note? note;
    final notes = ref.watch(notesProvider).valueOrNull;
    if (isMe) {
      note = notes?.mine;
    } else {
      for (final n in notes?.others ?? const <Note>[]) {
        if (n.profile?.id == widget.userId) note = n;
      }
    }

    if (profile == null) {
      return const Center(child: CupertinoActivityIndicator());
    }

    Widget stat(String value, String label, VoidCallback? onTap) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
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
        ),
      );
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar with story ring; the note bubble sits above its
              // top-right edge, its dots trailing down onto the avatar.
              SizedBox(
                width: 96,
                height: 146,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () {
                          if (story != null) {
                            pushFullscreen(
                              context,
                              StoryViewerPage(groups: [story]),
                            );
                          } else if (isMe) {
                            pushFullscreen(context, const StoryCreatePage());
                          }
                        },
                        child: GradientAvatar(
                          name: profile.username,
                          imageUrls: profile.avatarUrls,
                          size: 88,
                          ring: story != null,
                          seen: story != null && groupSeen(story, seen),
                          showPlus: isMe,
                          onPlus: isMe
                              ? () => pushFullscreen(
                                  context,
                                  const StoryCreatePage(),
                                )
                              : null,
                        ),
                      ),
                    ),
                    if (note != null || isMe)
                      Positioned(
                        left: 50,
                        top: 0,
                        child: GestureDetector(
                          onTap: () {
                            if (isMe) {
                              showNoteComposer(context);
                            } else {
                              showNoteViewer(context, note!);
                            }
                          },
                          child: NoteBubble(
                            text: note?.body ?? "Ask friends anything...",
                            placeholder: note == null,
                            maxWidth: 110,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          stat(
                            formatCount(stats?.posts ?? posts.length),
                            "posts",
                            null,
                          ),
                          stat(
                            compactCount(stats?.followers ?? 0),
                            "followers",
                            () => push(
                              context,
                              FollowListPage(
                                user: profile,
                                showFollowers: true,
                              ),
                            ),
                          ),
                          stat(
                            compactCount(stats?.following ?? 0),
                            "following",
                            () => push(
                              context,
                              FollowListPage(
                                user: profile,
                                showFollowers: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (profile.bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              profile.bio,
              style: TextStyle(fontSize: 14, color: colors.text),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (isMe) ...[
                Expanded(
                  child: IgButton(
                    label: "Edit profile",
                    expand: true,
                    onTap: () => push(context, const EditProfilePage()),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: IgButton(
                    label: "Share profile",
                    expand: true,
                    onTap: () => pushFullscreen(
                      context,
                      ShareProfilePage(profile: profile),
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: FollowButton(
                    following: following,
                    expand: true,
                    onTap: () => _toggleFollow(profile, following),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: IgButton(
                    label: "Message",
                    expand: true,
                    onTap: () => push(context, ChatPage(partner: profile)),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              IgButton(
                label: "",
                icon: CupertinoIcons.person_add,
                onTap: () => push(context, const DiscoverPeoplePage()),
              ),
            ],
          ),
          if (isMe) _CompleteProfile(profile: profile, posts: posts.length),
          const SizedBox(height: 8),
        ],
      ),
    );

    final tabs = Row(
      children: [
        for (final (i, icon) in [
          (0, CupertinoIcons.square_grid_3x2),
          (1, CupertinoIcons.play_rectangle),
          (2, CupertinoIcons.arrow_2_squarepath),
          (3, CupertinoIcons.person_crop_square),
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

    Widget empty(IconData icon, String title, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.text, width: 2),
            ),
            child: Icon(icon, size: 34, color: colors.text),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
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
    );

    Widget content;
    if (_tab == 0) {
      content = posts.isEmpty
          ? empty(
              CupertinoIcons.camera,
              isMe ? "Share photos" : "No posts yet",
              isMe
                  ? "When you share photos, they will appear on your profile."
                  : "When ${profile.username} shares photos, you'll see them here.",
            )
          : PostGrid(posts: posts, scrollable: false);
    } else if (_tab == 1) {
      // Reels tab: this account's video posts, in tall tiles.
      final reels = posts.where((p) => p.isVideo).toList();
      content = reels.isEmpty
          ? empty(
              CupertinoIcons.play_rectangle,
              isMe ? "Share a moment with the world" : "No reels yet",
              isMe
                  ? "Post a video and it will appear here and in Reels."
                  : "Reels ${profile.username} shares will appear here.",
            )
          : PostGrid(posts: reels, scrollable: false, aspectRatio: 9 / 16);
    } else if (_tab == 2) {
      // Reposts: posts (yours, friends' or sample channels') this account
      // reposted, newest first.
      final ids =
          ref.watch(userRepostIdsProvider(profile.id)).valueOrNull ??
          const <String>[];
      final reposts = [for (final id in ids) ?ref.watch(postProvider(id))];
      content = reposts.isEmpty
          ? empty(
              CupertinoIcons.arrow_2_squarepath,
              isMe ? "Share what you love" : "No reposts yet",
              isMe
                  ? "Posts you repost will appear here, and in your followers' feeds."
                  : "Posts ${profile.username} reposts will appear here.",
            )
          : PostGrid(posts: reposts, scrollable: false, aspectRatio: 3 / 4);
    } else {
      content = empty(
        CupertinoIcons.person_crop_square,
        isMe ? "Photos and videos of you" : "No photos",
        isMe
            ? "When people tag you in photos and videos, they'll appear here."
            : "Photos ${profile.username} is tagged in will appear here.",
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _refresh),
        SliverToBoxAdapter(child: header),
        SliverToBoxAdapter(child: tabs),
        SliverToBoxAdapter(child: content),
        SliverToBoxAdapter(child: SizedBox(height: bottomBarInset(context))),
      ],
    );
  }
}

/// "Complete your profile" cards (only while something is missing).
class _CompleteProfile extends ConsumerWidget {
  final Profile profile;
  final int posts;

  const _CompleteProfile({required this.profile, required this.posts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final following = ref.watch(followingProvider).valueOrNull?.length ?? 0;

    final steps = [
      (
        CupertinoIcons.person_crop_circle,
        "Add profile photo",
        "Choose a profile photo to represent yourself.",
        profile.avatarUrl != null,
        "Add photo",
        () => push(context, const EditProfilePage()),
      ),
      (
        CupertinoIcons.chat_bubble,
        "Add a bio",
        "Tell your followers a little bit about yourself.",
        profile.bio.isNotEmpty,
        "Add bio",
        () => push(context, const EditProfilePage()),
      ),
      (
        CupertinoIcons.person_2,
        "Find people to follow",
        "Follow 5 or more accounts.",
        following >= 5,
        "Find more",
        () => push(context, const DiscoverPeoplePage()),
      ),
    ];
    final done = steps.where((s) => s.$4).length;
    if (done == steps.length) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Complete your profile",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: colors.text,
            ),
          ),
          Text(
            "$done of ${steps.length} complete",
            style: TextStyle(fontSize: 13, color: colors.secondaryText),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (icon, title, text, complete, action, onTap)
                    in steps)
                  Container(
                    width: 170,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.separator),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: colors.text),
                              ),
                              child: Icon(icon, color: colors.text),
                            ),
                            if (complete)
                              const Positioned(
                                right: -4,
                                bottom: -4,
                                child: Icon(
                                  CupertinoIcons.checkmark_circle_fill,
                                  color: kCloseFriendsGreen,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(
                            text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.secondaryText,
                            ),
                          ),
                        ),
                        IgButton(
                          label: complete ? "Edit" : action,
                          primary: !complete,
                          onTap: onTap,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
