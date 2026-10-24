import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/social_models.dart";
import "../providers/social_providers.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "../widgets/gradient_avatar.dart";
import "../widgets/sub_page.dart";

/// Settings → Close Friends: choose who sees what you share with
/// "Close Friends". Only you can see this list.
class CloseFriendsPage extends ConsumerStatefulWidget {
  const CloseFriendsPage({super.key});

  @override
  ConsumerState<CloseFriendsPage> createState() => _CloseFriendsPageState();
}

class _CloseFriendsPageState extends ConsumerState<CloseFriendsPage> {
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final me = ref.watch(currentUserIdProvider);
    final close = ref.watch(closeFriendsProvider).valueOrNull ?? const {};
    final q = _query.text.trim().toLowerCase();
    // People you follow, or anyone when you search.
    final AsyncValue<List<Profile>> people = q.isNotEmpty
        ? ref.watch(userSearchProvider(q))
        : (me == null
              ? const AsyncValue.data([])
              : ref.watch(followingListProvider(me)));

    return SubPage(
      title: "Close Friends",
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              "Only you can see your Close Friends list. Posts, stories and "
              "notes you share with Close Friends are shown only to them.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.secondaryText),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: CupertinoSearchTextField(
              controller: _query,
              placeholder: "Search",
              style: TextStyle(color: colors.text),
              backgroundColor: colors.field,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "${close.length} ${close.length == 1 ? 'person' : 'people'}",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
            ),
          ),
          Expanded(
            child: people.when(
              loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (e, _) => Center(child: Text(errorText(e))),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        q.isEmpty
                            ? "Follow people to add them to Close Friends."
                            : "No account found.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.secondaryText),
                      ),
                    ),
                  );
                }
                // Close friends first.
                final sorted = [...list]
                  ..sort((a, b) {
                    final ca = close.contains(a.id) ? 0 : 1;
                    final cb = close.contains(b.id) ? 0 : 1;
                    return ca.compareTo(cb);
                  });
                return ListView.builder(
                  itemCount: sorted.length,
                  itemBuilder: (context, i) {
                    final p = sorted[i];
                    final on = close.contains(p.id);
                    return Semantics(
                      button: true,
                      selected: on,
                      label:
                          "${p.username}, ${on ? 'on' : 'not on'} Close Friends",
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => ref
                            .read(closeFriendsProvider.notifier)
                            .toggle(p.id)
                            .catchError((Object e) {
                              if (context.mounted) {
                                showToast(context, errorText(e), error: true);
                              }
                            }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              GradientAvatar(
                                name: p.username,
                                imageUrls: p.avatarUrls,
                                size: 48,
                                ring: false,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.username,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: colors.text,
                                      ),
                                    ),
                                    if (p.fullName.isNotEmpty)
                                      Text(
                                        p.fullName,
                                        style: TextStyle(
                                          color: colors.secondaryText,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: on ? kCloseFriendsGreen : null,
                                  border: on
                                      ? null
                                      : Border.all(
                                          color: colors.secondaryText,
                                          width: 1.5,
                                        ),
                                ),
                                child: on
                                    ? const Icon(
                                        CupertinoIcons.star_fill,
                                        size: 15,
                                        color: Color(0xFFFFFFFF),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
