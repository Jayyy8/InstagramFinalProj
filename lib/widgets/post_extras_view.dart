import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:url_launcher/url_launcher.dart";

import "../models/feed_models.dart";
import "../models/post_extras.dart";
import "../providers/feed_provider.dart";
import "../theme/app_theme.dart";
import "dialogs.dart";
import "post_actions.dart";

/// A post's poll: tap an answer to vote, tap it again to take it back.
class PostPollView extends ConsumerWidget {
  final FeedPost post;

  const PostPollView({super.key, required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poll = post.poll!;
    final colors = AppColors.of(context);
    final votes = [
      for (int i = 0; i < poll.options.length; i++)
        i < post.pollVotes.length ? post.pollVotes[i] : 0,
    ];
    final total = votes.fold(0, (a, b) => a + b);
    final voted = post.myVote != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colors.separator),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (poll.question.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                poll.question,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
            ),
          for (int i = 0; i < poll.options.length; i++)
            Semantics(
              button: true,
              selected: post.myVote == i,
              child: GestureDetector(
                onTap: () => ref
                    .read(postActionsProvider)
                    .vote(post, i)
                    .catchError((Object e) {
                      if (context.mounted) {
                        showToast(context, errorText(e), error: true);
                      }
                    }),
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: colors.field,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      if (voted)
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: total == 0 ? 0 : votes[i] / total,
                            child: ColoredBox(
                              color: post.myVote == i
                                  ? kIgBlue.withValues(alpha: 0.35)
                                  : colors.button,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                poll.options[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: post.myVote == i
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: colors.text,
                                ),
                              ),
                            ),
                            if (voted)
                              Text(
                                "${total == 0 ? 0 : (votes[i] * 100 / total).round()}%",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.text,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Text(
            voted
                ? "$total ${total == 1 ? "vote" : "votes"} · Tap your answer to undo"
                : "Tap to vote",
            style: TextStyle(fontSize: 12, color: colors.secondaryText),
          ),
        ],
      ),
    );
  }
}

/// A post's prompt: a question answered in the comments.
class PostPromptView extends StatelessWidget {
  final FeedPost post;

  const PostPromptView({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x1A962FBF), Color(0x1AFA7E1E)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.search, size: 20, color: colors.text),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Prompt",
                  style: TextStyle(fontSize: 12, color: colors.secondaryText),
                ),
                Text(
                  post.prompt!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ],
            ),
          ),
          if (!post.commentsOff)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 32),
              onPressed: () => openComments(context, post),
              child: const Text(
                "Answer",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}

/// "🔗 example.com" under the caption; opens in the browser.
class PostLinkView extends StatelessWidget {
  final PostLink link;

  const PostLinkView({super.key, required this.link});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(link.url);
        final ok =
            uri != null &&
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && context.mounted) {
          showToast(context, "Couldn't open the link", error: true);
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            const Icon(CupertinoIcons.link, size: 15, color: kIgBlue),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                link.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kIgBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
