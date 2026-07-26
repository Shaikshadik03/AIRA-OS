import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aira_app/features/chat/domain/chat_models.dart';

/// Handles saving and loading chat conversations directly from Supabase.
/// No backend server required — talks directly to Supabase DB.
class SupabaseChatService {
  static final SupabaseChatService _instance = SupabaseChatService._internal();
  factory SupabaseChatService() => _instance;
  SupabaseChatService._internal();

  final _db = Supabase.instance.client;

  String? get _userId => _db.auth.currentUser?.id;

  // ──────────────────── Conversations ────────────────────

  /// Create a new conversation and return its ID.
  Future<String> createConversation({String? title}) async {
    final uid = _userId;
    if (uid == null) throw Exception('Not authenticated');

    final response = await _db.from('conversations').insert({
      'user_id': uid,
      'title': title ?? 'New Chat',
    }).select('id').single();

    return response['id'] as String;
  }

  /// Update the title of a conversation.
  Future<void> updateConversationTitle(String conversationId, String title) async {
    await _db.from('conversations').update({'title': title}).eq('id', conversationId);
  }

  /// List all conversations for the current user, most recent first.
  Future<List<Map<String, dynamic>>> listConversations({int limit = 30}) async {
    final uid = _userId;
    if (uid == null) return [];

    final response = await _db
        .from('conversations')
        .select('id, title, created_at, updated_at')
        .eq('user_id', uid)
        .order('updated_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Delete a conversation and all its messages.
  Future<void> deleteConversation(String conversationId) async {
    await _db.from('conversations').delete().eq('id', conversationId);
  }

  // ──────────────────── Messages ────────────────────

  /// Save a single message to the DB.
  Future<void> saveMessage({
    required String conversationId,
    required String role,
    required String content,
  }) async {
    final uid = _userId;
    if (uid == null) return;

    await _db.from('messages').insert({
      'conversation_id': conversationId,
      'user_id': uid,
      'role': role,
      'content': content,
    });

    // Bump the conversation's updated_at so it appears at top of list
    await _db.from('conversations').update({
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', conversationId);
  }

  /// Load all messages for a conversation.
  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    final response = await _db
        .from('messages')
        .select('id, conversation_id, role, content, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return (response as List).map((m) {
      return ChatMessage(
        id: m['id'] as String,
        conversationId: m['conversation_id'] as String,
        role: m['role'] as String,
        content: m['content'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
    }).toList();
  }
}
