import "../models/feed_models.dart";

// ───────────── Photo helpers ─────────────

/// Photo from Wikimedia Commons, with a Picsum photo as backup.
List<String> _commons(String file, int fallbackId) => [
  "https://commons.wikimedia.org/wiki/Special:FilePath/$file?width=1000",
  "https://picsum.photos/id/$fallbackId/1000/1250",
];

/// Photo from Picsum (very reliable placeholder photos).
List<String> _picsum(int id) => ["https://picsum.photos/id/$id/1000/1250"];

// ───────────── Channels (fictional) ─────────────
// Rename these to whatever you like.

const FeedChannel _hoops = FeedChannel("hoops.daily");
const FeedChannel _match = FeedChannel("matchday.live");
const FeedChannel _news = FeedChannel("worldnews.now");
const FeedChannel _docs = FeedChannel("planet.docs");

// ───────────── Photos per topic ─────────────
// Used by stories and by posts you create. Replace any URL with your own.

final Map<FeedCategory, List<List<String>>> kPhotoPool = {
  FeedCategory.nba: [
    _commons("RoseGardenArenaInterior3.jpg", 1015),
    _commons("GeorgeMikan.jpg", 1018),
    _commons("Basketball_game_at_Camp_Lemonnier_DVIDS164937.jpg", 1035),
  ],
  FeedCategory.football: [
    _commons("Soccer-City-Stadium-at-capacity.jpg", 1016),
    _commons("Jeonju_World_Cup_Stadium_2016.jpg", 1036),
  ],
  FeedCategory.news: [_picsum(1005), _picsum(1027), _picsum(1040)],
  FeedCategory.docs: [
    _picsum(1015),
    _picsum(1018),
    _picsum(1035),
    _picsum(1074),
    _picsum(1020),
    _picsum(1069),
  ],
};

// ───────────── Stories ─────────────

final List<StoryTopic> kStoryTopics = [
  StoryTopic(
    id: "nba",
    label: _hoops.handle,
    category: FeedCategory.nba,
    channel: _hoops,
    photos: kPhotoPool[FeedCategory.nba]!,
  ),
  StoryTopic(
    id: "football",
    label: _match.handle,
    category: FeedCategory.football,
    channel: _match,
    photos: kPhotoPool[FeedCategory.football]!,
  ),
  StoryTopic(
    id: "news",
    label: _news.handle,
    category: FeedCategory.news,
    channel: _news,
    photos: kPhotoPool[FeedCategory.news]!,
  ),
  StoryTopic(
    id: "docs",
    label: _docs.handle,
    category: FeedCategory.docs,
    channel: _docs,
    photos: kPhotoPool[FeedCategory.docs]!,
  ),
];

// ───────────── Posts ─────────────

