/// Group members shown in Settings → Developer info.
///
/// Add each member's contributions to their list; members without any show
/// just their name and role.
class Developer {
  final String name;
  final String role;
  final List<String> contributions;

  /// Optional photo URL (leave null for the default avatar).
  final String? photoUrl;

  const Developer({
    required this.name,
    required this.role,
    required this.contributions,
    this.photoUrl,
  });
}

const String kProjectName = "Instagram Replica";
const String kCourse = "Mobile Application Development";

const List<Developer> kDevelopers = [
  Developer(
    name: "Tijano Tj Enriquez",
    role: "Project leader · Main developer",
    contributions: [
      "App architecture, Riverpod state management and the Supabase backend",
      "Adaptive UI for iPhone (Liquid Glass / Cupertino) and Android",
      "Home feed, posts, Reels, stories, notes, Instants and direct messages",
      "Story and post editors: text styles, music stickers, filters",
      "Database schema, security rules, sample accounts and testing",
    ],
  ),
  Developer(
    name: "Eingeline Trono",
    role: "UI / UX designer",
    contributions: [
      "Instagram-style layouts for the feed, profile and inbox",
      "Icons, colors and dark mode",
    ],
  ),
  Developer(
    name: "Kim Thea Bautista",
    role: "Authentication developer",
    contributions: [
      "Sign up with email code, login and logout",
      "Forgot password and change password in Settings",
    ],
  ),
  Developer(
    name: "Angela Pereyra",
    role: "Profile developer",
    contributions: [
      "Edit profile: name, username, bio and profile photo",
      "Followers / following lists and follow buttons",
    ],
  ),
  Developer(
    name: "Novie Mae Tambiga",
    role: "Messaging developer",
    contributions: [
      "Real-time direct messages with reactions and replies",
      "Notes (My Day) in the inbox",
    ],
  ),
  Developer(
    name: "Marck Herrera",
    role: "Stories developer",
    contributions: [
      "Story upload, viewer and story highlights archive",
      "Close Friends and who-can-see settings",
    ],
  ),
  Developer(
    name: "Keen Clever Latuna",
    role: "QA tester · Documentation",
    contributions: [
      "Testing on Android and iPhone, bug reports",
      "README, setup guide and project documentation",
    ],
  ),
];
