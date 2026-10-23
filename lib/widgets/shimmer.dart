import "package:flutter/cupertino.dart";

import "../theme/app_theme.dart";

/// Moving highlight drawn over its child (loading placeholders).
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.of(context).dark;
    final base = dark ? const Color(0xFF1F1F23) : const Color(0xFFE4E4EA);
    final light = dark ? const Color(0xFF34343A) : const Color(0xFFF5F5F9);

    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) {
        final t = _ctrl.value * 3 - 1; // -1 .. 2
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(t - 1, -0.3),
            end: Alignment(t + 1, 0.3),
            colors: [base, light, base],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// Grey shape used inside a [Shimmer].
class Bone extends StatelessWidget {
  final double? width;
  final double? height;
  final bool circle;
  final double radius;

  const Bone({super.key, this.width, this.height, this.radius = 6})
    : circle = false;

  const Bone.circle({super.key, required double size})
    : width = size,
      height = size,
      circle = true,
      radius = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.of(context).placeholder,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}
