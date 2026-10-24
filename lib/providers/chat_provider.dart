import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../models/social_models.dart";
import "social_providers.dart";
import "supabase_providers.dart";

// ─────────────────────────── Inbox ───────────────────────────

class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return [];
    return ref.read(repositoryProvider).conversations();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<Conversation>>(
      ConversationsNotifier.new,
    );

/// Number of conversations with unread messages (badge on the DM tab).
final unreadChatsProvider = Provider<int>((ref) {
  final list = ref.watch(conversationsProvider).valueOrNull ?? const [];
  return list.where((c) => c.unread > 0).length;
});

/// Listens for new messages sent to you and refreshes the inbox.
/// Watched by the home page so it stays connected while you are signed in.
final inboxRealtimeProvider = Provider<void>((ref) {
  final me = ref.watch(currentUserIdProvider);
  if (me == null) return;
  final client = ref.watch(supabaseProvider);

  final channel = client
      .channel("inbox:$me")
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: "public",
        table: "messages",
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: "receiver_id",
          value: me,
        ),
        callback: (_) => ref.invalidate(conversationsProvider),
      )
      .subscribe();

  ref.onDispose(() => client.removeChannel(channel));
});

// ─────────────────────────── One conversation ───────────────────────────

/// Messages with one person, updated live.
class ChatNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<Message>, String> {
  int _tempId = 0;

  String get _me => ref.read(currentUserIdProvider) ?? "";

  @override
  Future<List<Message>> build(String partnerId) async {
    final me = _me;
    final client = ref.read(supabaseProvider);
    final repo = ref.read(repositoryProvider);

    final channel = client
        .channel("chat:$me:$partnerId")
        // New message from them.
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: "public",
          table: "messages",
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: "receiver_id",
            value: me,
          ),
          callback: (payload) {
            final m = Message.fromMap(payload.newRecord);
            if (m.senderId != partnerId) return;
            _upsert(m);
            repo.markRead(partnerId).catchError((_) {});
          },
        )
        // They opened your message ("Seen").
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: "public",
          table: "messages",
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: "sender_id",
            value: me,
          ),
          callback: (payload) {
            final m = Message.fromMap(payload.newRecord);
            if (m.receiverId == partnerId) _upsert(m);
          },
        )
        // Unsent messages disappear for both people.
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: "public",
          table: "messages",
          callback: (payload) {
            final id = payload.oldRecord["id"];
            if (id is String) _remove(id);
          },
        )
        .subscribe();
    // Reactions added, changed or removed by either person. Separate
    // channel: if the reactions table is missing (schema.sql not re-run),
    // only reactions stop updating live, not the messages.
    final reactions = client
        .channel("reactions:$me:$partnerId")
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: "public",
          table: "message_reactions",
          callback: (payload) {
            final id =
                payload.newRecord["message_id"] ??
                payload.oldRecord["message_id"];
            if (id is String) _reloadReactions(id);
          },
        )
        .subscribe();
    ref.onDispose(() {
      client.removeChannel(channel);
      client.removeChannel(reactions);
    });

    final messages = await repo.messagesWith(partnerId);
    await repo.markRead(partnerId).catchError((_) {});
    ref.invalidate(conversationsProvider);
    return messages;
  }

  void _upsert(Message m) {
    final list = state.valueOrNull;
    if (list == null) return;
    if (m.deletedFor.contains(_me)) {
      _remove(m.id);
      return;
    }
    final index = list.indexWhere((x) => x.id == m.id);
    if (index >= 0) {
      // Realtime rows carry no reactions: keep the ones already shown.
      final merged = m.reactions.isEmpty
          ? m.copyWith(reactions: list[index].reactions)
          : m;
      state = AsyncData([...list]..[index] = merged);
    } else {
      state = AsyncData([...list, m]);
    }
  }

  void _remove(String id) {
    final list = state.valueOrNull;
    if (list == null || !list.any((m) => m.id == id)) return;
    state = AsyncData(list.where((m) => m.id != id).toList());
  }

  void _setReactions(String id, Map<String, String> reactions) {
    final list = state.valueOrNull;
    if (list == null) return;
    state = AsyncData([
      for (final m in list)
        if (m.id == id) m.copyWith(reactions: reactions) else m,
    ]);
  }

  Future<void> _reloadReactions(String id) async {
    final list = state.valueOrNull;
    if (list == null || !list.any((m) => m.id == id)) return;
    final all = await ref.read(repositoryProvider).reactionsFor([id]);
    _setReactions(id, all[id] ?? const {});
  }

  /// Sets your reaction; the same emoji again removes it.
  Future<void> react(Message message, String emoji) async {
    final current = message.reactions[_me];
    final next = {...message.reactions};
    if (current == emoji) {
      next.remove(_me);
    } else {
      next[_me] = emoji;
    }
    _setReactions(message.id, next);
    try {
      await ref
          .read(repositoryProvider)
          .react(message.id, current == emoji ? null : emoji);
    } catch (_) {
      _setReactions(message.id, message.reactions);
      rethrow;
    }
  }

  /// Hides a message for you only.
  Future<void> deleteForMe(Message message) async {
    _remove(message.id);
    try {
      await ref.read(repositoryProvider).deleteForMe(message);
      ref.invalidate(conversationsProvider);
    } catch (_) {
      ref.invalidateSelf();
      rethrow;
    }
  }

  Future<void> send({
    String text = "",
    XFile? photo,
    String? contextType,
    String? contextText,
    String? contextMediaUrl,
    String? replyToId,
  }) async {
    final body = text.trim();
    if (body.isEmpty && photo == null) return;

    final temp = Message(
      id: "temp${_tempId++}",
      senderId: _me,
      receiverId: arg,
      body: body,
      createdAt: DateTime.now(),
      contextType: contextType,
      contextText: contextText,
      contextMediaUrl: contextMediaUrl,
      mediaUrl: photo?.path,
      replyToId: replyToId,
      pending: true,
    );
    _upsert(temp);

    try {
      final saved = await ref
          .read(repositoryProvider)
          .sendMessage(
            to: arg,
            body: body,
            photo: photo,
            contextType: contextType,
            contextText: contextText,
            contextMediaUrl: contextMediaUrl,
            replyToId: replyToId,
          );
      final list = state.valueOrNull ?? [];
      state = AsyncData([
        for (final m in list)
          if (m.id == temp.id) saved else m,
      ]);
      ref.invalidate(conversationsProvider);
    } catch (_) {
      final list = state.valueOrNull ?? [];
      state = AsyncData(list.where((m) => m.id != temp.id).toList());
      rethrow;
    }
  }

  Future<void> unsend(Message message) async {
    await ref.read(repositoryProvider).unsend(message.id);
    final list = state.valueOrNull ?? [];
    state = AsyncData(list.where((m) => m.id != message.id).toList());
    ref.invalidate(conversationsProvider);
  }
}

