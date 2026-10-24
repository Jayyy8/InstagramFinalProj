import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/feed_models.dart";
import "../models/social_models.dart";
import "../providers/chat_provider.dart";
import "../providers/notes_provider.dart";
import "../providers/social_providers.dart";
import "../services/music_service.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "../widgets/gradient_avatar.dart";
import "../widgets/music_picker.dart";

/// Speech bubble drawn above an avatar (notes).
class NoteBubble extends StatelessWidget {
  final String text;
  final bool placeholder;
  final double maxWidth;

  const NoteBubble({
    super.key,
    required this.text,
    this.placeholder = false,
    this.maxWidth = 84,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fill = colors.dark
        ? const Color(0xFF363636)
        : const Color(0xFFFFFFFF);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: maxWidth, minWidth: 40),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              color: placeholder ? colors.secondaryText : colors.text,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 11, top: 1),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          ),
        ),
      ],
    );
  }
}

/// Write, change or delete your note.
Future<void> showNoteComposer(BuildContext context) {
  return showIgSheet<void>(context, builder: (_) => const _NoteComposer());
}

class _NoteComposer extends ConsumerStatefulWidget {
  const _NoteComposer();

  @override
  ConsumerState<_NoteComposer> createState() => _NoteComposerState();
}

class _NoteComposerState extends ConsumerState<_NoteComposer> {
  late final TextEditingController _text;
  bool _saving = false;
  Music? _music;
  String? _location;
  final PreviewPlayer _preview = PreviewPlayer();

  @override
  void initState() {
    super.initState();
    final existing = ref.read(myNoteProvider);
    _music = existing?.music;
    _location = existing?.location;
    // A song-only note stores the song as its text; start empty then.
    final body = existing?.body ?? "";
    _text = TextEditingController(text: body.startsWith("\u266B ") ? "" : body);
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _preview.stop();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickMusic() async {
    final music = await showMusicPicker(context);
    if (music == null || !mounted) return;
    setState(() => _music = music);
    await _preview.play(music.previewUrl);
  }

  Future<void> _pickLocation() async {
    final place = await askLocation(context, current: _location);
    if (place == null || !mounted) return;
    setState(() => _location = place.isEmpty ? null : place);
  }

  Future<void> _share() async {
    final text = _text.text.trim();
    if ((text.isEmpty && _music == null) || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(notesProvider.notifier)
          .setNote(text, location: _location, music: _music);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, errorText(e), error: true);
      }
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    try {
      await ref.read(notesProvider.notifier).deleteNote();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, errorText(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final me = ref.watch(myProfileProvider).valueOrNull;
    final existing = ref.watch(myNoteProvider);
    final canShare =
        (_text.text.trim().isNotEmpty || _music != null) && !_saving;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: Icon(CupertinoIcons.xmark, color: colors.text),
              ),
              Expanded(
                child: Text(
                  existing == null ? "New note" : "Your note",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: canShare ? _share : null,
                child: Text(
                  "Share",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: canShare ? kIgBlue : colors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxWidth: 260),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: colors.field,
              borderRadius: BorderRadius.circular(18),
            ),
            child: CupertinoTextField(
              controller: _text,
              autofocus: true,
              maxLength: 60,
              maxLines: 3,
              minLines: 1,
              textAlign: TextAlign.center,
              placeholder: "Share a thought...",
              placeholderStyle: TextStyle(color: colors.secondaryText),
              style: TextStyle(color: colors.text, fontSize: 15),
              decoration: null,
              onSubmitted: (_) => _share(),
            ),
          ),
          if (_music != null) ...[
            const SizedBox(height: 8),
            MusicChip(
              music: _music!,
              onDark: false,
              onTap: () {
                _preview.stop();
                setState(() => _music = null);
              },
            ),
          ],
          const SizedBox(height: 6),
          GradientAvatar(
            name: me?.username ?? "",
            imageUrls: me?.avatarUrls,
            size: 84,
            ring: false,
          ),
          const SizedBox(height: 12),
          // Song, location (like the icons under Instagram's note composer).
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ComposerTool(
                label: "Add music",
                icon: CupertinoIcons.music_note_2,
                color: const Color(0xFFD62976),
                active: _music != null,
                onTap: _pickMusic,
              ),
              const SizedBox(width: 12),
              _ComposerTool(
                label: "Add location",
                icon: CupertinoIcons.location_solid,
                color: const Color(0xFF4F5BD5),
                active: _location != null,
                onTap: _pickLocation,
              ),
            ],
          ),
          if (_location != null) ...[
            const SizedBox(height: 6),
            Text(
              "\u{1F4CD} $_location",
              style: TextStyle(fontSize: 13, color: colors.secondaryText),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            "${_text.text.characters.length}/60 · Shared with followers you follow back for 24 hours",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.secondaryText),
          ),
          if (existing != null) ...[
            const SizedBox(height: 12),
            CupertinoButton(
              onPressed: _saving ? null : _delete,
              child: const Text(
                "Delete note",
                style: TextStyle(color: CupertinoColors.destructiveRed),
              ),
            ),
          ],
          if (_saving) const CupertinoActivityIndicator(),
        ],
      ),
    );
  }
}

