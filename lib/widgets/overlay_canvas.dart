import "package:flutter/cupertino.dart";

import "../models/social_models.dart";
import "music_sticker.dart";
import "story_text.dart";

/// Texts are saved at their size on a 390-wide photo; on a wider or
/// narrower one they grow or shrink with it.
const double kOverlayBaseWidth = 390;

/// Texts and the song sticker over a post's photo or video. Positions are
/// fractions of the photo, so they land in the same spot at any size.
/// With [interactive], drag moves and pinch resizes whatever is under (or,
/// for a pinch, nearest to) the fingers, like the story editor.
class OverlayCanvas extends StatefulWidget {
  final List<StoryOverlay> texts;
  final Music? music;
  final MusicSticker? sticker;
  final bool interactive;

  /// Texts animate in the feed; in the editor they stay still.
  final bool animate;

  /// The vinyl sticker turns while the song plays.
  final bool spinning;

  final ValueChanged<int>? onTextTap;
  final VoidCallback? onMusicTap;

  /// Called after a drag / pinch changed texts[i] or the sticker.
  final void Function(int index, StoryOverlay text)? onTextChanged;
  final ValueChanged<MusicSticker>? onStickerChanged;

  /// A drag / pinch that started on no text or sticker (the editor moves
  /// the overlay photo with it).
  final void Function(ScaleUpdateDetails details, Size size)? onFreeScale;

  const OverlayCanvas({
    super.key,
    this.texts = const [],
    this.music,
    this.sticker,
    this.interactive = false,
    this.animate = true,
    this.spinning = true,
    this.onTextTap,
    this.onMusicTap,
    this.onTextChanged,
    this.onStickerChanged,
    this.onFreeScale,
  });

  @override
  State<OverlayCanvas> createState() => _OverlayCanvasState();
}

class _OverlayCanvasState extends State<OverlayCanvas> {
  final GlobalKey _stack = GlobalKey();
  final GlobalKey _musicKey = GlobalKey();
  final List<GlobalKey> _textKeys = [];

  /// "music", or the index of a text, while it is dragged / pinched.
  Object? _target;
  double _startSize = 1;

  bool get _showSticker =>
      widget.music != null && widget.sticker != null && !widget.sticker!.hidden;

  GlobalKey _keyFor(int i) {
    while (_textKeys.length <= i) {
      _textKeys.add(GlobalKey());
    }
    return _textKeys[i];
  }

  Rect? _rectOf(GlobalKey key, [double scale = 1]) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.attached) return null;
    final r = box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
    return Rect.fromCenter(
      center: r.center,
      width: r.width * scale,
      height: r.height * scale,
    );
  }

  void _grab(Offset at, int fingers) {
    final reach = fingers > 1 ? 90.0 : 14.0;
    Object? best;
    var bestDistance = double.infinity;
    void consider(Object id, Rect? rect) {
      if (rect == null || !rect.inflate(reach).contains(at)) return;
      final d = (rect.center - at).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = id;
      }
    }

    for (int i = 0; i < widget.texts.length && i < _textKeys.length; i++) {
      consider(i, _rectOf(_textKeys[i]));
    }
    if (_showSticker) {
      consider("music", _rectOf(_musicKey, widget.sticker!.scale));
    }
    _target = best;
    if (best == "music") {
      _startSize = widget.sticker!.scale;
    } else if (best is int) {
      _startSize = widget.texts[best as int].size;
    }
  }

  void _move(ScaleUpdateDetails d, Size size) {
    final target = _target;
    if (target == null) {
      widget.onFreeScale?.call(d, size);
      return;
    }
    final dx = d.focalPointDelta.dx / size.width;
    final dy = d.focalPointDelta.dy / size.height;
    final pinch = d.pointerCount > 1;
    if (target == "music") {
      final s = widget.sticker!;
      widget.onStickerChanged?.call(
        s.copyWith(
          x: (s.x + dx).clamp(0.06, 0.94),
          y: (s.y + dy).clamp(0.05, 0.95),
          scale: pinch ? (_startSize * d.scale).clamp(0.4, 2.8) : s.scale,
        ),
      );
    } else if (target is int && target < widget.texts.length) {
      final o = widget.texts[target];
      widget.onTextChanged?.call(
        target,
        o.copyWith(
          x: (o.x + dx).clamp(0.05, 0.95),
          y: (o.y + dy).clamp(0.05, 0.95),
          size: pinch ? (_startSize * d.scale).clamp(12.0, 110.0) : o.size,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final scale = w / kOverlayBaseWidth;
        final stack = Stack(
          key: _stack,
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            for (int i = 0; i < widget.texts.length; i++)
              Positioned(
                left: widget.texts[i].x * w - w / 2,
                width: w,
                top: widget.texts[i].y * h - widget.texts[i].size * scale,
                child: Center(
                  child: GestureDetector(
                    key: _keyFor(i),
                    onTap: widget.interactive
                        ? () => widget.onTextTap?.call(i)
                        : null,
                    child: StoryOverlayText(
                      overlay: widget.texts[i],
                      scale: scale,
                      animate: widget.animate,
                    ),
                  ),
                ),
              ),
            if (_showSticker)
              Positioned(
                left: widget.sticker!.x * w,
                top: widget.sticker!.y * h,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: GestureDetector(
                    key: _musicKey,
                    onTap: widget.interactive ? widget.onMusicTap : null,
                    child: MusicStickerView(
                      music: widget.music!,
                      // The sticker's size follows the photo like texts do.
                      sticker: widget.sticker!.copyWith(
                        scale: widget.sticker!.scale * scale,
                      ),
                      // Fits wide (landscape) videos too.
                      maxWidth: w < h ? w : h,
                      spinning: widget.spinning,
                    ),
                  ),
                ),
              ),
          ],
        );
        if (!widget.interactive) return IgnorePointer(child: stack);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onScaleStart: (d) => _grab(d.localFocalPoint, d.pointerCount),
          onScaleUpdate: (d) => _move(d, box.biggest),
          onScaleEnd: (_) => _target = null,
          child: stack,
        );
      },
    );
  }
}

/// Places [child] exactly over a photo / video of width / height [aspect]
/// drawn with BoxFit.cover in the space it gets (the feed's 4:5 frame,
/// a full-screen reel), so overlays line up with the picture.
class MediaFrame extends StatelessWidget {
  final double aspect;
  final Widget child;

  const MediaFrame({super.key, required this.aspect, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        if (!w.isFinite || !h.isFinite || h == 0 || aspect <= 0) {
          return child;
        }
        final double mw, mh;
        if (aspect > w / h) {
          mh = h;
          mw = h * aspect;
        } else {
          mw = w;
          mh = w / aspect;
        }
        return ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: (w - mw) / 2,
                top: (h - mh) / 2,
                width: mw,
                height: mh,
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}
