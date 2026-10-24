import "package:flutter/cupertino.dart";

import "../theme/app_theme.dart";
import "feed_image.dart";

/// Round avatar. [ring] draws the Instagram story ring (grey when [seen]).
class GradientAvatar extends StatelessWidget {
  final String name;
  final double size;
  final List<String>? imageUrls;
  final bool ring;
  final bool seen;
  final bool showPlus;
  final VoidCallback? onPlus;

  /// Green Close Friends ring instead of the gradient.
  final bool closeFriends;

  const GradientAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.imageUrls,
    this.ring = true,
    this.seen = false,
    this.showPlus = false,
    this.onPlus,
    this.closeFriends = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : "?";
    final double ringWidth = size > 50 ? 2.5 : 2;

    final Widget inner = ClipOval(
      child: SizedBox.expand(
        child: imageUrls != null && imageUrls!.isNotEmpty
            ? FeedImage(urls: imageUrls!)
            : ColoredBox(
                color: colors.dark
                    ? const Color(0xFF363636)
                    : const Color(0xFFDBDBDB),
                child: Center(
                  child: Icon(
                    CupertinoIcons.person_fill,
                    size: size * 0.62,
                    color: colors.dark
                        ? const Color(0xFF8E8E8E)
                        : const Color(0xFFFFFFFF),
                    semanticLabel: initial,
                  ),
                ),
              ),
      ),
    );

    final Widget avatar = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring ? (seen ? 1 : ringWidth) : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring && seen
            ? colors.separator
            : (ring && closeFriends ? kCloseFriendsGreen : null),
        gradient: ring && !seen && !closeFriends
            ? const LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: kStoryRingColors,
              )
            : null,
      ),
      child: Container(
        padding: EdgeInsets.all(ring ? (seen ? ringWidth + 1 : ringWidth) : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.background,
        ),
        child: inner,
      ),
    );

    if (!showPlus) return avatar;

    final plus = Container(
      width: size * 0.32,
      height: size * 0.32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
        border: Border.all(color: colors.background, width: 2.5),
      ),
      child: Icon(
        CupertinoIcons.add,
        size: size * 0.19,
        color: colors.dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: onPlus == null
                ? plus
                : GestureDetector(onTap: onPlus, child: plus),
          ),
        ],
      ),
    );
  }
}
