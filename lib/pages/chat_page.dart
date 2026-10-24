import "package:flutter/cupertino.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";

import "../models/feed_models.dart";
import "../models/social_models.dart";
import "../navigation.dart";
import "../providers/chat_provider.dart";
import "../providers/social_providers.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "../widgets/feed_image.dart";
import "../widgets/gradient_avatar.dart";
import "../widgets/message_input_bar.dart";
import "../widgets/sub_page.dart";
import "profile_page.dart";

/// Private conversation with one person. New messages arrive live.
class ChatPage extends ConsumerStatefulWidget {
  final Profile partner;

  const ChatPage({super.key, required this.partner});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final FocusNode _focus = FocusNode();

  /// Message being answered (swipe right or "Reply").
  Message? _replyTo;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send({XFile? photo}) async {
    final text = _controller.text;
    if (text.trim().isEmpty && photo == null) return;
    final replyTo = _replyTo;
    _controller.clear();
    setState(() => _replyTo = null);
    try {
      await ref
          .read(chatProvider(widget.partner.id).notifier)
          .send(text: text, photo: photo, replyToId: replyTo?.id);
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    }
  }

  void _pickPhoto() {
    Future<void> pick(ImageSource source) async {
      try {
        final photo = await _picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1440,
        );
        if (photo != null) await _send(photo: photo);
      } catch (e) {
        if (mounted) showToast(context, errorText(e), error: true);
      }
    }

