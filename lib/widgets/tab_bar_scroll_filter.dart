import "package:flutter/cupertino.dart";

/// Sits between the tabs and the iOS 26 tab bar, which shrinks on any scroll
/// down and grows on any scroll up. Left alone it shrank again right after
/// growing: the bounce at the top of a list scrolls down a little, and so
/// does swiping the stories strip sideways. This passes on only real
/// up-and-down scrolling, and asks for the full bar back at the top of a
/// list and on every tab switch.
class TabBarScrollFilter extends StatefulWidget {
  /// The tab being shown: changing it brings the full bar back.
  final int tab;
  final Widget child;

  const TabBarScrollFilter({super.key, required this.tab, required this.child});

  @override
  State<TabBarScrollFilter> createState() => _TabBarScrollFilterState();
}

class _TabBarScrollFilterState extends State<TabBarScrollFilter> {
  /// Tells the tab bar above that the page scrolled up, which expands it.
  void _expand([ScrollMetrics? metrics]) {
    ScrollUpdateNotification(
      metrics:
          metrics ??
          FixedScrollMetrics(
            minScrollExtent: 0,
            maxScrollExtent: 0,
            pixels: 0,
            viewportDimension: 0,
            axisDirection: AxisDirection.down,
            devicePixelRatio: 1,
          ),
      context: context,
      scrollDelta: -1,
    ).dispatch(context);
  }

  @override
  void didUpdateWidget(TabBarScrollFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _expand();
      });
    }
  }

  bool _onScroll(ScrollNotification n) {
    final m = n.metrics;
    // Sideways lists (stories, notes, carousels) don't move the bar.
    if (m.axis != Axis.vertical) return true;
    if (n is! ScrollUpdateNotification) return false;
    // Back at the top: full bar, whatever the bounce does next.
    if (m.pixels <= m.minScrollExtent + 4) {
      _expand(m);
      return true;
    }
    // The bounce past either end isn't the user scrolling.
    if (m.pixels > m.maxScrollExtent) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: widget.child,
    );
  }
}
