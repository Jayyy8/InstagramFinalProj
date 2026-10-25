import "dart:math" as math;

import "package:flutter/cupertino.dart";

import "../models/social_models.dart";
import "feed_image.dart";

/// A story's song sticker in its style (card, cover or vinyl), at its size.
/// Used by the story editor, the music sticker editor and the viewer.
class MusicStickerView extends StatelessWidget {
  final Music music;
  final MusicSticker sticker;

  /// Width of the story, so the sticker never runs off it.
  final double maxWidth;

  /// The vinyl turns while the song plays.
  final bool spinning;

  const MusicStickerView({
    super.key,
    required this.music,
    required this.sticker,
    required this.maxWidth,
    this.spinning = true,
  });

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (sticker.style) {
      MusicStickerStyle.card => _Card(music: music, sticker: sticker),
      MusicStickerStyle.cover => _Cover(
        music: music,
        sticker: sticker,
        size: math.min(maxWidth * 0.42, 170),
      ),
      MusicStickerStyle.vinyl => _Vinyl(
        music: music,
        sticker: sticker,
        size: math.min(maxWidth * 0.55, 210),
        spinning: spinning,
      ),
    };
    return Transform.scale(
      scale: sticker.scale,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth * 0.8),
        child: child,
      ),
    );
  }
}

Widget _art(Music music, double size, {double radius = 6}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      width: size,
      height: size,
      child: music.artworkUrl == null
          ? const ColoredBox(
              color: Color(0xFF363636),
              child: Icon(
                CupertinoIcons.music_note_2,
                color: Color(0xFFFFFFFF),
              ),
            )
          : FeedImage(urls: [music.artworkUrl!]),
    ),
  );
}

/// Title and artist under the cover / vinyl, in the sticker's color.
class _Caption extends StatelessWidget {
  final Music music;
  final MusicSticker sticker;

  const _Caption({required this.music, required this.sticker});

  @override
  Widget build(BuildContext context) {
    // The first color is the dark card; captions stay white then.
    final color = sticker.color == 0
        ? const Color(0xFFFFFFFF)
        : Color(sticker.colorValue);
    const shadow = [Shadow(color: Color(0x99000000), blurRadius: 6)];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          music.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            decoration: TextDecoration.none,
            shadows: shadow,
          ),
        ),
        Text(
          music.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color.withValues(alpha: 0.85),
            fontSize: 12,
            decoration: TextDecoration.none,
            shadows: shadow,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Music music;
  final MusicSticker sticker;

  const _Card({required this.music, required this.sticker});

  @override
  Widget build(BuildContext context) {
    final fg = sticker.lightCard
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(
        color: Color(sticker.colorValue),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _art(music, 38),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  music.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  music.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.75),
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final Music music;
  final MusicSticker sticker;
  final double size;

  const _Cover({
    required this.music,
    required this.sticker,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 40,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(color: Color(0x66000000), blurRadius: 12),
                  ],
                ),
                child: _art(music, size, radius: 4),
              ),
              // Little equalizer, like Instagram's cover sticker.
              Positioned(
                left: 10,
                bottom: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final h in const [10.0, 15.0, 8.0])
                      Container(
                        width: 3,
                        height: h,
                        margin: const EdgeInsets.only(right: 2),
                        color: const Color(0xFFFFFFFF),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Caption(music: music, sticker: sticker),
        ],
      ),
    );
  }
}

class _Vinyl extends StatefulWidget {
  final Music music;
  final MusicSticker sticker;
  final double size;
  final bool spinning;

  const _Vinyl({
    required this.music,
    required this.sticker,
    required this.size,
    required this.spinning,
  });

  @override
  State<_Vinyl> createState() => _VinylState();
}

class _VinylState extends State<_Vinyl> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _turn.repeat();
  }

  @override
  void didUpdateWidget(covariant _Vinyl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !_turn.isAnimating) {
      _turn.repeat();
    } else if (!widget.spinning && _turn.isAnimating) {
      _turn.stop();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size + 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _turn,
            child: SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _Grooves(),
                child: Center(
                  child: ClipOval(
                    child: _art(widget.music, size * 0.46, radius: 0),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _Caption(music: widget.music, sticker: widget.sticker),
        ],
      ),
    );
  }
}

/// A black record with faint grooves.
class _Grooves extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF0A0A0A), Color(0xFF1C1C1C)],
          stops: [0.3, 0.8, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0x22FFFFFF);
    for (double f = 0.52; f < 0.98; f += 0.06) {
      canvas.drawCircle(c, r * f, groove);
    }
    // A shine across the record (it turns with it, like a real one).
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.85),
      -2.4,
      0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.25
        ..color = const Color(0x14FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