List<FeedPost> buildSamplePosts() {
  final nba = kPhotoPool[FeedCategory.nba]!;
  final football = kPhotoPool[FeedCategory.football]!;
  final news = kPhotoPool[FeedCategory.news]!;
  final docs = kPhotoPool[FeedCategory.docs]!;

  return [
    FeedPost(
      id: "p1",
      category: FeedCategory.nba,
      channel: _hoops,
      fallbackUrls: true,
      imageUrls: nba[0],
      caption: "Packed house and a loud crowd. Tip-off in ten minutes.",
      location: "Downtown Arena",
      timeAgoText: "2 hours ago",
      baseLikes: 12840,
      comments: const [
        FeedComment(author: "alex.hoops", text: "That atmosphere is unreal."),
        FeedComment(author: "court_vision", text: "Best seats in the house."),
      ],
    ),
    FeedPost(
      id: "p2",
      category: FeedCategory.football,
      channel: _match,
      fallbackUrls: true,
      imageUrls: football[0],
      caption: "Full stadium, flags up. Kickoff is almost here.",
      location: "National Stadium",
      timeAgoText: "3 hours ago",
      baseLikes: 28410,
      comments: const [
        FeedComment(author: "sofia_fc", text: "Can't wait for kickoff!"),
      ],
    ),
    FeedPost(
      id: "p3",
      category: FeedCategory.news,
      channel: _news,
      fallbackUrls: true,
      imageUrls: news[0],
      caption: "Reporters on the ground tonight. Full coverage on air at 9.",
      location: "City Center",
      timeAgoText: "5 hours ago",
      baseLikes: 5230,
    ),
    FeedPost(
      id: "p4",
      category: FeedCategory.docs,
      channel: _docs,
      fallbackUrls: true,
      imageUrls: docs[0],
      caption:
          "First light over the river valley. New episode streaming Friday.",
      location: "River Valley",
      timeAgoText: "7 hours ago",
      baseLikes: 9876,
      comments: const [
        FeedComment(author: "nature_nerd", text: "The colors are unreal."),
      ],
    ),
    FeedPost(
      id: "p5",
      category: FeedCategory.nba,
      channel: _hoops,
      fallbackUrls: true,
      imageUrls: nba[1],
      caption: "Throwback: college basketball at Madison Square Garden.",
      location: "Madison Square Garden",
      timeAgoText: "Yesterday",
      baseLikes: 7420,
    ),
    FeedPost(
      id: "p6",
      category: FeedCategory.football,
      channel: _match,
      fallbackUrls: true,
      imageUrls: football[1],
      caption: "Stadium shot before the match. The pitch looks perfect.",
      location: "World Cup Stadium",
      timeAgoText: "Yesterday",
      baseLikes: 15360,
    ),
    FeedPost(
      id: "p7",
      category: FeedCategory.news,
      channel: _news,
      fallbackUrls: true,
      imageUrls: news[2],
      caption: "Morning light over an old castle. Travel desk picks.",
      location: "Old Town",
      timeAgoText: "2 days ago",
      baseLikes: 3105,
    ),
    FeedPost(
      id: "p8",
      category: FeedCategory.docs,
      channel: _docs,
      fallbackUrls: true,
      imageUrls: docs[1],
      caption: "Above the clouds. The high peaks, filmed over three winters.",
      location: "High Peaks",
      timeAgoText: "2 days ago",
      baseLikes: 11240,
    ),
    FeedPost(
      id: "p9",
      category: FeedCategory.docs,
      channel: _docs,
      fallbackUrls: true,
      imageUrls: docs[3],
      caption: "Big cat country. Wildlife special premieres this weekend.",
      location: "Savanna",
      timeAgoText: "3 days ago",
      baseLikes: 20580,
      comments: const [
        FeedComment(author: "wild_lens", text: "Setting a reminder for this."),
      ],
    ),
  ];
}
// ───────────── Notes ─────────────
// Shown in the inbox after the notes of people you follow.

final List<SampleNote> kSampleNotes = [
  SampleNote(
    id: "note_nba",
    handle: _hoops.handle,
    avatar: kPhotoPool[FeedCategory.nba]![0],
    text: "Game day. Who you got tonight? 🏀",
    age: const Duration(hours: 2),
  ),
  SampleNote(
    id: "note_football",
    handle: _match.handle,
    avatar: kPhotoPool[FeedCategory.football]![0],
    text: "Derby weekend ⚽🔥",
    age: const Duration(hours: 5),
  ),
  SampleNote(
    id: "note_news",
    handle: _news.handle,
    avatar: kPhotoPool[FeedCategory.news]![0],
    text: "Live coverage at 9 PM",
    age: const Duration(hours: 9),
  ),
  SampleNote(
    id: "note_docs",
    handle: _docs.handle,
    avatar: kPhotoPool[FeedCategory.docs]![0],
    text: "New episode Friday 🌍",
    age: const Duration(hours: 14),
  ),
];

/// Avatar photo of a sample channel (the first photo of its story).
List<String>? channelAvatar(String handle) {
  for (final topic in kStoryTopics) {
    if (topic.channel.handle == handle) return topic.photos.first;
  }
  return null;
}
