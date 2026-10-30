import "dart:async";

import "package:flutter/cupertino.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:video_player/video_player.dart";

import "../../data/sample_feed.dart";
import "../../models/feed_models.dart";
import "../../providers/feed_provider.dart";
import "../../providers/social_providers.dart";
import "../../services/music_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/dialogs.dart";
import "../../widgets/feed_image.dart";
import "../../widgets/gradient_avatar.dart";
import "../../widgets/post_actions.dart";
import "../../widgets/post_layers.dart";
import "../../widgets/shimmer.dart";
import "../channel_profile_page.dart";

const Color _white = Color(0xFFFFFFFF);

/// Full-screen vertical Reels, like Instagram: one video per page, tap to
/// mute, double-tap to like, hold to pause, swipe up for the next one.
class ReelsTab extends ConsumerStatefulWidget {
  /// The Reels tab is the one on screen (videos only play then).
  final bool active;

  const ReelsTab({super.key, this.active = true});

  @override
  ConsumerState<ReelsTab> createState() => _ReelsTabState();
}

class _ReelsTabState extends ConsumerState<ReelsTab> {
  final PageController _pages = PageController();
  int _page = 0;

  /// Sound is shared by all reels, like Instagram.
  bool _muted = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(reelsProvider);
    final mode = ref.watch(reelsModeProvider);

    // Back to the first reel when switching Reels / Friends.
    ref.listen(reelsModeProvider, (_, _) {
      _page = 0;
      if (_pages.hasClients) _pages.jumpToPage(0);
    });

    if (posts.isEmpty) {
      return ColoredBox(
        color: const Color(0xFF000000),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.play_rectangle,
                  color: _white,
                  size: 56,
                ),
                const SizedBox(height: 12),
                Text(
                  mode == ReelsMode.friends
                      ? "When people you follow share reels, they'll show up here."
                      : "No reels for these topics yet.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFA8A8A8)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: const Color(0xFF000000),
      child: PageView.builder(
        controller: _pages,
        scrollDirection: Axis.vertical,
        itemCount: posts.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (context, index) => _ReelPage(
          key: ValueKey(posts[index].id),
          post: posts[index],
          playing: widget.active && index == _page,
          muted: _muted,
          onToggleMute: () => setState(() => _muted = !_muted),
        ),
      ),
    );
  }
}

/// "Reels   Friends ●●●" title of the Reels top bar.
class ReelsHeaderTitle extends ConsumerWidget {
  /// White text (Android's black Reels bar); otherwise the theme's text.
  final bool onDark;

