import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/feed_models.dart";
import "../models/social_models.dart";
import "../providers/chat_provider.dart";
import "../providers/social_providers.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "../widgets/feed_image.dart";
import "../widgets/gradient_avatar.dart";

/// Opens friends' instants one after another. Each one can be seen only
/// once: it is marked as viewed as soon as it appears.
class InstantViewerPage extends ConsumerStatefulWidget {
  final List<Instant> instants;

  const InstantViewerPage({super.key, required this.instants});

  @override
  ConsumerState<InstantViewerPage> createState() => _InstantViewerPageState();
}

class _InstantViewerPageState extends ConsumerState<InstantViewerPage> {
  int _index = 0;
  final TextEditingController _reply = TextEditingController();
  final FocusNode _replyFocus = FocusNode();
  bool _sending = false;

  /// Instants you sent a heart to.
  final Set<String> _liked = {};

  @override
  void dispose() {
    _reply.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final body = text.trim();
    if (body.isEmpty || _sending) return;
    final instant = _current;
    setState(() => _sending = true);
    try {
      await sendDirect(
        ref,
        to: instant.profile.id,
        text: body,
        contextType: "instant_reply",
        contextMediaUrl: instant.mediaUrl,
      );
      _reply.clear();
      _replyFocus.unfocus();
      if (mounted) showToast(context, "Sent");
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _heart() {
    final id = _current.id;
    if (_liked.contains(id)) return;
    setState(() => _liked.add(id));
    _send("\u2764\uFE0F");
  }

  Instant get _current => widget.instants[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markViewed());
  }

  void _markViewed() {
    ref.read(instantsProvider.notifier).markViewed(_current).catchError((_) {});
  }

  void _next() {
    if (_index < widget.instants.length - 1) {
      setState(() => _index++);
      _markViewed();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final instant = _current;

    return PlainPage(
      background: const Color(0xFF000000),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_replyFocus.hasFocus) {
            _replyFocus.unfocus();
          } else {
            _next();
          }
        },
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).maybePop();
        },
        child: Padding(
          padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    GradientAvatar(
                      name: instant.profile.username,
                      imageUrls: instant.profile.avatarUrls,
                      size: 34,
                      ring: false,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "${instant.profile.username}  ${timeAgoShort(instant.createdAt)}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.instants.length > 1)
                      Text(
                        "${_index + 1}/${widget.instants.length}",
                        style: const TextStyle(color: Color(0xCCFFFFFF)),
                      ),
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        color: Color(0xFFFFFFFF),
                        semanticLabel: "Close",
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: width - 24,
                height: (width - 24) * 1.25,
                child: ClipPath(
                  clipper: const ShapeBorderClipper(
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(120)),
                    ),
                  ),
                  child: FeedImage(
                    key: ValueKey(instant.id),
                    urls: [instant.mediaUrl],
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _index < widget.instants.length - 1
                    ? "Tap for the next instant"
                    : "You can only view an instant once",
                style: const TextStyle(color: Color(0xFFA8A8A8), fontSize: 13),
              ),
              const SizedBox(height: 12),
              // Reply / heart, sent to them as a message.
              Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  0,
                  8,
                  12 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: _reply,
                        focusNode: _replyFocus,
                        placeholder: "Reply to ${instant.profile.username}...",
                        placeholderStyle: const TextStyle(
                          color: Color(0xCCFFFFFF),
                        ),
                        style: const TextStyle(color: Color(0xFFFFFFFF)),
                        cursorColor: const Color(0xFFFFFFFF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0x99FFFFFF)),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        onSubmitted: _send,
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      onPressed: _heart,
                      child: Icon(
                        _liked.contains(instant.id)
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
                        color: _liked.contains(instant.id)
                            ? kIgRed
                            : const Color(0xFFFFFFFF),
                        size: 28,
                        semanticLabel: "Like",
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      onPressed: () => _send(_reply.text),
                      child: const Icon(
                        CupertinoIcons.paperplane,
                        color: Color(0xFFFFFFFF),
                        size: 26,
                        semanticLabel: "Send",
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
