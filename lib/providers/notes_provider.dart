import "package:flutter_riverpod/flutter_riverpod.dart";

import "../data/sample_feed.dart";
import "../models/social_models.dart";
import "social_providers.dart";

class NotesState {
  /// Your active note.
  final Note? mine;

  /// Notes of people you follow, then the sample channels.
  final List<Note> others;

  const NotesState({this.mine, this.others = const []});
}

List<Note> _sampleNotes() => [
  for (final n in kSampleNotes)
    Note(
      id: n.id,
      body: n.text,
      createdAt: DateTime.now().subtract(n.age),
      username: n.handle,
      avatarUrls: n.avatar,
    ),
];

class NotesNotifier extends AsyncNotifier<NotesState> {
  @override
  Future<NotesState> build() async {
    final me = ref.watch(currentUserIdProvider);
    if (me == null) return NotesState(others: _sampleNotes());
    final following = await ref.watch(followingProvider.future);
    final notes = await ref.read(repositoryProvider).notes([me, ...following]);

    Note? mine;
    final others = <Note>[];
    for (final n in notes) {
      if (n.profile?.id == me) {
        mine = n;
      } else {
        others.add(n);
      }
    }
    return NotesState(mine: mine, others: [...others, ..._sampleNotes()]);
  }

  Future<void> setNote(String text) async {
    await ref.read(repositoryProvider).setNote(text);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteNote() async {
    await ref.read(repositoryProvider).deleteNote();
    ref.invalidateSelf();
    await future;
  }

  Future<void> toggleLike(Note note) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final like = !note.likedByMe;
    final updated = note.copyWith(
      likedByMe: like,
      likeCount: note.likeCount + (like ? 1 : -1),
    );
    state = AsyncData(
      NotesState(
        mine: current.mine,
        others: [
          for (final n in current.others)
            if (n.id == note.id) updated else n,
        ],
      ),
    );
    if (note.remote) {
      await ref.read(repositoryProvider).setNoteLike(note.id, like);
    }
  }
}

final notesProvider = AsyncNotifierProvider<NotesNotifier, NotesState>(
  NotesNotifier.new,
);

/// Your note text (shown above your avatar on the profile page too).
final myNoteProvider = Provider<Note?>(
  (ref) => ref.watch(notesProvider).valueOrNull?.mine,
);
