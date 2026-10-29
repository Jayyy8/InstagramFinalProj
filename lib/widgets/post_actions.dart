import "package:flutter/cupertino.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/feed_models.dart";
import "../models/social_models.dart";
import "../navigation.dart";
import "../pages/comments_page.dart";
import "../pages/profile_page.dart";
import "../providers/feed_provider.dart";
import "../providers/social_providers.dart";
import "audience_picker.dart";
import "dialogs.dart";
import "share_sheet.dart";

void openComments(BuildContext context, FeedPost post) {
  push(context, CommentsPage(postId: post.id));
}

void openProfile(BuildContext context, Profile profile) {
  push(context, ProfilePage(userId: profile.id, initial: profile));
}

/// Link that identifies a post (copied by "Copy link").
String postLink(FeedPost post) =>
    post.remote ? "instagram-replica://p/${post.id}" : post.cover.first;

Future<void> copyPostLink(BuildContext context, FeedPost post) async {
  await Clipboard.setData(ClipboardData(text: postLink(post)));
  if (context.mounted) showToast(context, "Link copied");
}

/// "Share" sheet: send the post to people you follow, or copy the link.
/// Repost / undo: the post goes on your profile's Reposts tab and in your
/// followers' feeds.
Future<void> toggleRepost(
  BuildContext context,
  WidgetRef ref,
  FeedPost post,
) async {
  final on =
      !(ref.read(myRepostsProvider).valueOrNull?.contains(post.id) ?? false);
  try {
    await ref.read(myRepostsProvider.notifier).toggle(post.id);
    if (context.mounted) {
      showToast(
        context,
        on ? "Reposted to your profile" : "Removed from your reposts",
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    final text = errorText(e);
    showInfo(
      context,
      title: "Couldn't repost",
      message: text.contains("reposts")
          ? "$text\n\nRun Update 6 of supabase/schema.sql in the Supabase SQL "
                "editor to turn on reposts."
          : text,
    );
  }
}

void sharePost(BuildContext context, WidgetRef ref, FeedPost post) =>
    showShareSheet(context, post);

/// The "⋯" menu of a post.
void showPostMenu(BuildContext context, WidgetRef ref, FeedPost post) {
  final me = ref.read(currentUserIdProvider);
  final actions = ref.read(postActionsProvider);
  final mine = post.author?.id == me;
  final following = post.remote
      ? ref.read(followingProvider.notifier).isFollowing(post.author!.id)
      : ref.read(followedChannelsProvider).contains(post.channel?.handle);

  showActionSheet(
    context,
    actions: [
      SheetAction(
        label: post.saved ? "Remove from saved" : "Save",
        icon: post.saved
            ? CupertinoIcons.bookmark_fill
            : CupertinoIcons.bookmark,
        onTap: () => actions.toggleSave(post),
      ),
      SheetAction(
        label: "Copy link",
        icon: CupertinoIcons.link,
        onTap: () => copyPostLink(context, post),
      ),
      if (!mine && following)
        SheetAction(
          label: "Unfollow",
          icon: CupertinoIcons.person_badge_minus,
          onTap: () {
            if (post.remote) {
              ref.read(followingProvider.notifier).toggle(post.author!.id);
            } else {
              ref
                  .read(followedChannelsProvider.notifier)
                  .toggle(post.channel!.handle);
            }
          },
        ),
      if (!mine)
        SheetAction(
          label: "Not interested",
          icon: CupertinoIcons.eye_slash,
          onTap: () => actions.hide(post),
        ),
      if (mine)
        SheetAction(
          label: "Edit audience · ${post.audience.label}",
          icon: post.audience.icon,
          onTap: () async {
            final picked = await showAudiencePicker(
              context,
              current: post.audience,
              title: "Who can see this post?",
            );
            if (picked == null || picked == post.audience) return;
            try {
              await actions.setAudience(post, picked);
              if (context.mounted) {
                showToast(context, "Now shared with ${picked.label}");
              }
            } catch (e) {
              if (context.mounted) {
                showToast(context, errorText(e), error: true);
              }
            }
          },
        ),
      if (mine)
        SheetAction(
          label: "Delete",
          icon: CupertinoIcons.delete,
          destructive: true,
          onTap: () => confirmAction(
            context,
            title: "Delete post?",
            message: "You won't be able to restore this post.",
            confirmLabel: "Delete",
            onConfirm: () async {
              try {
                await actions.delete(post);
              } catch (e) {
                if (context.mounted) {
                  showToast(context, errorText(e), error: true);
                }
              }
            },
          ),
        ),
    ],
  );
}
