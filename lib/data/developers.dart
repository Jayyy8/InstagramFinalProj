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
    role: "Project leader",
    contributions: [],
  ),
  Developer(name: "Eingeline Trono", role: "Member", contributions: []),
  Developer(name: "Kim Thea Bautista", role: "Member", contributions: []),
  Developer(name: "Angela Pereyra", role: "Member", contributions: []),
  Developer(name: "Novie Mae Tambiga", role: "Member", contributions: []),
  Developer(name: "Marck Herrera", role: "Member", contributions: []),
  Developer(name: "Keen Clever Latuna", role: "Member", contributions: []),
];
