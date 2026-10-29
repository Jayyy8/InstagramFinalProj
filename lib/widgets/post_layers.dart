import "package:flutter/cupertino.dart";

import "../models/feed_models.dart";
import "../models/post_extras.dart";
import "../services/photo_editing.dart";
import "feed_image.dart";
import "overlay_canvas.dart";

/// The color matrix of a video's filter and edits (null = none).
List<double>? videoLookMatrix(VideoLook? look) {
  if (look == null) return null;
  final edit = PhotoEdit()
    ..filter = PhotoFilter.values.firstWhere(
      (f) => f.name == look.filter,
      orElse: () => PhotoFilter.normal,
    );
  for (final e in look.adjust.entries) {
    for (final a in Adjustment.values) {
      if (a.name == e.key) edit.adjust[a] = e.value;
    }
  }
  return edit.changed ? edit.matrix : null;
}

/// A post's photo [index] (or its video) with what was added in the editor
/// on top: texts, the song sticker and, on videos, the overlay photo. All of
/// it sits in the photo's own frame, so it lines up however the feed or
/// Reels crops the picture.
class PostLayers extends StatelessWidget {
  final FeedPost post;
  final int index;

  /// The photo / video, drawn to fill (BoxFit.cover) what it is given.
  final Widget media;

  /// The post's song is playing (the vinyl sticker turns).
  final bool playing;

  const PostLayers({
    super.key,
    required this.post,
    required this.index,
    required this.media,
    this.playing = false,
  });

  @override
  Widget build(BuildContext context) {
    final edits = post.edits;
    final texts = [
      for (final t in post.texts)
        if (t.photo == index) t.text,
    ];
    final sticker =
        index == 0 && post.music != null && !post.musicSticker.hidden;
    final look = post.isVideo ? edits?.video : null;
    if (edits == null ||
        (texts.isEmpty && !sticker && look?.overlayUrl == null)) {
      return media;
    }
    return MediaFrame(
      aspect: edits.aspectOf(index),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          final overlay = look?.overlayUrl;
          return Stack(
            fit: StackFit.expand,
            children: [
              media,
              if (overlay != null)
                Positioned(
                  left: look!.overlayX * w - look.overlayWidth * w / 2,
                  top: look.overlayY * h - look.overlayWidth * w / 2,
                  width: look.overlayWidth * w,
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        look.overlayWidth * w * 0.06,
                      ),
                      child: FeedImage(urls: [overlay], fit: BoxFit.fitWidth),
                    ),
                  ),
                ),
              OverlayCanvas(
                texts: texts,
                music: sticker ? post.music : null,
                sticker: post.musicSticker,
                spinning: playing,
              ),
            ],
          );
        },
      ),
    );
  }
}
