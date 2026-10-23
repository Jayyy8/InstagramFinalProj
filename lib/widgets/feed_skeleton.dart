import "package:flutter/cupertino.dart";

import "shimmer.dart";

/// Placeholder shown instead of the feed while it loads:
/// a stories row and two posts made of shimmering shapes.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        children: const [
          _StoriesSkeleton(),
          SizedBox(height: 16),
          _PostSkeleton(),
          _PostSkeleton(),
        ],
      ),
    );
  }
}

class _StoriesSkeleton extends StatelessWidget {
  const _StoriesSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 6,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Bone.circle(size: 76),
              SizedBox(height: 8),
              Bone(width: 56, height: 10),
            ],
          );
        },
      ),
    );
  }
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Bone.circle(size: 34),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone(width: 130, height: 12),
                    SizedBox(height: 6),
                    Bone(width: 90, height: 10),
                  ],
                ),
              ),
              Bone(width: 72, height: 30),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Bone(width: width, height: width * 1.25, radius: 0);
          },
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Bone(width: 54, height: 22),
              SizedBox(width: 14),
              Bone(width: 54, height: 22),
              SizedBox(width: 14),
              Bone(width: 54, height: 22),
              Spacer(),
              Bone(width: 22, height: 22),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Bone(width: 260, height: 12),
              SizedBox(height: 6),
              Bone(width: 180, height: 12),
              SizedBox(height: 8),
              Bone(width: 80, height: 10),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