  const ReelsHeaderTitle({super.key, this.onDark = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final mode = ref.watch(reelsModeProvider);
    final me = ref.watch(currentUserIdProvider);
    final friends = me == null
        ? const []
        : (ref.watch(followingListProvider(me)).valueOrNull ?? const []);
    final active = onDark ? _white : colors.text;
    const inactive = Color(0xFF8E8E8E);

    Widget label(String text, ReelsMode m) => Semantics(
      button: true,
      selected: mode == m,
      child: GestureDetector(
        onTap: () => ref.read(reelsModeProvider.notifier).set(m),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: mode == m ? active : inactive,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );

    final faces = friends.take(3).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        label("Reels", ReelsMode.forYou),
        const SizedBox(width: 18),
        label("Friends", ReelsMode.friends),
        if (faces.isNotEmpty) ...[
          const SizedBox(width: 6),
          SizedBox(
            width: 22.0 + (faces.length - 1) * 12,
            height: 22,
            child: Stack(
              children: [
                for (int i = 0; i < faces.length; i++)
                  Positioned(
                    left: i * 12.0,
                    child: GradientAvatar(
                      name: faces[i].username,
                      imageUrls: faces[i].avatarUrls,
                      size: 22,
                      ring: false,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Reels filter: choose the topics you want to see.
void showReelTopics(BuildContext context) {
  showIgSheet<void>(
    context,
    builder: (_) => Consumer(
      builder: (context, ref, _) {
        final colors = AppColors.of(context);
        final picked = ref.watch(reelTopicsProvider);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  "Your algorithm",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  "Choose topics to see more of in Reels.",
                  style: TextStyle(color: colors.secondaryText),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in FeedCategory.values)
                    GestureDetector(
                      onTap: () =>
                          ref.read(reelTopicsProvider.notifier).toggle(c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: picked.contains(c)
                              ? colors.text
                              : colors.field,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          c.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: picked.contains(c)
                                ? colors.background
                                : colors.text,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (picked.isNotEmpty)
                Center(
                  child: CupertinoButton(
                    onPressed: () =>
                        ref.read(reelTopicsProvider.notifier).clear(),
                    child: const Text("Show everything"),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _ReelPage extends ConsumerStatefulWidget {
  final FeedPost post;
  final bool playing;
  final bool muted;
  final VoidCallback onToggleMute;

  const _ReelPage({
    super.key,
    required this.post,
    required this.playing,
    required this.muted,
    required this.onToggleMute,
  });

  @override
  ConsumerState<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends ConsumerState<_ReelPage> {
  VideoPlayerController? _video;
  bool _failed = false;
  bool _holding = false;
  bool _expanded = false;

  /// Heart shown where you double-tapped.
  Offset? _heartAt;

  /// Speaker icon flashed after tapping to mute / unmute.
  bool _showSound = false;
  Timer? _soundTimer;

  /// Hidden behind another tab or page: don't play.
  bool _onScreen = true;

  /// The reel's song (chosen in the editor) plays instead of its sound.
  final PreviewPlayer _song = PreviewPlayer();
  bool _songStarted = false;

  bool get _hasSong => widget.post.music != null;

  bool get _shouldPlay => widget.playing && !_holding && _onScreen;

  @override
  void initState() {
    super.initState();
    if (!widget.post.isVideo) return;
    final url = widget.post.imageUrls.first;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: kMixedAudio,
    );
    _video = controller;
    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          controller
            ..setLooping(true)
            ..setVolume(widget.muted || _hasSong ? 0 : 1);
          setState(() {});
          _sync();
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _onScreen = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(covariant _ReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.muted != widget.muted) {
      _video?.setVolume(widget.muted || _hasSong ? 0 : 1);
      if (_hasSong && widget.muted) _song.pause();
    }
    _sync();
  }

  @override
  void dispose() {
    _soundTimer?.cancel();
    _video?.dispose();
    _song.stop();
    super.dispose();
  }

  void _sync() {
    final v = _video;
    if (v == null || !v.value.isInitialized) return;
    if (_shouldPlay && !v.value.isPlaying) {
      v.play();
    } else if (!_shouldPlay && v.value.isPlaying) {
      v.pause();
    }
    _syncSong();
  }

  void _syncSong() {
    final music = widget.post.music;
    if (music == null) return;
    final play = _shouldPlay && !widget.muted;
    if (play && !_songStarted) {
      _songStarted = true;
      final s = widget.post.musicSticker;
      final chosen = !s.hidden || s.startMs > 0;
      _song.play(
        music.previewUrl,
        start: Duration(milliseconds: chosen ? s.startMs : 0),
        length: chosen ? Duration(milliseconds: s.clipMs) : null,
      );
    } else if (play) {
      _song.resume();
    } else {
      _song.pause();
    }
  }

  void _guard(Future<void> f) => f.catchError((Object e) {
    if (mounted) showToast(context, errorText(e), error: true);
  });

  void _tapMute() {
    widget.onToggleMute();
    _soundTimer?.cancel();
    setState(() => _showSound = true);
    _soundTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showSound = false);
    });
  }

  void _doubleTapLike(Offset at) {
    HapticFeedback.lightImpact();
    _guard(ref.read(postActionsProvider).like(widget.post));
    setState(() => _heartAt = at);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _heartAt = null);
    });
  }

  void _openAuthor(FeedPost post) {
    if (post.author == null) {
      openChannel(context, post.authorName);
    } else {
      openProfile(context, post.author!);
    }
  }

  Widget _media() {
    final post = widget.post;
    if (!post.isVideo) return FeedImage(urls: post.cover);
    final v = _video;
    if (_failed) {
      return const Center(
        child: Icon(CupertinoIcons.video_camera, color: _white, size: 48),
      );
    }
    if (v == null || !v.value.isInitialized) {
      return const Shimmer(child: Bone(radius: 0));
    }
    final size = v.value.size;
    // Landscape videos sit in the middle with black above and below, like
    // Instagram; portrait videos fill the screen.
    final landscape = size.width > size.height;
    Widget video = FittedBox(
      fit: landscape ? BoxFit.contain : BoxFit.cover,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(v),
      ),
    );
    final matrix = videoLookMatrix(post.edits?.video);
    if (matrix != null) {
      video = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: video,
      );
    }
    // Texts and the song sticker from the editor, on the video.
    return PostLayers(post: post, index: 0, playing: _shouldPlay, media: video);
  }

  @override
  Widget build(BuildContext context) {
    // Watch the post so likes and saves update the counts.
    final post = ref.watch(postProvider(widget.post.id)) ?? widget.post;
    final actions = ref.read(postActionsProvider);
    final me = ref.watch(currentUserIdProvider);
    final followingIds = ref.watch(followingProvider).valueOrNull ?? const {};
    final channels = ref.watch(followedChannelsProvider);
    final following = post.remote
        ? followingIds.contains(post.author!.id)
        : channels.contains(post.channel!.handle);
    final mine = post.author?.id == me;

    // Sample reels show believable counts; real ones show real counts.
    final reposted =
        ref.watch(myRepostsProvider).valueOrNull?.contains(post.id) ?? false;
    final reposts =
        (post.remote ? post.baseReposts : post.baseLikes ~/ 52) +
        (reposted ? 1 : 0);
    final shares = post.remote ? 0 : post.baseLikes ~/ 7;
    final saves = post.remote ? 0 : post.baseLikes ~/ 9;

    Widget side(
      IconData icon,
      String label,
      String count,
      VoidCallback onTap, {
      Color? color,
    }) {
      return Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Column(
              children: [
                Icon(icon, color: color ?? _white, size: 29),
                if (count.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    count,
                    style: const TextStyle(
                      color: _white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // The reel runs under the tab bar; on iOS 26 that bar floats over the
    // reel, so the name, caption and buttons sit above it.
    final barLift = bottomBarInset(context) - 12;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tapMute,
      onDoubleTapDown: (d) => _heartAt = d.localPosition,
      onDoubleTap: () => _doubleTapLike(_heartAt ?? Offset.zero),
      onLongPressStart: (_) {
        setState(() => _holding = true);
        _sync();
      },
      onLongPressEnd: (_) {
        setState(() => _holding = false);
        _sync();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          _media(),
          // Shade so the text stays readable.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(0, 0.35),
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x99000000)],
                ),
              ),
            ),
          ),

          // Heart where you double-tapped.
          if (_heartAt != null)
            Positioned(
              left: _heartAt!.dx - 50,
              top: _heartAt!.dy - 50,
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  builder: (_, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: const Icon(
                    CupertinoIcons.heart_fill,
                    size: 100,
                    color: kIgRed,
                  ),
                ),
              ),
            ),

          // Mute / unmute flash.
          if (_showSound)
            Center(
              child: IgnorePointer(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0x99000000),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.muted
                        ? CupertinoIcons.speaker_slash_fill
                        : CupertinoIcons.speaker_2_fill,
                    color: _white,
                    size: 28,
                  ),
                ),
              ),
            ),

          // Paused while holding.
          if (_holding)
            const Center(
              child: IgnorePointer(
                child: Icon(
                  CupertinoIcons.pause_fill,
                  color: Color(0xCCFFFFFF),
                  size: 64,
                ),
              ),
            ),

          // ───── Right column: like, comment, repost, share, save, menu ─────
          Positioned(
            right: 8,
            bottom: 34 + barLift,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                side(
                  post.liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  post.liked ? "Unlike" : "Like",
                  post.likes > 0 ? formatCount(post.likes) : "Likes",
                  () => _guard(actions.toggleLike(post)),
                  color: post.liked ? kIgRed : null,
                ),
                side(
                  CupertinoIcons.chat_bubble,
                  "Comment",
                  post.totalComments > 0 ? formatCount(post.totalComments) : "",
                  () => openComments(context, post),
                ),
                side(
                  CupertinoIcons.arrow_2_squarepath,
                  reposted ? "Undo repost" : "Repost",
                  reposts > 0 ? compactCount(reposts) : "",
                  () => toggleRepost(context, ref, post),
                  color: reposted ? const Color(0xFF2ECC71) : null,
                ),
                side(
                  CupertinoIcons.paperplane,
                  "Share",
                  shares > 0 ? compactCount(shares) : "",
                  () => sharePost(context, ref, post),
                ),
                side(
                  post.saved
                      ? CupertinoIcons.bookmark_fill
                      : CupertinoIcons.bookmark,
                  post.saved ? "Remove from saved" : "Save",
                  saves > 0 ? compactCount(saves) : "",
                  () => _guard(actions.toggleSave(post)),
                ),
                side(
                  CupertinoIcons.line_horizontal_3,
                  "More",
                  "",
                  () => showPostMenu(context, ref, post),
                ),
              ],
            ),
          ),

          // ───── Bottom left: account, follow, caption ─────
          Positioned(
            left: 14,
            right: 72,
            bottom: 20 + barLift,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _openAuthor(post),
                      child: GradientAvatar(
                        name: post.authorName,
                        imageUrls: post.remote
                            ? post.authorAvatar
                            : channelAvatar(post.authorName),
                        size: 34,
                        ring: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: GestureDetector(
                        onTap: () => _openAuthor(post),
                        child: Text(
                          post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    if (post.verified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        size: 14,
                        color: _white,
                      ),
                    ],
                    if (!mine && !following) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          if (post.remote) {
                            _guard(
                              ref
                                  .read(followingProvider.notifier)
                                  .toggle(post.author!.id),
                            );
                          } else {
                            ref
                                .read(followedChannelsProvider.notifier)
                                .toggle(post.channel!.handle);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xCCFFFFFF)),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Text(
                            "Follow",
                            style: TextStyle(
                              color: _white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (post.caption.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      post.caption,
                      maxLines: _expanded ? 6 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _white, fontSize: 14),
                    ),
                  ),
                ],
                if (post.location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.location_solid,
                        size: 13,
                        color: _white,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          post.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ───── Progress line ─────
          if (_video != null && _video!.value.isInitialized)
            Positioned(
              left: 14,
              right: 14,
              bottom: 8 + barLift,
              child: IgnorePointer(
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _video!,
                  builder: (_, value, _) {
                    final total = value.duration.inMilliseconds;
                    final done = total == 0
                        ? 0.0
                        : (value.position.inMilliseconds / total).clamp(
                            0.0,
                            1.0,
                          );
                    return Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: const Color(0x55FFFFFF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: done,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
