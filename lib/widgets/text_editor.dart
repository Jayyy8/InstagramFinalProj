import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/social_models.dart";
import "../providers/social_providers.dart";
import "../theme/app_theme.dart";
import "dialogs.dart";
import "gradient_avatar.dart";
import "music_picker.dart";
import "story_text.dart";

/// The tool row's buttons.
enum _Tool { font, color, animation, effect }

/// Instagram's text editor, laid over a story / post / reel editor: size
/// slider, fonts, colors, animations, effects, alignment, background box,
/// Mention and Location. [onDone] gets the text, or null when it was
/// emptied (remove it).
class TextEditorOverlay extends ConsumerStatefulWidget {
  final StoryOverlay initial;

  /// Size of the text on screen compared with its saved size.
  final double scale;
  final ValueChanged<StoryOverlay?> onDone;

  /// Location button: the story editor adds a location sticker (return
  /// null); elsewhere the place goes into the text.
  final Future<String?> Function()? onLocation;

  const TextEditorOverlay({
    super.key,
    required this.initial,
    required this.onDone,
    this.scale = 1,
    this.onLocation,
  });

  @override
  ConsumerState<TextEditorOverlay> createState() => _TextEditorOverlayState();
}

class _TextEditorOverlayState extends ConsumerState<TextEditorOverlay> {
  late StoryOverlay _o = widget.initial;
  late final TextEditingController _text = TextEditingController(
    text: widget.initial.text,
  );
  final FocusNode _focus = FocusNode();
  _Tool _tool = _Tool.font;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() => _o = _o.copyWith(text: _text.text)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _done() {
    final t = _text.text.trim();
    widget.onDone(t.isEmpty ? null : _o.copyWith(text: t));
  }

