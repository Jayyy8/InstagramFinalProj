import "dart:io";
import "dart:math" as math;
import "dart:ui" as ui;

import "package:flutter/cupertino.dart";
import "package:image_picker/image_picker.dart";

/// Photo edits from the post editor (Filter, Edit, Ratio, Overlay). Texts
/// are saved separately and drawn over the photo (see OverlayCanvas).
/// They are previewed live with widgets and, when you share, drawn into the
/// photo itself ([bakePhoto]) so everyone sees the edited version.

// ───────────────────────── Color matrices ─────────────────────────

/// A 4×5 color matrix as used by [ColorFilter.matrix].
typedef ColorMatrix = List<double>;

const ColorMatrix kIdentityMatrix = [
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// [a] applied after [b].
ColorMatrix combine(ColorMatrix a, ColorMatrix b) {
  final out = List<double>.filled(20, 0);
  for (int r = 0; r < 4; r++) {
    for (int c = 0; c < 5; c++) {
      double v = c == 4 ? a[r * 5 + 4] : 0;
      for (int k = 0; k < 4; k++) {
        v += a[r * 5 + k] * b[k * 5 + c];
      }
      out[r * 5 + c] = v;
    }
  }
  return out;
}

ColorMatrix _chain(List<ColorMatrix> steps) =>
    steps.fold(kIdentityMatrix, (m, step) => combine(step, m));

ColorMatrix saturation(double s) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  return [
    lr * (1 - s) + s, lg * (1 - s), lb * (1 - s), 0, 0, //
    lr * (1 - s), lg * (1 - s) + s, lb * (1 - s), 0, 0, //
    lr * (1 - s), lg * (1 - s), lb * (1 - s) + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

ColorMatrix contrast(double c) {
  final t = 128 * (1 - c);
  return [
    c, 0, 0, 0, t, //
    0, c, 0, 0, t, //
    0, 0, c, 0, t, //
    0, 0, 0, 1, 0, //
  ];
}

/// [b] from -1 (darker) to 1 (brighter).
ColorMatrix brightness(double b) {
  final o = b * 80;
  return [
    1, 0, 0, 0, o, //
    0, 1, 0, 0, o, //
    0, 0, 1, 0, o, //
    0, 0, 0, 1, 0, //
  ];
}

/// Shifts red / green / blue by the given amounts (0–255 scale).
ColorMatrix tint(double r, double g, double b) => [
  1, 0, 0, 0, r, //
  0, 1, 0, 0, g, //
  0, 0, 1, 0, b, //
  0, 0, 0, 1, 0, //
];

/// Washed-out blacks, like an old print. [f] from 0 to 1.
ColorMatrix fade(double f) {
  final k = 1 - 0.3 * f;
  final o = 0.3 * f * 160;
  return [
    k, 0, 0, 0, o, //
    0, k, 0, 0, o, //
    0, 0, k, 0, o, //
    0, 0, 0, 1, 0, //
  ];
}

// ───────────────────────── Filters ─────────────────────────

/// Instagram's filter strip.
enum PhotoFilter {
  normal("Normal"),
  clarendon("Clarendon"),
  gingham("Gingham"),
  moon("Moon"),
  lark("Lark"),
  reyes("Reyes"),
  juno("Juno"),
  slumber("Slumber"),
  crema("Crema"),
  ludwig("Ludwig"),
  aden("Aden"),
  perpetua("Perpetua");

  final String label;

  const PhotoFilter(this.label);

  ColorMatrix get matrix => switch (this) {
    PhotoFilter.normal => kIdentityMatrix,
    PhotoFilter.clarendon => _chain([
      contrast(1.2),
      saturation(1.35),
      tint(-6, 4, 14),
    ]),
    PhotoFilter.gingham => _chain([contrast(0.9), fade(0.4), tint(8, 4, -4)]),
    PhotoFilter.moon => _chain([saturation(0), contrast(1.1), brightness(0.1)]),
    PhotoFilter.lark => _chain([
      brightness(0.12),
      saturation(0.85),
      tint(-6, 4, 6),
    ]),
    PhotoFilter.reyes => _chain([fade(0.6), contrast(0.85), tint(14, 8, 0)]),
    PhotoFilter.juno => _chain([
      saturation(1.4),
      contrast(1.1),
      tint(12, 4, -8),
    ]),
    PhotoFilter.slumber => _chain([
      saturation(0.6),
      fade(0.35),
      tint(10, 2, -6),
    ]),
    PhotoFilter.crema => _chain([saturation(0.7), fade(0.3), tint(8, 4, 0)]),
    PhotoFilter.ludwig => _chain([
      saturation(1.15),
      contrast(1.05),
      tint(6, 0, -4),
    ]),
    PhotoFilter.aden => _chain([saturation(0.85), fade(0.3), tint(10, -4, 10)]),
    PhotoFilter.perpetua => _chain([contrast(0.95), tint(-4, 10, 8)]),
  };
}

// ───────────────────────── Adjust ("Edit") ─────────────────────────

/// The "Edit" tool's sliders, each from -1 to 1 (fade from 0 to 1).
enum Adjustment {
  brightness("Brightness", CupertinoIcons.sun_max),
  contrast("Contrast", CupertinoIcons.circle_lefthalf_fill),
  saturation("Saturation", CupertinoIcons.drop),
  warmth("Warmth", CupertinoIcons.thermometer),
  fade("Fade", CupertinoIcons.cloud_fog);

  final String label;
  final IconData icon;

  const Adjustment(this.label, this.icon);

  double get min => this == Adjustment.fade ? 0 : -1;
}

/// Everything done to one photo in the editor.
class PhotoEdit {
  PhotoFilter filter = PhotoFilter.normal;
  final Map<Adjustment, double> adjust = {};

  /// A second photo placed on top ("Overlay").
  EditOverlay? overlay;

  bool get changed =>
      filter != PhotoFilter.normal ||
      adjust.values.any((v) => v != 0) ||
      overlay != null;

  ColorMatrix get matrix {
    double v(Adjustment a) => adjust[a] ?? 0;
    return _chain([
      filter.matrix,
      brightness(v(Adjustment.brightness) * 0.6),
      contrast(1 + v(Adjustment.contrast) * 0.5),
      saturation(1 + v(Adjustment.saturation)),
      tint(v(Adjustment.warmth) * 24, 0, -v(Adjustment.warmth) * 24),
      fade(v(Adjustment.fade)),
    ]);
  }
}

/// A photo on top of the photo. [width] is a fraction of the photo's width.
class EditOverlay {
  final String path;
  double x;
  double y;
  double width;

  EditOverlay({
    required this.path,
    this.x = 0.5,
    this.y = 0.5,
    this.width = 0.4,
  });
}

// ───────────────────────── Ratio ─────────────────────────

/// The "Ratio" tool, cycling like Instagram's crop button.
enum PostRatio {
  original("Original", null),
  portrait("4:5", 4 / 5),
  square("1:1", 1),
  landscape("16:9", 16 / 9);

  final String label;
  final double? value;

  const PostRatio(this.label, this.value);

  PostRatio get next => PostRatio.values[(index + 1) % PostRatio.values.length];
}

/// Part of a [width]×[height] photo kept by [ratio] (centered crop).
Rect cropRect(double width, double height, PostRatio ratio) {
  final r = ratio.value;
  if (r == null) return Rect.fromLTWH(0, 0, width, height);
  if (width / height > r) {
    final w = height * r;
    return Rect.fromLTWH((width - w) / 2, 0, w, height);
  }
  final h = width / r;
  return Rect.fromLTWH(0, (height - h) / 2, width, h);
}

// ───────────────────────── Baking ─────────────────────────

Future<ui.Image> _decode(String path, {int? targetWidth}) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// Size (width, height) of the photo at [path].
Future<Size> photoSize(String path) async {
  final image = await _decode(path);
  final size = Size(image.width.toDouble(), image.height.toDouble());
  image.dispose();
  return size;
}

/// Draws [edit] and [ratio] into the photo and returns the new file
/// (a PNG at most 1440 px wide). Untouched photos are returned as they are.
Future<XFile> bakePhoto(XFile source, PhotoEdit edit, PostRatio ratio) async {
  if (!edit.changed && ratio == PostRatio.original) return source;

  var image = await _decode(source.path);
  if (image.width > 1440) {
    image.dispose();
    image = await _decode(source.path, targetWidth: 1440);
  }
  final crop = cropRect(image.width.toDouble(), image.height.toDouble(), ratio);
  final out = Rect.fromLTWH(0, 0, crop.width, crop.height);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, out);
  canvas.drawImageRect(
    image,
    crop,
    out,
    Paint()
      ..filterQuality = FilterQuality.high
      ..colorFilter = ColorFilter.matrix(edit.matrix),
  );

  final overlay = edit.overlay;
  if (overlay != null) {
    final top = await _decode(overlay.path, targetWidth: 1080);
    final w = out.width * overlay.width;
    final h = w * top.height / top.width;
    final dst = Rect.fromCenter(
      center: Offset(out.width * overlay.x, out.height * overlay.y),
      width: w,
      height: h,
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(dst, Radius.circular(w * 0.06)));
    canvas.drawImageRect(
      top,
      Rect.fromLTWH(0, 0, top.width.toDouble(), top.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
    top.dispose();
  }

  final picture = recorder.endRecording();
  final baked = await picture.toImage(
    math.max(1, out.width.round()),
    math.max(1, out.height.round()),
  );
  final data = await baked.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  baked.dispose();
  picture.dispose();

  final dir = await Directory.systemTemp.createTemp("post");
  final file = File("${dir.path}/photo.png");
  await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
  return XFile(file.path, mimeType: "image/png");
}
