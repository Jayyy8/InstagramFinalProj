import "package:flutter/cupertino.dart";
import "package:flutter/services.dart";
import "package:qr/qr.dart";

import "../models/social_models.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";

/// Background / code color themes, switched with the "COLOR" chip.
const List<List<Color>> _themes = [
  [Color(0xFF4F5BD5), Color(0xFF962FBF), Color(0xFFD62976)],
  [Color(0xFFFA7E1E), Color(0xFFD62976), Color(0xFF962FBF)],
  [Color(0xFF0F9B8E), Color(0xFF1BD760), Color(0xFF0095F6)],
  [Color(0xFF111111), Color(0xFF333333), Color(0xFF555555)],
];

/// Profile → Share profile: QR code that links to your profile.
class ShareProfilePage extends StatefulWidget {
  final Profile profile;

  const ShareProfilePage({super.key, required this.profile});

  @override
  State<ShareProfilePage> createState() => _ShareProfilePageState();
}

class _ShareProfilePageState extends State<ShareProfilePage> {
  int _theme = 0;

  String get _link => "instagram-replica://u/${widget.profile.username}";

  Future<void> _copy(String message) async {
    await Clipboard.setData(ClipboardData(text: _link));
    if (mounted) showToast(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final colors = _themes[_theme];
    final code = QrImage(QrCode(payload: QrPayload.fromString(_link)));

    Widget action(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(icon, color: const Color(0xFF000000), size: 24),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return PlainPage(
      background: colors[1],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: Color(0xFFFFFFFF),
                      size: 26,
                      semanticLabel: "Close",
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _theme = (_theme + 1) % _themes.length),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0x99FFFFFF)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        "COLOR",
                        style: TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 60),
                ],
              ),
            ),
            const Spacer(),
            Container(
              width: 260,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 20),
                ],
              ),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (rect) => LinearGradient(
                              colors: colors,
                            ).createShader(rect),
                            child: CustomPaint(painter: _QrPainter(code)),
                          ),
                        ),
                        // Instagram logo in the middle of the code.
                        Center(
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.bottomLeft,
                                  end: Alignment.topRight,
                                  colors: kStoryRingColors,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                CupertinoIcons.camera,
                                color: Color(0xFFFFFFFF),
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (rect) =>
                        LinearGradient(colors: colors).createShader(rect),
                    child: Text(
                      "@${widget.profile.username.toUpperCase()}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 280,
              child: Row(
                children: [
                  action(
                    CupertinoIcons.share,
                    "Share profile",
                    () => _copy("Profile link copied, paste it to share"),
                  ),
                  action(
                    CupertinoIcons.link,
                    "Copy link",
                    () => _copy("Link copied"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "Others can scan this code to find your profile.",
              style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 14),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Draws the QR modules (black squares) to fill the box.
class _QrPainter extends CustomPainter {
  final QrImage code;

  _QrPainter(this.code);

  @override
  void paint(Canvas canvas, Size size) {
    final n = code.moduleCount;
    final cell = size.width / n;
    final paint = Paint()..color = const Color(0xFF000000);
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (code.isDark(r, c)) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(c * cell, r * cell, cell, cell).deflate(0.4),
              Radius.circular(cell * 0.3),
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter old) => old.code != code;
}
