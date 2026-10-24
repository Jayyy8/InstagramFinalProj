import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../models/feed_models.dart";
import "../../models/social_models.dart";
import "../../navigation.dart";
import "../../providers/chat_provider.dart";
import "../../providers/notes_provider.dart";
import "../../providers/social_providers.dart";
import "../../theme/app_theme.dart";
import "../../widgets/feed_image.dart";
import "../../widgets/dialogs.dart";
import "../../widgets/gradient_avatar.dart";
import "../../widgets/follow_button.dart";
import "../../widgets/post_actions.dart";
import "../chat_page.dart";
import "../discover_people_page.dart";
import "../instant_camera_page.dart";
import "../instant_viewer_page.dart";
import "../note_sheets.dart";

/// Inbox: search, notes row, then conversations.
class MessagesTab extends ConsumerStatefulWidget {
  const MessagesTab({super.key});

  @override
  ConsumerState<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends ConsumerState<MessagesTab> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(notesProvider);
    ref.invalidate(instantsProvider);
    await ref.read(conversationsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final conversations = ref.watch(conversationsProvider);
    final local = ref.watch(localChatProvider);
    final me = ref.watch(currentUserIdProvider);
    final q = _search.text.trim().toLowerCase();

    bool matches(String a, [String b = ""]) =>
        q.isEmpty || a.toLowerCase().contains(q) || b.toLowerCase().contains(q);

    final real = (conversations.valueOrNull ?? const <Conversation>[])
        .where((c) => matches(c.partner.username, c.partner.fullName))
        .toList();
    final threads = kChatThreads.where((t) => matches(t.name)).toList();

    final list = SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _refresh),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
              child: CupertinoSearchTextField(
                controller: _search,
                placeholder: "Search",
                style: TextStyle(color: colors.text),
                backgroundColor: colors.field,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (q.isEmpty) const SliverToBoxAdapter(child: _NotesRow()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Text(
                    "Messages",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => showInfo(
                      context,
                      title: "Message requests",
                      message: "You don't have any message requests.",
                    ),
                    child: Text(
                      "Requests",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (conversations.isLoading && !conversations.hasValue)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CupertinoActivityIndicator(),
              ),
            ),
          if (conversations.hasError)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  errorText(conversations.error!),
                  style: TextStyle(color: colors.secondaryText),
                ),
              ),
            ),
          SliverList.builder(
            itemCount: real.length,
            itemBuilder: (context, i) {
              final c = real[i];
              final mine = c.last.senderId == me;
              return _InboxRow(
                name: c.partner.displayName,
                avatar: c.partner.avatarUrls,
                subtitle: c.unread > 1
                    ? "${c.unread} new messages"
                    : c.last.preview(mine: mine),
                time: timeAgoShort(c.last.createdAt),
                unread: c.unread > 0,
                onTap: () => push(context, ChatPage(partner: c.partner)),
              );
            },
          ),
          SliverList.builder(
            itemCount: threads.length,
            itemBuilder: (context, i) {
              final t = threads[i];
              final last = local[t.id]?.last;
              return _InboxRow(
                name: t.name,
                avatar: null,
                subtitle: last == null
                    ? ""
                    : (last.mine ? "You: ${last.text}" : last.text),
                time: last == null ? "" : timeAgoShort(last.time),
                unread: false,
                onTap: () => push(context, LocalChatPage(thread: t)),
              );
            },
          ),
          if (q.isEmpty)
            SliverToBoxAdapter(
              child: _InboxSuggestions(
                chattingWith: {for (final c in real) c.partner.id},
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: bottomBarInset(context))),
        ],
      ),
    );

    return Stack(
      children: [
        Positioned.fill(child: list),
        // Instants tab on the right edge, like Instagram.
        // Instants card on the right edge, like Instagram.
        const Positioned(
          right: 0,
          bottom: 150,
          child: ClipRect(child: _InstantsTab()),
        ),
      ],
    );
  }
}

