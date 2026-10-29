import "audience.dart";
import "post_extras.dart";
import "social_models.dart";

enum FeedCategory { nba, football, news, docs }

extension FeedCategoryX on FeedCategory {
  String get label {
    switch (this) {
      case FeedCategory.nba:
        return "NBA";
      case FeedCategory.football:
        return "Football";
      case FeedCategory.news:
        return "News";
      case FeedCategory.docs:
        return "Docs";
    }
  }
}

/// 12840 -> "12,840"
String formatCount(int n) {
  final s = n.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(",");
    buffer.write(s[i]);
  }
  return buffer.toString();
}

/// 71500 -> "71.5K", 1200000 -> "1.2M" (like the counts under a post).
String compactCount(int n) {
  String trim(double v) {
    final s = v.toStringAsFixed(1);
    return s.endsWith(".0") ? s.substring(0, s.length - 2) : s;
  }

  if (n >= 1000000) return "${trim(n / 1000000)}M";
  if (n >= 10000) return "${trim(n / 1000)}K";
  return formatCount(n);
}

/// "name@email.com" -> "name", long IDs -> first 8 characters.
String shortName(String full) {
  if (full.contains("@")) return full.split("@").first;
  return full.length > 8 ? full.substring(0, 8) : full;
}

/// "Just now", "5 minutes ago", "2 hours ago", "3 days ago", "Mar 4".
String timeAgoLong(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return "Just now";
  if (diff.inMinutes < 60) {
    return "${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago";
  }
  if (diff.inHours < 24) {
    return "${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago";
  }
  if (diff.inDays < 7) {
    return "${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago";
  }
  const months = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];
  return "${months[date.month - 1]} ${date.day}";
}

/// "now", "5m", "2h", "3d", "4w" (inbox and comments).
String timeAgoShort(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return "now";
  if (diff.inMinutes < 60) return "${diff.inMinutes}m";
  if (diff.inHours < 24) return "${diff.inHours}h";
  if (diff.inDays < 7) return "${diff.inDays}d";
  return "${diff.inDays ~/ 7}w";
}

/// "Active now", "Active 7h ago", "Active yesterday".
String activeStatus(DateTime? lastActive) {
  if (lastActive == null) return "";
  final diff = DateTime.now().difference(lastActive);
  if (diff.inMinutes < 5) return "Active now";
  if (diff.inHours < 1) return "Active ${diff.inMinutes}m ago";
  if (diff.inHours < 24) return "Active ${diff.inHours}h ago";
  if (diff.inDays < 2) return "Active yesterday";
  return "Active ${diff.inDays}d ago";
}

/// A news / sports / documentary account that "posts" in the sample feed.
class FeedChannel {
  final String handle;
  final bool verified;

  const FeedChannel(this.handle, {this.verified = true});
}

class FeedComment {
  final String? id;

  /// Username of the writer. null = the logged-in user (sample posts).
  final String? author;
  final String? authorId;
  final List<String>? avatarUrls;
  final String text;
  final DateTime? createdAt;

  const FeedComment({
    this.id,
    this.author,
    this.authorId,
    this.avatarUrls,
    required this.text,
    this.createdAt,
  });
}

class FeedPost {
  final String id;
  final FeedCategory? category;

  /// Sample channel that "posted" this (null for real posts).
  final FeedChannel? channel;

  /// Real account that posted this (null for sample posts).
  final Profile? author;

  /// One entry per photo. Sample posts may list backup URLs per photo:
  /// see [photos].
  final List<String> imageUrls;

  /// Sample posts keep one list of fallback URLs for a single photo.
  final bool fallbackUrls;
  final String caption;
  final String location;
  final String? timeAgoText;
  final DateTime? createdAt;
  final int baseLikes;
  final bool liked;
  final bool saved;
  final List<FeedComment> comments;
  final int commentCount;

  /// Reposts by other people (yours is kept by the reposts provider).
  final int baseReposts;

  /// The post is one video ([imageUrls] holds its URL).
  final bool isVideo;

  /// Who can see the post.
  final Audience audience;

  /// Sample posts that only appear on the channel's profile grid.
  final bool showInFeed;

  // ───── Chosen on the "New post" details page ─────
  final Music? music;

  /// The song sticker on the first photo / the video.
  final MusicSticker musicSticker;

  /// Texts on the photos / video, and each photo's size and the video's look.
  final List<PostText> texts;
  final PostEdits? edits;
  final Poll? poll;

