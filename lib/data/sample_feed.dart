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
    ..._profileOnlyPosts(),
    ..._sampleReels(),
  ];
}

/// Short public sample videos for Reels (and the channels' Reels tabs).
/// Sources: test-videos.co.uk (Big Buck Bunny and Sintel by the Blender
/// Foundation, CC BY; Jellyfish by jell.yfish.us), samplelib.com, and
/// MDN's CC0 sample video.
List<FeedPost> _sampleReels() {
  const reels = [
    (
      "r_docs_1",
      _docs,
      FeedCategory.docs,
      "https://test-videos.co.uk/vids/jellyfish/mp4/h264/720/Jellyfish_720_10s_1MB.mp4",
      "Jellyfish drifting through the deep. Full episode Friday.",
      "Pacific Ocean",
      18240,
    ),
    (
      "r_news_1",
      _news,
      FeedCategory.news,
      "https://download.samplelib.com/mp4/sample-10s.mp4",
      "City life this morning. Live coverage at 9.",
      "Downtown",
      7310,
    ),
    (
      "r_hoops_1",
      _hoops,
      FeedCategory.nba,
      "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4",
      "Halftime show: Big Buck Bunny (Blender Foundation).",
      "Arena",
      25600,
    ),
    (
      "r_docs_2",
      _docs,
      FeedCategory.docs,
      "https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4",
      "Spring in slow motion.",
      "Botanical Garden",
      9930,
    ),
    (
      "r_match_1",
      _match,
      FeedCategory.football,
      "https://test-videos.co.uk/vids/sintel/mp4/h264/720/Sintel_720_10s_1MB.mp4",
      "Matchday mood: Sintel (Blender Foundation).",
      "Stadium",
      14480,
    ),
    (
      "r_news_2",
      _news,
      FeedCategory.news,
      "https://download.samplelib.com/mp4/sample-5s.mp4",
      "Five seconds of the evening commute.",
      "Main Street",
      4120,
    ),
  ];
  return [
    for (final (id, channel, category, url, caption, location, likes) in reels)
      FeedPost(
        id: id,
        category: category,
        channel: channel,
        imageUrls: [url],
        isVideo: true,
        caption: caption,
        location: location,
        timeAgoText: "1 day ago",
        baseLikes: likes,
        showInFeed: false,
      ),
  ];
}

/// Extra posts that only appear on each channel's profile grid (and in
/// Explore), so sample profiles look full.
List<FeedPost> _profileOnlyPosts() {
  const captions = {
    "hoops.daily": [
      "Courtside view from last night.",
      "Warm-ups before the big one.",
      "Throwback to the finals run.",
      "Practice makes perfect.",
      "Road trip, game three.",
      "Fans brought the energy tonight.",
    ],
    "matchday.live": [
      "Matchday atmosphere.",
      "Training ground session.",
      "Tunnel cam before kickoff.",
      "The away end was loud today.",
      "Clean sheet celebrations.",
      "New kit, who's buying?",
    ],
    "worldnews.now": [
      "Morning briefing: the stories to watch.",
      "Live from the city council session.",
      "Weather desk: clear skies ahead.",
      "Behind the scenes in the newsroom.",
      "Markets open higher today.",
      "Our reporters on the ground.",
    ],
    "planet.docs": [
      "Into the wild, episode 4.",
      "Golden hour on the plains.",
      "Deep forest, early morning.",
      "Above the clouds.",
      "Coastline, filmed by drone.",
      "Night sky over the desert.",
    ],
  };
  const photoIds = {
    "hoops.daily": [1058, 1059, 1060, 1062, 1063, 1064],
    "matchday.live": [1070, 1071, 1072, 1073, 1076, 1077],
    "worldnews.now": [1078, 1079, 1080, 1081, 1082, 1083],
    "planet.docs": [1084, 1067, 1068, 1065, 1066, 1043],
  };
  const channels = {
    "hoops.daily": (_hoops, FeedCategory.nba),
    "matchday.live": (_match, FeedCategory.football),
    "worldnews.now": (_news, FeedCategory.news),
    "planet.docs": (_docs, FeedCategory.docs),
  };

  return [
    for (final entry in channels.entries)
      for (int i = 0; i < photoIds[entry.key]!.length; i++)
        FeedPost(
          id: "x_${entry.key}_$i",
          category: entry.value.$2,
          channel: entry.value.$1,
          fallbackUrls: true,
          imageUrls: _picsum(photoIds[entry.key]![i]),
          caption: captions[entry.key]![i],
          location: "",
          timeAgoText: "${i + 1} weeks ago",
          baseLikes: 4200 + i * 1375,
          showInFeed: false,
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

// ───────────── Channel profiles ─────────────

class ChannelInfo {
  final String name;
  final String category;
  final String bio;
  final int followers;
  final int following;

  const ChannelInfo({
    required this.name,
    required this.category,
    required this.bio,
    required this.followers,
    required this.following,
  });
}

const Map<String, ChannelInfo> kChannelInfo = {
  "hoops.daily": ChannelInfo(
    name: "Hoops Daily",
    category: "Sports",
    bio:
        "Basketball news, highlights and game-day photos.\nNot affiliated with any league.",
    followers: 2480000,
    following: 312,
  ),
  "matchday.live": ChannelInfo(
    name: "Matchday Live",
    category: "Sports",
    bio: "Every kickoff, every goal. Football from around the world.",
    followers: 5120000,
    following: 188,
  ),
  "worldnews.now": ChannelInfo(
    name: "World News Now",
    category: "News & media website",
    bio:
        "Breaking news and stories that matter. Live coverage every night at 9.",
    followers: 8730000,
    following: 95,
  ),
  "planet.docs": ChannelInfo(
    name: "Planet Docs",
    category: "Documentary",
    bio: "Nature and science documentaries. New episode every Friday.",
    followers: 3360000,
    following: 41,
  ),
};

/// Story topic of a sample channel (for its avatar ring), if any.
StoryTopic? channelTopic(String handle) {
  for (final topic in kStoryTopics) {
    if (topic.channel.handle == handle) return topic;
  }
  return null;
}
