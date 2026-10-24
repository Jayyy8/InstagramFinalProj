import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/feed_models.dart";
import "../models/social_models.dart";
import "../providers/social_providers.dart";
import "../theme/app_theme.dart";
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
        onTap: _next,
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
