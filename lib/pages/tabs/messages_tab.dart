import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../models/feed_models.dart";
import "../../models/social_models.dart";
import "../../navigation.dart";
import "../../providers/chat_provider.dart";
import "../../providers/notes_provider.dart";
import "../../providers/social_providers.dart";
import "../../theme/app_theme.dart";
import "../../widgets/android_bars.dart";
import "../../widgets/dialogs.dart";
import "../../widgets/gradient_avatar.dart";
import "../chat_page.dart";
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
          SliverToBoxAdapter(child: SizedBox(height: bottomBarInset(context))),
        ],
      ),
    );

    return Stack(
      children: [
        Positioned.fill(child: list),
        // Instants tab on the right edge, like Instagram.
        const Align(alignment: Alignment(1, 0.35), child: _InstantsTab()),
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

/// Right-edge tab: friends' unopened instants (tap to view once) and "+"
/// to send one.
class _InstantsTab extends ConsumerWidget {
  const _InstantsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final instants = ref.watch(instantsProvider).valueOrNull ?? const [];
    // One avatar per person, newest senders first.
    final senders = <String, Instant>{};
    for (final i in instants.reversed) {
      senders.putIfAbsent(i.profile.id, () => i);
    }
    final faces = senders.values.take(2).toList();

    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.dark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (instants.isNotEmpty) ...[
            Semantics(
              button: true,
              label: "${instants.length} new instants",
              child: GestureDetector(
                onTap: () => pushFullscreen(
                  context,
                  InstantViewerPage(instants: List.of(instants)),
                ),
                child: Badged(
                  count: instants.length,
                  child: SizedBox(
                    width: 40,
                    height: 40.0 + (faces.length - 1) * 14,
                    child: Stack(
                      children: [
                        for (int i = 0; i < faces.length; i++)
                          Positioned(
                            top: i * 14.0,
                            left: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.bottomLeft,
                                  end: Alignment.topRight,
                                  colors: kStoryRingColors,
                                ),
                              ),
                              child: GradientAvatar(
                                name: faces[i].profile.username,
                                imageUrls: faces[i].profile.avatarUrls,
                                size: 36,
                                ring: false,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Semantics(
            button: true,
            label: "New instant",
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => pushFullscreen(context, const InstantCameraPage()),
              child: SizedBox(
                width: 58,
                height: 48,
                child: Icon(
                  CupertinoIcons.add,
                  size: 30,
                  color: colors.secondaryText,
                ),
              ),
            ),
          ),
        ],
      ),
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