/// Note text, with the song underneath when the note has one.
String _bubbleText(Note n) {
  final music = n.music;
  if (music == null || n.body.startsWith("\u266B")) return n.body;
  return "${n.body}\n\u266B ${music.title}";
}

/// Instants card peeking in from the right edge, like Instagram: the
/// newest unopened instant with a red dot (tap to view them once), or a
/// grey "+" card to take one. Swipe it left to open it too.
class _InstantsTab extends ConsumerWidget {
  const _InstantsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final instants = ref.watch(instantsProvider).valueOrNull ?? const [];
    final latest = instants.isEmpty ? null : instants.last;

    void open() {
      if (instants.isNotEmpty) {
        pushFullscreen(context, InstantViewerPage(instants: List.of(instants)));
      } else {
        pushFullscreen(context, const InstantCameraPage());
      }
    }

    const shape = ContinuousRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(44)),
    );

    final card = Container(
      width: 92,
      height: 124,
      decoration: ShapeDecoration(
        shape: shape,
        color: colors.dark ? const Color(0xFF262626) : const Color(0xFFE9E9EE),
        shadows: const [BoxShadow(color: Color(0x33000000), blurRadius: 10)],
      ),
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: shape),
        child: latest != null
            ? FeedImage(urls: [latest.mediaUrl])
            : Align(
                alignment: const Alignment(-0.55, 0),
                child: Icon(
                  CupertinoIcons.add,
                  size: 28,
                  color: colors.secondaryText,
                ),
              ),
      ),
    );

    return Semantics(
      button: true,
      label: latest != null
          ? "${instants.length} new instants from ${latest.profile.username}"
          : "New instant",
      child: GestureDetector(
        onTap: open,
        onLongPress: () => pushFullscreen(context, const InstantCameraPage()),
        onHorizontalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -150) open();
        },
        child: SizedBox(
          // Only the left part of the cards shows; the rest is off screen.
          width: 58,
          height: 150,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // A second card tilted the other way when there are more.
              if (instants.length > 1)
                Positioned(
                  left: 14,
                  top: 14,
                  child: Transform.rotate(
                    angle: 0.12,
                    child: Opacity(
                      opacity: 0.85,
                      child: Container(
                        width: 92,
                        height: 124,
                        decoration: ShapeDecoration(
                          shape: shape,
                          color: colors.dark
                              ? const Color(0xFF363636)
                              : const Color(0xFFD9D9DE),
                        ),
                      ),
                    ),
                  ),
                ),
              // The front card leans to the left, like Instagram's.
              Positioned(
                left: 8,
                top: 12,
                child: Transform.rotate(angle: -0.14, child: card),
              ),
              if (latest != null)
                Positioned(
                  left: 4,
                  top: 18,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: kIgRed,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.background, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Below the chats, like Instagram: people you follow but haven't
/// messaged ("Tap to chat"), then accounts to follow.
class _InboxSuggestions extends ConsumerStatefulWidget {
  final Set<String> chattingWith;

  const _InboxSuggestions({required this.chattingWith});

  @override
  ConsumerState<_InboxSuggestions> createState() => _InboxSuggestionsState();
}

class _InboxSuggestionsState extends ConsumerState<_InboxSuggestions> {
  /// Accounts dismissed with ✕ (until the app restarts).
  final Set<String> _dismissed = {};

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final me = ref.watch(currentUserIdProvider);
    final followingList = me == null
        ? const <Profile>[]
        : (ref.watch(followingListProvider(me)).valueOrNull ?? const []);
    final followingIds = ref.watch(followingProvider).valueOrNull ?? const {};
    final suggested =
        ref.watch(suggestedProfilesProvider).valueOrNull ?? const [];

    final tapToChat = followingList
        .where((p) => !widget.chattingWith.contains(p.id))
        .take(6)
        .toList();
    final toFollow = suggested
        .where((p) => !_dismissed.contains(p.id))
        .take(8)
        .toList();

    Widget header(String title, {VoidCallback? seeAll}) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          const Spacer(),
          if (seeAll != null)
            GestureDetector(
              onTap: seeAll,
              child: const Text(
                "See all",
                style: TextStyle(
                  color: kIgBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tapToChat.isNotEmpty) ...[
          header("Suggestions"),
          for (final p in tapToChat)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => push(context, ChatPage(partner: p)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    GradientAvatar(
                      name: p.username,
                      imageUrls: p.avatarUrls,
                      size: 56,
                      ring: false,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.displayName,
                            style: TextStyle(fontSize: 14, color: colors.text),
                          ),
                          Text(
                            "Tap to chat",
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (toFollow.isNotEmpty) ...[
          header(
            "Accounts to follow",
            seeAll: () => push(context, const DiscoverPeoplePage()),
          ),
          for (final p in toFollow)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => openProfile(context, p),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
                child: Row(
                  children: [
                    GradientAvatar(
                      name: p.username,
                      imageUrls: p.avatarUrls,
                      size: 56,
                      ring: false,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.text,
                            ),
                          ),
                          Text(
                            p.fullName.isNotEmpty
                                ? p.fullName
                                : "Suggested for you",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FollowButton(
                      following: followingIds.contains(p.id),
                      onTap: () => ref
                          .read(followingProvider.notifier)
                          .toggle(p.id)
                          .catchError((Object e) {
                            if (context.mounted) {
                              showToast(context, errorText(e), error: true);
                            }
                          }),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(32, 32),
                      onPressed: () => setState(() => _dismissed.add(p.id)),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 16,
                        color: colors.secondaryText,
                        semanticLabel: "Dismiss",
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _NotesRow extends ConsumerWidget {
  const _NotesRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final me = ref.watch(myProfileProvider).valueOrNull;
    final notes = ref.watch(notesProvider).valueOrNull;
    final mine = notes?.mine;
    final others = notes?.others ?? const <Note>[];

    Widget item({
      required String label,
      required List<String>? avatar,
      required String bubble,
      required VoidCallback onTap,
      bool placeholder = false,
      String? caption,
    }) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 92,
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: NoteBubble(text: bubble, placeholder: placeholder),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -6),
                child: GradientAvatar(
                  name: label,
                  imageUrls: avatar,
                  size: 76,
                  ring: false,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.secondaryText),
              ),
              if (caption != null)
                Text(
                  caption,
                  maxLines: 1,
                  style: TextStyle(fontSize: 10, color: colors.secondaryText),
                ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 172,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          item(
            label: "Your note",
            avatar: me?.avatarUrls,
            bubble: mine == null ? "Share a thought..." : _bubbleText(mine),
            placeholder: mine == null,
            caption: mine?.location == null
                ? "Location off"
                : "\u{1F4CD} ${mine!.location}",
            onTap: () => showNoteComposer(context),
          ),
          for (final n in others)
            item(
              label: n.username,
              avatar: n.avatarUrls,
              bubble: _bubbleText(n),
              caption: n.location == null ? null : "\u{1F4CD} ${n.location}",
              onTap: () => showNoteViewer(context, n),
            ),
        ],
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  final String name;
  final List<String>? avatar;
  final String subtitle;
  final String time;
  final bool unread;
  final VoidCallback onTap;

  const _InboxRow({
    required this.name,
    required this.avatar,
    required this.subtitle,
    required this.time,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            GradientAvatar(
              name: name,
              imageUrls: avatar,
              size: 56,
              ring: false,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: unread ? colors.text : colors.secondaryText,
                          ),
                        ),
                      ),
                      if (time.isNotEmpty)
                        Text(
                          " · $time",
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.secondaryText,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(left: 8),
                decoration: const BoxDecoration(
                  color: kIgBlue,
                  shape: BoxShape.circle,
                ),
              )
            else
              Icon(
                CupertinoIcons.camera,
                color: colors.secondaryText,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