  void _insert(String value) {
    final sel = _text.selection;
    final at = sel.isValid ? sel.start : _text.text.length;
    final end = sel.isValid ? sel.end : _text.text.length;
    final next = _text.text.replaceRange(at, end, value);
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at + value.length),
    );
    _focus.requestFocus();
  }

  Future<void> _mention() async {
    final person = await showIgSheet<Profile>(
      context,
      heightFactor: 0.7,
      builder: (_) => const _MentionSheet(),
    );
    if (person != null && mounted) _insert("@${person.username} ");
  }

  Future<void> _location() async {
    final custom = widget.onLocation;
    if (custom != null) {
      final place = await custom();
      if (place != null && place.isNotEmpty && mounted) _insert("📍$place ");
      return;
    }
    final place = await askLocation(context);
    if (place != null && place.isNotEmpty && mounted) _insert("📍$place ");
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final style = storyTextStyle(_o, scale: widget.scale);
    final align = switch (_o.align) {
      0 => TextAlign.left,
      2 => TextAlign.right,
      _ => TextAlign.center,
    };

    return Positioned.fill(
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
        child: Stack(
          children: [
            // Dim the story; tapping outside the text finishes it.
            Positioned.fill(
              child: GestureDetector(
                onTap: _done,
                child: const ColoredBox(color: Color(0xB3000000)),
              ),
            ),
            Positioned(
              top: media.padding.top + 4,
              right: 4,
              child: CupertinoButton(
                onPressed: _done,
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

            // ───── Size slider (left) ─────
            Positioned(
              left: 0,
              top: media.padding.top + 90,
              child: SizedBox(
                width: 44,
                height: 230,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(14, 210),
                      painter: _TaperPainter(),
                    ),
                    RotatedBox(
                      quarterTurns: 3,
                      child: SizedBox(
                        width: 230,
                        child: CupertinoSlider(
                          value: _o.size.clamp(14.0, 90.0),
                          min: 14,
                          max: 90,
                          activeColor: const Color(0x00FFFFFF),
                          thumbColor: const Color(0xFFFFFFFF),
                          onChanged: (v) =>
                              setState(() => _o = _o.copyWith(size: v)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ───── The text, styled while you type ─────
            Positioned(
              left: 44,
              right: 24,
              top: media.padding.top + 110,
              child: Align(
                alignment: switch (_o.align) {
                  0 => Alignment.centerLeft,
                  2 => Alignment.centerRight,
                  _ => Alignment.center,
                },
                child: IntrinsicWidth(
                  child: CupertinoTextField(
                    controller: _text,
                    focusNode: _focus,
                    maxLines: null,
                    textAlign: align,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: Color(_o.color),
                    style: style,
                    padding: EdgeInsets.symmetric(
                      horizontal: _o.background == 0 ? 2 : 10,
                      vertical: 4,
                    ),
                    decoration: _o.background == 0
                        ? null
                        : BoxDecoration(
                            color: _o.background == 1
                                ? Color(_o.color)
                                : const Color(0x99000000),
                            borderRadius: BorderRadius.circular(8),
                          ),
                  ),
                ),
              ),
            ),

            // ───── Style rows above the keyboard ─────
            Positioned(
              left: 0,
              right: 0,
              bottom: keyboard > 0 ? keyboard : media.padding.bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 44, child: _optionRow()),
                  const SizedBox(height: 6),
                  _toolRow(),
                  const SizedBox(height: 6),
                  Container(
                    height: 40,
                    color: const Color(0x33000000),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TextLink(
                            icon: CupertinoIcons.at,
                            label: "Mention",
                            onTap: _mention,
                          ),
                        ),
                        Container(
                          width: 0.5,
                          height: 20,
                          color: const Color(0x66FFFFFF),
                        ),
                        Expanded(
                          child: _TextLink(
                            icon: CupertinoIcons.location,
                            label: "Location",
                            onTap: _location,
                          ),
                        ),
                      ],
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

  Widget _toolRow() {
    Widget tool(_Tool t, Widget child, String label) => Semantics(
      button: true,
      selected: _tool == t,
      label: label,
      child: GestureDetector(
        onTap: () => setState(() => _tool = t),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _tool == t
                ? const Color(0x55FFFFFF)
                : const Color(0x00000000),
          ),
          child: child,
        ),
      ),
    );
    Widget toggle(
      IconData icon,
      String label,
      VoidCallback onTap, {
      bool on = false,
    }) => Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? const Color(0xFFFFFFFF) : const Color(0x00000000),
          ),
          child: Icon(
            icon,
            size: 22,
            color: on ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
          ),
        ),
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        tool(
          _Tool.font,
          const Text(
            "Aa",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          "Fonts",
        ),
        tool(
          _Tool.color,
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Color(0xFFED4956),
                  Color(0xFFFDCB5C),
                  Color(0xFF70C050),
                  Color(0xFF3897F0),
                  Color(0xFFA307BA),
                  Color(0xFFED4956),
                ],
              ),
            ),
          ),
          "Colors",
        ),
        tool(
          _Tool.animation,
          const Text(
            "//A",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
            ),
          ),
          "Animations",
        ),
        tool(
          _Tool.effect,
          const Icon(CupertinoIcons.sparkles, size: 22),
          "Effects",
        ),
        toggle(
          switch (_o.align) {
            0 => CupertinoIcons.text_alignleft,
            2 => CupertinoIcons.text_alignright,
            _ => CupertinoIcons.text_aligncenter,
          },
          "Alignment",
          () => setState(
            () => _o = _o.copyWith(
              align: switch (_o.align) {
                1 => 0,
                0 => 2,
                _ => 1,
              },
            ),
          ),
        ),
        toggle(
          CupertinoIcons.textbox,
          "Text background",
          () => setState(
            () => _o = _o.copyWith(background: (_o.background + 1) % 3),
          ),
          on: _o.background != 0,
        ),
      ],
    );
  }

  Widget _optionRow() {
    Widget chip(String label, bool on, VoidCallback onTap, {TextStyle? style}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? const Color(0xFFFFFFFF) : const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: (style ?? const TextStyle(fontSize: 14)).copyWith(
              color: on ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
              decoration: TextDecoration.none,
              shadows: const [],
            ),
          ),
        ),
      );
    }

    switch (_tool) {
      case _Tool.font:
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          children: [
            for (final f in kTextFonts)
              chip(
                f.label,
                _o.font == f.key,
                () => setState(() => _o = _o.copyWith(font: f.key)),
                style: TextStyle(
                  fontFamily: f.family,
                  fontWeight: f.weight,
                  fontStyle: f.italic ? FontStyle.italic : FontStyle.normal,
                  fontSize: 14 * f.sizeFactor,
                ),
              ),
          ],
        );
      case _Tool.color:
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          children: [
            for (final c in kTextColors)
              GestureDetector(
                onTap: () => setState(() => _o = _o.copyWith(color: c)),
                child: Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFFFFF),
                      width: c == _o.color ? 3 : 1.5,
                    ),
                  ),
                ),
              ),
          ],
        );
      case _Tool.animation:
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          children: [
            for (final (key, label) in kTextAnimations)
              chip(
                label,
                _o.animation == key,
                () => setState(() => _o = _o.copyWith(animation: key)),
              ),
          ],
        );
      case _Tool.effect:
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          children: [
            for (final (key, label) in kTextEffects)
              chip(
                label,
                _o.effect == key,
                () => setState(() => _o = _o.copyWith(effect: key)),
              ),
          ],
        );
    }
  }
}

class _TextLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TextLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFFFFFF)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// The size slider's track: narrow at the bottom, wide at the top.
class _TaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2 + 1, size.height)
      ..lineTo(size.width / 2 - 1, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xCCFFFFFF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pick someone to @mention.
class _MentionSheet extends ConsumerStatefulWidget {
  const _MentionSheet();

  @override
  ConsumerState<_MentionSheet> createState() => _MentionSheetState();
}

class _MentionSheetState extends ConsumerState<_MentionSheet> {
  String _query = "";

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final me = ref.watch(currentUserIdProvider);
    final q = _query.trim();
    final people = q.isEmpty
        ? (ref.watch(followingListProvider(me ?? "")).valueOrNull ?? const [])
        : (ref.watch(userSearchProvider(q)).valueOrNull ?? const []);
    final list = people.where((p) => p.id != me).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: CupertinoSearchTextField(
            autofocus: true,
            placeholder: "Mention someone",
            style: TextStyle(color: colors.text),
            backgroundColor: colors.dark
                ? const Color(0xFF363636)
                : colors.field,
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    q.isEmpty ? "Search for someone" : "No one found",
                    style: TextStyle(color: colors.secondaryText),
                  ),
                )
              : ListView.builder(
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
                              size: 40,
                              ring: false,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                p.username,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colors.text,
                                ),
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
