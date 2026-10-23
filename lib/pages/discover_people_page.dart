import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/social_providers.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "../widgets/sub_page.dart";
import "../widgets/user_row.dart";

/// Accounts you don't follow yet (Add friend / Follow).
class DiscoverPeoplePage extends ConsumerWidget {
  const DiscoverPeoplePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final suggested = ref.watch(suggestedProfilesProvider);

    return SubPage(
      title: "Discover people",
      child: suggested.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text(errorText(e))),
        data: (list) => CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                ref.invalidate(suggestedProfilesProvider);
                await ref.read(suggestedProfilesProvider.future);
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  "Suggested for you",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ),
            ),
            if (list.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    "You're following everyone who has an account. Invite friends to join!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.secondaryText),
                  ),
                ),
              ),
            SliverList.builder(
              itemCount: list.length,
              itemBuilder: (context, i) => UserRow(profile: list[i]),
            ),
          ],
        ),
      ),
    );
  }
}
