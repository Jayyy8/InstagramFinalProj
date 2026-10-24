import "dart:io";

import "package:flutter/cupertino.dart";

import "../services/photo_editing.dart";

/// Live preview of a photo with its edits: the same crop, colors, texts and
/// overlay that [bakePhoto] draws into the shared photo.
class EditedPhoto extends StatelessWidget {
  final String path;
  final PhotoEdit edit;
  final PostRatio ratio;

  /// Width / height of the photo itself (for [PostRatio.original]).
  final double aspect;

  /// Lets you drag texts and the overlay (editor only).
  final bool interactive;
  final ValueChanged<EditText>? onTextTap;
  final VoidCallback? onOverlayTap;
  final VoidCallback? onChanged;

  const EditedPhoto({
    super.key,
    required this.path,
    required this.edit,
    required this.ratio,
    required this.aspect,
    this.interactive = false,
    this.onTextTap,
    this.onOverlayTap,
    this.onChanged,
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
                  child: ColorFiltered(
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
                for (final t in edit.texts)
                  _Placed(
                    x: t.x * w,
                    y: t.y * h,
                    child: GestureDetector(
                      onTap: interactive ? () => onTextTap?.call(t) : null,
                      onPanUpdate: interactive
                          ? (d) {
                              t.x = (t.x + d.delta.dx / w).clamp(0.0, 1.0);
                              t.y = (t.y + d.delta.dy / h).clamp(0.0, 1.0);
                              onChanged?.call();
                            }
                          : null,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: w * 0.9),
                        child: Text(
                          t.text,
                          textAlign: TextAlign.center,
                          style: t.styleFor(w),
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
