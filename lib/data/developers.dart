/// Group members shown in Settings → Developer info.
///
/// TODO: replace these placeholders with your group's real names, roles and
/// contributions before you present the project.
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
    name: "Member 1 (Project Lead)",
    role: "Project lead · Flutter developer",
    contributions: [
      "App architecture and Riverpod state management",
      "Adaptive UI (adaptive_platform_ui) for iOS and Android",
      "Home feed, stories and notes",
    ],
  ),
  Developer(
    name: "Member 2",
    role: "Backend developer",
    contributions: [
      "Supabase database schema and row level security",
      "Storage buckets for photos and videos",
      "Realtime direct messages",
    ],
  ),
  Developer(
    name: "Member 3",
    role: "Authentication developer",
    contributions: [
      "Registration with email code, login and logout",
      "Login with a code and Sign in with Apple",
      "Forgot password and change password",
    ],
  ),
  Developer(
    name: "Member 4",
    role: "UI / UX designer",
    contributions: [
      "Instagram-style screens and layouts",
      "Profile, edit profile and follow lists",
      "Testing on iPhone and Android devices",
    ],
  ),
];
