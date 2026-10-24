import "package:flutter/cupertino.dart";

/// Who can see a post, story or note. The database enforces it
/// (see can_view in supabase/schema.sql).
enum Audience {
  public("public", "Public", "Anyone on Instagram", CupertinoIcons.globe),
  followers(
    "followers",
    "Followers",
    "People who follow you",
    CupertinoIcons.person_2,
  ),
  friends(
    "friends",
    "Friends",
    "People you follow who follow you back",
    CupertinoIcons.person_2_fill,
  ),
  friendsOfFriends(
    "friends_of_friends",
    "Friends of friends",
    "Your friends and their friends",
    CupertinoIcons.person_3,
  ),
  closeFriends(
    "close_friends",
    "Close Friends",
    "Only people on your Close Friends list",
    CupertinoIcons.star_circle_fill,
  ),
  onlyMe("only_me", "Only me", "Only you can see it", CupertinoIcons.lock_fill);

  /// Value stored in the database.
  final String key;
  final String label;
  final String description;
  final IconData icon;

  const Audience(this.key, this.label, this.description, this.icon);

  static Audience fromKey(Object? key) {
    for (final a in Audience.values) {
      if (a.key == key) return a;
    }
    return Audience.public;
  }
}
