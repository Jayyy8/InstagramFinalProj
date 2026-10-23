import "package:flutter/cupertino.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../navigation.dart";
import "../theme/app_theme.dart";
import "../widgets/dialogs.dart";
import "new_post_page.dart";
import "note_sheets.dart";
import "story_create_page.dart";

/// The "+" menu: Create → Reel, Post, Story, Note, Live.
void showCreateSheet(BuildContext context, WidgetRef ref) {
  void notAvailable(String what) => showInfo(
    context,
    title: what,
    message: "$what isn't available in this version of the app.",
  );

  final rows = <(IconData, String, VoidCallback)>[
    (CupertinoIcons.play_rectangle, "Reel", () => notAvailable("Reels")),
    (
      CupertinoIcons.square_grid_2x2,
      "Post",
      () => push(context, const NewPostPage()),
    ),
    (
      CupertinoIcons.plus_circle,
      "Story",
      () => pushFullscreen(context, const StoryCreatePage()),
    ),
    (CupertinoIcons.chat_bubble_text, "Note", () => showNoteComposer(context)),
    (
      CupertinoIcons.antenna_radiowaves_left_right,
      "Live",
      () => notAvailable("Live video"),
    ),
  ];

  showIgSheet<void>(
    context,
    builder: (sheetContext) {
      final colors = AppColors.of(sheetContext);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "Create",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
          ),
          Container(height: 0.5, color: colors.separator),
          for (final (icon, label, onTap) in rows)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(sheetContext).pop();
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: colors.text, size: 26),
                    const SizedBox(width: 16),
                    Text(
                      label,
                      style: TextStyle(fontSize: 16, color: colors.text),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      );
    },
  );
}
