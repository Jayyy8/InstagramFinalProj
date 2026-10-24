import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";

import "../../models/audience.dart";
import "../../models/post_extras.dart";
import "../../models/social_models.dart";
import "../../navigation.dart";
import "../../providers/feed_provider.dart";
import "../../providers/social_providers.dart";
import "../../providers/story_provider.dart";
import "../../services/location_service.dart";
import "../../services/music_service.dart";
import "../../services/photo_editing.dart";
import "../../theme/app_theme.dart";
import "../../widgets/audience_picker.dart";
import "../../widgets/dialogs.dart";
import "../../widgets/edited_photo.dart";
import "../../widgets/feed_image.dart";
import "../../widgets/gradient_avatar.dart";
import "../../widgets/music_picker.dart";
import "../../widgets/sub_page.dart";
import "../close_friends_page.dart";
import "post_editor_page.dart";

/// Last step of a new post: caption, poll, audio, tags, location, link,
/// AI label, audience, then Share.
class PostDetailsPage extends ConsumerStatefulWidget {
  final List<PostMedia> media;
  final PostRatio ratio;
  final Music? music;
  final bool reel;

  const PostDetailsPage({
    super.key,
    required this.media,
    required this.ratio,
    this.music,
    this.reel = false,
  });

  @override
  ConsumerState<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends ConsumerState<PostDetailsPage> {
  final TextEditingController _caption = TextEditingController();

  late Music? _music = widget.music;
  List<Music> _songIdeas = const [];
  Poll? _poll;
  String? _prompt;
  final List<PostTag> _tags = [];
  String _location = "";
  PostLink? _link;
  bool _aiLabel = false;
  bool _profileOnly = false;
  late Audience _audience = ref.read(lastAudienceProvider);
  bool _alsoStory = false;
  bool _hideLikes = false;
  bool _commentsOff = false;
  bool _sharing = false;

  /// Places around you for the chips under "Add location".
  List<String> _nearby = [
    for (final p in LocationService.cachedNearby ?? const <Place>[]) p.label,
  ];
  bool _locating = false;
  String? _locateProblem;

  bool get _video => widget.media.first.video;

  @override
  void initState() {
    super.initState();
    MusicService.search("")
        .then((songs) {
          if (mounted) setState(() => _songIdeas = songs.take(8).toList());
        })
        .catchError((_) {});
    // Location already allowed: suggest places right away (no prompt).
    if (_nearby.isEmpty) {
      LocationService.allowed().then((ok) {
        if (ok && mounted) _loadNearby();
      });
    }
  }

  /// "Tap here to show location suggestions": asks for the location the
  /// first time, then shows your town and places around you.
  Future<void> _loadNearby() async {
    setState(() {
      _locating = true;
      _locateProblem = null;
    });
    final (position, reason) = await LocationService.locate();
    var problem = reason;
    List<Place> places = const [];
    if (position != null) {
      try {
        places = await LocationService.nearby(position);
      } catch (_) {
        problem = "Couldn't load places near you.";
      }
    }
    if (!mounted) return;
    setState(() {
      _locating = false;
      _locateProblem = problem;
      _nearby = [for (final p in places.take(10)) p.label];
    });
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  /// Places you tagged before, newest first.
  List<String> _recentPlaces() {
    final me = ref.read(currentUserIdProvider);
    final seen = <String>{};
    final posts = ref.read(postCacheProvider).values.toList()
      ..sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );
    for (final p in posts) {
      if (p.author?.id == me && p.location.trim().isNotEmpty) {
        seen.add(p.location.trim());
      }
    }
    return seen.take(6).toList();
  }

  // ───────────── Share ─────────────

  Future<void> _share() async {
    if (_sharing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _sharing = true);
    try {
      final photos = <XFile>[];
      XFile? video;
      for (final m in widget.media) {
        if (m.video) {
          video = m.file;
        } else {
          photos.add(await bakePhoto(m.file, m.edit, widget.ratio));
        }
      }
      await ref
          .read(postActionsProvider)
          .create(
            photos: photos,
            video: video,
            caption: _caption.text,
            location: _location,
            audience: _audience,
            music: _music,
            poll: _poll,
            prompt: _prompt,
            tags: _tags,
            link: _link,
            aiLabel: _aiLabel,
            hideLikes: _hideLikes,
            commentsOff: _commentsOff,
            profileOnly: _profileOnly,
          );
      if (_alsoStory) {
        await ref
            .read(storiesProvider.notifier)
            .add(
              file: video ?? photos.first,
              video: video != null,
              overlays: const [],
              durationMs: video != null
                  ? 15000
                  : (_music != null ? 15000 : 5000),
              location: _location.isEmpty ? null : _location,
              music: _music,
              audience: _audience,
            );
      }
      if (!mounted) return;
      showToast(
        context,
        _alsoStory
            ? "Shared to your profile and story"
            : "Your post has been shared",
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sharing = false);
      var message = errorText(e);
      if (message.contains("column")) {
        message +=
            "\n\nRun Update 5 of supabase/schema.sql in the Supabase SQL "
            "editor to save polls, prompts, tags, links and the other "
            "post options.";
      }
      showInfo(context, title: "Couldn't share post", message: message);
    }
  }

  // ───────────── Pickers ─────────────

  Future<void> _pickAudio() async {
    final music = await showMusicPicker(context);
    if (music != null && mounted) setState(() => _music = music);
  }

  Future<void> _pickLocation() async {
    final place = await askLocation(context, current: _location);
    if (place != null && mounted) setState(() => _location = place);
  }

  Future<void> _editPoll() async {
    final poll = await showIgSheet<Poll?>(
      context,
      builder: (_) => _PollSheet(initial: _poll),
    );
    if (poll != null && mounted) setState(() => _poll = poll);
  }

  Future<void> _editPrompt() async {
    final prompt = await showIgSheet<String>(
      context,
      builder: (_) => _PromptSheet(initial: _prompt),
    );
    if (prompt != null && mounted) {
      setState(() => _prompt = prompt.isEmpty ? null : prompt);
    }
  }

  Future<void> _editLink() async {
    final link = await showIgSheet<PostLink?>(
      context,
      builder: (_) => _LinkSheet(initial: _link),
    );
    if (link != null && mounted) {
      setState(() => _link = link.url.isEmpty ? null : link);
    }
  }

  Future<void> _tagPeople() async {
    if (_video) {
      showToast(context, "Tags go on photos");
      return;
    }
    final tags = await push<List<PostTag>>(
      context,
      TagPeoplePage(media: widget.media, ratio: widget.ratio, tags: _tags),
    );
    if (tags != null && mounted) {
      setState(() {
        _tags
          ..clear()
          ..addAll(tags);
      });
    }
  }

  Future<void> _pickAudience() async {
    final picked = await push<Audience>(
      context,
      _AudiencePage(current: _audience),
    );
    if (picked == null || !mounted) return;
    setState(() => _audience = picked);
    ref.read(lastAudienceProvider.notifier).set(picked);
  }

  // ───────────── Layout ─────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    final places = {..._recentPlaces(), ..._nearby}.toList();
    final secondary = TextStyle(fontSize: 12, color: colors.secondaryText);

    return SubPage(
      title: "New post",
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: ListView(
              padding: EdgeInsets.only(bottom: padding.bottom + 100),
              children: [
                const SizedBox(height: 12),
                _thumbnails(colors),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoTextField(
                    controller: _caption,
                    placeholder: "Add a caption...",
                    placeholderStyle: TextStyle(color: colors.secondaryText),
                    style: TextStyle(color: colors.text, fontSize: 15),
                    minLines: 3,
                    maxLines: 8,
                    maxLength: 2200,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                // Poll · Prompt
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      _Chip(
                        icon: CupertinoIcons.list_bullet,
                        label: "Poll",
                        active: _poll != null,
                        onTap: _editPoll,
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        icon: CupertinoIcons.search,
                        label: "Prompt",
                        active: _prompt != null,
                        onTap: _editPrompt,
                      ),
                    ],
                  ),
                ),
                if (_poll != null)
                  _AttachedCard(
                    title: _poll!.question.isEmpty ? "Poll" : _poll!.question,
                    subtitle: _poll!.options.join("  ·  "),
                    icon: CupertinoIcons.list_bullet,
                    onTap: _editPoll,
                    onRemove: () => setState(() => _poll = null),
                  ),
                if (_prompt != null)
                  _AttachedCard(
                    title: "Prompt",
                    subtitle: _prompt!,
                    icon: CupertinoIcons.search,
                    onTap: _editPrompt,
                    onRemove: () => setState(() => _prompt = null),
                  ),

                // Add audio + song ideas
                _Row(
                  icon: CupertinoIcons.music_note_2,
                  title: "Add audio",
                  value: _music?.label,
                  onTap: _pickAudio,
                ),
                if (_songIdeas.isNotEmpty || _music != null)
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final m in [
                          ?_music,
                          ..._songIdeas.where(
                            (s) => s.previewUrl != _music?.previewUrl,
                          ),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _SongChip(
                              music: m,
                              selected: m.previewUrl == _music?.previewUrl,
                              onTap: () => setState(() {
                                _music = m.previewUrl == _music?.previewUrl
                                    ? null
                                    : m;
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                _Row(
                  icon: CupertinoIcons.person_crop_square,
                  title: "Tag people",
                  value: _tags.isEmpty
                      ? null
                      : _tags.map((t) => t.username).join(", "),
                  onTap: _tagPeople,
                ),
                _Row(
                  icon: CupertinoIcons.placemark,
                  title: _location.isEmpty ? "Add location" : _location,
                  onTap: _pickLocation,
                  trailing: _location.isEmpty
                      ? null
                      : GestureDetector(
                          onTap: () => setState(() => _location = ""),
                          child: Icon(
                            CupertinoIcons.xmark,
                            size: 18,
                            color: colors.secondaryText,
                            semanticLabel: "Remove location",
                          ),
                        ),
                ),
                if (_location.isEmpty && _locating)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: CupertinoActivityIndicator(),
                    ),
                  )
                else if (_location.isEmpty)
                  places.isEmpty || _locateProblem != null
                      ? GestureDetector(
                          onTap: _locateProblem == null
                              ? _loadNearby
                              : _pickLocation,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                            child: Text(
                              _locateProblem == null
                                  ? "Tap here to show location suggestions"
                                  : "$_locateProblem Tap here to search "
                                        "for a place.",
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.secondaryText,
                              ),
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              for (final p in places)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _Chip(
                                    label: p,
                                    onTap: () => setState(() => _location = p),
                                  ),
                                ),
                            ],
                          ),
                        ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                  child: Text(
                    "People you share this content with can see the location "
                    "you tag.",
                    style: secondary,
                  ),
                ),
                _Row(
                  icon: CupertinoIcons.link,
                  title: _link == null ? "Add link" : _link!.label,
                  subtitle: _link == null ? "Add a link to your post" : null,
                  onTap: _editLink,
                ),
                _Row(
                  icon: CupertinoIcons.sparkles,
                  title: "Add AI label",
                  subtitle:
                      "This label is required for realistic photos and videos "
                      "made with AI. People will see it on your content.",
                  trailing: AdaptiveSwitch(
                    value: _aiLabel,
                    onChanged: (v) => setState(() => _aiLabel = v),
                  ),
                ),
                Container(
                  height: 8,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  color: colors.field,
                ),
                _Row(
                  icon: CupertinoIcons.square_grid_3x2,
                  title: "Post only to profile",
                  subtitle: "It won't show in your followers' feeds",
                  trailing: AdaptiveSwitch(
                    value: _profileOnly,
                    onChanged: (v) => setState(() => _profileOnly = v),
                  ),
                ),
                _Row(
                  icon: _audience == Audience.public
                      ? CupertinoIcons.eye
                      : _audience.icon,
                  title: "Audience",
                  value: _audience == Audience.public
                      ? "Everyone"
                      : _audience.label,
                  onTap: _pickAudience,
                ),
                _Row(
                  icon: CupertinoIcons.arrow_turn_up_right,
                  title: "Also share on...",
                  value: _alsoStory ? "Your story" : "Off",
                  onTap: () async {
                    final on = await push<bool>(
                      context,
                      _AlsoSharePage(story: _alsoStory),
                    );
                    if (on != null && mounted) setState(() => _alsoStory = on);
                  },
                ),
                _Row(
                  icon: CupertinoIcons.ellipsis,
                  title: "More options",
                  onTap: () async {
                    final result = await push<(bool, bool)>(
                      context,
                      _MoreOptionsPage(
                        hideLikes: _hideLikes,
                        commentsOff: _commentsOff,
                      ),
                    );
                    if (result != null && mounted) {
                      setState(() {
                        _hideLikes = result.$1;
                        _commentsOff = result.$2;
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          // Share
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: colors.background,
              padding: EdgeInsets.fromLTRB(16, 10, 16, padding.bottom + 12),
              child: CupertinoButton(
                color: const Color(0xFF4A5DF9),
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.symmetric(vertical: 14),
                onPressed: _sharing ? null : _share,
                child: Text(
                  _sharing ? "Sharing..." : "Share",
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          if (_sharing)
            Positioned.fill(
              child: ColoredBox(
                color: colors.background.withValues(alpha: 0.6),
                child: const Center(
                  child: CupertinoActivityIndicator(radius: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _thumbnails(AppColors colors) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: widget.media.length == 1
              ? (MediaQuery.sizeOf(context).width - 152) / 2
              : 16,
        ),
        itemCount: widget.media.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final m = widget.media[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 152,
              child: m.video
                  ? ColoredBox(
                      color: colors.placeholder,
                      child: Icon(
                        CupertinoIcons.play_rectangle_fill,
                        size: 40,
                        color: colors.secondaryText,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: 400,
                        child: EditedPhoto(
                          path: m.file.path,
                          edit: m.edit,
                          ratio: widget.ratio,
                          aspect: m.aspect ?? 1,
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── Rows and chips ─────────────────────────

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            crossAxisAlignment: subtitle == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24, color: colors.text),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: colors.text),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.secondaryText,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (value != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: colors.secondaryText),
                  ),
                ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: trailing,
                )
              else if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: colors.secondaryText,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Chip({
    this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? colors.text : colors.field,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: active ? colors.background : colors.text,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? colors.background : colors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongChip extends StatelessWidget {
  final Music music;
  final bool selected;
  final VoidCallback onTap;

  const _SongChip({
    required this.music,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: colors.field,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? colors.text : const Color(0x00000000),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                width: 32,
                height: 32,
                child: music.artworkUrl == null
                    ? ColoredBox(color: colors.button)
                    : FeedImage(urls: [music.artworkUrl!]),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "${music.title} · ${music.artist}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: colors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A poll / prompt that was added, with edit and remove.
class _AttachedCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _AttachedCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          border: Border.all(color: colors.separator),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.text),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: colors.secondaryText),
                  ),
                ],
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.all(8),
              onPressed: onRemove,
              child: Icon(
                CupertinoIcons.xmark_circle_fill,
                size: 20,
                color: colors.secondaryText,
                semanticLabel: "Remove",
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text field for the sheets below.
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final bool autofocus;
  final int? maxLength;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.placeholder,
    this.autofocus = false,
    this.maxLength,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return CupertinoTextField(
      controller: controller,
      autofocus: autofocus,
      placeholder: placeholder,
      maxLength: maxLength,
      keyboardType: keyboardType,
      placeholderStyle: TextStyle(color: colors.secondaryText),
      style: TextStyle(color: colors.text),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

Widget _sheetTitle(BuildContext context, String title, VoidCallback onDone) {
  final colors = AppColors.of(context);
  return Row(
    children: [
      const SizedBox(width: 64),
      Expanded(
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
      ),
      SizedBox(
        width: 64,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onDone,
          child: const Text(
            "Done",
            style: TextStyle(color: kIgBlue, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ],
  );
}

// ───────────────────────── Poll ─────────────────────────

class _PollSheet extends StatefulWidget {
  final Poll? initial;

  const _PollSheet({this.initial});

  @override
  State<_PollSheet> createState() => _PollSheetState();
}

class _PollSheetState extends State<_PollSheet> {
  late final TextEditingController _question = TextEditingController(
    text: widget.initial?.question ?? "",
  );
  late final List<TextEditingController> _options = [
    for (final o in widget.initial?.options ?? const ["Yes", "No"])
      TextEditingController(text: o),
  ];

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _done() {
    final options = [
      for (final c in _options)
        if (c.text.trim().isNotEmpty) c.text.trim(),
    ];
    if (options.length < 2) {
      showToast(context, "Add at least 2 answers");
      return;
    }
    Navigator.of(
      context,
    ).pop(Poll(question: _question.text.trim(), options: options));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle(context, "Poll", _done),
          const SizedBox(height: 8),
          _Field(
            controller: _question,
            placeholder: "Ask a question...",
            autofocus: true,
            maxLength: 120,
          ),
          for (int i = 0; i < _options.length; i++) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: _options[i],
                    placeholder: "Option ${i + 1}",
                    maxLength: 40,
                  ),
                ),
                if (_options.length > 2)
                  CupertinoButton(
                    padding: const EdgeInsets.only(left: 8),
                    onPressed: () =>
                        setState(() => _options.removeAt(i).dispose()),
                    child: Icon(
                      CupertinoIcons.minus_circle,
                      color: colors.secondaryText,
                      semanticLabel: "Remove option",
                    ),
                  ),
              ],
            ),
          ],
          if (_options.length < 4)
            Align(
              alignment: Alignment.centerLeft,
              child: CupertinoButton(
                padding: const EdgeInsets.only(top: 8),
                onPressed: () =>
                    setState(() => _options.add(TextEditingController())),
                child: const Text("Add option"),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── Prompt ─────────────────────────

class _PromptSheet extends StatefulWidget {
  final String? initial;

  const _PromptSheet({this.initial});

  @override
  State<_PromptSheet> createState() => _PromptSheetState();
}

class _PromptSheetState extends State<_PromptSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial ?? "",
  );

  static const _ideas = [
    "Show me your view right now",
    "What are you listening to?",
    "Your best photo this month",
    "Post your pet",
  ];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetTitle(
            context,
            "Prompt",
            () => Navigator.of(context).pop(_text.text.trim()),
          ),
          Text(
            "Ask something people answer in the comments.",
            style: TextStyle(fontSize: 13, color: colors.secondaryText),
          ),
          const SizedBox(height: 10),
          _Field(
            controller: _text,
            placeholder: "Add a prompt...",
            autofocus: true,
            maxLength: 100,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final idea in _ideas)
                _Chip(
                  label: idea,
                  onTap: () => setState(() => _text.text = idea),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Link ─────────────────────────

class _LinkSheet extends StatefulWidget {
  final PostLink? initial;

  const _LinkSheet({this.initial});

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  late final TextEditingController _url = TextEditingController(
    text: widget.initial?.url ?? "",
  );
  late final TextEditingController _title = TextEditingController(
    text: widget.initial?.title ?? "",
  );

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    super.dispose();
  }

  void _done() {
    var url = _url.text.trim();
    if (url.isEmpty) {
      Navigator.of(context).pop(const PostLink(url: ""));
      return;
    }
    if (!url.startsWith("http://") && !url.startsWith("https://")) {
      url = "https://$url";
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.host.contains(".")) {
      showToast(context, "Enter a web address like example.com");
      return;
    }
    Navigator.of(context).pop(PostLink(url: url, title: _title.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetTitle(context, "Add link", _done),
          const SizedBox(height: 8),
          _Field(
            controller: _url,
            placeholder: "URL",
            autofocus: true,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
          _Field(controller: _title, placeholder: "Link title (optional)"),
        ],
      ),
    );
  }
}

// ───────────────────────── Tag people ─────────────────────────

/// Tap a photo to tag someone there; tap a tag to remove it.
class TagPeoplePage extends ConsumerStatefulWidget {
  final List<PostMedia> media;
  final PostRatio ratio;
  final List<PostTag> tags;

  const TagPeoplePage({
    super.key,
    required this.media,
    required this.ratio,
    required this.tags,
  });

  @override
  ConsumerState<TagPeoplePage> createState() => _TagPeoplePageState();
}

class _TagPeoplePageState extends ConsumerState<TagPeoplePage> {
  late final List<PostTag> _tags = List.of(widget.tags);
  int _page = 0;

  Future<void> _add(int photo, Offset at, Size size) async {
    final profile = await showIgSheet<Profile>(
      context,
      heightFactor: 0.8,
      builder: (_) => const _PeopleSearch(),
    );
    if (profile == null || !mounted) return;
    setState(() {
      _tags.removeWhere((t) => t.userId == profile.id && t.photo == photo);
      _tags.add(
        PostTag(
          userId: profile.id,
          username: profile.username,
          photo: photo,
          x: (at.dx / size.width).clamp(0.05, 0.95),
          y: (at.dy / size.height).clamp(0.05, 0.95),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SubPage(
      title: "Tag people",
      actions: [
        AdaptiveAppBarAction(
          title: "Done",
          onPressed: () => Navigator.of(context).pop(_tags),
        ),
      ],
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              itemCount: widget.media.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final m = widget.media[i];
                return Center(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      return Stack(
                        children: [
                          EditedPhoto(
                            path: m.file.path,
                            edit: m.edit,
                            ratio: widget.ratio,
                            aspect: m.aspect ?? 1,
                          ),
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (context, photoBox) {
                                final size = photoBox.biggest;
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapUp: (d) =>
                                      _add(i, d.localPosition, size),
                                  child: Stack(
                                    children: [
                                      for (final t in _tags.where(
                                        (t) => t.photo == i,
                                      ))
                                        Positioned(
                                          left: t.x * size.width,
                                          top: t.y * size.height,
                                          child: FractionalTranslation(
                                            translation: const Offset(-0.5, 0),
                                            child: TagLabel(
                                              username: t.username,
                                              onTap: () => setState(
                                                () => _tags.remove(t),
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
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.media.length > 1
                  ? "Photo ${_page + 1} of ${widget.media.length}. Tap the "
                        "photo to tag people. Tap a tag to remove it."
                  : "Tap the photo to tag people. Tap a tag to remove it.",
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.secondaryText, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Black "username" bubble with a little arrow on top, like Instagram's.
class TagLabel extends StatelessWidget {
  final String username;
  final VoidCallback? onTap;

  const TagLabel({super.key, required this.username, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(size: const Size(12, 6), painter: _Arrow()),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xD9000000),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              username,
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xD9000000));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Search accounts to tag.
class _PeopleSearch extends ConsumerStatefulWidget {
  const _PeopleSearch();

  @override
  ConsumerState<_PeopleSearch> createState() => _PeopleSearchState();
}

class _PeopleSearchState extends ConsumerState<_PeopleSearch> {
  String _query = "";

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final me = ref.watch(currentUserIdProvider);
    final results = _query.trim().isEmpty
        ? ref.watch(followingListProvider(me ?? ""))
        : ref.watch(userSearchProvider(_query.trim()));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: CupertinoSearchTextField(
            autofocus: true,
            placeholder: "Search for a user",
            style: TextStyle(color: colors.text),
            backgroundColor: colors.field,
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: results.when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (e, _) => Center(
              child: Text(
                errorText(e),
                style: TextStyle(color: colors.secondaryText),
              ),
            ),
            data: (people) {
              final list = people.where((p) => p.id != me).toList();
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    _query.isEmpty
                        ? "Search for someone to tag"
                        : "No one found",
                    style: TextStyle(color: colors.secondaryText),
                  ),
                );
              }
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final p = list[i];
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          GradientAvatar(
                            name: p.username,
                            imageUrls: p.avatarUrls,
                            size: 44,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.username,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: colors.text,
                                  ),
                                ),
                                if (p.fullName.isNotEmpty)
                                  Text(
                                    p.fullName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colors.secondaryText,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Audience ─────────────────────────

/// "Who can see your post": Everyone, Close Friends and the rest.
class _AudiencePage extends ConsumerStatefulWidget {
  final Audience current;

  const _AudiencePage({required this.current});

  @override
  ConsumerState<_AudiencePage> createState() => _AudiencePageState();
}

class _AudiencePageState extends ConsumerState<_AudiencePage> {
  late Audience _picked = widget.current;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final closeCount = ref.watch(closeFriendsProvider).valueOrNull?.length ?? 0;
    return PopScope<Audience>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_picked);
      },
      child: SubPage(
        title: "Audience",
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                "Who can see your post",
                style: TextStyle(fontSize: 14, color: colors.secondaryText),
              ),
            ),
            for (final a in Audience.values)
              Semantics(
                button: true,
                selected: a == _picked,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _picked = a),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        a == Audience.public
                            ? Icon(CupertinoIcons.person_2, color: colors.text)
                            : AudienceBadge(audience: a, size: 26),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a == Audience.public ? "Everyone" : a.label,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colors.text,
                                ),
                              ),
                              if (a == Audience.closeFriends)
                                GestureDetector(
                                  onTap: () =>
                                      push(context, const CloseFriendsPage()),
                                  child: Text(
                                    "$closeCount ${closeCount == 1 ? "person" : "people"} ›",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: kIgBlue,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  a.description,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.secondaryText,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _Radio(on: a == _picked),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Text(
                "This only changes who sees this post. You can change it later "
                "from the post's ••• menu.",
                style: TextStyle(fontSize: 12, color: colors.secondaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  final bool on;

  const _Radio({required this.on});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: on ? colors.text : colors.secondaryText,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: on
          ? DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.text,
              ),
            )
          : null,
    );
  }
}

// ───────────────────────── Also share on / More options ─────────────────────────

class _AlsoSharePage extends StatefulWidget {
  final bool story;

  const _AlsoSharePage({required this.story});

  @override
  State<_AlsoSharePage> createState() => _AlsoSharePageState();
}

class _AlsoSharePageState extends State<_AlsoSharePage> {
  late bool _story = widget.story;

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_story);
      },
      child: SubPage(
        title: "Also share on...",
        child: ListView(
          children: [
            _Row(
              icon: CupertinoIcons.plus_circle,
              title: "Your story",
              subtitle: "Share the first photo or the video to your story too",
              trailing: AdaptiveSwitch(
                value: _story,
                onChanged: (v) => setState(() => _story = v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreOptionsPage extends StatefulWidget {
  final bool hideLikes;
  final bool commentsOff;

  const _MoreOptionsPage({required this.hideLikes, required this.commentsOff});

  @override
  State<_MoreOptionsPage> createState() => _MoreOptionsPageState();
}

class _MoreOptionsPageState extends State<_MoreOptionsPage> {
  late bool _hideLikes = widget.hideLikes;
  late bool _commentsOff = widget.commentsOff;

  @override
  Widget build(BuildContext context) {
    return PopScope<(bool, bool)>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop((_hideLikes, _commentsOff));
      },
      child: SubPage(
        title: "More options",
        child: ListView(
          children: [
            _Row(
              icon: CupertinoIcons.heart_slash,
              title: "Hide like count",
              subtitle:
                  "Only you will see the total number of likes on this post.",
              trailing: AdaptiveSwitch(
                value: _hideLikes,
                onChanged: (v) => setState(() => _hideLikes = v),
              ),
            ),
            _Row(
              icon: CupertinoIcons.chat_bubble_2,
              title: "Turn off commenting",
              subtitle: "No one will be able to comment on this post.",
              trailing: AdaptiveSwitch(
                value: _commentsOff,
                onChanged: (v) => setState(() => _commentsOff = v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
