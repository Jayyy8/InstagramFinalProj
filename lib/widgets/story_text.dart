import "dart:math" as math;

import "package:flutter/cupertino.dart";

import "../models/social_models.dart";

/// A text font from the editor's font row.
class TextFont {
  final String key;
  final String label;

  /// Bundled font (see assets/fonts), or null for the phone's own font.
  final String? family;
  final FontWeight weight;
  final bool italic;
  final double letterSpacing;

  /// Some fonts are much bigger or smaller than others at the same size.
  final double sizeFactor;

  const TextFont(
    this.key,
    this.label, {
    this.family,
    this.weight = FontWeight.w700,
    this.italic = false,
    this.letterSpacing = 0,
    this.sizeFactor = 1,
  });
}

/// Instagram's font row, in the same order.
const List<TextFont> kTextFonts = [
  TextFont("modern", "Modern", weight: FontWeight.w500),
  TextFont("classic", "Classic"),
  TextFont("signature", "Signature", family: "IgSignature", sizeFactor: 1.15),
  TextFont("editor", "Editor", family: "IgEditor", weight: FontWeight.w500),
  TextFont("poster", "Poster", family: "IgPoster", weight: FontWeight.w400),
  TextFont("bubble", "Bubble", family: "IgBubble", weight: FontWeight.w600),
  TextFont("deco", "Deco", family: "IgDeco", weight: FontWeight.w400),
  TextFont("squeeze", "Squeeze", family: "IgSqueeze", weight: FontWeight.w400),
  TextFont(
    "typewriter",
    "Typewriter",
    family: "IgTypewriter",
    weight: FontWeight.w400,
  ),
  TextFont("strong", "Strong", weight: FontWeight.w900, italic: true),
  TextFont(
    "meme",
    "Meme",
    family: "IgMeme",
    weight: FontWeight.w400,
    letterSpacing: 1,
  ),
  TextFont("elegant", "Elegant", family: "IgElegant", sizeFactor: 1.15),
  TextFont(
    "directional",
    "Directional",
    family: "IgDirectional",
    weight: FontWeight.w400,
  ),
  TextFont(
    "literature",
    "Literature",
    family: "IgLiterature",
    weight: FontWeight.w500,
    sizeFactor: 1.1,
  ),
  TextFont(
    "arcade",
    "Arcade",
    family: "IgArcade",
    weight: FontWeight.w400,
    sizeFactor: 0.62,
  ),
  TextFont("gothic", "Gothic", family: "IgGothic", weight: FontWeight.w400),
];

TextFont textFont(String key) =>
    kTextFonts.firstWhere((f) => f.key == key, orElse: () => kTextFonts[1]);

/// The effect row (✨A) and the animation row (//A): key and label.
const List<(String, String)> kTextEffects = [
  ("none", "None"),
  ("neon", "Neon"),
  ("glow", "Glow"),
  ("shadow", "Shadow"),
  ("outline", "Outline"),
  ("shimmer", "Shimmer"),
];

const List<(String, String)> kTextAnimations = [
  ("none", "None"),
  ("typewriter", "Typewriter"),
  ("pop", "Pop"),
  ("fade", "Fade"),
  ("jump", "Jump"),
  ("wobble", "Wobble"),
];

/// Text colors (the color wheel row).
const List<int> kTextColors = [
  0xFFFFFFFF,
  0xFF000000,
  0xFF3897F0,
  0xFF70C050,
  0xFFFDCB5C,
  0xFFFD8D32,
  0xFFED4956,
  0xFFD10869,
  0xFFA307BA,
  0xFF262626,
  0xFFB3B3B3,
  0xFFFFC1C1,
];

/// The text's style without its effect / background, at [scale]. Also used
/// for the text field while typing.
TextStyle storyTextStyle(StoryOverlay o, {double scale = 1}) {
  final f = textFont(o.font);
  final color = o.background == 1 ? _onBox(Color(o.color)) : Color(o.color);
  return TextStyle(
    color: color,
    fontFamily: f.family,
    fontWeight: f.weight,
    fontStyle: f.italic ? FontStyle.italic : FontStyle.normal,
    fontSize: o.size * f.sizeFactor * scale,
    letterSpacing: f.letterSpacing * scale,
    height: 1.2,
    decoration: TextDecoration.none,
    shadows: _shadows(o, scale),
  );
}

/// Black or white text on a solid box of the text's color.
Color _onBox(Color box) => box.computeLuminance() > 0.55
    ? const Color(0xFF000000)
    : const Color(0xFFFFFFFF);

