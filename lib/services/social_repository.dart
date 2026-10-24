import "dart:typed_data";

import "package:image_picker/image_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../models/feed_models.dart";
import "../models/social_models.dart";

/// Every Supabase read and write the app makes, in one place.
/// Tables and security rules are in supabase/schema.sql.
class SocialRepository {
  final SupabaseClient _db;

  SocialRepository(this._db);

  String get me {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw const AuthException("You are signed out.");
    return id;
  }

  String get _now => DateTime.now().toUtc().toIso8601String();

  // ─────────────────────────── Storage ───────────────────────────

  static String _contentType(String ext) {
    switch (ext) {
      case "png":
        return "image/png";
      case "gif":
        return "image/gif";
      case "webp":
        return "image/webp";
      case "heic":
        return "image/heic";
      case "mp4":
        return "video/mp4";
      case "mov":
        return "video/quicktime";
      case "m4v":
        return "video/x-m4v";
      default:
        return "image/jpeg";
    }
  }

  static bool isVideoFile(XFile file) {
    final mime = file.mimeType ?? "";
    if (mime.startsWith("video/")) return true;
    final ext = file.path.split(".").last.toLowerCase();
    return const {"mp4", "mov", "m4v", "3gp", "webm", "mkv"}.contains(ext);
  }

