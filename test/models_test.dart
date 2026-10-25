import "package:flutter/painting.dart";
import "package:flutter_test/flutter_test.dart";
import "package:oauth_activity/data/sample_feed.dart";
import "package:oauth_activity/models/audience.dart";
import "package:oauth_activity/models/feed_models.dart";
import "package:oauth_activity/models/post_extras.dart";
import "package:oauth_activity/models/social_models.dart";
import "package:oauth_activity/providers/story_provider.dart";
import "package:oauth_activity/services/photo_editing.dart";

void main() {
  group("number formatting", () {
    test("formatCount adds thousands separators", () {
      expect(formatCount(0), "0");
      expect(formatCount(999), "999");
      expect(formatCount(12840), "12,840");
      expect(formatCount(1234567), "1,234,567");
    });

    test("compactCount matches Instagram's short counts", () {
      expect(compactCount(9999), "9,999");
      expect(compactCount(71500), "71.5K");
      expect(compactCount(293000), "293K");
      expect(compactCount(1200000), "1.2M");
      expect(compactCount(5000000), "5M");
    });
  });

  group("time labels", () {
    test("timeAgoShort", () {
      final now = DateTime.now();
      expect(timeAgoShort(now), "now");
      expect(timeAgoShort(now.subtract(const Duration(minutes: 5))), "5m");
      expect(timeAgoShort(now.subtract(const Duration(hours: 3))), "3h");
      expect(timeAgoShort(now.subtract(const Duration(days: 2))), "2d");
      expect(timeAgoShort(now.subtract(const Duration(days: 15))), "2w");
    });

    test("timeAgoLong uses singular and plural", () {
      final now = DateTime.now();
      expect(timeAgoLong(now), "Just now");
      expect(
        timeAgoLong(now.subtract(const Duration(minutes: 1))),
        "1 minute ago",
      );
      expect(
        timeAgoLong(now.subtract(const Duration(hours: 2))),
        "2 hours ago",
      );
    });

    test("activeStatus", () {
      final now = DateTime.now();
      expect(activeStatus(null), "");
      expect(activeStatus(now), "Active now");
      expect(
        activeStatus(now.subtract(const Duration(hours: 7))),
        "Active 7h ago",
      );
    });
  });

  group("Profile", () {
    test("tolerates missing columns and nulls", () {
      final p = Profile.fromMap({"id": "u1", "username": null});
      expect(p.username, "");
      expect(p.fullName, "");
      expect(p.bio, "");
      expect(p.isPrivate, false);
      expect(p.avatarUrls, isNull);
      expect(p.activitySeenAt, isNull);
    });

    test("displayName falls back to username", () {
      expect(const Profile(id: "1", username: "jay").displayName, "jay");
      expect(
        const Profile(id: "1", username: "jay", fullName: "Jay E").displayName,
        "Jay E",
      );
    });
  });

  group("Music", () {
    test("round-trips through JSON", () {
      const m = Music(
        title: "Song",
        artist: "Artist",
        previewUrl: "https://example.com/a.m4a",
        artworkUrl: "https://example.com/a.jpg",
      );
      final back = Music.fromJson(m.toJson())!;
      expect(back.title, "Song");
      expect(back.artist, "Artist");
      expect(back.previewUrl, m.previewUrl);
      expect(back.artworkUrl, m.artworkUrl);
      expect(back.label, "Song · Artist");
    });

    test("is null without a preview URL", () {
      expect(Music.fromJson(null), isNull);
      expect(Music.fromJson("text"), isNull);
      expect(Music.fromJson({"title": "x"}), isNull);
    });
  });

  group("StorySlide.fromMap", () {
    test("reads a video story with song and location", () {
      final slide = StorySlide.fromMap({
        "id": "s1",
        "media_url": "https://example.com/v.mp4",
        "media_type": "video",
        "overlays": [
          {"text": "hi", "color": 0xFF000000, "x": 0.2, "y": 0.3},
        ],
        "duration_ms": 12000,
        "created_at": "2026-10-24T10:00:00Z",
        "location": "Dumaguete",
        "music": {"title": "T", "artist": "A", "preview_url": "https://p"},
      });
      expect(slide.isVideo, true);
      expect(slide.videoUrl, "https://example.com/v.mp4");
      expect(slide.imageUrls, isEmpty);
      expect(slide.overlays.single.text, "hi");
      expect(slide.overlays.single.x, 0.2);
      expect(slide.durationMs, 12000);
      expect(slide.location, "Dumaguete");
      expect(slide.music?.title, "T");
      expect(slide.remote, true);
    });

    test("reads a photo story from before the music update", () {
      final slide = StorySlide.fromMap({
        "id": "s2",
        "media_url": "https://example.com/p.jpg",
        "created_at": "2026-10-24T10:00:00Z",
      });
      expect(slide.isVideo, false);
      expect(slide.previewUrl, "https://example.com/p.jpg");
      expect(slide.music, isNull);
      expect(slide.location, isNull);
      expect(slide.durationMs, 5000);
    });
  });

  test("StoryOverlay round-trips", () {
    const o = StoryOverlay(text: "Hello", color: 0xFF0095F6, x: 0.3, y: 0.6);
    final back = StoryOverlay.fromMap(o.toMap());
    expect(back.text, "Hello");
    expect(back.color, 0xFF0095F6);
    expect(back.x, 0.3);
    expect(back.y, 0.6);
  });

  group("Message", () {
    Map<String, dynamic> row({Object? deletedFor, String body = "hey"}) => {
      "id": "m1",
      "sender_id": "a",
      "receiver_id": "b",
      "body": body,
      "created_at": "2026-10-24T10:00:00Z",
      "reply_to_id": "m0",
      "deleted_for": deletedFor,
    };

    test("reads replies, reactions and deleted_for", () {
      final m = Message.fromMap(row(deletedFor: ["b"]), reactions: {"b": "❤️"});
      expect(m.replyToId, "m0");
      expect(m.reactions["b"], "❤️");
      expect(m.deletedFor, ["b"]);
      expect(m.readAt, isNull);
    });

    test("works without the new columns", () {
      final m = Message.fromMap({
        "id": "m1",
        "sender_id": "a",
        "receiver_id": "b",
        "body": "hi",
        "created_at": "2026-10-24T10:00:00Z",
      });
      expect(m.replyToId, isNull);
      expect(m.deletedFor, isEmpty);
      expect(m.reactions, isEmpty);
    });

    test("copyWith keeps everything but what changed", () {
      final m = Message.fromMap(row(), reactions: {"a": "😂"});
      final read = m.copyWith(readAt: DateTime(2026));
      expect(read.reactions, {"a": "😂"});
      expect(read.replyToId, "m0");
      final cleared = m.copyWith(reactions: const {});
      expect(cleared.reactions, isEmpty);
    });

    test("snippet and inbox preview", () {
      expect(Message.fromMap(row()).snippet, "hey");
      expect(Message.fromMap(row()).preview(mine: true), "You: hey");
      final photo = Message.fromMap({...row(body: ""), "media_url": "x"});
      expect(photo.snippet, "Photo");
      expect(photo.preview(mine: false), "Sent a photo");
    });
  });

  group("FeedPost", () {
    test("sample posts keep their fallback URLs as one photo", () {
      const p = FeedPost(
        id: "p",
        imageUrls: ["a", "b"],
        fallbackUrls: true,
        caption: "",
        location: "",
        baseLikes: 10,
      );
      expect(p.photos, [
        ["a", "b"],
      ]);
      expect(p.cover, ["a", "b"]);
    });

    test("real posts have one URL per photo", () {
      const p = FeedPost(
        id: "p",
        imageUrls: ["a", "b"],
        caption: "",
        location: "",
        baseLikes: 10,
        liked: true,
      );
      expect(p.photos, [
        ["a"],
        ["b"],
      ]);
      expect(p.likes, 11);
    });

    test("copyWith keeps video and feed flags", () {
      const p = FeedPost(
        id: "v",
        imageUrls: ["v.mp4"],
        caption: "",
        location: "",
        baseLikes: 0,
        isVideo: true,
        showInFeed: false,
      );
      final liked = p.copyWith(liked: true);
      expect(liked.isVideo, true);
      expect(liked.showInFeed, false);
    });
  });

  group("sample content", () {
    final posts = buildSamplePosts();

    test("every channel has a profile, an avatar and posts", () {
      for (final handle in kChannelInfo.keys) {
        expect(channelAvatar(handle), isNotNull, reason: handle);
        expect(
          posts.where((p) => p.channel?.handle == handle).length,
          greaterThan(3),
          reason: handle,
        );
      }
    });

    test("profile-only posts stay out of the feed", () {
      final hidden = posts.where((p) => !p.showInFeed);
      expect(hidden, isNotEmpty);
      expect(
        hidden.every((p) => p.id.startsWith("x_") || p.id.startsWith("r_")),
        true,
      );
    });

    test("sample reels are videos and stay out of the feed", () {
      final reels = posts.where((p) => p.isVideo).toList();
      expect(reels.length, greaterThanOrEqualTo(5));
      for (final r in reels) {
        expect(r.showInFeed, false, reason: r.id);
        expect(r.imageUrls.single, startsWith("https://"), reason: r.id);
        expect(r.imageUrls.single, endsWith(".mp4"), reason: r.id);
      }
    });

    test("post ids are unique", () {
      final ids = posts.map((p) => p.id).toSet();
      expect(ids.length, posts.length);
    });

    test("sample stories and seen state", () {
      final groups = sampleStoryGroups();
      expect(groups.length, kStoryTopics.length);
      final first = groups.first;
      expect(groupSeen(first, {}), false);
      expect(groupSeen(first, {for (final s in first.slides) s.id}), true);
    });
  });

  group("Audience", () {
    test("database keys round-trip and unknown values are public", () {
      for (final a in Audience.values) {
        expect(Audience.fromKey(a.key), a);
      }
      expect(Audience.fromKey(null), Audience.public);
      expect(Audience.fromKey("something_else"), Audience.public);
      expect(Audience.friendsOfFriends.key, "friends_of_friends");
      expect(Audience.onlyMe.key, "only_me");
    });

    test("posts, stories and notes read their audience", () {
      final slide = StorySlide.fromMap({
        "id": "s",
        "media_url": "https://x/p.jpg",
        "created_at": "2026-10-24T10:00:00Z",
        "audience": "close_friends",
      });
      expect(slide.audience, Audience.closeFriends);
      final group = StoryGroup(key: "u", username: "u", slides: [slide]);
      expect(group.closeFriends, true);

      const post = FeedPost(
        id: "p",
        imageUrls: ["a"],
        caption: "",
        location: "",
        baseLikes: 0,
      );
      expect(post.audience, Audience.public);
      expect(
        post.copyWith(audience: Audience.onlyMe).audience,
        Audience.onlyMe,
      );
    });
  });

  group("post editor", () {
    test("Ratio crops the middle of the photo", () {
      expect(
        cropRect(1000, 1000, PostRatio.original),
        const Rect.fromLTWH(0, 0, 1000, 1000),
      );
      // A square photo cropped to 4:5 keeps the full height.
      final portrait = cropRect(1000, 1000, PostRatio.portrait);
      expect(portrait.height, 1000);
      expect(portrait.width, 800);
      expect(portrait.left, 100);
      // A tall photo cropped to 16:9 keeps the full width.
      final wide = cropRect(900, 1600, PostRatio.landscape);
      expect(wide.width, 900);
      expect(wide.height, closeTo(506.25, 0.01));
      expect(PostRatio.landscape.next, PostRatio.original);
    });

    test("an untouched photo has the identity color matrix", () {
      final edit = PhotoEdit();
      expect(edit.changed, isFalse);
      for (int i = 0; i < 20; i++) {
        expect(edit.matrix[i], closeTo(kIdentityMatrix[i], 1e-9));
      }
      edit.filter = PhotoFilter.moon;
      expect(edit.changed, isTrue);
      // Moon is black and white: red, green and blue rows are equal.
      final m = edit.matrix;
      expect(m[0], closeTo(m[5], 1e-9));
      expect(m[1], closeTo(m[11], 1e-9));
    });

    test("poll, tags and link survive a round trip through JSON", () {
      const poll = Poll(question: "Best?", options: ["A", "B", "C"]);
      final back = Poll.fromJson(poll.toJson())!;
      expect(back.question, "Best?");
      expect(back.options, ["A", "B", "C"]);
      expect(
        Poll.fromJson({
          "question": "x",
          "options": ["only one"],
        }),
        isNull,
      );

      final tags = PostTag.listFromJson([
        const PostTag(
          userId: "u1",
          username: "ana",
          photo: 1,
          x: 0.2,
          y: 0.7,
        ).toJson(),
        {"username": "no id"},
      ]);
      expect(tags.length, 1);
      expect(tags.first.username, "ana");
      expect(tags.first.photo, 1);

      const link = PostLink(url: "https://www.example.com/page");
      expect(PostLink.fromJson(link.toJson())!.label, "example.com/page");
    });

    test("story song sticker keeps its place, size and hidden state", () {
      const sticker = MusicSticker(x: 0.3, y: 0.2, scale: 1.5, hidden: true);
      final music = {"title": "T", "sticker": sticker.toJson()};
      final back = MusicSticker.fromJson(music);
      expect(back.x, 0.3);
      expect(back.y, 0.2);
      expect(back.scale, 1.5);
      expect(back.hidden, isTrue);
      // Stories saved before stickers could move: the old default spot.
      final old = MusicSticker.fromJson({"title": "T"});
      expect(old.y, 0.72);
      expect(old.hidden, isFalse);
    });

    test("song length is shown as m:ss", () {
      const m = Music(
        title: "T",
        artist: "A",
        previewUrl: "u",
        durationMs: 201000,
      );
      expect(m.length, "3:21");
      expect(const Music(title: "T", artist: "A", previewUrl: "u").length, "");
    });
  });
}