    showActionSheet(
      context,
      actions: [
        SheetAction(
          label: "Camera",
          icon: CupertinoIcons.camera,
          onTap: () => pick(ImageSource.camera),
        ),
        SheetAction(
          label: "Photo library",
          icon: CupertinoIcons.photo,
          onTap: () => pick(ImageSource.gallery),
        ),
      ],
    );
  }

  ChatNotifier get _chat => ref.read(chatProvider(widget.partner.id).notifier);

  void _guard(Future<void> action) {
    action.catchError((Object e) {
      if (mounted) showToast(context, errorText(e), error: true);
    });
  }

  void _react(Message m, String emoji) {
    if (m.pending) return;
    _guard(_chat.react(m, emoji));
  }

  void _startReply(Message m) {
    if (m.pending) return;
    HapticFeedback.selectionClick();
    setState(() => _replyTo = m);
    _focus.requestFocus();
  }

  /// Hold a message: reactions on top, then Reply / Copy / Unsend / Delete.
  void _messageMenu(Message m, bool mine) {
    if (m.pending) return;
    HapticFeedback.mediumImpact();
    final me = ref.read(currentUserIdProvider);
    showIgSheet<void>(
      context,
      builder: (sheetContext) {
        final colors = AppColors.of(sheetContext);
        void close() => Navigator.of(sheetContext).pop();

        Widget action(
          IconData icon,
          String label,
          VoidCallback onTap, {
          bool destructive = false,
        }) {
          final color = destructive ? kIgRed : colors.text;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              close();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Text(label, style: TextStyle(fontSize: 16, color: color)),
                  const Spacer(),
                  Icon(icon, color: color, size: 22),
                ],
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reaction bar.
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: colors.field,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final emoji in kReactions)
                    GestureDetector(
                      onTap: () {
                        close();
                        _react(m, emoji);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: m.reactions[me] == emoji
                              ? colors.button
                              : const Color(0x00000000),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(height: 0.5, color: colors.separator),
            action(CupertinoIcons.reply, "Reply", () => _startReply(m)),
            if (m.body.isNotEmpty)
              action(
                CupertinoIcons.doc_on_doc,
                "Copy",
                () => Clipboard.setData(ClipboardData(text: m.body)),
              ),
            if (mine)
              action(
                CupertinoIcons.arrow_uturn_left,
                "Unsend",
                () => confirmAction(
                  context,
                  title: "Unsend message?",
                  message: "It will be removed for everyone in the chat.",
                  confirmLabel: "Unsend",
                  onConfirm: () => _guard(_chat.unsend(m)),
                ),
                destructive: true,
              ),
            action(
              CupertinoIcons.delete,
              "Delete for you",
              () => _guard(_chat.deleteForMe(m)),
              destructive: true,
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void _openProfile() {
    push(
      context,
      ProfilePage(userId: widget.partner.id, initial: widget.partner),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final partner =
        ref.watch(profileProvider(widget.partner.id)).valueOrNull ??
        widget.partner;
    final messages = ref.watch(chatProvider(partner.id));
    final me = ref.watch(currentUserIdProvider);

    return SubPage(
      title: partner.displayName,
      safeBottom: true,
      titleWidget: GestureDetector(
        onTap: _openProfile,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GradientAvatar(
              name: partner.username,
              imageUrls: partner.avatarUrls,
              size: 30,
              ring: false,
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partner.displayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  activeStatus(partner.lastActiveAt).isEmpty
                      ? partner.username
                      : activeStatus(partner.lastActiveAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.secondaryText,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        barAction(
          context,
          const AppIcon("info.circle", CupertinoIcons.info),
          label: "Profile",
          onPressed: _openProfile,
        ),
      ],
      child: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(errorText(e), textAlign: TextAlign.center),
                ),
              ),
              data: (list) => _MessageList(
                messages: list,
                me: me ?? "",
                partner: partner,
                onLongPress: _messageMenu,
                onOpenProfile: _openProfile,
                onReply: _startReply,
                onDoubleTap: (m) => _react(m, "\u2764\uFE0F"),
              ),
            ),
          ),
          if (_replyTo != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyTo!.senderId == me
                              ? "Replying to yourself"
                              : "Replying to ${partner.displayName}",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          _replyTo!.snippet,
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
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(36, 36),
                    onPressed: () => setState(() => _replyTo = null),
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 18,
                      color: colors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          MessageInputBar(
            controller: _controller,
            focusNode: _focus,
            placeholder: "Message...",
            onSend: _send,
            onCamera: _pickPhoto,
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final List<Message> messages;
  final String me;
  final Profile partner;
  final void Function(Message, bool mine) onLongPress;
  final VoidCallback onOpenProfile;
  final ValueChanged<Message> onReply;
  final ValueChanged<Message> onDoubleTap;

  const _MessageList({
    required this.messages,
    required this.me,
    required this.partner,
    required this.onLongPress,
    required this.onOpenProfile,
    required this.onReply,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reversed = messages.reversed.toList();
    final lastMineIndex = reversed.indexWhere((m) => m.senderId == me);
    final byId = {for (final m in messages) m.id: m};

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: reversed.length + 1,
      itemBuilder: (context, i) {
        // Top of the chat: who you are talking to.
        if (i == reversed.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                GradientAvatar(
                  name: partner.username,
                  imageUrls: partner.avatarUrls,
                  size: 90,
                  ring: false,
                ),
                const SizedBox(height: 10),
                Text(
                  partner.displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                Text(
                  "${partner.username} · Instagram",
                  style: TextStyle(color: colors.secondaryText),
                ),
                const SizedBox(height: 12),
                CupertinoButton(
                  color: colors.button,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(10, 32),
                  borderRadius: BorderRadius.circular(8),
                  onPressed: onOpenProfile,
                  child: Text(
                    "View profile",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final m = reversed[i];
        final mine = m.senderId == me;
        final older = i + 1 < reversed.length ? reversed[i + 1] : null;
        final newer = i > 0 ? reversed[i - 1] : null;
        final showTime =
            older == null ||
            m.createdAt.difference(older.createdAt).inMinutes > 60;
        final lastOfGroup = newer == null || newer.senderId != m.senderId;

        return Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (showTime)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _stamp(m.createdAt),
                    style: TextStyle(fontSize: 12, color: colors.secondaryText),
                  ),
                ),
              ),
            _SwipeToReply(
              onReply: () => onReply(m),
              child: GestureDetector(
                onLongPress: () => onLongPress(m, mine),
                onDoubleTap: () => onDoubleTap(m),
                child: Row(
                  mainAxisAlignment: mine
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!mine)
                      SizedBox(
                        width: 34,
                        child: lastOfGroup
                            ? GradientAvatar(
                                name: partner.username,
                                imageUrls: partner.avatarUrls,
                                size: 28,
                                ring: false,
                              )
                            : null,
                      ),
                    Flexible(
                      child: _Bubble(
                        message: m,
                        mine: mine,
                        quoted: m.replyToId == null ? null : byId[m.replyToId],
                        quotedMine: byId[m.replyToId]?.senderId == me,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (mine && i == lastMineIndex)
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 4),
                child: Text(
                  m.pending
                      ? "Sending..."
                      : (m.readAt != null ? "Seen" : "Sent"),
                  style: TextStyle(fontSize: 11, color: colors.secondaryText),
                ),
              ),
            SizedBox(height: lastOfGroup ? 8 : 2),
          ],
        );
      },
    );
  }

  static String _stamp(DateTime d) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, "0");
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final time = "$hour:${two(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}";
    if (now.difference(d).inDays == 0 && now.day == d.day) return time;
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return "${months[d.month - 1]} ${d.day}, $time";
  }
}

/// Emojis offered when you hold a message.
const List<String> kReactions = [
  "\u2764\uFE0F",
  "\u{1F602}",
  "\u{1F62E}",
  "\u{1F622}",
  "\u{1F621}",
  "\u{1F44D}",
];

/// Drag a message to the right to reply to it.
class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const _SwipeToReply({required this.child, required this.onReply});

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) =>
          setState(() => _dx = (_dx + d.delta.dx).clamp(0, 80)),
      onHorizontalDragEnd: (_) {
        if (_dx > 56) widget.onReply();
        setState(() => _dx = 0);
      },
      onHorizontalDragCancel: () => setState(() => _dx = 0),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_dx > 8)
            Opacity(
              opacity: (_dx / 56).clamp(0, 1),
              child: Icon(
                CupertinoIcons.reply,
                size: 20,
                color: AppColors.of(context).secondaryText,
              ),
            ),
          AnimatedContainer(
            duration: Duration(milliseconds: _dx == 0 ? 180 : 0),
            transform: Matrix4.translationValues(_dx, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message message;
  final bool mine;
  final Message? quoted;
  final bool quotedMine;

  const _Bubble({
    required this.message,
    required this.mine,
    this.quoted,
    this.quotedMine = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final m = message;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.7;
    final textColor = mine ? const Color(0xFFFFFFFF) : colors.text;

    final children = <Widget>[];

    // The message this one replies to.
    if (m.replyToId != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 2, left: 4, right: 4),
          child: Text(
            mine
                ? (quotedMine ? "You replied to yourself" : "You replied")
                : (quotedMine ? "Replied to you" : "Replied"),
            style: TextStyle(fontSize: 11, color: colors.secondaryText),
          ),
        ),
      );
      children.add(
        Container(
          constraints: BoxConstraints(maxWidth: maxWidth * 0.9),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.theirBubble.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            quoted?.snippet ?? "Message unavailable",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: colors.secondaryText),
          ),
        ),
      );
    }

    // What this message replies to / shares.
    if (m.contextType == "story_reply" || m.contextType == "note_reply") {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            m.contextType == "story_reply"
                ? (mine
                      ? "You replied to their story"
                      : "Replied to your story")
                : (mine ? "You replied to their note" : "Replied to your note"),
            style: TextStyle(fontSize: 12, color: colors.secondaryText),
          ),
        ),
      );
      if (m.contextMediaUrl != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 110,
                height: 180,
                child: FeedImage(urls: [m.contextMediaUrl!]),
              ),
            ),
          ),
        );
      }
      if (m.contextText != null) {
        children.add(
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: colors.separator),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              m.contextText!,
              style: TextStyle(color: colors.secondaryText, fontSize: 13),
            ),
          ),
        );
      }
    }

    if (m.contextType == "post_share") {
      children.add(
        Container(
          width: 220,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: colors.theirBubble,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (m.contextMediaUrl != null)
                AspectRatio(
                  aspectRatio: 4 / 5,
                  child: FeedImage(urls: [m.contextMediaUrl!]),
                ),
              if (m.contextText != null)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    m.contextText!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: colors.text),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (m.mediaUrl != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 200,
              height: 260,
              child: Opacity(
                opacity: m.pending ? 0.6 : 1,
                child: FeedImage(urls: [m.mediaUrl!]),
              ),
            ),
          ),
        ),
      );
    }

    if (m.body.isNotEmpty) {
      final onlyEmoji =
          m.body.runes.length <= 3 && !RegExp(r"[A-Za-z0-9]").hasMatch(m.body);
      children.add(
        onlyEmoji
            ? Text(m.body, style: const TextStyle(fontSize: 40))
            : Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: mine
                      ? kIgMessageBlue.withValues(alpha: m.pending ? 0.6 : 1)
                      : colors.theirBubble,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  m.body,
                  style: TextStyle(fontSize: 15, color: textColor),
                ),
              ),
      );
    }

    // Reactions under the bubble.
    if (m.reactions.isNotEmpty) {
      final counts = <String, int>{};
      for (final e in m.reactions.values) {
        counts[e] = (counts[e] ?? 0) + 1;
      }
      children.add(
        Transform.translate(
          offset: const Offset(0, -4),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colors.field,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.background, width: 2),
            ),
            child: Text(
              [
                for (final e in counts.entries)
                  e.value > 1 ? "${e.key} ${e.value}" : e.key,
              ].join(" "),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: children,
    );
  }
}

/// Group chat with a sample channel (kept on the phone).
class LocalChatPage extends ConsumerStatefulWidget {
  final ChatThread thread;

  const LocalChatPage({super.key, required this.thread});

  @override
  ConsumerState<LocalChatPage> createState() => _LocalChatPageState();
}

class _LocalChatPageState extends ConsumerState<LocalChatPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    ref
        .read(localChatProvider.notifier)
        .send(widget.thread.id, _controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(localChatProvider)[widget.thread.id] ?? [];
    final colors = AppColors.of(context);

    return SubPage(
      title: widget.thread.name,
      safeBottom: true,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final m = messages[messages.length - 1 - i];
                return Align(
                  alignment: m.mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.7,
                    ),
                    decoration: BoxDecoration(
                      color: m.mine ? kIgMessageBlue : colors.theirBubble,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      m.text,
                      style: TextStyle(
                        fontSize: 15,
                        color: m.mine ? const Color(0xFFFFFFFF) : colors.text,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          MessageInputBar(
            controller: _controller,
            placeholder: "Message...",
            onSend: _send,
          ),
        ],
      ),
    );
  }
}
