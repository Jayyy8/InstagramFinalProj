import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../data/sample_feed.dart";
import "../../models/feed_models.dart";
import "../../providers/feed_provider.dart";
import "../../providers/social_providers.dart";
import "../../theme/app_theme.dart";
import "../../widgets/dialogs.dart";
import "../../widgets/gradient_avatar.dart";
import "../../widgets/post_grid.dart";
import "../../widgets/user_row.dart";
import "../channel_profile_page.dart";

/// Search accounts, or browse the explore grid when the field is empty.
class SearchTab extends ConsumerStatefulWidget {
  const SearchTab({super.key});

  @override
  ConsumerState<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<SearchTab> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final q = _query.text.trim();

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoSearchTextField(
                    controller: _query,
                    focusNode: _focus,
                    placeholder: "Search",
                    style: TextStyle(color: colors.text),
                    backgroundColor: colors.field,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                if (_focus.hasFocus)
                  CupertinoButton(
                    padding: const EdgeInsets.only(left: 10),
                    onPressed: () {
                      _query.clear();
                      _focus.unfocus();
                    },
                    child: Text("Cancel", style: TextStyle(color: colors.text)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: q.isNotEmpty || _focus.hasFocus
                ? _Results(query: q)
                : const _Explore(),
          ),
        ],
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  final String query;

  const _Results({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    if (query.isEmpty) {
      final suggested = ref.watch(suggestedProfilesProvider);
      return suggested.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text(errorText(e))),
        data: (list) => ListView(
          padding: EdgeInsets.only(bottom: bottomBarInset(context)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                "Suggested for you",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: colors.text,
                ),
              ),
            ),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "No suggestions right now.",
                  style: TextStyle(color: colors.secondaryText),
                ),
              ),
            for (final p in list) UserRow(profile: p),
          ],
        ),
      );
    }

    final results = ref.watch(userSearchProvider(query));
    final q = query.toLowerCase();
    // Sample channels match by handle or name too.
    final channels = [
      for (final e in kChannelInfo.entries)
        if (e.key.contains(q) || e.value.name.toLowerCase().contains(q)) e,
    ];

    Widget channelRow(MapEntry<String, ChannelInfo> e) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openChannel(context, e.key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              GradientAvatar(
                name: e.key,
                imageUrls: channelAvatar(e.key),
                size: 50,
                ring: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          e.key,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          CupertinoIcons.checkmark_seal_fill,
                          size: 13,
                          color: kIgBlue,
                        ),
                      ],
                    ),
                    Text(
                      "${e.value.name} · ${compactCount(e.value.followers)} followers",
                      style: TextStyle(color: colors.secondaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return results.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Center(child: Text(errorText(e))),
      data: (list) => list.isEmpty && channels.isEmpty
          ? Center(
              child: Text(
                "No results for \"$query\"",
                style: TextStyle(color: colors.secondaryText),
              ),
            )
          : ListView(
              padding: EdgeInsets.only(bottom: bottomBarInset(context)),
              children: [
                for (final c in channels) channelRow(c),
                for (final p in list) UserRow(profile: p),
              ],
            ),
    );
  }
}

class _Explore extends ConsumerStatefulWidget {
  const _Explore();

  @override
  ConsumerState<_Explore> createState() => _ExploreState();
}

class _ExploreState extends ConsumerState<_Explore> {
  /// 0 = For you, 1 = Reels, then one chip per topic.
  int _chip = 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ids = ref.watch(explorePostIdsProvider).valueOrNull ?? const [];
    final remote = postsFor(ref, ids);
    final samples = ref.watch(samplePostsProvider);
    final all = <FeedPost>[...remote, ...samples];
    final topics = FeedCategory.values;
    final List<FeedPost> posts = switch (_chip) {
      0 => all,
      1 => all.where((p) => p.isVideo).toList(),
      _ => all.where((p) => p.category == topics[_chip - 2]).toList(),
    };
    final chips = ["For you", "Reels", for (final t in topics) t.label];

    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () async {
            ref.invalidate(explorePostIdsProvider);
            await ref.read(explorePostIdsProvider.future);
          },
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => Semantics(
                button: true,
                selected: i == _chip,
                child: GestureDetector(
                  onTap: () => setState(() => _chip = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == _chip ? colors.text : colors.field,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      chips[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: i == _chip ? colors.background : colors.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (posts.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  "Nothing here yet.",
                  style: TextStyle(color: colors.secondaryText),
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.only(bottom: bottomBarInset(context)),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 1.5,
              crossAxisSpacing: 1.5,
              childAspectRatio: 3 / 4,
            ),
            itemCount: posts.length,
            itemBuilder: (context, i) => PostTile(post: posts[i]),
          ),
        ),
      ],
    );
  }
}