List<Shadow> _shadows(StoryOverlay o, double scale) {
  final c = Color(o.color);
  switch (o.effect) {
    case "neon":
      return [
        for (final blur in [4.0, 10.0, 22.0])
          Shadow(color: c.withValues(alpha: 0.9), blurRadius: blur * scale),
      ];
    case "glow":
      return [
        for (final blur in [6.0, 16.0])
          Shadow(color: const Color(0xCCFFFFFF), blurRadius: blur * scale),
      ];
    case "shadow":
      return [
        Shadow(
          color: const Color(0xCC000000),
          offset: Offset(2.5 * scale, 2.5 * scale),
        ),
      ];
    default:
      if (o.background != 0) return const [];
      // A soft shadow keeps plain text readable on any photo.
      final dark = c.computeLuminance() > 0.6;
      return [
        Shadow(
          color: dark ? const Color(0x99000000) : const Color(0x55000000),
          blurRadius: 6 * scale,
        ),
      ];
  }
}

TextAlign _align(int a) => switch (a) {
  0 => TextAlign.left,
  2 => TextAlign.right,
  _ => TextAlign.center,
};

/// A text placed on a story, post or reel, in its font, color, background,
/// effect and animation. [scale] grows it with the photo / video it is on.
class StoryOverlayText extends StatefulWidget {
  final StoryOverlay overlay;
  final double scale;

  /// Play the animation (off while dragging in an editor).
  final bool animate;

  const StoryOverlayText({
    super.key,
    required this.overlay,
    this.scale = 1,
    this.animate = true,
  });

  @override
  State<StoryOverlayText> createState() => _StoryOverlayTextState();
}

class _StoryOverlayTextState extends State<StoryOverlayText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant StoryOverlayText old) {
    super.didUpdateWidget(old);
    final o = widget.overlay;
    if (old.overlay.animation != o.animation ||
        old.overlay.effect != o.effect ||
        old.overlay.text != o.text ||
        old.animate != widget.animate) {
      _start();
    }
  }

  void _start() {
    final o = widget.overlay;
    final loops =
        o.effect == "shimmer" ||
        o.animation == "jump" ||
        o.animation == "wobble";
    _anim.stop();
    if (!widget.animate || (o.animation == "none" && !loops)) {
      _anim.value = 1;
      return;
    }
    _anim.duration = switch (o.animation) {
      "typewriter" => Duration(
        milliseconds: (o.text.length * 70).clamp(400, 4000),
      ),
      "pop" => const Duration(milliseconds: 650),
      "fade" => const Duration(milliseconds: 800),
      _ => const Duration(milliseconds: 1600),
    };
    if (loops) {
      _anim.repeat();
    } else {
      _anim.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.overlay;
    final scale = widget.scale;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = _anim.value;
        final once = o.animation == "jump" || o.animation == "wobble" ? 1.0 : t;
        final shown = o.animation == "typewriter"
            ? o.text.substring(0, (o.text.length * once).round())
            : o.text;

        final style = storyTextStyle(o, scale: scale);
        Widget text = Text(shown, textAlign: _align(o.align), style: style);

        if (o.effect == "outline") {
          text = Stack(
            children: [
              Text(
                shown,
                textAlign: _align(o.align),
                style: style.copyWith(
                  shadows: const [],
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 4 * scale
                    ..strokeJoin = StrokeJoin.round
                    ..color = Color(o.color).computeLuminance() > 0.5
                        ? const Color(0xFF000000)
                        : const Color(0xFFFFFFFF),
                ),
              ),
              text,
            ],
          );
        } else if (o.effect == "shimmer") {
          // A light band sweeping across the letters.
          text = ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(-1 + 3 * t - 1, 0),
              end: Alignment(-1 + 3 * t, 0),
              colors: [
                const Color(0x00FFFFFF),
                const Color(0xCCFFFFFF),
                const Color(0x00FFFFFF),
              ],
            ).createShader(rect),
            child: text,
          );
        }

        if (o.background != 0) {
          text = Container(
            padding: EdgeInsets.symmetric(
              horizontal: 9 * scale,
              vertical: 4 * scale,
            ),
            decoration: BoxDecoration(
              color: o.background == 1
                  ? Color(o.color)
                  : const Color(0x99000000),
              borderRadius: BorderRadius.circular(7 * scale),
            ),
            child: text,
          );
        }

        switch (o.animation) {
          case "pop":
            final s = Curves.elasticOut.transform(t.clamp(0.0, 1.0));
            return Transform.scale(scale: 0.3 + 0.7 * s, child: text);
          case "fade":
            return Opacity(opacity: t.clamp(0.0, 1.0), child: text);
          case "jump":
            return Transform.translate(
              offset: Offset(0, -math.sin(t * 2 * math.pi).abs() * 8 * scale),
              child: text,
            );
          case "wobble":
            return Transform.rotate(
              angle: math.sin(t * 2 * math.pi) * 0.06,
              child: text,
            );
          default:
            return text;
        }
      },
    );
  }
}
