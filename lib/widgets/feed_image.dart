import "dart:io";

import "package:flutter/cupertino.dart";

import "../theme/app_theme.dart";
import "shimmer.dart";

/// Photo that tries each URL in [urls] until one loads, so a failed
/// download falls back instead of leaving a blank. A path that is not a
/// web address is read from the phone (photos still uploading).
/// While a photo downloads, a shimmering placeholder is shown.
class FeedImage extends StatefulWidget {
  final List<String> urls;
  final BoxFit fit;

  /// Called once the photo is shown, or when no URL could be loaded
  /// (stories start their timer then).
  final VoidCallback? onReady;

  const FeedImage({
    super.key,
    required this.urls,
    this.fit = BoxFit.cover,
    this.onReady,
  });

  @override
  State<FeedImage> createState() => _FeedImageState();
}

class _FeedImageState extends State<FeedImage> {
  int _index = 0;
  bool _reported = false;

  void _ready() {
    if (_reported || widget.onReady == null) return;
    _reported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady!();
    });
  }

  // Wikimedia asks apps to identify themselves.
  static const Map<String, String> _headers = {
    "User-Agent": "OauthActivityDemo/1.0 (student project)",
  };

  @override
  void didUpdateWidget(covariant FeedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urls.isEmpty ||
        widget.urls.isEmpty ||
        oldWidget.urls.first != widget.urls.first) {
      _index = 0;
      _reported = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty || _index >= widget.urls.length) {
      _ready();
      return const _FailedPlaceholder();
    }

    final int current = _index;
    final String url = widget.urls[current];

    if (!url.startsWith("http")) {
      return Image.file(
        File(url),
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) =>
            const _FailedPlaceholder(),
      );
    }

    return Image.network(
      url,
      key: ValueKey(url),
      headers: _headers,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      frameBuilder: (context, child, frame, synchronous) {
        if (frame != null || synchronous) _ready();
        return child;
      },
      loadingBuilder: (context, child, progress) {
        return progress == null ? child : const _LoadingPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        // Try the next URL after this frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _index == current) setState(() => _index++);
        });
        return const _LoadingPlaceholder();
      },
    );
  }
}

/// Shimmering box shown while a photo downloads.
class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(child: Bone(radius: 0));
  }
}

class _FailedPlaceholder extends StatelessWidget {
  const _FailedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.of(context).placeholder,
      child: const Center(
        child: Icon(
          CupertinoIcons.photo,
          color: CupertinoColors.systemGrey,
          size: 40,
        ),
      ),
    );
  }
}
