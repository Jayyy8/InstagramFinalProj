import "package:flutter/cupertino.dart";
import "package:flutter_test/flutter_test.dart";
import "package:oauth_activity/models/social_models.dart";
import "package:oauth_activity/widgets/tab_bar_scroll_filter.dart";

void main() {
  testWidgets("the tab bar only hears up-and-down scrolling and grows back", (
    tester,
  ) async {
    final deltas = <double>[];
    final axes = <Axis>[];
    Widget app(int tab) => CupertinoApp(
      home: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollUpdateNotification) {
            deltas.add(n.scrollDelta ?? 0);
            axes.add(n.metrics.axis);
          }
          return false;
        },
        child: TabBarScrollFilter(
          tab: tab,
          child: ListView(
            children: [
              SizedBox(
                height: 100,
                child: ListView(
                  key: const Key("strip"),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (int i = 0; i < 20; i++)
                      const SizedBox(width: 100, height: 100),
                  ],
                ),
              ),
              for (int i = 0; i < 40; i++) const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(0));

    // Swiping the strip sideways doesn't reach the tab bar.
    await tester.drag(find.byKey(const Key("strip")), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(axes, isNot(contains(Axis.horizontal)));

    // Scrolling down the page does (the bar shrinks).
    deltas.clear();
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(deltas.where((d) => d > 0), isNotEmpty);

    // Back at the top it is told to grow, and the bounce isn't passed on.
    deltas.clear();
    await tester.fling(find.byType(ListView).first, const Offset(0, 900), 3000);
    await tester.pumpAndSettle();
    expect(deltas.last, lessThan(0));

    // Switching tabs brings the full bar back too.
    deltas.clear();
    await tester.pumpWidget(app(1));
    await tester.pump();
    expect(deltas, [-1]);
  });

  test("a photo's stand-in text is never shown", () {
    final photo = Message.fromMap({
      "id": "m1",
      "sender_id": "a",
      "receiver_id": "b",
      "body": Message.contentOnlyBody,
      "media_url": "https://example.com/p.jpg",
      "created_at": "2026-10-30T10:00:00Z",
    });
    expect(photo.body, "");
    expect(photo.preview(mine: true), "You sent a photo");

    // Someone who really sent the camera emoji still sees it.
    final emoji = Message.fromMap({
      "id": "m2",
      "sender_id": "a",
      "receiver_id": "b",
      "body": Message.contentOnlyBody,
      "created_at": "2026-10-30T10:00:00Z",
    });
    expect(emoji.body, Message.contentOnlyBody);
  });
}