  /// Votes per poll option, and the option you picked (null = no vote).
  final List<int> pollVotes;
  final int? myVote;

  /// "Prompt" sticker: a question others answer in the comments.
  final String? prompt;
  final List<PostTag> tags;
  final PostLink? link;

  /// "AI info" label (made or edited with AI).
  final bool aiLabel;

  /// Like and view counts hidden from others.
  final bool hideLikes;
  final bool commentsOff;

  /// Posted only to the profile grid, not to followers' feeds.
  final bool profileOnly;

  const FeedPost({
    required this.id,
    required this.imageUrls,
    required this.caption,
    required this.location,
    required this.baseLikes,
    this.category,
    this.channel,
    this.author,
    this.fallbackUrls = false,
    this.timeAgoText,
    this.createdAt,
    this.liked = false,
    this.saved = false,
    this.comments = const [],
    this.commentCount = 0,
    this.baseReposts = 0,
    this.isVideo = false,
    this.audience = Audience.public,
    this.showInFeed = true,
    this.music,
    this.musicSticker = const MusicSticker(hidden: true),
    this.texts = const [],
    this.edits,
    this.poll,
    this.pollVotes = const [],
    this.myVote,
    this.prompt,
    this.tags = const [],
    this.link,
    this.aiLabel = false,
    this.hideLikes = false,
    this.commentsOff = false,
    this.profileOnly = false,
  });

  bool get remote => author != null;
  String get authorName => author?.username ?? channel?.handle ?? "you";
  bool get verified => channel?.verified ?? author?.verified ?? false;
  List<String>? get authorAvatar => author?.avatarUrls;
  int get likes => baseLikes + (liked ? 1 : 0);
  int get totalComments => remote ? commentCount : comments.length;
  String get timeAgo =>
      timeAgoText ?? (createdAt == null ? "" : timeAgoLong(createdAt!));

  /// Each photo as a list of URLs to try in order.
  List<List<String>> get photos => fallbackUrls
      ? [imageUrls]
      : [
          for (final url in imageUrls) [url],
        ];

  /// The first photo, for grids and thumbnails.
  List<String> get cover => photos.isEmpty ? const [] : photos.first;

  FeedPost copyWith({
    Audience? audience,
    bool? liked,
    bool? saved,
    int? baseLikes,
    List<FeedComment>? comments,
    int? commentCount,
    List<int>? pollVotes,
    int? Function()? myVote,
  }) {
    return FeedPost(
      id: id,
      category: category,
      channel: channel,
      author: author,
      imageUrls: imageUrls,
      fallbackUrls: fallbackUrls,
      caption: caption,
      location: location,
      timeAgoText: timeAgoText,
      createdAt: createdAt,
      baseLikes: baseLikes ?? this.baseLikes,
      liked: liked ?? this.liked,
      saved: saved ?? this.saved,
      comments: comments ?? this.comments,
      commentCount: commentCount ?? this.commentCount,
      baseReposts: baseReposts,
      isVideo: isVideo,
      audience: audience ?? this.audience,
      showInFeed: showInFeed,
      music: music,
      musicSticker: musicSticker,
      texts: texts,
      edits: edits,
      poll: poll,
      pollVotes: pollVotes ?? this.pollVotes,
      myVote: myVote != null ? myVote() : this.myVote,
      prompt: prompt,
      tags: tags,
      link: link,
      aiLabel: aiLabel,
      hideLikes: hideLikes,
      commentsOff: commentsOff,
      profileOnly: profileOnly,
    );
  }
}

class StoryTopic {
  final String id;
  final String label;
  final FeedCategory category;
  final FeedChannel channel;

  /// One entry per story photo; each entry is a list of fallback URLs.
  final List<List<String>> photos;

  /// Song played over the stories (title, artist, preview URL, artwork).
  final List<String>? song;

  /// Where the song's sticker sits on these stories.
  final MusicSticker sticker;

  StoryTopic({
    required this.id,
    required this.label,
    required this.category,
    required this.channel,
    required this.photos,
    this.song,
    this.sticker = const MusicSticker(),
  });
}

/// A sample note from one of the sample channels.
class SampleNote {
  final String id;
  final String handle;
  final List<String> avatar;
  final String text;
  final Duration age;

  const SampleNote({
    required this.id,
    required this.handle,
    required this.avatar,
    required this.text,
    required this.age,
  });
}
