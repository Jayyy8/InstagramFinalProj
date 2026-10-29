import "dart:io";

import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "package:video_player/video_player.dart";

import "../models/audience.dart";
import "../models/social_models.dart";
import "../providers/social_providers.dart";
import "../providers/story_provider.dart";
import "../services/music_service.dart";
import "../services/social_repository.dart";
import "../theme/app_theme.dart";
import "../widgets/audience_picker.dart";
import "../widgets/dialogs.dart";
import "../widgets/gradient_avatar.dart";
import "../widgets/music_picker.dart";
import "../widgets/music_sticker.dart";
import "../widgets/story_text.dart";
import "../widgets/text_editor.dart";
import "music_sticker_editor.dart";

/// "Add to story": choose where the photo or video comes from.
class StoryCreatePage extends ConsumerStatefulWidget {
  const StoryCreatePage({super.key});

  @override
  ConsumerState<StoryCreatePage> createState() => _StoryCreatePageState();
}

class _StoryCreatePageState extends ConsumerState<StoryCreatePage> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  Future<void> _pick(Future<XFile?> Function() pick) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await pick();
      if (file == null || !mounted) return;
      final video = SocialRepository.isVideoFile(file);
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => StoryEditorPage(file: file, video: video),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } catch (e) {
      if (mounted) {
        showInfo(
          context,
          title: "Couldn't open media",
          message:
              "Allow access to your camera and photos in Settings, then try again.\n\n${errorText(e)}",
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);

    final options = [
      (
        CupertinoIcons.camera_fill,
        "Camera",
        () => _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1440,
        ),
      ),
      (
        CupertinoIcons.videocam_fill,
        "Video",
        () => _picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(seconds: 60),
        ),
      ),
      (
        CupertinoIcons.photo_fill_on_rectangle_fill,
        "Gallery",
        () => _picker.pickMedia(imageQuality: 85, maxWidth: 1440),
      ),
    ];

    return PlainPage(
      background: const Color(0xFF000000),
      child: Padding(
        padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      "Add to story",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (final (icon, label, pick) in options)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => _pick(pick),
                          child: Container(
                            height: 96,
                            decoration: BoxDecoration(
                              color: const Color(0xFF262626),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  icon,
                                  color: const Color(0xFFFFFFFF),
                                  size: 30,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  label,
                                  style: const TextStyle(
                                    color: Color(0xFFFFFFFF),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: _busy
                    ? const CupertinoActivityIndicator(
                        color: Color(0xFFFFFFFF),
                        radius: 14,
                      )
                    : const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          "Share a photo or a video up to 60 seconds.\nYour story disappears after 24 hours.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFA8A8A8),
                            fontSize: 14,
                            height: 1.4,
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

/// Preview of the picked photo / video with text tools, then share.
class StoryEditorPage extends ConsumerStatefulWidget {
  final XFile file;
  final bool video;

  const StoryEditorPage({super.key, required this.file, required this.video});

  @override
  ConsumerState<StoryEditorPage> createState() => _StoryEditorPageState();
}

class _StoryEditorPageState extends ConsumerState<StoryEditorPage> {
  final List<StoryOverlay> _overlays = [];
  VideoPlayerController? _video;

  /// Index of the text being typed (-1 = new text), null = not editing.
  int? _editing;
  bool _uploading = false;
  Music? _music;

  /// Where the song sticker sits (drag / pinch it), or hidden.
  MusicSticker _sticker = const MusicSticker();

  /// Where the location sticker sits and its size.
  LocationSticker _place = const LocationSticker();

  /// What a drag / pinch is moving: "music", "place" or "text:" + index.
  String? _target;
  double _targetStartSize = 1;
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _musicKey = GlobalKey();
  final GlobalKey _placeKey = GlobalKey();
  final List<GlobalKey> _textKeys = [];

  /// The sticker editor is open (the story's own sticker hides meanwhile).
  bool _editingSticker = false;
  String? _location;
  final PreviewPlayer _preview = PreviewPlayer();

  @override
  void initState() {
    super.initState();
    if (widget.video) {
      final controller = VideoPlayerController.file(
        File(widget.file.path),
        videoPlayerOptions: kMixedAudio,
      );
      _video = controller;
      controller.initialize().then((_) {
        if (!mounted) return;
        controller
          ..setLooping(true)
          ..play();
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    _preview.stop();
    super.dispose();
  }

  void _startText([int? index]) {
    setState(() => _editing = index ?? -1);
  }

  /// Back from the text editor: a new text, the edited one, or none.
  void _finishText(StoryOverlay? text) {
    final index = _editing;
    setState(() {
      if (index != null && index >= 0) {
        if (text == null) {
          _overlays.removeAt(index);
        } else {
          _overlays[index] = text;
        }
      } else if (text != null) {
        _overlays.add(text);
      }
      _editing = null;
    });
  }

  /// Picks a song, then opens the sticker editor like Instagram. Cancel
  /// there keeps the song you had before (or none).
  Future<void> _pickMusic() async {
    final music = await showMusicPicker(context);
    if (music == null || !mounted) return;
    final before = _music;
    _video?.setVolume(0);
    final sticker = await _openStickerEditor(
      music,
      // A new song starts at the beginning; the sticker keeps its place.
      _sticker.copyWith(startMs: 0),
    );
    if (!mounted) return;
    if (sticker != null) {
      setState(() {
        _music = music;
        _sticker = sticker;
      });
    } else if (before != null) {
      _preview.play(
        before.previewUrl,
        start: Duration(milliseconds: _sticker.startMs),
        length: Duration(milliseconds: _sticker.clipMs),
      );
    } else {
      _preview.stop();
      _video?.setVolume(1);
    }
  }

  Future<MusicSticker?> _openStickerEditor(
    Music music,
    MusicSticker sticker,
  ) async {
    setState(() => _editingSticker = true);
    final result = await editMusicSticker(
      context,
      music: music,
      sticker: sticker,
      player: _preview,
    );
    if (mounted) setState(() => _editingSticker = false);
    return result;
  }

  /// Tap the sticker: style, color and clip again.
  Future<void> _editSticker() async {
    final music = _music;
    if (music == null) return;
    final sticker = await _openStickerEditor(music, _sticker);
    if (sticker != null && mounted) setState(() => _sticker = sticker);
  }

  void _musicMenu() {
    showActionSheet(
      context,
      title: _music?.label,
      actions: [
        SheetAction(
          label: _sticker.hidden ? "Show sticker" : "Edit sticker",
          icon: CupertinoIcons.slider_horizontal_3,
          onTap: _editSticker,
        ),
        SheetAction(
          label: "Change song",
          icon: CupertinoIcons.music_note,
          onTap: _pickMusic,
        ),
        SheetAction(
          label: "Remove song",
          icon: CupertinoIcons.delete,
          destructive: true,
          onTap: () {
            _preview.stop();
            _video?.setVolume(1);
            setState(() {
              _music = null;
              _sticker = const MusicSticker();
            });
          },
        ),
      ],
    );
  }

  GlobalKey _textKey(int i) {
    while (_textKeys.length <= i) {
      _textKeys.add(GlobalKey());
    }
    return _textKeys[i];
  }

  /// Where a sticker is on the story, at its drawn size.
  Rect? _rectOf(GlobalKey key, [double scale = 1]) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: stack);
    final rect = topLeft & box.size;
    return Rect.fromCenter(
      center: rect.center,
      width: rect.width * scale,
      height: rect.height * scale,
    );
  }

  /// A finger (or two) went down: pick the sticker under them, or the
  /// closest one for a pinch, like Instagram (pinching a small sticker
  /// with both fingers on it is hard).
  void _grab(Offset at, int fingers) {
    final reach = fingers > 1 ? 90.0 : 14.0;
    final candidates = <(String, Rect?)>[
      for (int i = 0; i < _overlays.length; i++)
        if (_editing != i && i < _textKeys.length)
          ("text:$i", _rectOf(_textKeys[i])),
      if (_location != null) ("place", _rectOf(_placeKey, _place.scale)),
      if (_music != null && !_sticker.hidden)
        ("music", _rectOf(_musicKey, _sticker.scale)),
    ];
    String? best;
    var bestDistance = double.infinity;
    for (final (id, rect) in candidates) {
      if (rect == null || !rect.inflate(reach).contains(at)) continue;
      final d = (rect.center - at).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = id;
      }
    }
    _target = best;
    if (best == "music") {
      _targetStartSize = _sticker.scale;
    } else if (best == "place") {
      _targetStartSize = _place.scale;
    } else if (best != null) {
      _targetStartSize = _overlays[int.parse(best.substring(5))].size;
    }
  }

  void _move(ScaleUpdateDetails d, Size size) {
    final target = _target;
    if (target == null) return;
    final dx = d.focalPointDelta.dx / size.width;
    final dy = d.focalPointDelta.dy / size.height;
    final pinch = d.pointerCount > 1;
    setState(() {
      if (target == "music") {
        _sticker = _sticker.copyWith(
          x: (_sticker.x + dx).clamp(0.08, 0.92),
          y: (_sticker.y + dy).clamp(0.06, 0.94),
          scale: pinch
              ? (_targetStartSize * d.scale).clamp(0.5, 2.8)
              : _sticker.scale,
        );
      } else if (target == "place") {
        _place = _place.copyWith(
          x: (_place.x + dx).clamp(0.08, 0.92),
          y: (_place.y + dy).clamp(0.04, 0.96),
          scale: pinch
              ? (_targetStartSize * d.scale).clamp(0.5, 3.0)
              : _place.scale,
        );
      } else {
        final i = int.parse(target.substring(5));
        if (i >= _overlays.length) return;
        final o = _overlays[i];
        _overlays[i] = o.copyWith(
          x: (o.x + dx).clamp(0.05, 0.95),
          y: (o.y + dy).clamp(0.05, 0.95),
          size: pinch ? (_targetStartSize * d.scale).clamp(14.0, 90.0) : o.size,
        );
      }
    });
  }

  Future<void> _pickLocation() async {
    final place = await askLocation(context, current: _location);
    if (place == null || !mounted) return;
    setState(() => _location = place.isEmpty ? null : place);
  }

  /// Who "Your story" is shared with (starts at the audience used last).
  late Audience _audience =
      ref.read(lastAudienceProvider) == Audience.closeFriends
      ? Audience.public
      : ref.read(lastAudienceProvider);

  Future<void> _pickAudience() async {
    final picked = await showAudiencePicker(
      context,
      current: _audience,
      title: "Who can see your story?",
    );
    if (picked == null || !mounted) return;
    setState(() => _audience = picked);
    ref.read(lastAudienceProvider.notifier).set(picked);
  }

  Future<void> _share(Audience audience) async {
    if (_uploading) return;
    setState(() => _uploading = true);
    _video?.pause();
    _preview.pause();
    try {
      final length = _video?.value.duration ?? Duration.zero;
      // Photo stories with a song play for 15 seconds, like Instagram.
      final duration = widget.video
          ? length.inMilliseconds.clamp(1000, 60000)
          : (_music != null ? _sticker.clipMs : 5000);
      await ref
          .read(storiesProvider.notifier)
          .add(
            file: widget.file,
            video: widget.video,
            overlays: _overlays,
            durationMs: duration,
            location: _location,
            place: _place,
            music: _music,
            sticker: _sticker,
            audience: audience,
          );
      if (!mounted) return;
      showToast(
        context,
        audience == Audience.closeFriends
            ? "Shared with Close Friends"
            : "Your story was shared",
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      _video?.play();
      _preview.resume();
      showInfo(context, title: "Couldn't share story", message: errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final me = ref.watch(myProfileProvider).valueOrNull;

    Widget media;
    if (widget.video) {
      final v = _video;
      media = v != null && v.value.isInitialized
          ? FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: v.value.size.width,
                height: v.value.size.height,
                child: VideoPlayer(v),
              ),
            )
          : const Center(
              child: CupertinoActivityIndicator(color: Color(0xFFFFFFFF)),
            );
    } else {
      media = Image.file(File(widget.file.path), fit: BoxFit.cover);
    }

    return PlainPage(
      background: const Color(0xFF000000),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ───── Media with stickers (drag to move, pinch to resize) ─────
          Positioned.fill(
            top: padding.top,
            bottom: padding.bottom + 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LayoutBuilder(
                builder: (context, box) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (d) => _grab(d.localFocalPoint, d.pointerCount),
                  onScaleUpdate: (d) => _move(d, box.biggest),
                  onScaleEnd: (_) => _target = null,
                  child: Stack(
                    key: _stackKey,
                    fit: StackFit.expand,
                    children: [
                      media,
                      for (int i = 0; i < _overlays.length; i++)
                        if (_editing != i)
                          Positioned(
                            left:
                                _overlays[i].x * box.maxWidth -
                                box.maxWidth / 2,
                            width: box.maxWidth,
                            top:
                                _overlays[i].y * box.maxHeight -
                                _overlays[i].size,
                            child: Center(
                              child: GestureDetector(
                                key: _textKey(i),
                                onTap: () => _startText(i),
                                onLongPress: () =>
                                    setState(() => _overlays.removeAt(i)),
                                child: StoryOverlayText(overlay: _overlays[i]),
                              ),
                            ),
                          ),
                      if (_location != null)
                        Positioned(
                          left: _place.x * box.maxWidth,
                          top: _place.y * box.maxHeight,
                          child: FractionalTranslation(
                            translation: const Offset(-0.5, -0.5),
                            child: GestureDetector(
                              key: _placeKey,
                              onTap: _pickLocation,
                              child: Transform.scale(
                                scale: _place.scale,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: box.maxWidth * 0.8,
                                  ),
                                  child: LocationChip(location: _location!),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Song sticker: tap for its editor, hold for the menu.
                      if (_music != null &&
                          !_sticker.hidden &&
                          !_editingSticker)
                        Positioned(
                          left: _sticker.x * box.maxWidth,
                          top: _sticker.y * box.maxHeight,
                          child: FractionalTranslation(
                            translation: const Offset(-0.5, -0.5),
                            child: GestureDetector(
                              key: _musicKey,
                              onTap: _editSticker,
                              onLongPress: _musicMenu,
                              child: MusicStickerView(
                                music: _music!,
                                sticker: _sticker,
                                maxWidth: box.maxWidth,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ───── Top tools ─────
          if (_editing == null && !_editingSticker)
            Positioned(
              top: padding.top + 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  _RoundTool(
                    icon: CupertinoIcons.xmark,
                    semantics: "Close",
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  _RoundTool(label: "Aa", onTap: _startText),
                  const SizedBox(width: 8),
                  _RoundTool(
                    semantics: _music == null ? "Add music" : "Song options",
                    icon: CupertinoIcons.music_note_2,
                    // Lit while a song is on (handy when its sticker is hidden).
                    active: _music != null,
                    onTap: _music == null ? _pickMusic : _musicMenu,
                  ),
                  const SizedBox(width: 8),
                  _RoundTool(
                    semantics: "Add location",
                    icon: CupertinoIcons.location_solid,
                    onTap: _pickLocation,
                  ),
                ],
              ),
            ),

          // ───── Bottom: who sees it, then share ─────
          if (_editing == null && !_editingSticker)
            Positioned(
              left: 12,
              right: 12,
              bottom: padding.bottom + 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    label: "Your story audience: ${_audience.label}",
                    child: GestureDetector(
                      onTap: _pickAudience,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x99000000),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _audience.icon,
                              size: 15,
                              color: const Color(0xFFFFFFFF),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Your story: ${_audience.label}",
                              style: const TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              CupertinoIcons.chevron_down,
                              size: 12,
                              color: Color(0xFFFFFFFF),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: "Share to your story",
                          child: GestureDetector(
                            onTap: () => _share(_audience),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF262626),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Row(
                                children: [
                                  GradientAvatar(
                                    name: me?.username ?? "",
                                    imageUrls: me?.avatarUrls,
                                    size: 32,
                                    ring: false,
                                  ),
                                  const SizedBox(width: 8),
                                  const Flexible(
                                    child: Text(
                                      "Your story",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Color(0xFFFFFFFF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: "Share to Close Friends",
                          child: GestureDetector(
                            onTap: () => _share(Audience.closeFriends),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF262626),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: const Row(
                                children: [
                                  CircleAvatarStar(),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      "Close Friends",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Color(0xFFFFFFFF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: "Share",
                        child: GestureDetector(
                          onTap: () => _share(_audience),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFFFFF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.arrow_right,
                              color: Color(0xFF000000),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // ───── Typing a text (Instagram's text editor) ─────
          if (_editing != null)
            TextEditorOverlay(
              initial: _editing! >= 0
                  ? _overlays[_editing!]
                  : const StoryOverlay(text: ""),
              onDone: _finishText,
              // Location adds the location sticker, like Instagram.
              onLocation: () async {
                await _pickLocation();
                return null;
              },
            ),

          if (_uploading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x99000000),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoActivityIndicator(
                        color: Color(0xFFFFFFFF),
                        radius: 16,
                      ),
                      SizedBox(height: 12),
                      Text(
                        "Sharing...",
                        style: TextStyle(color: Color(0xFFFFFFFF)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundTool extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String? semantics;
  final VoidCallback onTap;
  final bool active;

  const _RoundTool({
    this.icon,
    this.label,
    this.semantics,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(button: true, label: semantics ?? label, child: _tool());
  }

  Widget _tool() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFFFFF) : const Color(0x66000000),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(
                icon,
                color: active
                    ? const Color(0xFF000000)
                    : const Color(0xFFFFFFFF),
                size: 22,
              )
            : Text(
                label ?? "",
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// Green circle with a star (Close Friends button).
class CircleAvatarStar extends StatelessWidget {
  const CircleAvatarStar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: kCloseFriendsGreen,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        CupertinoIcons.star_fill,
        size: 16,
        color: Color(0xFFFFFFFF),
      ),
    );
  }
}
