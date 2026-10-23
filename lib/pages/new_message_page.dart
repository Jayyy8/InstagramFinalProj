import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/social_models.dart";
import "../navigation.dart";
import "../providers/social_providers.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "../widgets/sub_page.dart";
import "../widgets/user_row.dart";
import "chat_page.dart";

/// Pick someone to message: people you follow, or search everyone.
class NewMessagePage extends ConsumerStatefulWidget {
  const NewMessagePage({super.key});

  @override
  ConsumerState<NewMessagePage> createState() => _NewMessagePageState();
}

class _NewMessagePageState extends ConsumerState<NewMessagePage> {
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

  void _open(Profile p) {
    Navigator.of(context).pushReplacement(adaptiveRoute(ChatPage(partner: p)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final me = ref.watch(currentUserIdProvider);
    final q = _query.text.trim();
    final AsyncValue<List<Profile>> people = q.isNotEmpty
        ? ref.watch(userSearchProvider(q))
        : (me == null
              ? const AsyncValue.data([])
              : ref.watch(followingListProvider(me)));

    return SubPage(
      title: "New message",
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Text("To:", style: TextStyle(color: colors.text, fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(
                  child: CupertinoTextField(
                    controller: _query,
                    autofocus: true,
                    placeholder: "Search",
                    placeholderStyle: TextStyle(color: colors.secondaryText),
                    style: TextStyle(color: colors.text),
                    decoration: null,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: colors.separator),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                q.isEmpty ? "Suggested" : "Accounts",
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
              data: (list) => list.isEmpty
                  ? Center(
                      child: Text(
                        q.isEmpty
                            ? "Follow people or search to start a chat."
                            : "No account found.",
                        style: TextStyle(color: colors.secondaryText),
                      ),
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) => UserRow(
                        profile: list[i],
                        showFollow: false,
                        onTap: () => _open(list[i]),
                        trailing: Icon(
                          CupertinoIcons.chat_bubble,
                          color: colors.secondaryText,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
