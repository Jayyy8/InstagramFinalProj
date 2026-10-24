import "package:flutter/cupertino.dart";

import "../models/feed_models.dart";
import "../navigation.dart";
import "../pages/post_detail_page.dart";
import "feed_image.dart";
import "post_video.dart";

/// 3-column photo grid. Tapping a photo opens the full post.
class PostGrid extends StatelessWidget {
  final List<FeedPost> posts;
  final bool scrollable;
  final EdgeInsets padding;

  /// Instagram's profile grid uses tall 3:4 tiles; explore uses squares.
  final double aspectRatio;

  const PostGrid({
    super.key,
    required this.posts,
    this.scrollable = true,
    this.padding = EdgeInsets.zero,
    this.aspectRatio = 3 / 4,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: !scrollable,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 1.5,
        crossAxisSpacing: 1.5,
        childAspectRatio: aspectRatio,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) => PostTile(post: posts[index]),
    );
  }
}

class PostTile extends StatelessWidget {
  final FeedPost post;

  const PostTile({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => push(context, PostDetailPage(postId: post.id)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (post.isVideo)
            PostVideo(url: post.imageUrls.first, thumbnail: true)
          else
            FeedImage(urls: post.cover),
          if (post.isVideo)
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(
                CupertinoIcons.play_rectangle_fill,
                size: 16,
                color: Color(0xFFFFFFFF),
              ),
            )
          else if (post.photos.length > 1)
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(
                CupertinoIcons.square_stack_fill,
                size: 16,
                color: Color(0xFFFFFFFF),
              ),
            ),
        ],
      ),
    );
  }
}
