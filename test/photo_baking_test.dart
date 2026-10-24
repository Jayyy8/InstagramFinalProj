import "dart:io";
import "dart:ui" as ui;

import "package:flutter/painting.dart";
import "package:flutter_test/flutter_test.dart";
import "package:image_picker/image_picker.dart";
import "package:oauth_activity/services/photo_editing.dart";

/// A [width]×[height] PNG filled with pure red, saved to a temp file.
Future<String> _redPhoto(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFFFF0000),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = await Directory.systemTemp.createTemp("bake_test");
  final file = File("${dir.path}/red.png");
  await file.writeAsBytes(data!.buffer.asUint8List());
  return file.path;
}

Future<ui.Image> _open(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  return (await codec.getNextFrame()).image;
}

void main() {
  testWidgets("an untouched photo is shared as it is", (tester) async {
    await tester.runAsync(() async {
      final path = await _redPhoto(40, 50);
      final out = await bakePhoto(XFile(path), PhotoEdit(), PostRatio.original);
      expect(out.path, path);
    });
  });

  testWidgets("filter and ratio are drawn into the shared photo", (
    tester,
  ) async {
    await tester.runAsync(() async {
      final path = await _redPhoto(400, 500);
      final edit = PhotoEdit()..filter = PhotoFilter.moon;
      final out = await bakePhoto(XFile(path), edit, PostRatio.square);
      expect(out.path, isNot(path));

      final image = await _open(out.path);
      // 1:1 crop of a 400×500 photo.
      expect(image.width, 400);
      expect(image.height, 400);

      // Moon is black and white: the red turned grey.
      final pixels = await image.toByteData();
      final r = pixels!.getUint8(0), g = pixels.getUint8(1);
      final b = pixels.getUint8(2);
      expect((r - g).abs(), lessThan(3));
      expect((g - b).abs(), lessThan(3));
    });
  });
}
