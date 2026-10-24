import "package:flutter/cupertino.dart";
import "package:flutter_test/flutter_test.dart";
import "package:oauth_activity/theme/app_theme.dart";
import "package:oauth_activity/widgets/android_bars.dart";
import "package:oauth_activity/widgets/follow_button.dart";
import "package:oauth_activity/widgets/shimmer.dart";

Widget _app(Widget child, {Brightness brightness = Brightness.light}) {
  return CupertinoApp(
    theme: brightness == Brightness.dark ? kDarkTheme : kLightTheme,
    home: CupertinoPageScaffold(child: Center(child: child)),
  );
}

void main() {
  testWidgets("Badged shows the count, 9+ and nothing for zero", (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badged(count: 3, child: Icon(CupertinoIcons.heart)),
            Badged(count: 12, child: Icon(CupertinoIcons.heart)),
            Badged(count: 0, child: Icon(CupertinoIcons.heart)),
          ],
        ),
      ),
    );
    expect(find.text("3"), findsOneWidget);
    expect(find.text("9+"), findsOneWidget);
    expect(find.text("0"), findsNothing);
  });

  testWidgets("IgBottomBar reports the tapped tab", (tester) async {
    int? tapped;
    await tester.pumpWidget(
      _app(
        IgBottomBar(
          selectedIndex: 0,
          onTap: (i) => tapped = i,
          items: const [
            IgTabItem(
              icon: CupertinoIcons.house,
              selectedIcon: CupertinoIcons.house_fill,
              label: "Home",
            ),
            IgTabItem(
              icon: CupertinoIcons.search,
              selectedIcon: CupertinoIcons.search,
              label: "Search",
              badge: 2,
            ),
          ],
        ),
      ),
    );
    expect(find.byIcon(CupertinoIcons.house_fill), findsOneWidget);
    expect(find.text("2"), findsOneWidget);
    await tester.tap(find.byIcon(CupertinoIcons.search));
    expect(tapped, 1);
  });

  testWidgets("IgTopBar shows a back arrow only when it can go back", (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const SizedBox(
          height: 56,
          child: IgTopBar(title: Text("Settings")),
        ),
      ),
    );
    expect(find.text("Settings"), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.arrow_left), findsNothing);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      CupertinoPageRoute<void>(
        builder: (_) => const CupertinoPageScaffold(
          child: IgTopBar(title: Text("Inner")),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.arrow_left), findsOneWidget);
    await tester.tap(find.byIcon(CupertinoIcons.arrow_left));
    await tester.pumpAndSettle();
    expect(find.text("Inner"), findsNothing);
  });

  testWidgets("FollowButton labels", (tester) async {
    await tester.pumpWidget(
      _app(FollowButton(following: false, onTap: () {})),
    );
    expect(find.text("Follow"), findsOneWidget);
    await tester.pumpWidget(_app(FollowButton(following: true, onTap: () {})));
    expect(find.text("Following"), findsOneWidget);
    await tester.pumpWidget(
      _app(FollowButton(following: false, followsYou: true, onTap: () {})),
    );
    expect(find.text("Follow back"), findsOneWidget);
  });

  testWidgets("AppColors follow the theme brightness", (tester) async {
    late AppColors light;
    late AppColors dark;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            light = AppColors.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            dark = AppColors.of(context);
            return const SizedBox();
          },
        ),
        brightness: Brightness.dark,
      ),
    );
    expect(light.dark, false);
    expect(dark.dark, true);
    expect(dark.background, const Color(0xFF000000));
  });

  testWidgets("Shimmer animates without errors", (tester) async {
    await tester.pumpWidget(
      _app(const Shimmer(child: Bone(width: 100, height: 20))),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(Bone), findsOneWidget);
  });
}
