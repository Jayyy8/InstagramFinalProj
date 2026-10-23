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
        .subscribe();
    ref.onDispose(() => client.removeChannel(channel));

    final messages = await repo.messagesWith(partnerId);
    await repo.markRead(partnerId).catchError((_) {});
    ref.invalidate(conversationsProvider);
    return messages;
  }

  void _upsert(Message m) {
    final list = state.valueOrNull;
    if (list == null) return;
    final index = list.indexWhere((x) => x.id == m.id);
    if (index >= 0) {
      state = AsyncData([...list]..[index] = m);
    } else {
      state = AsyncData([...list, m]);
    }
  }

  Future<void> send({
    String text = "",
    XFile? photo,
    String? contextType,
    String? contextText,
    String? contextMediaUrl,
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
