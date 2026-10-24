/// Extras chosen on the "New post" details page (Poll, Prompt, Tag people,
/// Add link). Stored as jsonb columns on posts (schema.sql, Update 5).
library;

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
