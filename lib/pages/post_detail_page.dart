import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/feed_provider.dart";
import "../widgets/post_card.dart";
import "../widgets/sub_page.dart";

class PostDetailPage extends ConsumerWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(postProvider(postId));

    if (post == null) {
      return const SubPage(
        title: "Post",
        child: Center(child: Text("This post is no longer available.")),
      );
    }

    return SubPage(
      title: post.remote ? "Posts" : "Explore",
      child: ListView(children: [PostCard(post: post)]),
    );
  }
}
