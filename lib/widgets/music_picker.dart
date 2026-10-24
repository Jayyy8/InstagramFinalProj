import "dart:async";

import "package:flutter/cupertino.dart";

import "../models/social_models.dart";
import "../services/music_service.dart";
import "../theme/app_theme.dart";
import "dialogs.dart";
import "feed_image.dart";

/// Songs bookmarked in the picker (the "Saved" tab), for this app run.
final List<Music> _savedSongs = [];

/// Song search sheet like Instagram's: For you / Trending / Original audio /
/// Saved. Tap the cover to listen, a row to choose it, the bookmark to save.
Future<Music?> showMusicPicker(BuildContext context) {
  return showIgSheet<Music>(
    context,
    heightFactor: 0.85,
    builder: (_) => const _MusicPicker(),
  );
}

class _MusicPicker extends StatefulWidget {
  const _MusicPicker();

  @override
  State<_MusicPicker> createState() => _MusicPickerState();
}

class _MusicPickerState extends State<_MusicPicker> {
  final TextEditingController _query = TextEditingController();
  final PreviewPlayer _player = PreviewPlayer();
  Timer? _debounce;
  List<Music> _results = const [];
  bool _loading = true;
  String? _error;
  String? _playing;

  /// 0 For you, 1 Trending, 2 Original audio, 3 Saved.
  int _tab = 0;
  static const _tabs = ["For you", "Trending", "Original audio", "Saved"];

  @override
  void initState() {
    super.initState();
    _load("");
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _player.stop();
    _query.dispose();
    super.dispose();
  }

  Future<void> _load(String term) async {
    if (term.trim().isEmpty && _tab == 3) {
      setState(() {
        _results = List.of(_savedSongs);
        _loading = false;
        _error = null;
      });
      return;
    }
    final query = term.trim().isNotEmpty
        ? term
        : switch (_tab) {
            1 => MusicService.trendingQuery,
            2 => MusicService.originalQuery,
            _ => "",
          };
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await MusicService.search(query);
      if (!mounted || term != _query.text) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load songs. Check your internet connection.";
      });
    }
  }

  void _toggleSaved(Music m) {
    setState(() {
      final i = _savedSongs.indexWhere((s) => s.previewUrl == m.previewUrl);
      if (i < 0) {
        _savedSongs.insert(0, m);
      } else {
        _savedSongs.removeAt(i);
        if (_tab == 3 && _query.text.isEmpty) _results = List.of(_savedSongs);
      }
    });
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(value));
  }

  Future<void> _togglePreview(Music m) async {
    if (_playing == m.previewUrl) {
      await _player.stop();
      setState(() => _playing = null);
    } else {
      setState(() => _playing = m.previewUrl);
      await _player.play(m.previewUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: CupertinoSearchTextField(
            controller: _query,
            placeholder: "Search music",
            style: TextStyle(color: colors.text),
            backgroundColor: colors.field,
            borderRadius: BorderRadius.circular(12),
            onChanged: _onChanged,
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            itemCount: _tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final on = i == _tab;
              return GestureDetector(
                onTap: () {
                  if (on) return;
                  setState(() => _tab = i);
                  _query.clear();
                  _load("");
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? colors.text : colors.field,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    _tabs[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: on ? colors.background : colors.text,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CupertinoActivityIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.secondaryText),
                    ),
                  ),
                )
              : _results.isEmpty
              ? Center(
                  child: Text(
                    _tab == 3 && _query.text.isEmpty
                        ? "Tap the bookmark on a song to save it"
                        : "No songs found",
                    style: TextStyle(color: colors.secondaryText),
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final m = _results[i];
                    final playing = _playing == m.previewUrl;
                    final saved = _savedSongs.any(
                      (s) => s.previewUrl == m.previewUrl,
                    );
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(m),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        child: Row(
                          children: [
                            // Tap the cover to listen.
                            GestureDetector(
                              onTap: () => _togglePreview(m),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      m.artworkUrl == null
                                          ? ColoredBox(color: colors.field)
                                          : FeedImage(urls: [m.artworkUrl!]),
                                      ColoredBox(
                                        color: playing
                                            ? const Color(0x66000000)
                                            : const Color(0x00000000),
                                        child: Icon(
                                          playing
                                              ? CupertinoIcons.pause_fill
                                              : CupertinoIcons.play_fill,
                                          size: 18,
                                          color: const Color(0xE6FFFFFF),
                                          semanticLabel: playing
                                              ? "Pause preview"
                                              : "Play preview",
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: colors.text,
                                    ),
                                  ),
                                  Text(
                                    m.length.isEmpty
                                        ? m.artist
                                        : "${m.artist} · ${m.length}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.secondaryText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CupertinoButton(
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(40, 40),
                              onPressed: () => _toggleSaved(m),
                              child: Icon(
                                saved
                                    ? CupertinoIcons.bookmark_fill
                                    : CupertinoIcons.bookmark,
                                size: 24,
                                color: colors.text,
                                semanticLabel: saved ? "Unsave" : "Save",
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// "♫ Title · Artist" chip with the cover, shown on stories, notes and
/// the story editor.
class MusicChip extends StatelessWidget {
  final Music music;
  final bool onDark;
  final VoidCallback? onTap;

  const MusicChip({
    super.key,
    required this.music,
    this.onDark = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? const Color(0xFFFFFFFF) : AppColors.of(context).text;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
        decoration: BoxDecoration(
          color: onDark ? const Color(0x99000000) : AppColors.of(context).field,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 36,
                height: 36,
                child: music.artworkUrl == null
                    ? const ColoredBox(color: Color(0xFF363636))
                    : FeedImage(urls: [music.artworkUrl!]),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    music.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Text(
                    music.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.8),
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "📍 Place" sticker for stories.
class LocationChip extends StatelessWidget {
  final String location;
  final VoidCallback? onTap;

  const LocationChip({super.key, required this.location, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.location_solid,
              size: 16,
              color: Color(0xFFD62976),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                location.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFD62976),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for a place name (stories, notes). Returns null when cancelled,
/// "" to remove the location.
Future<String?> askLocation(BuildContext context, {String? current}) {
  return showIgSheet<String>(
    context,
    builder: (_) => _LocationSheet(current: current),
  );
}

class _LocationSheet extends StatefulWidget {
  final String? current;

  const _LocationSheet({this.current});

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current ?? "",
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final current = widget.current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Add location",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _controller,
            autofocus: true,
            placeholder: "Find a location",
            prefix: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Icon(
                CupertinoIcons.location,
                size: 18,
                color: colors.secondaryText,
              ),
            ),
            placeholderStyle: TextStyle(color: colors.secondaryText),
            style: TextStyle(color: colors.text),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.field,
              borderRadius: BorderRadius.circular(12),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (current != null && current.isNotEmpty)
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(""),
                  child: const Text(
                    "Remove",
                    style: TextStyle(color: CupertinoColors.destructiveRed),
                  ),
                ),
              const Spacer(),
              CupertinoButton(
                onPressed: () =>
                    Navigator.of(context).pop(_controller.text.trim()),
                child: const Text(
                  "Done",
                  style: TextStyle(color: kIgBlue, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
