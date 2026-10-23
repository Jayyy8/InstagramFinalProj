import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../providers/social_providers.dart";
import "../profile_page.dart";

/// Your own profile (bottom tab).
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserIdProvider);
    if (me == null) return const SizedBox.shrink();
    return SafeArea(bottom: false, child: ProfileView(userId: me));
  }
}