  /// Uploads a picked file to `<bucket>/<my id>/<time>.<ext>` and returns
  /// its public URL.
  Future<String> upload(String bucket, XFile file) async {
    final Uint8List bytes = await file.readAsBytes();
    var ext = file.path.contains(".")
        ? file.path.split(".").last.toLowerCase()
        : "jpg";
    if (ext.length > 5) ext = "jpg";
    final path = "$me/${DateTime.now().microsecondsSinceEpoch}.$ext";
    await _db.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentType(ext),
            upsert: true,
          ),
        );
    return _db.storage.from(bucket).getPublicUrl(path);
  }

  // ─────────────────────────── Profiles ───────────────────────────

  Future<Profile?> profile(String id) async {
    final row = await _db.from("profiles").select().eq("id", id).maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }

  /// Your profile. Creates it if the database trigger has not.
  Future<Profile> myProfile() async {
    final existing = await profile(me);
    if (existing != null) return existing;
    final email = _db.auth.currentUser?.email ?? me;
    final base = email
        .split("@")
        .first
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9._]"), "");
    final username =
        "${base.length < 3 ? 'user$base' : base}${DateTime.now().millisecond}";
    final row = await _db
        .from("profiles")
        .upsert({"id": me, "username": username})
        .select()
        .single();
    return Profile.fromMap(row);
  }

  Future<Profile> updateProfile({
    String? username,
    String? fullName,
    String? bio,
    String? avatarUrl,
    bool? isPrivate,
  }) async {
    final changes = <String, dynamic>{
      "username": ?username?.trim().toLowerCase(),
      "full_name": ?fullName?.trim(),
      "bio": ?bio?.trim(),
      "avatar_url": ?avatarUrl,
      "is_private": ?isPrivate,
    };
    final row = await _db
        .from("profiles")
        .update(changes)
        .eq("id", me)
        .select()
        .single();
    return Profile.fromMap(row);
  }

  /// Notifications opened: activity before now is no longer "new".
  Future<void> markActivitySeen() async {
    await _db.from("profiles").update({"activity_seen_at": _now}).eq("id", me);
  }

  Future<void> touchLastActive() async {
    await _db.from("profiles").update({"last_active_at": _now}).eq("id", me);
  }

  Future<List<Profile>> searchProfiles(String query) async {
    final q = query.trim().replaceAll(RegExp(r"[,()%]"), "");
    if (q.isEmpty) return [];
    final rows = await _db
        .from("profiles")
        .select()
        .or("username.ilike.%$q%,full_name.ilike.%$q%")
        .neq("id", me)
        .limit(30);
    return [for (final r in rows) Profile.fromMap(r)];
  }

  /// Accounts you don't follow yet, newest first.
  Future<List<Profile>> suggestedProfiles(Set<String> following) async {
    final rows = await _db
        .from("profiles")
        .select()
        .neq("id", me)
        .order("created_at", ascending: false)
        .limit(50);
    return [
      for (final r in rows)
        if (!following.contains(r["id"])) Profile.fromMap(r),
    ];
  }

  /// Profiles by id. Fetched separately (instead of embedded) so queries
  /// work whatever table the foreign keys point to.
  Future<Map<String, Profile>> _profiles(Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return {};
    final rows = await _db.from("profiles").select().inFilter("id", unique);
    return {for (final r in rows) r["id"] as String: Profile.fromMap(r)};
  }

  Future<List<Profile>> _orderedProfiles(List<String> ids) async {
    final byId = await _profiles(ids);
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  // ─────────────────────────── Follows ───────────────────────────

  Future<Set<String>> followingIds([String? userId]) async {
    final rows = await _db
        .from("follows")
        .select("following_id")
        .eq("follower_id", userId ?? me);
    return {for (final r in rows) r["following_id"] as String};
  }

  Future<void> follow(String userId) async {
    await _db
        .from("follows")
        .upsert(
          {"follower_id": me, "following_id": userId},
          onConflict: "follower_id,following_id",
          ignoreDuplicates: true,
        );
  }

  Future<void> unfollow(String userId) async {
    await _db
        .from("follows")
        .delete()
        .eq("follower_id", me)
        .eq("following_id", userId);
  }

  Future<({int posts, int followers, int following})> stats(String id) async {
    final results = await Future.wait([
      _db.from("posts").count().eq("user_id", id),
      _db.from("follows").count().eq("following_id", id),
      _db.from("follows").count().eq("follower_id", id),
    ]);
    return (posts: results[0], followers: results[1], following: results[2]);
  }

  Future<List<Profile>> followers(String id) async {
    final rows = await _db
        .from("follows")
        .select("follower_id")
        .eq("following_id", id)
        .order("created_at", ascending: false);
    return _orderedProfiles([for (final r in rows) r["follower_id"] as String]);
  }

  Future<List<Profile>> following(String id) async {
    final rows = await _db
        .from("follows")
        .select("following_id")
        .eq("follower_id", id)
        .order("created_at", ascending: false);
    return _orderedProfiles([
      for (final r in rows) r["following_id"] as String,
    ]);
  }

  // ─────────────────────────── Posts ───────────────────────────

  static const _postColumns = "*";

  static List<String> _imageUrls(Map<String, dynamic> r) {
    final many = r["image_urls"] as List?;
    if (many != null && many.isNotEmpty) return List<String>.from(many);
    final one = r["image_url"] as String?;
    return one == null ? const [] : [one];
  }

  Future<List<FeedPost>> _toPosts(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    final ids = [for (final r in rows) r["id"] as String];
    final myId = me;

    final results = await Future.wait([
      _db.from("likes").select("post_id, user_id").inFilter("post_id", ids),
      _db.from("comments").select("post_id").inFilter("post_id", ids),
      // saved_posts is created by schema.sql; until then nothing is saved.
      _db
          .from("saved_posts")
          .select("post_id")
          .eq("user_id", myId)
          .inFilter("post_id", ids)
          .then((v) => v, onError: (_) => <Map<String, dynamic>>[]),
    ]);
    final authors = await _profiles([
      for (final r in rows) r["user_id"] as String,
    ]);

    final likeCount = <String, int>{};
    final likedByMe = <String>{};
    for (final l in results[0]) {
      final id = l["post_id"] as String;
      likeCount[id] = (likeCount[id] ?? 0) + 1;
      if (l["user_id"] == myId) likedByMe.add(id);
    }
    final commentCount = <String, int>{};
    for (final c in results[1]) {
      final id = c["post_id"] as String;
      commentCount[id] = (commentCount[id] ?? 0) + 1;
    }
    final saved = {for (final r in results[2]) r["post_id"] as String};

    return [
      for (final r in rows)
        if (authors[r["user_id"]] != null && _imageUrls(r).isNotEmpty)
          () {
            final id = r["id"] as String;
            final liked = likedByMe.contains(id);
            return FeedPost(
              id: id,
              author: authors[r["user_id"]],
              imageUrls: _imageUrls(r),
              caption: (r["caption"] ?? "") as String,
              location: (r["location"] ?? "") as String,
              createdAt: DateTime.tryParse(
                r["created_at"] as String,
              )?.toLocal(),
              baseLikes: (likeCount[id] ?? 0) - (liked ? 1 : 0),
              liked: liked,
              saved: saved.contains(id),
              commentCount: commentCount[id] ?? 0,
              isVideo: r["media_type"] == "video",
            );
          }(),
    ];
  }

  /// Posts from you and the people you follow, newest first.
  Future<List<FeedPost>> homeFeed(Set<String> following) async {
    final rows = await _db
        .from("posts")
        .select(_postColumns)
        .inFilter("user_id", [me, ...following])
        .order("created_at", ascending: false)
        .limit(60);
    return _toPosts(rows);
  }

  Future<List<FeedPost>> userPosts(String userId) async {
    final rows = await _db
        .from("posts")
        .select(_postColumns)
        .eq("user_id", userId)
        .order("created_at", ascending: false);
    return _toPosts(rows);
  }

  /// Newest posts from everyone (search / explore grid).
  Future<List<FeedPost>> explorePosts() async {
    final rows = await _db
        .from("posts")
        .select(_postColumns)
        .order("created_at", ascending: false)
        .limit(60);
    return _toPosts(rows);
  }

  Future<List<FeedPost>> savedPosts() async {
    final rows = await _db
        .from("saved_posts")
        .select("post_id")
        .eq("user_id", me)
        .order("created_at", ascending: false);
    final ids = [for (final r in rows) r["post_id"] as String];
    if (ids.isEmpty) return [];
    final posts = await _db
        .from("posts")
        .select(_postColumns)
        .inFilter("id", ids);
    final list = await _toPosts(posts);
    list.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
    return list;
  }

  Future<List<FeedPost>> likedPosts() async {
    final rows = await _db
        .from("likes")
        .select("post_id")
        .eq("user_id", me)
        .order("created_at", ascending: false)
        .limit(60);
    final ids = [for (final r in rows) r["post_id"] as String];
    if (ids.isEmpty) return [];
    final posts = await _db
        .from("posts")
        .select(_postColumns)
        .inFilter("id", ids);
    final list = await _toPosts(posts);
    list.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
    return list;
  }

  /// [photos] are uploaded in order. A post with [video] has that one
  /// video instead of photos.
  Future<FeedPost> createPost({
    required List<XFile> photos,
    required String caption,
    required String location,
    XFile? video,
  }) async {
    final urls = <String>[];
    if (video != null) {
      urls.add(await upload("posts", video));
    } else {
      for (final photo in photos) {
        urls.add(await upload("posts", photo));
      }
    }
    final row = await _db
        .from("posts")
        .insert({
          "user_id": me,
          "caption": caption.trim(),
          "location": location.trim(),
          "image_url": urls.first,
          "image_urls": urls,
          if (video != null) "media_type": "video",
        })
        .select(_postColumns)
        .single();
    return (await _toPosts([row])).first;
  }

  Future<void> deletePost(String id) async {
    await _db.from("posts").delete().eq("id", id).eq("user_id", me);
  }

  Future<void> setLike(String postId, bool like) async {
    if (like) {
      await _db
          .from("likes")
          .upsert(
            {"post_id": postId, "user_id": me},
            onConflict: "post_id,user_id",
            ignoreDuplicates: true,
          );
    } else {
      await _db.from("likes").delete().eq("post_id", postId).eq("user_id", me);
    }
  }

  Future<void> setSaved(String postId, bool save) async {
    if (save) {
      await _db.from("saved_posts").upsert({
        "post_id": postId,
        "user_id": me,
      }, ignoreDuplicates: true);
    } else {
      await _db
          .from("saved_posts")
          .delete()
          .eq("post_id", postId)
          .eq("user_id", me);
    }
  }

  Future<List<FeedComment>> comments(String postId) async {
    final rows = await _db
        .from("comments")
        .select()
        .eq("post_id", postId)
        .order("created_at");
    final authors = await _profiles([
      for (final r in rows) r["user_id"] as String,
    ]);
    return [
      for (final r in rows)
        FeedComment(
          id: r["id"] as String,
          author: authors[r["user_id"]]?.username ?? "",
          authorId: r["user_id"] as String,
          avatarUrls: authors[r["user_id"]]?.avatarUrls,
          text: (r["body"] ?? "") as String,
          createdAt: DateTime.tryParse(r["created_at"] as String)?.toLocal(),
        ),
    ];
  }

  Future<void> addComment(String postId, String text) async {
    await _db.from("comments").insert({
      "post_id": postId,
      "user_id": me,
      "body": text.trim(),
    });
  }

  Future<void> deleteComment(String id) async {
    await _db.from("comments").delete().eq("id", id);
  }

  // ─────────────────────────── Stories ───────────────────────────

  /// Active stories of [userIds], grouped per account in the order given.
  Future<List<StoryGroup>> storyGroups(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final rows = await _db
        .from("stories")
        .select()
        .inFilter("user_id", userIds)
        .gt("expires_at", _now)
        .order("created_at");
    final authors = await _profiles([
      for (final r in rows) r["user_id"] as String,
    ]);

    final byUser = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      byUser.putIfAbsent(r["user_id"] as String, () => []).add(r);
    }
    final myId = me;
    return [
      for (final id in userIds)
        if (byUser[id] != null && authors[id] != null)
          () {
            final author = authors[id]!;
            return StoryGroup(
              key: id,
              username: author.username,
              avatarUrls: author.avatarUrls,
              profile: author,
              isMine: id == myId,
              slides: [for (final r in byUser[id]!) StorySlide.fromMap(r)],
            );
          }(),
    ];
  }

  /// All of your stories, including expired ones (Archive).
  Future<List<StorySlide>> storyArchive() async {
    final rows = await _db
        .from("stories")
        .select()
        .eq("user_id", me)
        .order("created_at", ascending: false);
    return [for (final r in rows) StorySlide.fromMap(r)];
  }

  Future<Set<String>> viewedStoryIds(List<String> storyIds) async {
    if (storyIds.isEmpty) return {};
    final rows = await _db
        .from("story_views")
        .select("story_id")
        .eq("viewer_id", me)
        .inFilter("story_id", storyIds);
    return {for (final r in rows) r["story_id"] as String};
  }

  Future<void> createStory({
    required XFile file,
    required bool video,
    required List<StoryOverlay> overlays,
    required int durationMs,
    String? location,
    Music? music,
  }) async {
    final url = await upload("stories", file);
    await _db.from("stories").insert({
      "user_id": me,
      "media_url": url,
      "media_type": video ? "video" : "image",
      "overlays": [for (final o in overlays) o.toMap()],
      "duration_ms": durationMs,
      "location": ?location,
      "music": ?music?.toJson(),
    });
  }

  Future<void> deleteStory(String id) async {
    await _db.from("stories").delete().eq("id", id).eq("user_id", me);
  }

  Future<void> markStoryViewed(String storyId) async {
    await _db.from("story_views").upsert({
      "story_id": storyId,
      "viewer_id": me,
    }, ignoreDuplicates: true);
  }

  Future<List<({Profile viewer, bool liked})>> storyViewers(
    String storyId,
  ) async {
    final results = await Future.wait([
      _db
          .from("story_views")
          .select("viewer_id")
          .eq("story_id", storyId)
          .neq("viewer_id", me)
          .order("viewed_at", ascending: false),
      _db.from("story_likes").select("user_id").eq("story_id", storyId),
    ]);
    final liked = {for (final r in results[1]) r["user_id"] as String};
    final viewers = await _orderedProfiles([
      for (final r in results[0]) r["viewer_id"] as String,
    ]);
    return [for (final v in viewers) (viewer: v, liked: liked.contains(v.id))];
  }

  Future<bool> storyLikedByMe(String storyId) async {
    final row = await _db
        .from("story_likes")
        .select("story_id")
        .eq("story_id", storyId)
        .eq("user_id", me)
        .maybeSingle();
    return row != null;
  }

  Future<void> setStoryLike(String storyId, bool like) async {
    if (like) {
      await _db.from("story_likes").upsert({
        "story_id": storyId,
        "user_id": me,
      }, ignoreDuplicates: true);
    } else {
      await _db
          .from("story_likes")
          .delete()
          .eq("story_id", storyId)
          .eq("user_id", me);
    }
  }

  // ─────────────────────────── Notes ───────────────────────────

  Future<List<Note>> notes(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final rows = await _db
        .from("notes")
        .select()
        .inFilter("user_id", userIds)
        .gt("expires_at", _now)
        .order("created_at", ascending: false);
    if (rows.isEmpty) return [];
    final ids = [for (final r in rows) r["id"] as String];
    final authors = await _profiles([
      for (final r in rows) r["user_id"] as String,
    ]);
    // note_likes is created by schema.sql; until then notes have no likes.
    final likes = await _db
        .from("note_likes")
        .select("note_id, user_id")
        .inFilter("note_id", ids)
        .then((v) => v, onError: (_) => <Map<String, dynamic>>[]);
    final myId = me;

    final seen = <String>{};
    return [
      for (final r in rows)
        // One note per person: the newest.
        if (authors[r["user_id"]] != null && seen.add(r["user_id"] as String))
          () {
            final author = authors[r["user_id"]]!;
            final mine = likes.where((l) => l["note_id"] == r["id"]);
            return Note(
              id: r["id"] as String,
              body: (r["content"] ?? "") as String,
              createdAt:
                  DateTime.tryParse(r["created_at"] as String)?.toLocal() ??
                  DateTime.now(),
              username: author.username,
              avatarUrls: author.avatarUrls,
              profile: author,
              likedByMe: mine.any((l) => l["user_id"] == myId),
              likeCount: mine.length,
              location: r["location"] as String?,
              music: Music.fromJson(r["music"]),
            );
          }(),
    ];
  }

  /// Replaces your note (likes on the old one are removed with it).
  Future<void> setNote(String text, {String? location, Music? music}) async {
    // A note with only a song shows the song as its text.
    var content = text.trim();
    if (content.isEmpty && music != null) content = "♫ ${music.label}";
    if (content.length > 60) content = content.substring(0, 60);
    await _db.from("notes").delete().eq("user_id", me);
    await _db.from("notes").insert({
      "user_id": me,
      "content": content,
      "location": ?location,
      "music": ?music?.toJson(),
      "expires_at": DateTime.now()
          .add(const Duration(hours: 24))
          .toUtc()
          .toIso8601String(),
    });
  }

  Future<void> deleteNote() async {
    await _db.from("notes").delete().eq("user_id", me);
  }

  Future<void> setNoteLike(String noteId, bool like) async {
    if (like) {
      await _db.from("note_likes").upsert({
        "note_id": noteId,
        "user_id": me,
      }, ignoreDuplicates: true);
    } else {
      await _db
          .from("note_likes")
          .delete()
          .eq("note_id", noteId)
          .eq("user_id", me);
    }
  }

  // ─────────────────────────── Messages ───────────────────────────

  Future<List<Conversation>> conversations() async {
    final myId = me;
    final rows = await _db
        .from("messages")
        .select()
        .or("sender_id.eq.$myId,receiver_id.eq.$myId")
        .order("created_at", ascending: false)
        .limit(500);

    final last = <String, Message>{};
    final unread = <String, int>{};
    for (final r in rows) {
      if ((r["deleted_for"] as List?)?.contains(myId) ?? false) continue;
      final m = Message.fromMap(r);
      final partner = m.senderId == myId ? m.receiverId : m.senderId;
      last.putIfAbsent(partner, () => m);
      if (m.receiverId == myId && m.readAt == null) {
        unread[partner] = (unread[partner] ?? 0) + 1;
      }
    }
    if (last.isEmpty) return [];

    final profiles = await _db
        .from("profiles")
        .select()
        .inFilter("id", last.keys.toList());
    final byId = {
      for (final p in profiles) p["id"] as String: Profile.fromMap(p),
    };

    return [
      for (final entry in last.entries)
        if (byId[entry.key] != null)
          Conversation(
            partner: byId[entry.key]!,
            last: entry.value,
            unread: unread[entry.key] ?? 0,
          ),
    ];
  }

  Future<List<Message>> messagesWith(String partnerId) async {
    final myId = me;
    final rows = await _db
        .from("messages")
        .select()
        .or(
          "and(sender_id.eq.$myId,receiver_id.eq.$partnerId),"
          "and(sender_id.eq.$partnerId,receiver_id.eq.$myId)",
        )
        .order("created_at")
        .limit(500);
    final reactions = await reactionsFor([
      for (final r in rows) r["id"] as String,
    ]);
    return [
      for (final r in rows)
        if (!((r["deleted_for"] as List?)?.contains(myId) ?? false))
          Message.fromMap(r, reactions: reactions[r["id"]] ?? const {}),
    ];
  }

  /// Reactions per message id: {message id: {user id: emoji}}.
  Future<Map<String, Map<String, String>>> reactionsFor(
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return {};
    try {
      final rows = await _db
          .from("message_reactions")
          .select("message_id, user_id, emoji")
          .inFilter("message_id", messageIds);
      final out = <String, Map<String, String>>{};
      for (final r in rows) {
        out.putIfAbsent(
          r["message_id"] as String,
          () => {},
        )[r["user_id"] as String] = r["emoji"] as String;
      }
      return out;
    } catch (_) {
      // message_reactions is created by schema.sql.
      return {};
    }
  }

  /// Sets your reaction ([emoji] null removes it).
  Future<void> react(String messageId, String? emoji) async {
    if (emoji == null) {
      await _db
          .from("message_reactions")
          .delete()
          .eq("message_id", messageId)
          .eq("user_id", me);
    } else {
      await _db.from("message_reactions").upsert({
        "message_id": messageId,
        "user_id": me,
        "emoji": emoji,
      }, onConflict: "message_id,user_id");
    }
  }

  /// "Delete for you": hides the message for you only.
  Future<void> deleteForMe(Message message) async {
    await _db
        .from("messages")
        .update({
          "deleted_for": [...message.deletedFor, me],
        })
        .eq("id", message.id);
  }

  Future<Message> sendMessage({
    required String to,
    String body = "",
    XFile? photo,
    String? contextType,
    String? contextText,
    String? contextMediaUrl,
    String? replyToId,
  }) async {
    final mediaUrl = photo == null ? null : await upload("chat", photo);
    final row = await _db
        .from("messages")
        .insert({
          "sender_id": me,
          "receiver_id": to,
          "body": body.trim(),
          "media_url": ?mediaUrl,
          "context_type": ?contextType,
          "context_text": ?contextText,
          "context_media_url": ?contextMediaUrl,
          "reply_to_id": ?replyToId,
        })
        .select()
        .single();
    return Message.fromMap(row);
  }

  Future<void> markRead(String partnerId) async {
    await _db
        .from("messages")
        .update({"read_at": _now})
        .eq("sender_id", partnerId)
        .eq("receiver_id", me)
        .isFilter("read_at", null);
  }

  Future<void> unsend(String messageId) async {
    await _db.from("messages").delete().eq("id", messageId).eq("sender_id", me);
  }

  // ─────────────────────────── Activity ───────────────────────────

  Future<List<ActivityItem>> activity() async {
    final myId = me;
    final myPosts = await _db
        .from("posts")
        .select()
        .eq("user_id", myId)
        .order("created_at", ascending: false)
        .limit(100);
    final images = {
      for (final p in myPosts)
        p["id"] as String: _imageUrls(p).isEmpty ? null : _imageUrls(p).first,
    };
    final postIds = images.keys.toList();

    final results = await Future.wait([
      _db
          .from("follows")
          .select("follower_id, created_at")
          .eq("following_id", myId)
          .order("created_at", ascending: false)
          .limit(30),
      if (postIds.isNotEmpty) ...[
        _db
            .from("likes")
            .select("post_id, user_id, created_at")
            .inFilter("post_id", postIds)
            .neq("user_id", myId)
            .order("created_at", ascending: false)
            .limit(30),
        _db
            .from("comments")
            .select("post_id, user_id, body, created_at")
            .inFilter("post_id", postIds)
            .neq("user_id", myId)
            .order("created_at", ascending: false)
            .limit(30),
      ],
    ]);
    final follows = results[0];
    final likes = results.length > 1
        ? results[1]
        : const <Map<String, dynamic>>[];
    final comments = results.length > 2
        ? results[2]
        : const <Map<String, dynamic>>[];

    final people = await _profiles([
      for (final r in follows) r["follower_id"] as String,
      for (final r in likes) r["user_id"] as String,
      for (final r in comments) r["user_id"] as String,
    ]);

    DateTime when(Map r) =>
        DateTime.tryParse(r["created_at"] as String)?.toLocal() ??
        DateTime.now();

    final items = <ActivityItem>[
      for (final r in follows)
        if (people[r["follower_id"]] != null)
          ActivityItem(
            actor: people[r["follower_id"]]!,
            kind: "follow",
            createdAt: when(r),
          ),
      for (final r in likes)
        if (people[r["user_id"]] != null)
          ActivityItem(
            actor: people[r["user_id"]]!,
            kind: "like",
            createdAt: when(r),
            postImage: images[r["post_id"]],
            postId: r["post_id"] as String,
          ),
      for (final r in comments)
        if (people[r["user_id"]] != null)
          ActivityItem(
            actor: people[r["user_id"]]!,
            kind: "comment",
            text: r["body"] as String?,
            createdAt: when(r),
            postImage: images[r["post_id"]],
            postId: r["post_id"] as String,
          ),
    ];
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }
}
