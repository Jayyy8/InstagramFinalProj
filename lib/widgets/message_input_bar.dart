import "package:flutter/cupertino.dart";

import "../theme/app_theme.dart";

/// Rounded "Message..." / "Add a comment..." field with a Send button,
/// like the bottom of an Instagram chat.
class MessageInputBar extends StatefulWidget {
  final TextEditingController controller;
  final String placeholder;
  final VoidCallback onSend;

  /// Shows a camera button on the left (send a photo).
  final VoidCallback? onCamera;
  final Widget? leading;
  final FocusNode? focusNode;
  final bool autofocus;

  const MessageInputBar({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.onSend,
    this.onCamera,
    this.leading,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasText = widget.controller.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ?widget.leading,
          if (widget.leading != null) const SizedBox(width: 10),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                color: colors.field,
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.onCamera != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: GestureDetector(
                        onTap: widget.onCamera,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: kIgMessageBlue,
                          ),
                          child: const Icon(
                            CupertinoIcons.camera_fill,
                            size: 18,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 8),
                  Expanded(
                    child: CupertinoTextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      autofocus: widget.autofocus,
                      placeholder: widget.placeholder,
                      placeholderStyle: TextStyle(
                        color: colors.secondaryText,
                        fontSize: 15,
                      ),
                      style: TextStyle(color: colors.text, fontSize: 15),
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      decoration: null,
                      onSubmitted: (_) => widget.onSend(),
                    ),
                  ),
                  if (hasText)
                    CupertinoButton(
                      padding: const EdgeInsets.fromLTRB(8, 0, 10, 12),
                      minimumSize: const Size(40, 40),
                      onPressed: widget.onSend,
                      child: const Text(
                        "Send",
                        style: TextStyle(
                          color: kIgMessageBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
