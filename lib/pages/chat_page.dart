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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send({XFile? photo}) async {
    final text = _controller.text;
    if (text.trim().isEmpty && photo == null) return;
    _controller.clear();
    try {
      await ref
          .read(chatProvider(widget.partner.id).notifier)
          .send(text: text, photo: photo);
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

  void _messageMenu(Message m, bool mine) {
    showActionSheet(
      context,
      actions: [
        if (m.body.isNotEmpty)
          SheetAction(
            label: "Copy",
            icon: CupertinoIcons.doc_on_doc,
            onTap: () => Clipboard.setData(ClipboardData(text: m.body)),
          ),
        if (mine && !m.pending)
          SheetAction(
            label: "Unsend",
            icon: CupertinoIcons.arrow_uturn_left,
            destructive: true,
            onTap: () => ref
                .read(chatProvider(widget.partner.id).notifier)
                .unsend(m)
                .catchError((Object e) {
                  if (mounted) showToast(context, errorText(e), error: true);
                }),
          ),
      ],
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
              ),
            ),
          ),
          MessageInputBar(
            controller: _controller,
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

  const _MessageList({
    required this.messages,
    required this.me,
    required this.partner,
    required this.onLongPress,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reversed = messages.reversed.toList();
    final lastMineIndex = reversed.indexWhere((m) => m.senderId == me);

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
            GestureDetector(
              onLongPress: () => onLongPress(m, mine),
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
                    child: _Bubble(message: m, mine: mine),
                  ),
                ],
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

class _Bubble extends StatelessWidget {
  final Message message;
  final bool mine;

  const _Bubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final m = message;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.7;
    final textColor = mine ? const Color(0xFFFFFFFF) : colors.text;

    final children = <Widget>[];

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
