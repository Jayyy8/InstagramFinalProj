import "dart:io";

import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "package:video_player/video_player.dart";

import "../models/social_models.dart";
import "../providers/social_providers.dart";
import "../providers/story_provider.dart";
import "../services/music_service.dart";
import "../services/social_repository.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "../widgets/gradient_avatar.dart";
import "../widgets/music_picker.dart";
import "story_viewer_page.dart";

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

const List<int> _textColors = [
  0xFFFFFFFF,
  0xFF000000,
  0xFF0095F6,
  0xFF1BD760,
  0xFFFED800,
  0xFFFA7E1E,
  0xFFED4956,
  0xFFD62976,
  0xFF962FBF,
];

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
  final TextEditingController _text = TextEditingController();
  VideoPlayerController? _video;

  /// Index of the text being typed (-1 = new text), null = not editing.
  int? _editing;
  int _color = _textColors.first;
  bool _uploading = false;
  Music? _music;
  String? _location;
  final PreviewPlayer _preview = PreviewPlayer();

  @override
  void initState() {
    super.initState();
    if (widget.video) {
      final controller = VideoPlayerController.file(File(widget.file.path));
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
    _text.dispose();
    super.dispose();
  }

  void _startText([int? index]) {
    setState(() {
      _editing = index ?? -1;
      if (index != null) {
        _text.text = _overlays[index].text;
        _color = _overlays[index].color;
      } else {
        _text.clear();
        _color = _textColors.first;
      }
    });
  }

  void _finishText() {
    final t = _text.text.trim();
    final index = _editing;
    setState(() {
      if (index != null && index >= 0) {
        if (t.isEmpty) {
          _overlays.removeAt(index);
        } else {
          _overlays[index] = _overlays[index].copyWith(text: t, color: _color);
        }
      } else if (t.isNotEmpty) {
        _overlays.add(StoryOverlay(text: t, color: _color));
      }
      _editing = null;
    });
  }

  Future<void> _pickMusic() async {
    final music = await showMusicPicker(context);
    if (music == null || !mounted) return;
    setState(() => _music = music);
    _video?.setVolume(0);
    await _preview.play(music.previewUrl);
  }

  void _musicMenu() {
    showActionSheet(
      context,
      title: _music?.label,
      actions: [
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
            setState(() => _music = null);
          },
        ),
      ],
    );
  }

  Future<void> _pickLocation() async {
    final place = await askLocation(context, current: _location);
    if (place == null || !mounted) return;
    setState(() => _location = place.isEmpty ? null : place);
  }

  Future<void> _share() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    _video?.pause();
    _preview.pause();
    try {
      final length = _video?.value.duration ?? Duration.zero;
      // Photo stories with a song play for 15 seconds, like Instagram.
      final duration = widget.video
          ? length.inMilliseconds.clamp(1000, 60000)
          : (_music != null ? 15000 : 5000);
      await ref
          .read(storiesProvider.notifier)
          .add(
            file: widget.file,
            video: widget.video,
            overlays: _overlays,
            durationMs: duration,
            location: _location,
            music: _music,
          );
      if (!mounted) return;
      showToast(context, "Your story was shared");
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
          // ───── Media with draggable texts ─────
          Positioned.fill(
            top: padding.top,
            bottom: padding.bottom + 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LayoutBuilder(
                builder: (context, box) => Stack(
                  fit: StackFit.expand,
                  children: [
                    media,
                    for (int i = 0; i < _overlays.length; i++)
                      if (_editing != i)
                        Positioned(
                          left:
                              _overlays[i].x * box.maxWidth - box.maxWidth / 2,
                          width: box.maxWidth,
                          top:
                              _overlays[i].y * box.maxHeight -
                              _overlays[i].size,
                          child: Center(
                            child: GestureDetector(
                              onTap: () => _startText(i),
                              onLongPress: () =>
                                  setState(() => _overlays.removeAt(i)),
                              onPanUpdate: (d) => setState(() {
                                final o = _overlays[i];
                                _overlays[i] = o.copyWith(
                                  x: (o.x + d.delta.dx / box.maxWidth).clamp(
                                    0.05,
                                    0.95,
                                  ),
                                  y: (o.y + d.delta.dy / box.maxHeight).clamp(
                                    0.05,
                                    0.95,
                                  ),
                                );
                              }),
                              child: StoryOverlayText(overlay: _overlays[i]),
                            ),
                          ),
                        ),
                    if (_location != null)
                      Positioned(
                        top: box.maxHeight * 0.16,
                        left: 24,
                        right: 24,
                        child: Center(
                          child: LocationChip(
                            location: _location!,
                            onTap: _pickLocation,
                          ),
                        ),
                      ),
                    if (_music != null)
                      Positioned(
                        top: box.maxHeight * 0.7,
                        left: 24,
                        right: 24,
                        child: Center(
                          child: MusicChip(music: _music!, onTap: _musicMenu),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ───── Top tools ─────
          if (_editing == null)
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
                    semantics: "Add music",
                    icon: CupertinoIcons.music_note_2,
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

          // ───── Bottom: share ─────
          if (_editing == null)
            Positioned(
              left: 12,
              right: 12,
              bottom: padding.bottom + 12,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _share,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF262626),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            GradientAvatar(
                              name: me?.username ?? "",
                              imageUrls: me?.avatarUrls,
                              size: 32,
                              ring: false,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              "Your story",
                              style: TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _share,
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
                ],
              ),
            ),

          // ───── Typing a text ─────
          if (_editing != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: _finishText,
                child: ColoredBox(
                  color: const Color(0x99000000),
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: padding.top + 8,
                      bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
                    ),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: CupertinoButton(
                            onPressed: _finishText,
                            child: const Text(
                              "Done",
                              style: TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: CupertinoTextField(
                              controller: _text,
                              autofocus: true,
                              textAlign: TextAlign.center,
                              maxLines: null,
                              decoration: null,
                              cursorColor: Color(_color),
                              style: TextStyle(
                                color: Color(_color),
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            children: [
                              for (final c in _textColors)
                                GestureDetector(
                                  onTap: () => setState(() => _color = c),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(c),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFFFFFFF),
                                        width: c == _color ? 3 : 1.5,
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

  const _RoundTool({
    this.icon,
    this.label,
    this.semantics,
    required this.onTap,
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
        decoration: const BoxDecoration(
          color: Color(0x66000000),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, color: const Color(0xFFFFFFFF), size: 22)
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
