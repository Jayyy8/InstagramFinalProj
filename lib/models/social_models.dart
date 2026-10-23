/// Data that lives in Supabase: profiles, stories, notes and messages.
library;

DateTime _date(Object? value) =>
    DateTime.tryParse(value?.toString() ?? "")?.toLocal() ?? DateTime.now();

DateTime? _dateOrNull(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

class Profile {
  final String id;
  final String username;
  final String fullName;
  final String bio;
  final String? avatarUrl;
  final bool isPrivate;
  final DateTime? lastActiveAt;

  const Profile({
    required this.id,
    required this.username,
    this.fullName = "",
    this.bio = "",
    this.avatarUrl,
    this.isPrivate = false,
    this.lastActiveAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
    id: map["id"] as String,
    username: (map["username"] ?? "") as String,
    fullName: (map["full_name"] ?? "") as String,
    bio: (map["bio"] ?? "") as String,
    avatarUrl: map["avatar_url"] as String?,
    isPrivate: (map["is_private"] ?? false) as bool,
    lastActiveAt: _dateOrNull(map["last_active_at"]),
  );

  /// Name shown under the avatar: full name, or the username.
  String get displayName => fullName.trim().isEmpty ? username : fullName;

  List<String>? get avatarUrls => avatarUrl == null ? null : [avatarUrl!];

  Profile copyWith({
    String? username,
    String? fullName,
    String? bio,
    String? avatarUrl,
    bool? isPrivate,
  }) {
    return Profile(
      id: id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isPrivate: isPrivate ?? this.isPrivate,
      lastActiveAt: lastActiveAt,
    );
  }
}

/// Text placed on top of a story photo or video.
/// [x] and [y] are fractions of the screen (0..1) for the text center.
class StoryOverlay {
  final String text;
  final int color;
  final double x;
  final double y;
  final double size;

  const StoryOverlay({
    required this.text,
    this.color = 0xFFFFFFFF,
    this.x = 0.5,
    this.y = 0.45,
    this.size = 28,
  });

  factory StoryOverlay.fromMap(Map<String, dynamic> map) => StoryOverlay(
    text: (map["text"] ?? "") as String,
    color: (map["color"] as num?)?.toInt() ?? 0xFFFFFFFF,
    x: (map["x"] as num?)?.toDouble() ?? 0.5,
    y: (map["y"] as num?)?.toDouble() ?? 0.45,
    size: (map["size"] as num?)?.toDouble() ?? 28,
  );

  Map<String, dynamic> toMap() => {
    "text": text,
    "color": color,
    "x": x,
    "y": y,
    "size": size,
  };

  StoryOverlay copyWith({String? text, int? color, double? x, double? y}) {
    return StoryOverlay(
      text: text ?? this.text,
      color: color ?? this.color,
      x: x ?? this.x,
      y: y ?? this.y,
      size: size,
    );
  }
}

/// One photo or video inside a story.
class StorySlide {
  final String id;

  /// Photo URLs tried in order (sample stories have fallbacks).
  final List<String> imageUrls;
  final String? videoUrl;
  final List<StoryOverlay> overlays;
  final int durationMs;
  final DateTime createdAt;

  /// True when the slide is stored in Supabase (it can be viewed, liked,
  /// replied to and deleted for real).
  final bool remote;

  const StorySlide({
    required this.id,
    required this.createdAt,
    this.imageUrls = const [],
    this.videoUrl,
    this.overlays = const [],
    this.durationMs = 5000,
    this.remote = false,
  });

  bool get isVideo => videoUrl != null;

  /// URL used for thumbnails and story replies.
  String? get previewUrl => imageUrls.isNotEmpty ? imageUrls.first : videoUrl;

  factory StorySlide.fromMap(Map<String, dynamic> map) {
    final type = map["media_type"] as String? ?? "image";
    final url = map["media_url"] as String;
    final overlays = (map["overlays"] as List?) ?? const [];
    return StorySlide(
      id: map["id"] as String,
      imageUrls: type == "image" ? [url] : const [],
      videoUrl: type == "video" ? url : null,
      overlays: [
        for (final o in overlays)
          StoryOverlay.fromMap(Map<String, dynamic>.from(o as Map)),
      ],
      durationMs: (map["duration_ms"] as num?)?.toInt() ?? 5000,
      createdAt: _date(map["created_at"]),
      remote: true,
    );
  }
}

/// All active stories of one account, shown as one bubble in the stories row.
class StoryGroup {
  /// Profile id for real accounts, topic id for sample channels.
  final String key;
  final String username;
  final List<String>? avatarUrls;
  final bool verified;
  final Profile? profile;
  final List<StorySlide> slides;
  final bool isMine;

  const StoryGroup({
    required this.key,
    required this.username,
    required this.slides,
    this.avatarUrls,
    this.verified = false,
    this.profile,
    this.isMine = false,
  });

  bool get remote => profile != null;
}

/// A short status shown above the avatar in the inbox (Notes / My Day).
class Note {
  final String id;
  final String body;
  final DateTime createdAt;
  final String username;
  final List<String>? avatarUrls;
  final Profile? profile;
  final bool likedByMe;
  final int likeCount;

  const Note({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.username,
    this.avatarUrls,
    this.profile,
    this.likedByMe = false,
    this.likeCount = 0,
  });

  bool get remote => profile != null;

  Note copyWith({bool? likedByMe, int? likeCount}) {
    return Note(
      id: id,
      body: body,
      createdAt: createdAt,
      username: username,
      avatarUrls: avatarUrls,
      profile: profile,
      likedByMe: likedByMe ?? this.likedByMe,
      likeCount: likeCount ?? this.likeCount,
    );
  }
}

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String body;
  final String? mediaUrl;
  final String? contextType;
  final String? contextText;
  final String? contextMediaUrl;
  final DateTime createdAt;
  final DateTime? readAt;

  /// True while the message is still being sent.
  final bool pending;

  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.body,
    required this.createdAt,
    this.mediaUrl,
    this.contextType,
    this.contextText,
    this.contextMediaUrl,
    this.readAt,
    this.pending = false,
  });

  factory Message.fromMap(Map<String, dynamic> map) => Message(
    id: map["id"] as String,
    senderId: map["sender_id"] as String,
    receiverId: map["receiver_id"] as String,
    body: (map["body"] ?? "") as String,
    mediaUrl: map["media_url"] as String?,
    contextType: map["context_type"] as String?,
    contextText: map["context_text"] as String?,
    contextMediaUrl: map["context_media_url"] as String?,
    createdAt: _date(map["created_at"]),
    readAt: _dateOrNull(map["read_at"]),
  );

  /// Short text for the inbox row.
  String preview({required bool mine}) {
    if (contextType == "story_reply") {
      return mine ? "You replied to their story" : "Replied to your story";
    }
    if (contextType == "note_reply") {
      return mine ? "You replied to their note" : "Replied to your note";
    }
    if (contextType == "post_share") {
      return mine ? "You sent a post" : "Sent a post";
    }
    if (body.isEmpty && mediaUrl != null) {
      return mine ? "You sent a photo" : "Sent a photo";
    }
    return mine ? "You: $body" : body;
  }
}

class Conversation {
  final Profile partner;
  final Message last;
  final int unread;

  const Conversation({
    required this.partner,
    required this.last,
    this.unread = 0,
  });
}

/// One row in the Activity (heart) page.
class ActivityItem {
  final Profile actor;
  final String kind; // "follow", "like", "comment"
  final String? text;
  final String? postImage;
  final String? postId;
  final DateTime createdAt;

  const ActivityItem({
    required this.actor,
    required this.kind,
    required this.createdAt,
    this.text,
    this.postImage,
    this.postId,
  });
}
