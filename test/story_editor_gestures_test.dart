import "dart:io";
import "dart:ui" as ui;

import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:image_picker/image_picker.dart";
import "package:oauth_activity/pages/story_create_page.dart";
import "package:oauth_activity/pages/story_viewer_page.dart";
import "package:oauth_activity/providers/social_providers.dart";

/// A small PNG to put in the story editor.
Future<String> _photo() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 90, 160),
    Paint()..color = const Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(90, 160);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = await Directory.systemTemp.createTemp("story_test");
  final file = File("${dir.path}/photo.png");
  await file.writeAsBytes(data!.buffer.asUint8List());
  return file.path;
}

void main() {
  testWidgets("story stickers move with one finger and resize with a pinch", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final path = (await tester.runAsync(_photo))!;
    await tester.pumpWidget(
      ProviderScope(
        // Signed out: nothing talks to Supabase.
        overrides: [currentUserIdProvider.overrideWithValue(null)],
        child: CupertinoApp(
          home: StoryEditorPage(file: XFile(path), video: false),
        ),
      ),
    );
    await tester.pump();

    // Add a text with "Aa".
    await tester.tap(find.text("Aa"));
    await tester.pump();
    await tester.enterText(find.byType(CupertinoTextField), "Hello");
    await tester.tap(find.text("Done"));
    await tester.pumpAndSettle();

    double fontSize() => tester
        .widget<StoryOverlayText>(find.byType(StoryOverlayText))
        .overlay
        .size;
    Offset where() => tester.getCenter(find.byType(StoryOverlayText));

    final size0 = fontSize();
    final start = where();

    // One finger drags it.
    await tester.drag(find.byType(StoryOverlayText), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(where().dy, greaterThan(start.dy + 150));
    expect(fontSize(), size0);

    // Two fingers next to it (not on it) pinch it bigger.
    final c = where();
    final a = await tester.startGesture(c + const Offset(-60, 40));
    final b = await tester.startGesture(c + const Offset(60, 40));
    for (int i = 1; i <= 10; i++) {
      await a.moveTo(c + Offset(-60.0 - 10 * i, 40));
      await b.moveTo(c + Offset(60.0 + 10 * i, 40));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(fontSize(), greaterThan(size0 * 1.4));

    // And smaller again.
    final big = fontSize();
    final c2 = where();
    final a2 = await tester.startGesture(c2 + const Offset(-140, 0));
    final b2 = await tester.startGesture(c2 + const Offset(140, 0));
    for (int i = 1; i <= 10; i++) {
      await a2.moveTo(c2 + Offset(-140.0 + 10 * i, 0));
      await b2.moveTo(c2 + Offset(140.0 - 10 * i, 0));
      await tester.pump();
    }
    await a2.up();
    await b2.up();
    await tester.pumpAndSettle();
    expect(fontSize(), lessThan(big * 0.8));
  });
}
