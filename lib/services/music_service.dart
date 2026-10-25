import "dart:convert";

import "package:http/http.dart" as http;
import "package:video_player/video_player.dart";

import "../models/social_models.dart";

/// Song search for stories and notes. Uses Apple's public iTunes Search API
/// (no account or key), which returns 30-second previews.
class MusicService {
  static const _host = "itunes.apple.com";

  /// Songs shown before you type anything.
  static const String popularQuery = "top hits 2026";

  /// The song picker's tabs (Saved is kept on the phone).
  static const String trendingQuery = "viral hits";
  static const String originalQuery = "acoustic sessions";

  static Future<List<Music>> search(String term) async {
    final q = term.trim().isEmpty ? popularQuery : term.trim();
    final uri = Uri.https(_host, "/search", {
      "term": q,
      "media": "music",
      "entity": "song",
      "limit": "30",
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception("Music search failed (${response.statusCode}).");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (data["results"] as List?) ?? const [];
    return [
      for (final r in results.cast<Map<String, dynamic>>())
        if (r["previewUrl"] != null)
          Music(
            title: (r["trackName"] ?? "") as String,
            artist: (r["artistName"] ?? "") as String,
            previewUrl: r["previewUrl"] as String,
            artworkUrl: (r["artworkUrl100"] as String?)?.replaceFirst(
              "100x100",
              "300x300",
            ),
            durationMs: (r["trackTimeMillis"] as num?)?.toInt(),
          ),
    ];
  }
}

/// Options for every player in the app. Without mixWithOthers each player
/// takes the audio focus when it starts, and on Android the player that loses
/// it pauses: a story's video (or a feed video) silenced the story's song.
final VideoPlayerOptions kMixedAudio = VideoPlayerOptions(mixWithOthers: true);

/// Plays one song preview at a time (stories, notes, the song picker).
/// video_player plays audio-only URLs too, so no extra audio package.
class PreviewPlayer {
  VideoPlayerController? _controller;
  String? _url;

  /// The part of the preview that plays (a story's chosen clip).
  Duration _start = Duration.zero;
  Duration? _length;
  bool _loop = true;

  String? get url => _url;
  bool get isPlaying => _controller?.value.isPlaying ?? false;
  Duration get position => _controller?.value.position ?? Duration.zero;

  /// Length of the whole preview (about 30 s), zero until it loads.
  Duration get duration => _controller?.value.duration ?? Duration.zero;

  /// Plays [url]; with [length], only from [start] to [start] + [length].
  Future<void> play(
    String url, {
    bool loop = true,
    Duration start = Duration.zero,
    Duration? length,
  }) async {
    _loop = loop;
    if (_url == url && _controller != null) {
      await setClip(start, length);
      await _controller!.play();
      return;
    }
    await stop();
    _url = url;
    _start = start;
    _length = length;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: kMixedAudio,
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (_controller != controller) return;
      controller.addListener(_keepInClip);
      // A clip loops by itself; the whole preview loops in the player.
      await controller.setLooping(loop && _length == null);
      if (_start > Duration.zero) await controller.seekTo(_start);
      await controller.play();
    } catch (_) {
      // A preview that fails to load just stays silent.
    }
  }

  /// Changes the part that plays and jumps to its start.
  Future<void> setClip(Duration start, Duration? length) async {
    _start = start;
    _length = length;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    await c.setLooping(_loop && length == null);
    await c.seekTo(start);
  }

  void _keepInClip() {
    final c = _controller;
    final length = _length;
    if (c == null || length == null || !c.value.isPlaying) return;
    final end = _start + length;
    if (c.value.position >= end || c.value.position < _start) {
      if (_loop) {
        c.seekTo(_start);
      } else {
        c.pause();
      }
    }
  }

  Future<void> pause() async => _controller?.pause();

  Future<void> resume() async => _controller?.play();

  Future<void> stop() async {
    final c = _controller;
    _controller = null;
    _url = null;
    c?.removeListener(_keepInClip);
    await c?.dispose();
  }
}
