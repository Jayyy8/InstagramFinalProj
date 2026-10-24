import "dart:async";
import "dart:io";

import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";

import "../../models/social_models.dart";
import "../../services/music_service.dart";
import "../../services/photo_editing.dart";
import "../../theme/app_theme.dart";
import "../../widgets/dialogs.dart";
import "../../widgets/edited_photo.dart";
import "../../widgets/feed_image.dart";
import "../../widgets/music_picker.dart";
import "../../widgets/post_video.dart";
import "post_details_page.dart";

/// One photo or video going into a post, with its edits.
class PostMedia {
  final XFile file;
  final bool video;

  /// Width / height (photos); found when the editor opens if unknown.
  double? aspect;
  final PhotoEdit edit = PhotoEdit();

  PostMedia({required this.file, required this.video, this.aspect});
}

/// The editor after "Next": Audio, Text, Overlay, Filter, Edit, Ratio.
class PostEditorPage extends ConsumerStatefulWidget {
  final List<PostMedia> media;

  /// Opened from REEL (the post shows in Reels too).
  final bool reel;

  const PostEditorPage({super.key, required this.media, this.reel = false});

  @override
  ConsumerState<PostEditorPage> createState() => _PostEditorPageState();
}

enum _Panel { none, filter, adjust }

class _PostEditorPageState extends ConsumerState<PostEditorPage> {
  final PreviewPlayer _player = PreviewPlayer();
  final PageController _pages = PageController();
  final ImagePicker _picker = ImagePicker();

  late final List<PostMedia> _media = List.of(widget.media);
  int _index = 0;
  PostRatio _ratio = PostRatio.original;
  Music? _music;

  /// First song of "For you", offered in the top pill.
  Music? _suggested;
  _Panel _panel = _Panel.none;
  Adjustment _adjusting = Adjustment.brightness;

  /// Grid shown for a moment after changing the ratio.
  bool _grid = false;
  Timer? _gridTimer;

  /// Text being typed (null = not typing).
  EditText? _typing;
  final TextEditingController _text = TextEditingController();
  Color _textColor = const Color(0xFFFFFFFF);

  /// The "Sharing posts" explainer is shown once per app run.
  static bool _explained = false;

  PostMedia get _current => _media[_index];
  bool get _isVideo => _current.video;

