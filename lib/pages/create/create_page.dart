import "dart:io";
import "dart:typed_data";

import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "package:photo_manager/photo_manager.dart";

import "../../theme/app_theme.dart";
import "../../widgets/dialogs.dart";
import "../instant_camera_page.dart";
import "../story_create_page.dart";
import "post_editor_page.dart";

/// What the "+" screen makes; switched with the pill at the bottom.
enum CreateMode {
  post("POST", "New post"),
  story("STORY", "Add to story"),
  instants("INSTANTS", "New instant"),
  reel("REEL", "New reel"),
  live("LIVE", "Live");

  final String tab;
  final String title;

  const CreateMode(this.tab, this.title);
}

/// Instagram's create screen: preview on top, your photos below, and
/// POST / STORY / INSTANTS / REEL / LIVE at the bottom.
class CreatePage extends ConsumerStatefulWidget {
  final CreateMode mode;

  const CreatePage({super.key, this.mode = CreateMode.post});

  @override
  ConsumerState<CreatePage> createState() => _CreatePageState();
}

/// Gallery access: still asking, allowed (all or some photos), refused.
enum _Access { asking, allowed, denied }

class _CreatePageState extends ConsumerState<CreatePage> {
  static const int _pageSize = 80;
  static const int _maxPhotos = 10;

  late CreateMode _mode = widget.mode;
  _Access _access = _Access.asking;

  List<AssetPathEntity> _albums = const [];
  AssetPathEntity? _album;
  final List<AssetEntity> _assets = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  /// Shown in the big preview.
  AssetEntity? _current;

  /// Picked for a carousel post, in order ("Select" mode).
  final List<AssetEntity> _selected = [];
  bool _multi = false;
  bool _opening = false;

  final ImagePicker _picker = ImagePicker();
  final ScrollController _scroll = ScrollController();

  /// Thumbnails already loaded, so scrolling doesn't reload them.
  final Map<String, Future<Uint8List?>> _thumbs = {};

