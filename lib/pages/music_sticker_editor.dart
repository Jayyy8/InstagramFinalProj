import "dart:async";
import "dart:math" as math;

import "package:flutter/cupertino.dart";

import "../models/social_models.dart";
import "../services/music_service.dart";
import "../theme/app_theme.dart";
import "../widgets/feed_image.dart";
import "../widgets/music_sticker.dart";

/// Opens Instagram's song sticker editor over the story editor: pick the
/// sticker style (or "Music only"), its color, the clip length and which
/// part of the song plays. Returns the new sticker, null on Cancel.
Future<MusicSticker?> editMusicSticker(
  BuildContext context, {
  required Music music,
  required MusicSticker sticker,
  required PreviewPlayer player,
}) {
  return Navigator.of(context).push<MusicSticker>(
    PageRouteBuilder<MusicSticker>(
      opaque: false,
      barrierColor: const Color(0x99000000),
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) =>
          _MusicStickerEditor(music: music, initial: sticker, player: player),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// The style buttons: Music only, then each sticker style.
enum _Choice { musicOnly, card, cover, vinyl }

class _MusicStickerEditor extends StatefulWidget {
  final Music music;
  final MusicSticker initial;
  final PreviewPlayer player;

  const _MusicStickerEditor({
    required this.music,
    required this.initial,
    required this.player,
  });

  @override
  State<_MusicStickerEditor> createState() => _MusicStickerEditorState();
}

class _MusicStickerEditorState extends State<_MusicStickerEditor> {
  late MusicSticker _sticker = widget.initial;
  Timer? _tick;
  bool _paused = false;

  /// Start of the clip while its box is being dragged.
  double? _dragStartMs;

  PreviewPlayer get _player => widget.player;

  /// The whole preview (Apple's previews are about 30 seconds).
  int get _previewMs {
    final d = _player.duration.inMilliseconds;
    return d > 0 ? d : 30000;
  }

  int get _clipMs => math.min(_sticker.clipMs, _previewMs);

  _Choice get _choice => _sticker.hidden
      ? _Choice.musicOnly
      : switch (_sticker.style) {
          MusicStickerStyle.card => _Choice.card,
          MusicStickerStyle.cover => _Choice.cover,
          MusicStickerStyle.vinyl => _Choice.vinyl,
        };

  @override
  void initState() {
    super.initState();
    _play();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _play() async {
    await _player.play(
      widget.music.previewUrl,
      start: Duration(milliseconds: _sticker.startMs),
      length: Duration(milliseconds: _clipMs),
    );
    if (_paused) await _player.pause();
  }

  void _choose(_Choice c) {
    setState(() {
      _sticker = switch (c) {
        _Choice.musicOnly => _sticker.copyWith(hidden: true),
        _Choice.card => _sticker.copyWith(
          hidden: false,
          style: MusicStickerStyle.card,
        ),
        _Choice.cover => _sticker.copyWith(
          hidden: false,
          style: MusicStickerStyle.cover,
        ),
        _Choice.vinyl => _sticker.copyWith(
          hidden: false,
          style: MusicStickerStyle.vinyl,
        ),
      };
    });
  }

  void _nextColor() {
    setState(() {
      _sticker = _sticker.copyWith(
        color: (_sticker.color + 1) % MusicSticker.colors.length,
        hidden: false,
      );
    });
  }

  void _nextLength() {
    final lengths = MusicSticker.clipLengths;
    final i = lengths.indexOf(_sticker.clipMs);
    final next = lengths[(i + 1) % lengths.length];
    setState(() {
      _sticker = _sticker.copyWith(
        clipMs: next,
        // Keep the clip inside the preview.
        startMs: math.max(
          0,
          math.min(_sticker.startMs, _previewMs - math.min(next, _previewMs)),
        ),
      );
    });
    _play();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _player.pause();
    } else {
      _player.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);

    return DefaultTextStyle(
      style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 15),
      child: Stack(
        children: [
          // ───── Top: Cancel · song + color · Done ─────
          Positioned(
            top: padding.top + 4,
            left: 0,
            right: 0,
            child: Row(
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: widget.music.artworkUrl == null
                        ? const ColoredBox(color: Color(0xFF363636))
                        : FeedImage(urls: [widget.music.artworkUrl!]),
                  ),
                ),
                const SizedBox(width: 14),
                Semantics(
                  button: true,
                  label: "Sticker color",
                  child: GestureDetector(
                    onTap: _nextColor,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFFFFF),
                          width: 2,
                        ),
                        gradient: _sticker.color == 0
                            ? const SweepGradient(
                                colors: [
                                  Color(0xFFE1306C),
                                  Color(0xFFFDCB5C),
                                  Color(0xFF70C050),
                                  Color(0xFF4F5BD5),
                                  Color(0xFFE1306C),
                                ],
                              )
                            : null,
                        color: _sticker.color == 0
                            ? null
                            : Color(_sticker.colorValue),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                CupertinoButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(_sticker.copyWith(clipMs: _clipMs)),
                  child: const Text(
                    "Done",
                    style: TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ───── The sticker as it will look ─────
          Positioned(
            left: 0,
            right: 0,
            top: size.height * 0.2,
            child: Center(
              child: _sticker.hidden
                  ? const Text(
                      "Music only",
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    )
                  : MusicStickerView(
                      music: widget.music,
                      // Shown at normal size here; the story keeps its size.
                      sticker: _sticker.copyWith(scale: 1),
                      maxWidth: size.width,
                      spinning: !_paused,
                    ),
            ),
          ),

          // ───── Styles, clip length, play, waveform ─────
          Positioned(
            left: 0,
            right: 0,
            bottom: padding.bottom + 24,
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: math.max(16, (size.width - 4 * 52) / 2),
                    ),
                    children: [
                      for (final c in _Choice.values)
                        _StyleButton(
                          choice: c,
                          selected: c == _choice,
                          onTap: () => _choose(c),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Semantics(
                        button: true,
                        label: "Clip length ${_clipMs ~/ 1000} seconds",
                        child: GestureDetector(
                          onTap: _nextLength,
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFFFFFF),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              "${_clipMs ~/ 1000}",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: _progressLine()),
                      const SizedBox(width: 14),
                      Semantics(
                        button: true,
                        label: _paused ? "Play" : "Pause",
                        child: GestureDetector(
                          onTap: _togglePause,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFFFFFF),
                            ),
                            child: Icon(
                              _paused
                                  ? CupertinoIcons.play_fill
                                  : CupertinoIcons.pause_fill,
                              size: 16,
                              color: const Color(0xFF000000),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _waveform(size.width),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// How far into the clip the song is.
  double get _clipProgress {
    final pos = _player.position.inMilliseconds - _sticker.startMs;
    return (pos / _clipMs).clamp(0.0, 1.0);
  }

  Widget _progressLine() {
    return LayoutBuilder(
      builder: (context, box) => Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(height: 2, color: const Color(0x55FFFFFF)),
          Container(
            height: 2,
            width: box.maxWidth * _clipProgress,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: kStoryRingColors),
            ),
          ),
        ],
      ),
    );
  }

  /// The song as bars; drag the box to choose the part that plays.
  Widget _waveform(double width) {
    final preview = _previewMs.toDouble();
    final boxWidth = width * 0.34;
    // Scale: the box covers the clip, the rest of the bars the preview.
    final msPerPx = _clipMs / boxWidth;
    final trackWidth = preview / msPerPx;
    final boxLeft = (width - boxWidth) / 2;
    final offset = boxLeft - _sticker.startMs / msPerPx;

    return GestureDetector(
      onHorizontalDragStart: (_) => _dragStartMs = _sticker.startMs.toDouble(),
      onHorizontalDragUpdate: (d) {
        final maxStart = math.max(0.0, preview - _clipMs);
        _dragStartMs = ((_dragStartMs ?? 0) - d.delta.dx * msPerPx).clamp(
          0.0,
          maxStart,
        );
        setState(
          () => _sticker = _sticker.copyWith(startMs: _dragStartMs!.round()),
        );
      },
      onHorizontalDragEnd: (_) {
        _dragStartMs = null;
        _play();
      },
      child: SizedBox(
        height: 46,
        width: width,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: offset,
              top: 0,
              bottom: 0,
              width: trackWidth,
              child: CustomPaint(
                painter: _Bars(seed: widget.music.title.hashCode),
              ),
            ),
            // The chosen clip, filling up as it plays.
            Positioned(
              left: boxLeft,
              width: boxWidth,
              top: 2,
              bottom: 2,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFE1306C),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _clipProgress,
                        heightFactor: 1,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xCCFA7E1E), Color(0xCCD62976)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleButton extends StatelessWidget {
  final _Choice choice;
  final bool selected;
  final VoidCallback onTap;

  const _StyleButton({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (choice) {
      _Choice.musicOnly => (CupertinoIcons.xmark_circle, "Music only"),
      _Choice.card => (CupertinoIcons.rectangle_fill, "Card"),
      _Choice.cover => (CupertinoIcons.photo_fill, "Album cover"),
      _Choice.vinyl => (CupertinoIcons.smallcircle_circle_fill, "Vinyl"),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? const Color(0xFFFFFFFF) : const Color(0x33FFFFFF),
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected ? const Color(0xFFE1306C) : const Color(0xFFFFFFFF),
          ),
        ),
      ),
    );
  }
}

/// Thin bars of varying height (a stand-in waveform: previews carry no
/// loudness data). The same song always draws the same bars.
class _Bars extends CustomPainter {
  final int seed;

  _Bars({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final mid = size.height / 2;
    for (double x = 2; x < size.width; x += 7) {
      final h = size.height * (0.18 + random.nextDouble() * 0.6);
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _Bars old) => old.seed != seed;
}
