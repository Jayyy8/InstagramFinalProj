import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:image_picker/image_picker.dart";
import "package:oauth_activity/models/social_models.dart";
import "package:oauth_activity/pages/account_setup_page.dart";
import "package:oauth_activity/providers/social_providers.dart";
import "package:oauth_activity/providers/supabase_providers.dart";
import "package:oauth_activity/services/social_repository.dart";
import "package:supabase_flutter/supabase_flutter.dart";

/// Says every username is free, without a server.
class _FakeRepository extends SocialRepository {
  _FakeRepository(super.db);

  @override
  Future<bool> usernameFree(String username) async => username != "taken";
}

/// Remembers what the setup saved.
class _FakeProfile extends MyProfileNotifier {
  Map<String, Object?>? saved;

  @override
  Future<Profile?> build() async => _profile;

  @override
  Future<void> completeSetup({
    required String firstName,
    required String lastName,
    required String username,
    required DateTime birthday,
    String? gender,
    String bio = "",
    XFile? photo,
  }) async {
    saved = {
      "first": firstName,
      "last": lastName,
      "username": username,
      "birthday": birthday,
      "bio": bio,
    };
  }
}

const _profile = Profile(
  id: "u1",
  username: "newuser1234",
  setupDone: false,
);

void main() {
  test("accounts from before the setup existed count as set up", () {
    expect(Profile.fromMap({"id": "a", "username": "x"}).setupDone, isTrue);
    expect(
      Profile.fromMap({"id": "a", "username": "x", "setup_done": false})
          .setupDone,
      isFalse,
    );
    final p = Profile.fromMap({
      "id": "a",
      "username": "x",
      "first_name": "Juan",
      "last_name": "Dela Cruz",
      "birthday": "2000-05-17",
    });
    expect(p.firstName, "Juan");
    expect(p.birthday, DateTime(2000, 5, 17));
  });

  testWidgets("setup walks through name, birthday, username and photo", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final client = SupabaseClient(
      "http://localhost:54321",
      "test-key",
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final fake = _FakeProfile();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseProvider.overrideWithValue(client),
          repositoryProvider.overrideWithValue(_FakeRepository(client)),
          myProfileProvider.overrideWith(() => fake),
        ],
        child: const CupertinoApp(home: AccountSetupPage(profile: _profile)),
      ),
    );
    await tester.pump();

    // 1. Name: Next stays off until both names are in.
    expect(find.text("What's your name?"), findsOneWidget);
    await tester.enterText(find.byType(CupertinoTextField).at(0), "Juan");
    await tester.enterText(find.byType(CupertinoTextField).at(1), "Dela Cruz");
    await tester.pump();
    await tester.tap(find.text("Next"));
    await tester.pumpAndSettle();

    // 2. Birthday: the picker starts 18 years ago, which is old enough.
    expect(find.text("What's your birthday?"), findsOneWidget);
    await tester.drag(
      find.byType(CupertinoDatePicker),
      const Offset(0, -40),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("Next"));
    await tester.pumpAndSettle();

    // 3. Username: suggested from the name, checked while typing.
    expect(find.text("Create a username"), findsOneWidget);
    expect(find.text("juan.delacruz"), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text("juan.delacruz is available."), findsOneWidget);
    await tester.tap(find.text("Next"));
    await tester.pumpAndSettle();

    // 4. Photo and bio, then Finish saves it all.
    expect(find.text("Add a profile picture"), findsOneWidget);
    await tester.enterText(find.byType(CupertinoTextField), "Hello!");
    await tester.tap(find.text("Finish"));
    // The page keeps its spinner: in the app the next screen replaces it.
    await tester.pump(const Duration(milliseconds: 100));

    expect(fake.saved?["first"], "Juan");
    expect(fake.saved?["last"], "Dela Cruz");
    expect(fake.saved?["username"], "juan.delacruz");
    expect(fake.saved?["bio"], "Hello!");
    final birthday = fake.saved?["birthday"] as DateTime;
    expect(DateTime.now().difference(birthday).inDays, greaterThan(13 * 365));
  });
}
