import "dart:io";

import "package:flutter/cupertino.dart";
import "package:video_player/video_player.dart";

import "shimmer.dart";

/// Video of a post. In the feed it plays when tapped; in Reels [autoplay]
/// follows the page on screen. A speaker button toggles sound.
class PostVideo extends StatefulWidget {
  final String url;
  final bool autoplay;
  final BoxFit fit;

  /// Grid tiles: just the first frame, no controls.
  final bool thumbnail;

  const PostVideo({
    super.key,
    required this.url,
    this.autoplay = false,
    this.fit = BoxFit.cover,
    this.thumbnail = false,
  });

  @override
  State<PostVideo> createState() => _PostVideoState();
}

class _PostVideoState extends State<PostVideo> {
  /// Web address, or a file on the phone (a video being posted).
  late final VideoPlayerController _controller = widget.url.startsWith("http")
      ? VideoPlayerController.networkUrl(Uri.parse(widget.url))
      : VideoPlayerController.file(File(widget.url));
  bool _ready = false;
  bool _failed = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          _controller.setLooping(true);
          setState(() => _ready = true);
          if (widget.autoplay && !widget.thumbnail && _onScreen) {
            _controller.play();
          }
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
    _controller.addListener(_onTick);
  }

  /// False while the video's page is hidden: another tab is selected or
  /// a page is open on top. Hidden videos must not keep playing sound.
  bool _onScreen = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final onScreen = TickerMode.valuesOf(context).enabled;
    if (onScreen == _onScreen) return;
    _onScreen = onScreen;
    if (!_ready || widget.thumbnail) return;
    if (!onScreen) {
      _controller.pause();
    } else if (widget.autoplay) {
      _controller.play();
    }
  }

  @override
  void didUpdateWidget(covariant PostVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready || widget.thumbnail) return;
    if (widget.autoplay && !oldWidget.autoplay && _onScreen) {
      _controller.play();
    }
    if (!widget.autoplay && oldWidget.autoplay) _controller.pause();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  bool _wasPlaying = false;

  void _onTick() {
    final playing = _controller.value.isPlaying;
    if (playing != _wasPlaying && mounted) {
      _wasPlaying = playing;
      setState(() {});
    }
  }

  void _toggle() {
    if (!_ready) return;
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller.setVolume(_muted ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const ColoredBox(
        color: Color(0xFF1C1C1E),
        child: Center(
          child: Icon(
            CupertinoIcons.video_camera,
            color: Color(0xFF8E8E8E),
            size: 40,
          ),
        ),
      );
    }
    if (!_ready) return const Shimmer(child: Bone(radius: 0));

    final video = ClipRect(
      child: FittedBox(
        fit: widget.fit,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );

    if (widget.thumbnail) return video;

    final playing = _controller.value.isPlaying;
    return GestureDetector(
      onTap: _toggle,
      child: Stack(
        fit: StackFit.expand,
        children: [
          video,
          if (!playing)
            const Center(
              child: Icon(
                CupertinoIcons.play_fill,
                size: 64,
                color: Color(0xCCFFFFFF),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 12,
            child: GestureDetector(
              onTap: _toggleMute,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0x99000000),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _muted
                      ? CupertinoIcons.speaker_slash_fill
                      : CupertinoIcons.speaker_2_fill,
                  size: 15,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
