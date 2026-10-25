import "dart:async";

import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:video_player/video_player.dart";

import "../models/audience.dart";
import "../models/feed_models.dart";
import "../models/social_models.dart";
import "../navigation.dart";
import "../providers/chat_provider.dart";
import "../providers/social_providers.dart";
import "../providers/story_provider.dart";
import "../services/music_service.dart";
import "../theme/app_theme.dart";
import "../widgets/audience_picker.dart";
import "../widgets/dialogs.dart";
import "../widgets/feed_image.dart";
import "../widgets/gradient_avatar.dart";
import "../widgets/music_picker.dart";
import "../widgets/music_sticker.dart";
import "channel_profile_page.dart";
import "profile_page.dart";
import "story_create_page.dart";

/// Full-screen stories. Swipe sideways between accounts, tap right = next,
/// tap left = back, hold = pause, swipe down = close.
class StoryViewerPage extends StatefulWidget {
  final List<StoryGroup> groups;
  final int initialIndex;

  const StoryViewerPage({
    super.key,
    required this.groups,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  double _dragY = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _nextGroup(int current) {
    if (current < widget.groups.length - 1) {
      _pages.animateToPage(
        current + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _previousGroup(int current) {
    if (current > 0) {
      _pages.animateToPage(
        current - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return PlainPage(
      background: const Color(0xFF000000),
      child: GestureDetector(
        onVerticalDragUpdate: (d) {
          if (d.delta.dy > 0 || _dragY > 0) {
            setState(() => _dragY = (_dragY + d.delta.dy).clamp(0, height));
          }
        },
        onVerticalDragEnd: (d) {
          if (_dragY > 120 || (d.primaryVelocity ?? 0) > 700) {
            Navigator.of(context).maybePop();
          } else {
            setState(() => _dragY = 0);
          }
        },
        child: Transform.translate(
          offset: Offset(0, _dragY),
          child: Transform.scale(
            scale: 1 - (_dragY / height) * 0.3,
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.groups.length,
              itemBuilder: (context, i) => _StoryGroupView(
                key: ValueKey(widget.groups[i].key),
                group: widget.groups[i],
                paused: _dragY > 0,
                onFinished: () => _nextGroup(i),
                onBeforeFirst: () => _previousGroup(i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryGroupView extends ConsumerStatefulWidget {
  final StoryGroup group;
  final bool paused;
  final VoidCallback onFinished;
  final VoidCallback onBeforeFirst;

  const _StoryGroupView({
    super.key,
    required this.group,
    required this.paused,
    required this.onFinished,
    required this.onBeforeFirst,
  });

  @override
  ConsumerState<_StoryGroupView> createState() => _StoryGroupViewState();
}

class _StoryGroupViewState extends ConsumerState<_StoryGroupView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  final TextEditingController _reply = TextEditingController();
  final FocusNode _replyFocus = FocusNode();

  VideoPlayerController? _video;

  /// Song of the current story.
  final PreviewPlayer _audio = PreviewPlayer();
  int _index = 0;
  bool _holding = false;
  bool _liked = false;
  bool _sending = false;

  /// This account's page is the one on screen in the page view.
  bool _visible = false;
  bool _routeCurrent = true;

  List<StorySlide> get _slides => widget.group.slides;
  StorySlide get _slide => _slides[_index];

  @override
  void initState() {
    super.initState();
    // Start at the first story not seen yet.
    final seen = ref.read(seenStoriesProvider);
    final firstUnseen = _slides.indexWhere((s) => !seen.contains(s.id));
    _index = firstUnseen < 0 ? 0 : firstUnseen;

    _progress = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    _replyFocus.addListener(_syncPlayback);
    // After the first frame: _show updates providers (seen stories), which
    // is not allowed while widgets are building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _show();
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    _video?.dispose();
    _audio.stop();
    _reply.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _StoryGroupView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused) _syncPlayback();
  }

  bool get _shouldPause =>
      _holding ||
      widget.paused ||
      _replyFocus.hasFocus ||
      !_visible ||
      !_routeCurrent;

  void _syncPlayback() {
    if (!mounted) return;
    if (_shouldPause) {
      _progress.stop();
      _video?.pause();
      _audio.pause();
    } else if (_progress.duration != null &&
        (_slide.isVideo ? _video?.value.isInitialized == true : true)) {
      _progress.forward();
      _video?.play();
      _audio.resume();
    }
    setState(() {});
  }

  Future<void> _show() async {
    final slide = _slide;
    _progress.stop();
    _progress.value = 0;
    final old = _video;
    _video = null;
    await old?.dispose();
    await _audio.stop();
    _liked = false;

    if (slide.music != null) {
      // The part of the song the owner chose.
      _audio
          .play(
            slide.music!.previewUrl,
            start: Duration(milliseconds: slide.musicSticker.startMs),
            length: Duration(milliseconds: slide.musicSticker.clipMs),
          )
          .then((_) {
            if (mounted && _shouldPause) _audio.pause();
          });
    }

    ref.read(seenStoriesProvider.notifier).markSeen(slide);

    if (slide.remote && !widget.group.isMine) {
      ref
          .read(repositoryProvider)
          .storyLikedByMe(slide.id)
          .then((v) {
            if (mounted && _slide.id == slide.id) setState(() => _liked = v);
          })
          .catchError((_) {});
    }

    if (slide.isVideo) {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(slide.videoUrl!),
        videoPlayerOptions: kMixedAudio,
      );
      _video = controller;
      setState(() {});
      try {
        await controller.initialize();
      } catch (_) {
        if (mounted && _video == controller) _next();
        return;
      }
      if (!mounted || _video != controller) return;
      final length = controller.value.duration;
      _progress.duration = length.inMilliseconds > 0
          ? (length > const Duration(seconds: 60)
                ? const Duration(seconds: 60)
                : length)
          : Duration(milliseconds: slide.durationMs);
      await controller.seekTo(Duration.zero);
      // A song replaces the video's own sound, as in the story editor.
      if (slide.music != null) await controller.setVolume(0);
    } else {
      // Photo slides wait for the photo (see _photoReady), like Instagram:
      // a slow photo must not use up its time while still black.
      _progress.duration = null;
      if (_photoShown == slide.id) _photoReady(slide.id);
    }
    if (mounted) _syncPlayback();
  }

  /// Id of the photo slide whose photo is on screen.
  String? _photoShown;

  void _photoReady(String slideId) {
    _photoShown = slideId;
    if (!mounted || _slide.id != slideId || _slide.isVideo) return;
    if (_progress.duration != null) return;
    _progress.duration = Duration(milliseconds: _slide.durationMs);
    _syncPlayback();
  }

  void _next() {
    if (!mounted) return;
    if (_index < _slides.length - 1) {
      setState(() => _index++);
      _show();
    } else {
      widget.onFinished();
    }
  }

  void _previous() {
    if (_index > 0) {
      setState(() => _index--);
      _show();
    } else {
      widget.onBeforeFirst();
      _show();
    }
  }

  Future<void> _toggleLike() async {
    final slide = _slide;
    final like = !_liked;
    setState(() => _liked = like);
    if (!slide.remote) return;
    try {
      await ref.read(repositoryProvider).setStoryLike(slide.id, like);
    } catch (e) {
      if (mounted) setState(() => _liked = !like);
    }
  }

  Future<void> _sendReply() async {
    final text = _reply.text.trim();
    final profile = widget.group.profile;
    if (text.isEmpty || _sending) return;
    if (profile == null) {
      _reply.clear();
      _replyFocus.unfocus();
      showToast(context, "Message sent");
      return;
    }
    setState(() => _sending = true);
    try {
      await sendDirect(
        ref,
        to: profile.id,
        text: text,
        contextType: "story_reply",
        contextMediaUrl: _slide.previewUrl,
      );
      _reply.clear();
      _replyFocus.unfocus();
      if (mounted) showToast(context, "Message sent");
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openViewers() {
    _holding = true;
    _syncPlayback();
    showIgSheet<void>(
      context,
      heightFactor: 0.55,
      builder: (_) => _ViewersSheet(storyId: _slide.id),
    ).whenComplete(() {
      _holding = false;
      _syncPlayback();
    });
  }

  void _openMenu() {
    _holding = true;
    _syncPlayback();
    final mine = widget.group.isMine;
    showActionSheet(
      context,
      actions: [
        if (mine)
          SheetAction(
            label: "Delete",
            icon: CupertinoIcons.delete,
            destructive: true,
            onTap: () => confirmAction(
              context,
              title: "Delete story?",
              message: "This story will be removed for everyone.",
              confirmLabel: "Delete",
              onConfirm: () async {
                try {
                  await ref.read(storiesProvider.notifier).delete(_slide.id);
                  if (mounted) Navigator.of(context).maybePop();
                } catch (e) {
                  if (mounted) showToast(context, errorText(e), error: true);
                }
              },
            ),
          ),
        if (mine && _slide.remote)
          SheetAction(
            label: "Change audience · ${_slide.audience.label}",
            icon: _slide.audience.icon,
            onTap: () async {
              _holding = true;
              _syncPlayback();
              final picked = await showAudiencePicker(
                context,
                current: _slide.audience,
                title: "Who can see this story?",
              );
              _holding = false;
              _syncPlayback();
              if (picked == null || picked == _slide.audience) return;
              try {
                await ref
                    .read(storiesProvider.notifier)
                    .setAudience(_slide.id, picked);
                if (mounted) {
                  showToast(context, "Now shared with ${picked.label}");
                }
              } catch (e) {
                if (mounted) showToast(context, errorText(e), error: true);
              }
            },
          ),
        if (mine)
          SheetAction(
            label: "Add to your story",
            icon: CupertinoIcons.add_circled,
            onTap: () => pushFullscreen(context, const StoryCreatePage()),
          ),
        if (!mine && widget.group.profile != null)
          SheetAction(
            label: "View profile",
            icon: CupertinoIcons.person,
            onTap: () {
              final p = widget.group.profile!;
              push(context, ProfilePage(userId: p.id, initial: p));
            },
          ),
        if (!mine)
          SheetAction(
            label: "Report",
            icon: CupertinoIcons.exclamationmark_bubble,
            destructive: true,
            onTap: () => showToast(context, "Thanks for letting us know"),
          ),
      ],
    ).whenComplete(() {
      _holding = false;
      _syncPlayback();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pause while another page (a profile, a sheet) covers the stories.
    final routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (routeCurrent != _routeCurrent) {
      _routeCurrent = routeCurrent;
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncPlayback());
    }

    final group = widget.group;
    final slide = _slide;
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return VisibilityProbe(
      onVisible: (v) {
        if (v != _visible) {
          _visible = v;
          _syncPlayback();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ───── Media ─────
          Positioned.fill(
            top: padding.top,
            bottom: padding.bottom + 64,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  if (_replyFocus.hasFocus) {
                    _replyFocus.unfocus();
                    return;
                  }
                  if (details.localPosition.dx < size.width / 3) {
                    _previous();
                  } else {
                    _next();
                  }
                },
                onLongPressStart: (_) {
                  _holding = true;
                  _syncPlayback();
                },
                onLongPressEnd: (_) {
                  _holding = false;
                  _syncPlayback();
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (slide.isVideo)
                      _video != null && _video!.value.isInitialized
                          ? FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _video!.value.size.width,
                                height: _video!.value.size.height,
                                child: VideoPlayer(_video!),
                              ),
                            )
                          : const Center(
                              child: CupertinoActivityIndicator(
                                color: Color(0xFFFFFFFF),
                                radius: 14,
                              ),
                            )
                    else
                      FeedImage(
                        key: ValueKey(slide.id),
                        urls: slide.imageUrls,
                        onReady: () => _photoReady(slide.id),
                      ),
                    // Shade so the header stays readable.
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment(0, -0.6),
                            colors: [Color(0x66000000), Color(0x00000000)],
                          ),
                        ),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, box) => Stack(
                        children: [
                          for (final o in slide.overlays)
                            Positioned(
                              left: o.x * box.maxWidth - box.maxWidth / 2,
                              width: box.maxWidth,
                              top: o.y * box.maxHeight - o.size,
                              child: IgnorePointer(
                                child: StoryOverlayText(overlay: o),
                              ),
                            ),
                          if (slide.location != null &&
                              slide.location!.isNotEmpty)
                            Positioned(
                              top: box.maxHeight * 0.16,
                              left: 24,
                              right: 24,
                              child: IgnorePointer(
                                child: Center(
                                  child: LocationChip(
                                    location: slide.location!,
                                  ),
                                ),
                              ),
                            ),
                          // Where the owner put the song sticker (unless
                          // they hid it; the song plays either way).
                          if (slide.music != null && !slide.musicSticker.hidden)
                            Positioned(
                              left: slide.musicSticker.x * box.maxWidth,
                              top: slide.musicSticker.y * box.maxHeight,
                              child: IgnorePointer(
                                child: FractionalTranslation(
                                  translation: const Offset(-0.5, -0.5),
                                  child: MusicStickerView(
                                    music: slide.music!,
                                    sticker: slide.musicSticker,
                                    maxWidth: box.maxWidth,
                                    spinning: !_shouldPause,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ───── Header: progress bars, account, close ─────
          Positioned(
            left: 0,
            right: 0,
            top: padding.top + 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  _ProgressBars(
                    count: _slides.length,
                    index: _index,
                    progress: _progress,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const SizedBox(width: 4),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (group.profile != null) {
                              push(
                                context,
                                ProfilePage(
                                  userId: group.profile!.id,
                                  initial: group.profile,
                                ),
                              );
                            } else if (!group.isMine) {
                              openChannel(context, group.username);
                            }
                          },
                          child: Row(
                            children: [
                              GradientAvatar(
                                name: group.username,
                                imageUrls: group.avatarUrls,
                                size: 32,
                                ring: false,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            group.isMine
                                                ? (slide.audience ==
                                                          Audience.public
                                                      ? "Your story"
                                                      : "Your story · ${slide.audience.label}")
                                                : group.username,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFFFFFFFF),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (group.verified) ...[
                                          const SizedBox(width: 4),
                                          const Icon(
                                            CupertinoIcons.checkmark_seal_fill,
                                            size: 13,
                                            color: kIgBlue,
                                          ),
                                        ],
                                        const SizedBox(width: 8),
                                        Text(
                                          timeAgoShort(slide.createdAt),
                                          style: const TextStyle(
                                            color: Color(0xCCFFFFFF),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (slide.music != null)
                                      Text(
                                        "♫ ${slide.music!.label}",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xE6FFFFFF),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_holding)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            CupertinoIcons.pause_fill,
                            color: Color(0xFFFFFFFF),
                            size: 18,
                          ),
                        ),
                      _WhiteIcon(
                        icon: CupertinoIcons.ellipsis,
                        onTap: _openMenu,
                      ),
                      _WhiteIcon(
                        icon: CupertinoIcons.xmark,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ───── Footer: reply / activity ─────
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboard > 0 ? keyboard : padding.bottom,
            child: SizedBox(
              height: 64,
              child: group.isMine
                  ? _OwnFooter(
                      onActivity: slide.remote ? _openViewers : null,
                      onMore: _openMenu,
                    )
                  : Row(
                      children: [
                        const SizedBox(width: 12),
                        Expanded(
                          child: CupertinoTextField(
                            controller: _reply,
                            focusNode: _replyFocus,
                            placeholder: "Send message",
                            placeholderStyle: const TextStyle(
                              color: Color(0xCCFFFFFF),
                            ),
                            style: const TextStyle(color: Color(0xFFFFFFFF)),
                            cursorColor: const Color(0xFFFFFFFF),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0x99FFFFFF),
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            onSubmitted: (_) => _sendReply(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (_replyFocus.hasFocus)
                          CupertinoButton(
                            onPressed: _sending ? null : _sendReply,
                            child: const Text(
                              "Send",
                              style: TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else ...[
                          _WhiteIcon(
                            icon: _liked
                                ? CupertinoIcons.heart_fill
                                : CupertinoIcons.heart,
                            color: _liked ? kIgRed : null,
                            size: 28,
                            onTap: _toggleLike,
                          ),
                          _WhiteIcon(
                            icon: CupertinoIcons.paperplane,
                            size: 26,
                            onTap: () => _replyFocus.requestFocus(),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reports whether the story page is the one on screen in the page view.
class VisibilityProbe extends StatefulWidget {
  final Widget child;
  final ValueChanged<bool> onVisible;

  const VisibilityProbe({
    super.key,
    required this.child,
    required this.onVisible,
  });

  @override
  State<VisibilityProbe> createState() => _VisibilityProbeState();
}

class _VisibilityProbeState extends State<VisibilityProbe> {
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position?.removeListener(_check);
    _position = Scrollable.maybeOf(context)?.position;
    _position?.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final dx = box.localToGlobal(Offset.zero).dx.abs();
    widget.onVisible(dx < box.size.width / 2);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _OwnFooter extends StatelessWidget {
  final VoidCallback? onActivity;
  final VoidCallback onMore;

  const _OwnFooter({required this.onActivity, required this.onMore});

  Widget _item(IconData icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFFFFFFF), size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 11,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fixed-size items: no button padding, so nothing overflows the 64 px
    // footer on small or high-density screens.
    return Row(
      children: [
        const SizedBox(width: 6),
        _item(CupertinoIcons.eye, "Activity", onActivity),
        const Spacer(),
        _item(CupertinoIcons.ellipsis_circle, "More", onMore),
        const SizedBox(width: 6),
      ],
    );
  }
}

class _WhiteIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final double size;

  const _WhiteIcon({
    required this.icon,
    required this.onTap,
    this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.all(6),
      minimumSize: const Size(40, 40),
      onPressed: onTap,
      child: Icon(icon, color: color ?? const Color(0xFFFFFFFF), size: size),
    );
  }
}

class _ProgressBars extends StatelessWidget {
  final int count;
  final int index;
  final Animation<double> progress;

  const _ProgressBars({
    required this.count,
    required this.index,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        return Row(
          children: [
            for (int i = 0; i < count; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      height: 2.5,
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: ColoredBox(color: Color(0x59FFFFFF)),
                          ),
                          FractionallySizedBox(
                            widthFactor: i < index
                                ? 1.0
                                : (i == index ? progress.value : 0.0),
                            child: const SizedBox.expand(
                              child: ColoredBox(color: Color(0xFFFFFFFF)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Text placed on a story (also used by the story editor).
class StoryOverlayText extends StatelessWidget {
  final StoryOverlay overlay;

  const StoryOverlayText({super.key, required this.overlay});

  @override
  Widget build(BuildContext context) {
    final color = Color(overlay.color);
    final darkText = color.computeLuminance() > 0.6;
    return Text(
      overlay.text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: overlay.size,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.none,
        shadows: [
          Shadow(
            color: darkText ? const Color(0x99000000) : const Color(0x66000000),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

/// "Activity" sheet on your own story: who viewed it and who liked it.
class _ViewersSheet extends ConsumerWidget {
  final String storyId;

  const _ViewersSheet({required this.storyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    return FutureBuilder(
      future: ref.read(repositoryProvider).storyViewers(storyId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(errorText(snapshot.error!)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CupertinoActivityIndicator());
        }
        final viewers = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Icon(CupertinoIcons.eye, color: colors.text, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "${viewers.length} ${viewers.length == 1 ? 'view' : 'views'}",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 0.5, color: colors.separator),
            Expanded(
              child: viewers.isEmpty
                  ? Center(
                      child: Text(
                        "No views yet",
                        style: TextStyle(color: colors.secondaryText),
                      ),
                    )
                  : ListView.builder(
                      itemCount: viewers.length,
                      itemBuilder: (context, i) {
                        final v = viewers[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              GradientAvatar(
                                name: v.viewer.username,
                                imageUrls: v.viewer.avatarUrls,
                                size: 44,
                                ring: false,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v.viewer.username,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: colors.text,
                                      ),
                                    ),
                                    if (v.viewer.fullName.isNotEmpty)
                                      Text(
                                        v.viewer.fullName,
                                        style: TextStyle(
                                          color: colors.secondaryText,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (v.liked)
                                const Icon(
                                  CupertinoIcons.heart_fill,
                                  color: kIgRed,
                                  size: 20,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