final chatProvider = AsyncNotifierProvider.autoDispose
    .family<ChatNotifier, List<Message>, String>(ChatNotifier.new);

/// Sends one message without opening the chat (story / note replies,
/// sharing a post).
Future<void> sendDirect(
  WidgetRef ref, {
  required String to,
  String text = "",
  String? contextType,
  String? contextText,
  String? contextMediaUrl,
}) async {
  await ref
      .read(repositoryProvider)
      .sendMessage(
        to: to,
        body: text,
        contextType: contextType,
        contextText: contextText,
        contextMediaUrl: contextMediaUrl,
      );
  ref.invalidate(conversationsProvider);
}

// ─────────────────────────── Sample channels ───────────────────────────

/// Group chats with the sample channels. Kept on the phone only.
class ChatThread {
  final String id;
  final String name;

  const ChatThread(this.id, this.name);
}

const List<ChatThread> kChatThreads = [
  ChatThread("nba", "NBA Fans"),
  ChatThread("football", "Football Talk"),
  ChatThread("news", "Daily News"),
];

class LocalChatMessage {
  final String text;
  final bool mine;
  final DateTime time;

  LocalChatMessage(this.text, {required this.mine, DateTime? time})
    : time = time ?? DateTime.now();
}

class LocalChatNotifier extends Notifier<Map<String, List<LocalChatMessage>>> {
  @override
  Map<String, List<LocalChatMessage>> build() {
    ref.watch(currentUserIdProvider);
    final yesterday = DateTime.now().subtract(const Duration(hours: 20));
    return {
      "nba": [
        LocalChatMessage(
          "Did you catch the game last night?",
          mine: false,
          time: yesterday,
        ),
      ],
      "football": [
        LocalChatMessage(
          "Who are you backing this weekend?",
          mine: false,
          time: yesterday,
        ),
      ],
      "news": [
        LocalChatMessage(
          "Morning headlines are out.",
          mine: false,
          time: yesterday,
        ),
      ],
    };
  }

  void send(String threadId, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    state = {
      ...state,
      threadId: [
        ...(state[threadId] ?? <LocalChatMessage>[]),
        LocalChatMessage(t, mine: true),
      ],
    };
  }
}

final localChatProvider =
    NotifierProvider<LocalChatNotifier, Map<String, List<LocalChatMessage>>>(
      LocalChatNotifier.new,
    );
