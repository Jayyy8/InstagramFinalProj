import "dart:async";

import "package:flutter/cupertino.dart";
import "package:flutter/services.dart";
import "package:adaptive_platform_ui/adaptive_platform_ui.dart";

import "../theme/app_theme.dart";
import "auth_button.dart";

bool isValidEmail(String value) =>
    RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(value.trim());

const List<Color> kInstagramColors = [
  Color(0xFFFFB000),
  Color(0xFFFF2D55),
  Color(0xFF8E2DE2),
];

/// "Instagram" wordmark with the gradient.
class AuthLogo extends StatelessWidget {
  final double size;

  const AuthLogo({super.key, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) =>
          const LinearGradient(colors: kInstagramColors).createShader(rect),
      child: Text(
        "Instagram",
        style: TextStyle(
          fontSize: size,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w700,
          color: CupertinoColors.white,
          fontFamily: "Snell Roundhand",
          fontFamilyFallback: const [
            "Brush Script MT",
            "Segoe Script",
            "cursive",
          ],
        ),
      ),
    );
  }
}

/// Gradient icon badge with a title and subtitle, used at the top of auth pages.
class AuthHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const AuthHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: kInstagramColors,
            ),
          ),
          child: Icon(icon, size: 34, color: CupertinoColors.white),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.35,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ],
    );
  }
}

/// Progress dots for multi-step flows (current is zero-based).
class StepDots extends StatelessWidget {
  final int current;
  final int total;

  const StepDots({super.key, required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: i == current ? 22 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i <= current ? kAuthBlue : const Color(0xFF6E6E73),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

/// Four-segment password strength bar with a label.
class PasswordStrength extends StatelessWidget {
  final String password;

  const PasswordStrength({super.key, required this.password});

  int get _score {
    int s = 0;
    if (password.length >= 8) s++;
    if (RegExp(r"[A-Z]").hasMatch(password) &&
        RegExp(r"[a-z]").hasMatch(password)) {
      s++;
    }
    if (RegExp(r"\d").hasMatch(password)) s++;
    if (RegExp(r"[^A-Za-z0-9]").hasMatch(password)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final score = _score;
    const labels = ["Very weak", "Weak", "Fair", "Good", "Strong"];
    const colors = [
      CupertinoColors.systemRed,
      CupertinoColors.systemRed,
      CupertinoColors.systemOrange,
      CupertinoColors.systemYellow,
      CupertinoColors.systemGreen,
    ];
    final filled = score == 0 ? 1 : score;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                for (int i = 0; i < 4; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: i < filled
                            ? colors[score]
                            : const Color(0x336E6E73),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            labels[score],
            style: TextStyle(fontSize: 12, color: colors[score]),
          ),
        ],
      ),
    );
  }
}

/// One-time code input made of boxes. The boxes are the input: a transparent
/// glass text field sits on top of them, so tapping a box opens the number
/// keyboard and typed digits fill the boxes one by one.
class CodeInput extends StatefulWidget {
  final TextEditingController controller;
  final int length;

  const CodeInput({super.key, required this.controller, this.length = 8});

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _focus.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focus.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final Color fill = isDark
        ? const Color(0xFF1C1C1F)
        : const Color(0xFFF2F2F7);
    final Color border = isDark
        ? const Color(0xFF2A2A2E)
        : const Color(0xFFD9D9E0);

    final digits = widget.controller.text.replaceAll(RegExp(r"\D"), "");

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          // The visible boxes.
          Row(
            children: [
              for (int i = 0; i < widget.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AspectRatio(
                      aspectRatio: 0.78,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _focus.hasFocus && i == digits.length
                                ? kAuthBlue
                                : border,
                            width: _focus.hasFocus && i == digits.length
                                ? 1.6
                                : 1,
                          ),
                        ),
                        child: Text(
                          i < digits.length ? digits[i] : "",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // The real input: invisible, on top of the boxes.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: CupertinoTextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: true,
                keyboardType: TextInputType.number,
                showCursor: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Resend" button with a countdown (matches the 60 s email limit).
/// The countdown starts as soon as the button appears.
class ResendButton extends StatefulWidget {
  final String label;
  final Future<bool> Function() onResend;
  final int seconds;

  const ResendButton({
    super.key,
    required this.label,
    required this.onResend,
    this.seconds = 60,
  });

  @override
  State<ResendButton> createState() => _ResendButtonState();
}

class _ResendButtonState extends State<ResendButton> {
  Timer? _timer;
  late int _left;

  @override
  void initState() {
    super.initState();
    _left = widget.seconds;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _left--;
        if (_left <= 0) timer.cancel();
      });
    });
  }

  Future<void> _resend() async {
    final ok = await widget.onResend();
    if (ok && mounted) {
      setState(() => _left = widget.seconds);
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthButton(
      label: _left > 0 ? "${widget.label} (${_left}s)" : widget.label,
      outlined: true,
      onTap: _left > 0 ? null : _resend,
    );
  }
}

/// Text field for the login and sign-up forms.
/// Cupertino style on iPhone, Material outlined field on Android.
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;

  const AuthField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AdaptiveTextField(
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboardType,
      obscureText: obscure,
      autocorrect: false,
      suffixIcon: suffix,
      style: TextStyle(color: colors.text, fontSize: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      cupertinoDecoration: BoxDecoration(
        color: colors.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.separator, width: 0.5),
      ),
    );
  }
}

/// Password field with a show / hide eye button.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String placeholder;

  const PasswordField({
    super.key,
    required this.controller,
    this.placeholder = "Password",
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return AuthField(
      controller: widget.controller,
      placeholder: widget.placeholder,
      obscure: _hidden,
      suffix: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(40, 40),
        onPressed: () => setState(() => _hidden = !_hidden),
        child: Icon(
          _hidden ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
          size: 20,
          color: AppColors.of(context).secondaryText,
        ),
      ),
    );
  }
}