  @override
  void initState() {
    super.initState();
    for (final m in _media) {
      if (!m.video && m.aspect == null) {
        photoSize(m.file.path)
            .then((s) {
              if (mounted) setState(() => m.aspect = s.width / s.height);
            })
            .catchError((_) {
              if (mounted) setState(() => m.aspect = 1);
            });
      }
    }
    MusicService.search("")
        .then((songs) {
          if (mounted && songs.isNotEmpty) {
            setState(() => _suggested = songs.first);
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _player.stop();
    _pages.dispose();
    _gridTimer?.cancel();
    _text.dispose();
    super.dispose();
  }

  // ───────────── Tools ─────────────

  Future<void> _audio() async {
    final music = await showMusicPicker(context);
    if (music == null || !mounted) return;
    setState(() => _music = music);
    await _player.play(music.previewUrl);
  }

  void _audioMenu() {
    final music = _music;
    if (music == null) {
      _audio();
      return;
    }
    showActionSheet(
      context,
      title: music.label,
      actions: [
        SheetAction(
          label: "Change song",
          icon: CupertinoIcons.music_note,
          onTap: _audio,
        ),
        SheetAction(
          label: "Remove song",
          icon: CupertinoIcons.delete,
          destructive: true,
          onTap: () {
            _player.stop();
            setState(() => _music = null);
          },
        ),
      ],
    );
  }

  void _useSuggested() {
    final s = _suggested;
    if (s == null) {
      _audio();
      return;
    }
    setState(() => _music = s);
    _player.play(s.previewUrl);
  }

  bool _photoOnly(String tool) {
    if (!_isVideo) return true;
    showToast(context, "$tool works on photos");
    return false;
  }

  void _startText([EditText? existing]) {
    if (!_photoOnly("Text")) return;
    setState(() {
      _typing = existing ?? EditText(text: "");
      _text.text = existing?.text ?? "";
      _textColor = existing?.color ?? const Color(0xFFFFFFFF);
    });
  }

  void _finishText() {
    final t = _typing;
    if (t == null) return;
    final value = _text.text.trim();
    setState(() {
      final texts = _current.edit.texts;
      if (value.isEmpty) {
        texts.remove(t);
      } else {
        t
          ..text = value
          ..color = _textColor;
        if (!texts.contains(t)) texts.add(t);
      }
      _typing = null;
    });
  }

  Future<void> _overlay() async {
    if (!_photoOnly("Overlay")) return;
    if (_current.edit.overlay != null) {
      _overlayMenu();
      return;
    }
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        imageQuality: 88,
      );
      if (photo == null || !mounted) return;
      setState(() => _current.edit.overlay = EditOverlay(path: photo.path));
      showToast(context, "Drag to move, pinch to resize");
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
  }

  void _overlayMenu() {
    showActionSheet(
      context,
      actions: [
        SheetAction(
          label: "Remove overlay",
          icon: CupertinoIcons.delete,
          destructive: true,
          onTap: () => setState(() => _current.edit.overlay = null),
        ),
      ],
    );
  }

  void _ratioTool() {
    if (!_photoOnly("Ratio")) return;
    _gridTimer?.cancel();
    setState(() {
      _ratio = _ratio.next;
      _grid = true;
    });
    showToast(context, _ratio.label);
    _gridTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _grid = false);
    });
  }

  // ───────────── Next ─────────────

  Future<void> _next() async {
    _player.pause();
    if (!_explained) {
      _explained = true;
      await showSharingPostsInfo(context);
      if (!mounted) return;
    }
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => PostDetailsPage(
          media: _media,
          ratio: _ratio,
          music: _music,
          reel: widget.reel,
        ),
      ),
    );
    if (mounted && _music != null) _player.resume();
  }

  // ───────────── Layout ─────────────

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return CupertinoTheme(
      data: kDarkTheme,
      child: PlainPage(
        background: const Color(0xFF000000),
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: padding.top),
                _topBar(),
                Expanded(child: _preview()),
                const SizedBox(height: 10),
                if (_panel == _Panel.filter)
                  _filterPanel()
                else if (_panel == _Panel.adjust)
                  _adjustPanel()
                else ...[
                  _toolRow(),
                  const SizedBox(height: 14),
                  _bottomRow(),
                ],
                SizedBox(height: padding.bottom + 8),
              ],
            ),
            if (_typing != null) _textEditor(padding),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    final music = _music ?? _suggested;
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            onPressed: () => Navigator.of(context).pop(),
            child: const Icon(
              CupertinoIcons.xmark,
              color: Color(0xFFFFFFFF),
              size: 24,
              semanticLabel: "Back",
            ),
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _music != null ? _audioMenu : _audio,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 240),
                  padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF262626),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: music?.artworkUrl == null
                              ? const ColoredBox(
                                  color: Color(0xFF363636),
                                  child: Icon(
                                    CupertinoIcons.music_note_2,
                                    size: 16,
                                    color: Color(0xFFFFFFFF),
                                  ),
                                )
                              : FeedImage(urls: [music!.artworkUrl!]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              music == null ? "Add audio" : music.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _music != null
                                  ? "Tap to change"
                                  : "Suggested audio",
                              style: const TextStyle(
                                color: Color(0xFFA8A8A8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (_music == null)
                        GestureDetector(
                          onTap: _useSuggested,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xFF363636),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.add,
                              size: 16,
                              color: Color(0xFFFFFFFF),
                              semanticLabel: "Use suggested audio",
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 52),
        ],
      ),
    );
  }

  Widget _preview() {
    return PageView.builder(
      controller: _pages,
      itemCount: _media.length,
      // Dragging texts must not swipe to the next photo.
      physics: _media.length > 1
          ? const PageScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      onPageChanged: (i) => setState(() {
        _index = i;
        _panel = _Panel.none;
      }),
      itemBuilder: (context, i) {
        final m = _media[i];
        if (m.video) {
          return Center(
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: PostVideo(
                key: ValueKey(m.file.path),
                url: m.file.path,
                autoplay: true,
              ),
            ),
          );
        }
        final aspect = m.aspect;
        if (aspect == null) {
          return const Center(
            child: CupertinoActivityIndicator(color: Color(0xFFFFFFFF)),
          );
        }
        return Center(
          child: Stack(
            children: [
              EditedPhoto(
                path: m.file.path,
                edit: m.edit,
                ratio: _ratio,
                aspect: aspect,
                interactive: true,
                onTextTap: _startText,
                onOverlayTap: _overlayMenu,
                onChanged: () => setState(() {}),
              ),
              if (_grid && i == _index)
                Positioned.fill(
                  child: IgnorePointer(child: CustomPaint(painter: _Grid())),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _toolRow() {
    final tools = <(IconData, String, VoidCallback, bool)>[
      (CupertinoIcons.music_note_2, "Audio", _audio, true),
      (CupertinoIcons.textformat, "Text", () => _startText(), !_isVideo),
      (CupertinoIcons.square_stack, "Overlay", _overlay, !_isVideo),
      (
        CupertinoIcons.wand_stars,
        "Filter",
        () {
          if (_photoOnly("Filter")) setState(() => _panel = _Panel.filter);
        },
        !_isVideo,
      ),
      (
        CupertinoIcons.slider_horizontal_3,
        "Edit",
        () {
          if (_photoOnly("Edit")) setState(() => _panel = _Panel.adjust);
        },
        !_isVideo,
      ),
      (CupertinoIcons.crop, "Ratio", _ratioTool, !_isVideo),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final (icon, label, onTap, enabled) in tools)
            Semantics(
              button: true,
              label: label,
              child: GestureDetector(
                onTap: onTap,
                child: Opacity(
                  opacity: enabled ? 1 : 0.4,
                  child: Container(
                    width: 52,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 20, color: const Color(0xFFFFFFFF)),
                        const SizedBox(height: 3),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 10,
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
    );
  }

  Widget _bottomRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (int i = 0; i < _media.length; i++)
                    GestureDetector(
                      onTap: () => _pages.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                      child: Container(
                        width: 36,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: i == _index
                                ? const Color(0xFFFFFFFF)
                                : const Color(0x00000000),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: _media[i].video
                              ? const ColoredBox(
                                  color: Color(0xFF363636),
                                  child: Icon(
                                    CupertinoIcons.videocam_fill,
                                    size: 16,
                                    color: Color(0xFFFFFFFF),
                                  ),
                                )
                              : Image.file(
                                  File(_media[i].file.path),
                                  fit: BoxFit.cover,
                                  cacheWidth: 120,
                                ),
                        ),
                      ),
                    ),
                  // Back to the gallery to change the selection.
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF262626),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        CupertinoIcons.add,
                        size: 18,
                        color: Color(0xFFFFFFFF),
                        semanticLabel: "Add more",
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Semantics(
            button: true,
            label: "Next",
            child: GestureDetector(
              onTap: _next,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A5DF9),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    Text(
                      "Next",
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      CupertinoIcons.arrow_right,
                      size: 16,
                      color: Color(0xFFFFFFFF),
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

  Widget _panelHeader(String title, VoidCallback onDone) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          const SizedBox(width: 70),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onDone,
              child: const Text(
                "Done",
                style: TextStyle(
                  color: Color(0xFF4F8BFF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPanel() {
    final m = _current;
    return Column(
      children: [
        _panelHeader("Filter", () => setState(() => _panel = _Panel.none)),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: PhotoFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final f = PhotoFilter.values[i];
              final on = m.edit.filter == f;
              return GestureDetector(
                onTap: () => setState(() => m.edit.filter = f),
                child: Column(
                  children: [
                    Text(
                      f.label,
                      style: TextStyle(
                        color: on
                            ? const Color(0xFFFFFFFF)
                            : const Color(0xFFA8A8A8),
                        fontSize: 12,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 72,
                      height: 86,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: on
                              ? const Color(0xFFFFFFFF)
                              : const Color(0x00000000),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: ColorFiltered(
                          colorFilter: ColorFilter.matrix(f.matrix),
                          child: Image.file(
                            File(m.file.path),
                            fit: BoxFit.cover,
                            cacheWidth: 200,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _adjustPanel() {
    final edit = _current.edit;
    final a = _adjusting;
    final value = edit.adjust[a] ?? 0;
    return Column(
      children: [
        _panelHeader("Edit", () => setState(() => _panel = _Panel.none)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: CupertinoSlider(
                  value: value,
                  min: a.min,
                  max: 1,
                  activeColor: const Color(0xFFFFFFFF),
                  onChanged: (v) => setState(() => edit.adjust[a] = v),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  "${(value * 100).round()}",
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Color(0xFFFFFFFF)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 64,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final adj in Adjustment.values)
                GestureDetector(
                  onTap: () => setState(() => _adjusting = adj),
                  onDoubleTap: () => setState(() => edit.adjust[adj] = 0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: adj == a
                                  ? const Color(0xFFFFFFFF)
                                  : const Color(0xFF555555),
                            ),
                          ),
                          child: Icon(
                            adj.icon,
                            size: 18,
                            color: (edit.adjust[adj] ?? 0) != 0
                                ? const Color(0xFF4F8BFF)
                                : const Color(0xFFFFFFFF),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          adj.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: adj == a
                                ? const Color(0xFFFFFFFF)
                                : const Color(0xFFA8A8A8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _textEditor(EdgeInsets padding) {
    const swatches = [
      Color(0xFFFFFFFF),
      Color(0xFF000000),
      Color(0xFF3897F0),
      Color(0xFF70C050),
      Color(0xFFFDCB5C),
      Color(0xFFFD8D32),
      Color(0xFFED4956),
      Color(0xFFD10869),
      Color(0xFFA307BA),
    ];
    return Positioned.fill(
      child: GestureDetector(
        onTap: _finishText,
        child: ColoredBox(
          color: const Color(0xB3000000),
          child: Column(
            children: [
              SizedBox(height: padding.top + 6),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: CupertinoTextField(
                      controller: _text,
                      autofocus: true,
                      maxLines: null,
                      textAlign: TextAlign.center,
                      cursorColor: _textColor,
                      decoration: null,
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final c in swatches)
                      GestureDetector(
                        onTap: () => setState(() => _textColor = c),
                        child: Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFFFFFF),
                              width: c == _textColor ? 3 : 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: MediaQuery.viewInsetsOf(context).bottom + 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rule-of-thirds lines shown while changing the ratio.
class _Grid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xB3FFFFFF)
      ..strokeWidth = 1;
    for (int i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    canvas.drawRect(
      Offset.zero & size,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// "Sharing posts" explainer, shown before the details page.
Future<void> showSharingPostsInfo(BuildContext context) {
  return showIgSheet<void>(
    context,
    builder: (sheetContext) {
      final colors = AppColors.of(sheetContext);
      Widget row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: colors.text),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 14, color: colors.text, height: 1.3),
              ),
            ),
          ],
        ),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text(
            "Sharing posts",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 16),
          row(
            CupertinoIcons.globe,
            "Posts shared with Everyone can be discovered by anyone, who can "
            "also follow you.",
          ),
          row(
            CupertinoIcons.person_2,
            "Choose who sees each post with Audience: Everyone, Followers, "
            "Friends, Close Friends or only you.",
          ),
          row(
            CupertinoIcons.slider_horizontal_3,
            "You can change who sees a post any time from its ••• menu.",
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: const Color(0xFF4A5DF9),
                borderRadius: BorderRadius.circular(12),
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text(
                  "OK",
                  style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
    },
  );
}
