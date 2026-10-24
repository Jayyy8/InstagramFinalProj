import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/feed_models.dart";
import "../services/music_service.dart";

/// The song of one post at a time, played when you tap its music line or
/// speaker. The state is the id of the post playing (null = silent).
class PostMusicNotifier extends Notifier<String?> {
  final PreviewPlayer _player = PreviewPlayer();

  @override
  String? build() {
    ref.onDispose(_player.stop);
    return null;
  }

  Future<void> toggle(FeedPost post) async {
    final music = post.music;
    if (music == null) return;
    if (state == post.id) {
      await stop();
      return;
    }
    state = post.id;
    await _player.play(music.previewUrl);
  }

  Future<void> stop() async {
    state = null;
    await _player.stop();
  }

  /// Stops when [postId] is the one playing (its card left the screen).
  void stopIf(String postId) {
    if (state == postId) stop();
  }
}

final postMusicProvider = NotifierProvider<PostMusicNotifier, String?>(
  PostMusicNotifier.new,
);
