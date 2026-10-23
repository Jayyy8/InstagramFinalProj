import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../models/feed_models.dart";
import "../../providers/feed_provider.dart";
import "../../providers/social_providers.dart";
import "../../theme/app_theme.dart";
import "../../widgets/dialogs.dart";
import "../../widgets/post_grid.dart";
import "../../widgets/user_row.dart";

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
    return results.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Center(child: Text(errorText(e))),
      data: (list) => list.isEmpty
          ? Center(
              child: Text(
                "No results for \"$query\"",
                style: TextStyle(color: colors.secondaryText),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.only(bottom: bottomBarInset(context)),
              itemCount: list.length,
              itemBuilder: (context, i) => UserRow(profile: list[i]),
            ),
    );
  }
}

class _Explore extends ConsumerWidget {
  const _Explore();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(explorePostIdsProvider).valueOrNull ?? const [];
    final remote = postsFor(ref, ids);
    final samples = ref.watch(samplePostsProvider);
    final List<FeedPost> posts = [...remote, ...samples];

    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () async {
            ref.invalidate(explorePostIdsProvider);
            await ref.read(explorePostIdsProvider.future);
          },
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
