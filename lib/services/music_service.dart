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
          ),
    ];
  }
}

/// Plays one song preview at a time (stories, notes, the song picker).
/// video_player plays audio-only URLs too, so no extra audio package.
class PreviewPlayer {
  VideoPlayerController? _controller;
  String? _url;

  String? get url => _url;
  bool get isPlaying => _controller?.value.isPlaying ?? false;

  Future<void> play(String url, {bool loop = true}) async {
    if (_url == url && _controller != null) {
      await _controller!.play();
      return;
    }
    await stop();
    _url = url;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    try {
      await controller.initialize();
      if (_controller != controller) return;
      await controller.setLooping(loop);
      await controller.play();
    } catch (_) {
      // A preview that fails to load just stays silent.
    }
  }

  Future<void> pause() async => _controller?.pause();

  Future<void> resume() async => _controller?.play();

  Future<void> stop() async {
    final c = _controller;
    _controller = null;
    _url = null;
    await c?.dispose();
  }
}
