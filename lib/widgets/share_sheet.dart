import "dart:io";

import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:http/http.dart" as http;
import "package:image_picker/image_picker.dart";

import "../models/feed_models.dart";
import "../models/social_models.dart";
import "../navigation.dart";
import "../pages/discover_people_page.dart";
import "../pages/story_create_page.dart";
import "../providers/chat_provider.dart";
import "../providers/feed_provider.dart";
import "../providers/social_providers.dart";
import "../theme/app_theme.dart";
import "dialogs.dart";
import "gradient_avatar.dart";
import "post_actions.dart";

/// Instagram's share sheet: search, tap people to select them (✓), then
/// Send. Below: Add to story, Copy link, Share to feed (repost).
void showShareSheet(BuildContext context, FeedPost post) {
  showIgSheet<void>(
    context,
    heightFactor: 0.82,
    builder: (_) => _ShareSheet(post: post),
  );
}

class _ShareSheet extends ConsumerStatefulWidget {
  final FeedPost post;

  const _ShareSheet({required this.post});

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _message = TextEditingController();

  /// People picked, in the order they were tapped.
  final List<Profile> _picked = [];
  bool _sending = false;
  String _query = "";

  @override
  void dispose() {
    _search.dispose();
    _message.dispose();
    super.dispose();
  }

  /// Recent chats first, then people you follow, then your followers.
  List<Profile> _people() {
    final me = ref.watch(currentUserIdProvider);
    if (me == null) return const [];
    final chats = ref.watch(conversationsProvider).valueOrNull ?? const [];
    final following =
        ref.watch(followingListProvider(me)).valueOrNull ?? const [];
    final followers =
        ref.watch(followersListProvider(me)).valueOrNull ?? const [];
    final seen = <String>{me};
    return [
      for (final p in [
        for (final c in chats) c.partner,
        ...following,
        ...followers,
      ])
        if (seen.add(p.id)) p,
    ];
  }

  void _toggle(Profile p) {
    setState(() {
      final i = _picked.indexWhere((x) => x.id == p.id);
      if (i < 0) {
        _picked.add(p);
      } else {
        _picked.removeAt(i);
      }
    });
  }

  Future<void> _send() async {
    if (_picked.isEmpty || _sending) return;
    final post = widget.post;
    setState(() => _sending = true);
    final note = _message.text.trim();
    try {
      for (final to in _picked) {
        await sendDirect(
          ref,
          to: to.id,
          text: note,
          contextType: "post_share",
          contextText: post.isVideo
              ? "\u{1F3AC} Video · ${post.authorName}: ${post.caption}"
              : "${post.authorName}: ${post.caption}",
          // A video URL can't be shown as a picture in the chat.
          contextMediaUrl: post.isVideo || post.cover.isEmpty
              ? null
              : post.cover.first,
        );
      }
      if (!mounted) return;
      final names = _picked.length == 1
          ? _picked.first.username
          : "${_picked.length} people";
      Navigator.of(context).pop();
      showToast(context, "Sent to $names");
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showToast(context, errorText(e), error: true);
    }
  }

  /// The post's photo (or video) as a new story.
  Future<void> _addToStory() async {
    final post = widget.post;
    final url = post.isVideo ? post.imageUrls.first : post.cover.firstOrNull;
    if (url == null) return;
    final navigator = Navigator.of(context);
    showToast(context, "Getting the post ready...");
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception("Download failed");
      final dir = await Directory.systemTemp.createTemp("share");
      final file = File("${dir.path}/post.${post.isVideo ? "mp4" : "jpg"}");
      await file.writeAsBytes(response.bodyBytes, flush: true);
      if (!mounted) return;
      navigator.pop();
      await pushFullscreen(
        navigator.context,
        StoryEditorPage(file: XFile(file.path), video: post.isVideo),
      );
    } catch (_) {
      if (mounted) {
        showToast(context, "Couldn't open the post for a story", error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final q = _query.trim().toLowerCase();
    var people = _people();
    if (q.isNotEmpty) {
      people = people
          .where(
            (p) =>
                p.username.toLowerCase().contains(q) ||
                p.fullName.toLowerCase().contains(q),
          )
          .toList();
      // Anyone on the app, when nobody you know matches.
      if (people.isEmpty) {
        final me = ref.watch(currentUserIdProvider);
        people = (ref.watch(userSearchProvider(q)).valueOrNull ?? const [])
            .where((p) => p.id != me)
            .toList();
      }
    }
    final reposted =
        ref.watch(myRepostsProvider).valueOrNull?.contains(widget.post.id) ??
        false;

    return Column(
      children: [
        // ───── Search + find people ─────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: CupertinoSearchTextField(
                  controller: _search,
                  placeholder: "Search",
                  style: TextStyle(color: colors.text),
                  backgroundColor: colors.dark
                      ? const Color(0xFF363636)
                      : colors.field,
                  borderRadius: BorderRadius.circular(12),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: "Find people",
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    push(context, const DiscoverPeoplePage());
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.dark
                          ? const Color(0xFF363636)
                          : colors.field,
                    ),
                    child: Icon(
                      CupertinoIcons.person_add,
                      size: 20,
                      color: colors.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ───── People: tap to select ─────
        Expanded(
          child: people.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      q.isEmpty
                          ? "Follow people to send them posts."
                          : "No one found.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.secondaryText),
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.74,
                  ),
                  itemCount: people.length,
                  itemBuilder: (context, i) {
                    final p = people[i];
                    final picked = _picked.any((x) => x.id == p.id);
                    return Semantics(
                      button: true,
                      selected: picked,
                      label: p.displayName,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _toggle(p),
                        child: Column(
                          children: [
                            const SizedBox(height: 6),
                            Stack(
                              children: [
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 150),
                                  opacity: picked ? 0.75 : 1,
                                  child: GradientAvatar(
                                    name: p.username,
                                    imageUrls: p.avatarUrls,
                                    size: 82,
                                    ring: false,
                                  ),
                                ),
                                if (picked)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: kIgBlue,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colors.sheet,
                                          width: 2.5,
                                        ),
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.checkmark_alt,
                                        size: 15,
                                        color: Color(0xFFFFFFFF),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Text(
                              p.displayName,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.text,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(height: 0.5, color: colors.separator),

        // ───── Send (people picked) or the share options ─────
        if (_picked.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              children: [
                CupertinoTextField(
                  controller: _message,
                  placeholder: "Write a message...",
                  placeholderStyle: TextStyle(color: colors.secondaryText),
                  style: TextStyle(color: colors.text),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
                  decoration: null,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: kIgBlue,
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const CupertinoActivityIndicator(
                            color: Color(0xFFFFFFFF),
                          )
                        : Text(
                            _picked.length == 1 ? "Send" : "Send separately",
                            style: const TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              children: [
                _ShareOption(
                  icon: CupertinoIcons.add_circled,
                  label: "Add to story",
                  onTap: _addToStory,
                ),
                _ShareOption(
                  icon: CupertinoIcons.link,
                  label: "Copy link",
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    await copyPostLink(context, widget.post);
                    navigator.pop();
                  },
                ),
                _ShareOption(
                  icon: CupertinoIcons.arrow_2_squarepath,
                  label: reposted ? "On your feed" : "Share to feed",
                  active: reposted,
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    await toggleRepost(context, ref, widget.post);
                    navigator.pop();
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 84,
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF2ECC71)
                      : (colors.dark ? const Color(0xFF363636) : colors.field),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: active ? const Color(0xFFFFFFFF) : colors.text,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