  bool get _videosOnly => _mode == CreateMode.reel;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _loadMore();
    });
    _requestAccess();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _requestAccess() async {
    setState(() => _access = _Access.asking);
    try {
      final state = await PhotoManager.requestPermissionExtend();
      if (!mounted) return;
      if (state.hasAccess) {
        setState(() => _access = _Access.allowed);
        await _loadAlbums();
      } else {
        setState(() => _access = _Access.denied);
      }
    } catch (_) {
      if (mounted) setState(() => _access = _Access.denied);
    }
  }

  Future<void> _loadAlbums() async {
    final albums = await PhotoManager.getAssetPathList(
      type: _videosOnly ? RequestType.video : RequestType.common,
    );
    if (!mounted) return;
    setState(() {
      _albums = albums;
      _album = albums.isEmpty ? null : albums.first;
    });
    await _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _assets.clear();
      _page = 0;
      _hasMore = true;
      _selected.clear();
      _current = null;
    });
    await _loadMore();
    if (mounted && _assets.isNotEmpty && _mode != CreateMode.story) {
      setState(() => _current = _assets.first);
    }
  }

  Future<void> _loadMore() async {
    final album = _album;
    if (album == null || !_hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final page = await album.getAssetListPaged(page: _page, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _assets.addAll(page);
        _page++;
        _hasMore = page.length == _pageSize;
      });
    } finally {
      _loadingMore = false;
    }
  }

  Future<Uint8List?> _thumb(AssetEntity a) => _thumbs.putIfAbsent(
    a.id,
    () => a.thumbnailDataWithSize(const ThumbnailSize.square(240)),
  );

  // ───────────── Mode switcher ─────────────

  void _switchMode(CreateMode mode) {
    if (mode == _mode) return;
    switch (mode) {
      case CreateMode.instants:
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (_, _, _) => const InstantCameraPage(),
            transitionsBuilder: (_, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
        return;
      case CreateMode.live:
        showToast(context, "Live video isn't available in this version");
        return;
      default:
        final reloadAlbums =
            (mode == CreateMode.reel) != (_mode == CreateMode.reel);
        setState(() {
          _mode = mode;
          _multi = false;
          _selected.clear();
        });
        if (_access == _Access.allowed) {
          if (reloadAlbums) {
            _loadAlbums();
          } else if (mode == CreateMode.story) {
            setState(() => _current = null);
          } else if (_current == null && _assets.isNotEmpty) {
            setState(() => _current = _assets.first);
          }
        }
    }
  }

  // ───────────── Picking ─────────────

  void _tap(AssetEntity a) {
    if (_mode == CreateMode.story) {
      _openStory(a);
      return;
    }
    setState(() {
      if (!_multi || _mode == CreateMode.reel) {
        _current = a;
        return;
      }
      final i = _selected.indexWhere((s) => s.id == a.id);
      if (i < 0) {
        if (_selected.length >= _maxPhotos) {
          showToast(context, "You can choose up to $_maxPhotos");
          return;
        }
        _selected.add(a);
        _current = a;
      } else if (_current?.id == a.id) {
        _selected.removeAt(i);
        _current = _selected.isEmpty ? a : _selected.last;
      } else {
        _current = a;
      }
    });
  }

  void _toggleMulti() {
    setState(() {
      _multi = !_multi;
      _selected.clear();
      if (_multi && _current != null) _selected.add(_current!);
    });
  }

  /// The chosen photo / video as a file small enough to upload.
  Future<PostMedia?> _mediaOf(AssetEntity a) async {
    if (a.type == AssetType.video) {
      final file = await a.file;
      if (file == null) return null;
      return PostMedia(file: XFile(file.path), video: true);
    }
    // A JPEG at most 1440 px wide (photos straight from the camera are
    // far bigger than a post needs).
    final w = a.orientatedWidth.toDouble();
    final h = a.orientatedHeight.toDouble();
    final scale = w > 1440 ? 1440 / w : 1.0;
    final bytes = await a.thumbnailDataWithOption(
      ThumbnailOption(
        size: ThumbnailSize((w * scale).round(), (h * scale).round()),
        format: ThumbnailFormat.jpeg,
        quality: 90,
      ),
    );
    if (bytes == null) return null;
    final dir = await Directory.systemTemp.createTemp("pick");
    final file = File("${dir.path}/${a.id.hashCode.abs()}.jpg");
    await file.writeAsBytes(bytes, flush: true);
    return PostMedia(
      file: XFile(file.path, mimeType: "image/jpeg"),
      video: false,
      aspect: h == 0 ? 1 : w / h,
    );
  }

  Future<void> _next() async {
    if (_opening) return;
    final picks = _multi && _selected.isNotEmpty
        ? List.of(_selected)
        : [?_current];
    if (picks.isEmpty) {
      showToast(context, "Choose a photo or video first");
      return;
    }
    if (picks.length > 1 && picks.any((a) => a.type == AssetType.video)) {
      showToast(context, "Videos are posted on their own");
      return;
    }
    setState(() => _opening = true);
    try {
      final media = <PostMedia>[];
      for (final a in picks) {
        final m = await _mediaOf(a);
        if (m != null) media.add(m);
      }
      if (!mounted) return;
      if (media.isEmpty) {
        showToast(context, "Couldn't open that file", error: true);
        return;
      }
      await _openEditor(media);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _openEditor(List<PostMedia> media) {
    return Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) =>
            PostEditorPage(media: media, reel: _mode == CreateMode.reel),
      ),
    );
  }

  Future<void> _openStory(AssetEntity a) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final file = await a.file;
      if (file == null || !mounted) return;
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => StoryEditorPage(
            file: XFile(file.path),
            video: a.type == AssetType.video,
          ),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  /// The camera tile.
  Future<void> _camera() async {
    try {
      final video = _mode == CreateMode.reel;
      final shot = video
          ? await _picker.pickVideo(
              source: ImageSource.camera,
              maxDuration: const Duration(seconds: 90),
            )
          : await _picker.pickImage(
              source: ImageSource.camera,
              imageQuality: 88,
              maxWidth: 1440,
            );
      if (shot == null || !mounted) return;
      await _openPicked([shot], video: video);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
  }

  /// Without gallery access: the phone's own photo picker.
  Future<void> _systemPicker() async {
    try {
      if (_mode == CreateMode.reel) {
        final v = await _picker.pickVideo(source: ImageSource.gallery);
        if (v != null && mounted) await _openPicked([v], video: true);
        return;
      }
      final picked = await _picker.pickMultipleMedia(
        imageQuality: 88,
        maxWidth: 1440,
        limit: _mode == CreateMode.story ? 1 : _maxPhotos,
      );
      if (picked.isEmpty || !mounted) return;
      final video = _isVideo(picked.first.path);
      await _openPicked(
        video
            ? [picked.first]
            : picked.where((f) => !_isVideo(f.path)).toList(),
        video: video,
      );
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
  }

  static bool _isVideo(String path) {
    final p = path.toLowerCase();
    return p.endsWith(".mp4") || p.endsWith(".mov") || p.endsWith(".m4v");
  }

  Future<void> _openPicked(List<XFile> files, {required bool video}) async {
    if (_mode == CreateMode.story) {
      await Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) =>
              StoryEditorPage(file: files.first, video: video),
        ),
      );
      return;
    }
    await _openEditor([
      for (final f in files) PostMedia(file: f, video: video),
    ]);
  }

  void _chooseAlbum() {
    if (_albums.length < 2) return;
    showIgSheet<void>(
      context,
      heightFactor: 0.6,
      builder: (sheetContext) => CupertinoTheme(
        data: kDarkTheme,
        child: ListView(
          children: [
            for (final album in _albums)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() => _album = album);
                  _reload();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          album.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: album.id == _album?.id
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: const Color(0xFFFFFFFF),
                          ),
                        ),
                      ),
                      FutureBuilder<int>(
                        future: album.assetCountAsync,
                        builder: (_, snap) => Text(
                          snap.hasData ? "${snap.data}" : "",
                          style: const TextStyle(color: Color(0xFFA8A8A8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ───────────── Layout ─────────────

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;

    return CupertinoTheme(
      data: kDarkTheme,
      child: PlainPage(
        background: const Color(0xFF000000),
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: padding.top),
                _header(),
                Expanded(child: _body(width)),
              ],
            ),
            // POST · STORY · INSTANTS · REEL · LIVE
            Positioned(
              left: 0,
              right: 0,
              bottom: padding.bottom + 12,
              child: Center(
                child: _ModePill(mode: _mode, onChanged: _switchMode),
              ),
            ),
            if (_opening)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: CupertinoActivityIndicator(
                      radius: 14,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final showNext = _mode == CreateMode.post || _mode == CreateMode.reel;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            onPressed: () => Navigator.of(context).pop(),
            child: const Icon(
              CupertinoIcons.xmark,
              color: Color(0xFFFFFFFF),
              size: 24,
              semanticLabel: "Close",
            ),
          ),
          Expanded(
            child: Text(
              _mode.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 82,
            child: showNext
                ? Semantics(
                    button: true,
                    label: "Next",
                    child: GestureDetector(
                      onTap: _access == _Access.allowed ? _next : _systemPicker,
                      child: Container(
                        height: 34,
                        margin: const EdgeInsets.only(right: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF262626),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          "Next",
                          style: TextStyle(
                            color: Color(0xFF4F8BFF),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _body(double width) {
    switch (_access) {
      case _Access.asking:
        return const Center(
          child: CupertinoActivityIndicator(color: Color(0xFFFFFFFF)),
        );
      case _Access.denied:
        return _NoAccess(
          onAllow: () async {
            final state = await PhotoManager.requestPermissionExtend();
            if (state.hasAccess) {
              if (!mounted) return;
              setState(() => _access = _Access.allowed);
              await _loadAlbums();
            } else {
              await PhotoManager.openSetting();
            }
          },
          onPicker: _systemPicker,
          onCamera: _camera,
        );
      case _Access.allowed:
        break;
    }

    final current = _current;
    final showPreview = _mode != CreateMode.story;
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        if (showPreview)
          SliverToBoxAdapter(
            child: SizedBox(
              width: width,
              height: width,
              child: current == null
                  ? const ColoredBox(color: Color(0xFF121212))
                  : _Preview(key: ValueKey(current.id), asset: current),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _chooseAlbum,
                  child: Row(
                    children: [
                      Text(
                        _album?.name ?? "Recents",
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: Color(0xFFFFFFFF),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_mode == CreateMode.post)
                  _Pill(
                    icon: CupertinoIcons.square_on_square,
                    label: _multi ? "Cancel" : "Select",
                    active: _multi,
                    onTap: _toggleMulti,
                  ),
              ],
            ),
          ),
        ),
        if (_assets.isEmpty && !_loadingMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Text(
                    _videosOnly ? "No videos yet" : "No photos yet",
                    style: const TextStyle(color: Color(0xFFA8A8A8)),
                  ),
                  CupertinoButton(
                    onPressed: _systemPicker,
                    child: const Text("Choose from library"),
                  ),
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + 80,
          ),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 1.5,
              crossAxisSpacing: 1.5,
            ),
            itemCount: _assets.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return GestureDetector(
                  onTap: _camera,
                  child: const ColoredBox(
                    color: Color(0xFF262626),
                    child: Center(
                      child: Icon(
                        CupertinoIcons.camera_fill,
                        color: Color(0xFFFFFFFF),
                        size: 26,
                        semanticLabel: "Camera",
                      ),
                    ),
                  ),
                );
              }
              final a = _assets[i - 1];
              final order = _selected.indexWhere((s) => s.id == a.id);
              return _Tile(
                asset: a,
                thumb: _thumb(a),
                current: showPreview && _current?.id == a.id,
                multi: _multi,
                order: order < 0 ? null : order + 1,
                onTap: () => _tap(a),
                onLongPress: _mode == CreateMode.post && !_multi
                    ? () {
                        _toggleMulti();
                        _tap(a);
                      }
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Big preview of the photo / video tapped last.
class _Preview extends StatelessWidget {
  final AssetEntity asset;

  const _Preview({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF000000),
      child: FutureBuilder<Uint8List?>(
        future: asset.thumbnailDataWithSize(const ThumbnailSize.square(1080)),
        builder: (_, snap) {
          final bytes = snap.data;
          if (bytes == null) {
            return const Center(
              child: CupertinoActivityIndicator(color: Color(0xFFFFFFFF)),
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
              if (asset.type == AssetType.video)
                const Center(
                  child: Icon(
                    CupertinoIcons.play_fill,
                    size: 56,
                    color: Color(0xE6FFFFFF),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final AssetEntity asset;
  final Future<Uint8List?> thumb;
  final bool current;
  final bool multi;
  final int? order;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _Tile({
    required this.asset,
    required this.thumb,
    required this.current,
    required this.multi,
    required this.order,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final video = asset.type == AssetType.video;
    final d = asset.videoDuration;
    final length =
        "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, "0")}";
    return Semantics(
      button: true,
      selected: order != null,
      label: video ? "Video, $length" : "Photo",
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List?>(
              future: thumb,
              builder: (_, snap) => snap.data == null
                  ? const ColoredBox(color: Color(0xFF1C1C1E))
                  : Image.memory(
                      snap.data!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
            ),
            if (current) const ColoredBox(color: Color(0x66FFFFFF)),
            if (video)
              Positioned(
                right: 6,
                bottom: 4,
                child: Text(
                  length,
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Color(0x99000000), blurRadius: 4)],
                  ),
                ),
              ),
            if (multi)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: order != null ? kIgBlue : const Color(0x33000000),
                    border: Border.all(
                      color: const Color(0xFFFFFFFF),
                      width: 1.5,
                    ),
                  ),
                  child: order == null
                      ? null
                      : Text(
                          "$order",
                          style: const TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Pill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFFFFF) : const Color(0xFF262626),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active
                    ? const Color(0xFF000000)
                    : const Color(0xFFFFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// POST · STORY · INSTANTS · REEL · LIVE. Tap a word or swipe the pill.
class _ModePill extends StatelessWidget {
  final CreateMode mode;
  final ValueChanged<CreateMode> onChanged;

  const _ModePill({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 200) return;
        final i = (mode.index + (v < 0 ? 1 : -1)).clamp(
          0,
          CreateMode.values.length - 1,
        );
        onChanged(CreateMode.values[i]);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xE6262626),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in CreateMode.values)
              Semantics(
                button: true,
                selected: m == mode,
                label: m.tab,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(m),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 8,
                    ),
                    child: Text(
                      m.tab,
                      style: TextStyle(
                        fontSize: 13,
                        letterSpacing: 0.8,
                        fontWeight: m == mode
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: m == mode
                            ? const Color(0xFFFFFFFF)
                            : const Color(0xFF8E8E8E),
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

/// Shown when the app may not read your photos.
class _NoAccess extends StatelessWidget {
  final VoidCallback onAllow;
  final VoidCallback onPicker;
  final VoidCallback onCamera;

  const _NoAccess({
    required this.onAllow,
    required this.onPicker,
    required this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.photo_on_rectangle,
            size: 64,
            color: Color(0xFFFFFFFF),
          ),
          const SizedBox(height: 18),
          const Text(
            "Allow access to your photos and videos",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Your photos show here so you can pick what to share. You can "
            "also choose them one at a time with your phone's picker.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFA8A8A8), fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: kIgBlue,
              borderRadius: BorderRadius.circular(10),
              onPressed: onAllow,
              child: const Text(
                "Allow access",
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          CupertinoButton(
            onPressed: onPicker,
            child: const Text("Choose from library"),
          ),
          CupertinoButton(
            onPressed: onCamera,
            child: const Text("Open camera"),
          ),
        ],
      ),
    );
  }
}