/// Someone else's note: like it or reply in a message.
Future<void> showNoteViewer(BuildContext context, Note note) {
  return showIgSheet<void>(context, builder: (_) => _NoteViewer(note: note));
}

class _NoteViewer extends ConsumerStatefulWidget {
  final Note note;

  const _NoteViewer({required this.note});

  @override
  ConsumerState<_NoteViewer> createState() => _NoteViewerState();
}

class _NoteViewerState extends ConsumerState<_NoteViewer> {
  final TextEditingController _reply = TextEditingController();
  late bool _liked = widget.note.likedByMe;
  bool _sending = false;
  final PreviewPlayer _preview = PreviewPlayer();

  @override
  void initState() {
    super.initState();
    final music = widget.note.music;
    if (music != null) _preview.play(music.previewUrl);
  }

  @override
  void dispose() {
    _preview.stop();
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;
    final profile = widget.note.profile;
    if (profile == null) {
      Navigator.of(context).pop();
      showToast(context, "Sent");
      return;
    }
    setState(() => _sending = true);
    try {
      await sendDirect(
        ref,
        to: profile.id,
        text: text,
        contextType: "note_reply",
        contextText: widget.note.body,
      );
      if (mounted) {
        Navigator.of(context).pop();
        showToast(context, "Sent");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showToast(context, errorText(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final note = widget.note;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "${note.username} · ${timeAgoShort(note.createdAt)}",
            style: TextStyle(fontWeight: FontWeight.w600, color: colors.text),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GradientAvatar(
                name: note.username,
                imageUrls: note.avatarUrls,
                size: 72,
                ring: false,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.field,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    note.body,
                    style: TextStyle(fontSize: 15, color: colors.text),
                  ),
                ),
              ),
            ],
          ),
          if (note.music != null) ...[
            const SizedBox(height: 12),
            MusicChip(music: note.music!, onDark: false),
          ],
          if (note.location != null && note.location!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "\u{1F4CD} ${note.location}",
              style: TextStyle(fontSize: 13, color: colors.secondaryText),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _reply,
                  autofocus: false,
                  placeholder: "Reply to ${note.username}...",
                  placeholderStyle: TextStyle(color: colors.secondaryText),
                  style: TextStyle(color: colors.text),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.field,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.only(left: 10),
                onPressed: () {
                  setState(() => _liked = !_liked);
                  ref
                      .read(notesProvider.notifier)
                      .toggleLike(note.copyWith(likedByMe: !_liked))
                      .catchError((_) {});
                },
                child: Icon(
                  _liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  color: _liked ? kIgRed : colors.text,
                  size: 28,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.only(left: 6),
                onPressed: _sending ? null : _send,
                child: Icon(
                  CupertinoIcons.paperplane_fill,
                  color: colors.text,
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComposerTool extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _ComposerTool({
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 32,
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.18) : null,
            border: Border.all(color: color.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
