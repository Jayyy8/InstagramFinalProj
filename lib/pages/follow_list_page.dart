import "package:adaptive_platform_ui/adaptive_platform_ui.dart";
import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/social_models.dart";
import "../providers/social_providers.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "../widgets/sub_page.dart";
import "../widgets/user_row.dart";

/// Followers / Following of an account.
class FollowListPage extends ConsumerStatefulWidget {
  final Profile user;
  final bool showFollowers;

  const FollowListPage({
    super.key,
    required this.user,
    required this.showFollowers,
  });

  @override
  ConsumerState<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends ConsumerState<FollowListPage> {
  late int _tab = widget.showFollowers ? 0 : 1;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final list = _tab == 0
        ? ref.watch(followersListProvider(widget.user.id))
        : ref.watch(followingListProvider(widget.user.id));

    return SubPage(
      title: widget.user.username,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: AdaptiveSegmentedControl(
              labels: const ["Followers", "Following"],
              selectedIndex: _tab,
              onValueChanged: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: list.when(
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (e, _) => Center(child: Text(errorText(e))),
              data: (people) => people.isEmpty
                  ? Center(
                      child: Text(
                        _tab == 0
                            ? "No followers yet"
                            : "Not following anyone yet",
                        style: TextStyle(color: colors.secondaryText),
                      ),
                    )
                  : ListView.builder(
                      itemCount: people.length,
                      itemBuilder: (context, i) => UserRow(profile: people[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
