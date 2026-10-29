import "dart:io";

import "package:flutter/cupertino.dart";

import "../services/photo_editing.dart";
import "post_video.dart";

/// Live preview of a photo (or video) with its edits: the same crop, colors and
/// overlay that [bakePhoto] draws into the shared photo.
class EditedPhoto extends StatelessWidget {
  final String path;
  final PhotoEdit edit;
  final PostRatio ratio;

  /// Width / height of the photo itself (for [PostRatio.original]).
  final double aspect;

  /// Lets you drag the overlay photo (editor only).
  final bool interactive;
  final VoidCallback? onOverlayTap;
  final VoidCallback? onChanged;

  /// [path] is a video: it plays with the filter and crop on top (a video
  /// can't have them drawn into it).
  final bool video;
  final bool startMuted;
  final ValueChanged<double>? onVideoAspect;

  const EditedPhoto({
    super.key,
    required this.path,
    required this.edit,
    required this.ratio,
    required this.aspect,
    this.interactive = false,
    this.onOverlayTap,
    this.onChanged,
    this.video = false,
    this.startMuted = false,
    this.onVideoAspect,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: ratio.value ?? aspect,
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            final overlay = edit.overlay;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: video
                      ? PostVideo(
                          key: ValueKey(path),
                          url: path,
                          autoplay: true,
                          startMuted: startMuted,
                          colorMatrix: edit.matrix,
                          onAspect: onVideoAspect,
                        )
                      : ColorFiltered(
                          colorFilter: ColorFilter.matrix(edit.matrix),
                          child: Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                ),
                if (overlay != null)
                  _Placed(
                    x: overlay.x * w,
                    y: overlay.y * h,
                    child: GestureDetector(
                      onTap: interactive ? onOverlayTap : null,
                      onScaleUpdate: interactive
                          ? (d) {
                              overlay.x = (overlay.x + d.focalPointDelta.dx / w)
                                  .clamp(0.0, 1.0);
                              overlay.y = (overlay.y + d.focalPointDelta.dy / h)
                                  .clamp(0.0, 1.0);
                              if (d.scale != 1) {
                                overlay.width =
                                    (overlay.width * (1 + (d.scale - 1) * 0.05))
                                        .clamp(0.15, 0.95);
                              }
                              onChanged?.call();
                            }
                          : null,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          overlay.width * w * 0.06,
                        ),
                        child: SizedBox(
                          width: overlay.width * w,
                          child: Image.file(
                            File(overlay.path),
                            fit: BoxFit.fitWidth,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Centers [child] on the point ([x], [y]).
class _Placed extends StatelessWidget {
  final double x;
  final double y;
  final Widget child;

  const _Placed({required this.x, required this.y, required this.child});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x,
      top: y,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: child,
      ),
    );
  }
}
