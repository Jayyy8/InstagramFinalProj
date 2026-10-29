/// Extras chosen on the "New post" details page (Poll, Prompt, Tag people,
/// Add link) and in the editor (texts, video looks). Stored as jsonb columns
/// on posts (schema.sql, Updates 5 and 6).
library;

import "social_models.dart";

/// A poll under a post: a question and 2–4 answers.
class Poll {
  final String question;
  final List<String> options;

  const Poll({required this.question, required this.options});

  static Poll? fromJson(Object? value) {
    if (value is! Map) return null;
    final options = [
      for (final o in (value["options"] as List? ?? const [])) "$o",
    ];
    if (options.length < 2) return null;
    return Poll(question: "${value["question"] ?? ""}", options: options);
  }

  Map<String, dynamic> toJson() => {"question": question, "options": options};
}

/// Someone tagged on a photo, at a spot given as fractions of its size.
class PostTag {
  final String userId;
  final String username;

  /// Which photo of the post (0 = first).
  final int photo;
  final double x;
  final double y;

  const PostTag({
    required this.userId,
    required this.username,
    this.photo = 0,
    this.x = 0.5,
    this.y = 0.5,
  });

  static List<PostTag> listFromJson(Object? value) {
    if (value is! List) return const [];
    return [
      for (final t in value)
        if (t is Map && t["user_id"] != null)
          PostTag(
            userId: "${t["user_id"]}",
            username: "${t["username"] ?? ""}",
            photo: (t["photo"] as num?)?.toInt() ?? 0,
            x: (t["x"] as num?)?.toDouble() ?? 0.5,
            y: (t["y"] as num?)?.toDouble() ?? 0.5,
          ),
    ];
  }

  Map<String, dynamic> toJson() => {
    "user_id": userId,
    "username": username,
    "photo": photo,
    "x": x,
    "y": y,
  };
}

/// A link shown under the caption.
class PostLink {
  final String url;
  final String title;

  const PostLink({required this.url, this.title = ""});

  static PostLink? fromJson(Object? value) {
    if (value is! Map || value["url"] == null) return null;
    return PostLink(url: "${value["url"]}", title: "${value["title"] ?? ""}");
  }

  Map<String, dynamic> toJson() => {"url": url, "title": title};

  /// "example.com/page" without the scheme, for display.
  String get label {
    if (title.isNotEmpty) return title;
    return url.replaceFirst(RegExp(r"^https?://(www\.)?"), "");
  }
}

/// A text on one of a post's photos (or its video): the same texts as
/// stories, placed relative to that photo.
class PostText {
  /// Which photo (0 = first, or the video).
  final int photo;
  final StoryOverlay text;

  const PostText({required this.photo, required this.text});

  static List<PostText> listFromJson(Object? value) {
    if (value is! List) return const [];
    return [
      for (final t in value)
        if (t is Map && (t["text"] ?? "").toString().isNotEmpty)
          PostText(
            photo: (t["photo"] as num?)?.toInt() ?? 0,
            text: StoryOverlay.fromMap(Map<String, dynamic>.from(t)),
          ),
    ];
  }

  Map<String, dynamic> toJson() => {...text.toMap(), "photo": photo};
}

/// A video's filter, edits, crop and overlay photo, applied while it plays
/// (a video can't have them drawn into it like a photo).
class VideoLook {
  /// Names of PhotoFilter / Adjustment / PostRatio in photo_editing.dart.
  final String filter;
  final Map<String, double> adjust;
  final String ratio;

  /// A photo placed on the video ("Overlay"), uploaded with the post.
  final String? overlayUrl;
  final double overlayX;
  final double overlayY;
  final double overlayWidth;

  const VideoLook({
    this.filter = "normal",
    this.adjust = const {},
    this.ratio = "original",
    this.overlayUrl,
    this.overlayX = 0.5,
    this.overlayY = 0.5,
    this.overlayWidth = 0.4,
  });

  bool get isPlain =>
      filter == "normal" &&
      adjust.values.every((v) => v == 0) &&
      ratio == "original" &&
      overlayUrl == null;

  static VideoLook? fromJson(Object? value) {
    if (value is! Map) return null;
    final adjust = value["adjust"];
    final overlay = value["overlay"];
    return VideoLook(
      filter: (value["filter"] as String?) ?? "normal",
      adjust: adjust is Map
          ? {
              for (final e in adjust.entries)
                "${e.key}": (e.value as num?)?.toDouble() ?? 0,
            }
          : const {},
      ratio: (value["ratio"] as String?) ?? "original",
      overlayUrl: overlay is Map ? overlay["url"] as String? : null,
      overlayX: overlay is Map
          ? (overlay["x"] as num?)?.toDouble() ?? 0.5
          : 0.5,
      overlayY: overlay is Map
          ? (overlay["y"] as num?)?.toDouble() ?? 0.5
          : 0.5,
      overlayWidth: overlay is Map
          ? (overlay["width"] as num?)?.toDouble() ?? 0.4
          : 0.4,
    );
  }

  Map<String, dynamic> toJson() => {
    "filter": filter,
    "adjust": adjust,
    "ratio": ratio,
    if (overlayUrl != null)
      "overlay": {
        "url": overlayUrl,
        "x": overlayX,
        "y": overlayY,
        "width": overlayWidth,
      },
  };
}

/// Saved with a post: each photo's width / height (so texts and the song
/// sticker land in the same spot when the feed crops the photo) and the
/// video's look.
class PostEdits {
  final List<double> aspects;
  final VideoLook? video;

  const PostEdits({this.aspects = const [], this.video});

  static PostEdits? fromJson(Object? value) {
    if (value is! Map) return null;
    return PostEdits(
      aspects: [
        for (final a in (value["aspects"] as List? ?? const []))
          (a as num).toDouble(),
      ],
      video: VideoLook.fromJson(value["video"]),
    );
  }

  Map<String, dynamic> toJson() => {
    "aspects": aspects,
    "video": ?video?.toJson(),
  };

  /// Width / height of photo [i] (1 when unknown).
  double aspectOf(int i) =>
      i < aspects.length && aspects[i] > 0 ? aspects[i] : 1;
}
