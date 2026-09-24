import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aira_app/features/chat/domain/chat_models.dart';
import 'package:aira_app/core/services/chat_cache_service.dart';

/// Handles saving and loading chat conversations directly from Supabase,
/// with seamless offline local caching via ChatCacheService.
class SupabaseChatService {
  static final SupabaseChatService _instance = SupabaseChatService._internal();
  factory SupabaseChatService() => _instance;
  SupabaseChatService._internal();

  SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get _userId => _db?.auth.currentUser?.id;

  // ──────────────────── Conversations ────────────────────

  /// Create a new conversation and return its ID.
  Future<String> createConversation({String? title}) async {
    final db = _db;
    final uid = _userId;
    if (db == null || uid == null) {
      final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final existing = ChatCacheService.getCachedConversations();
      ChatCacheService.cacheConversations([
        {
          'id': localId,
          'title': title ?? 'New Chat',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        ...existing,
      ]);
      return localId;
    }

    try {
      final response = await db.from('conversations').insert({
        'user_id': uid,
        'title': title ?? 'New Chat',
      }).select('id').single();

      final convId = response['id'] as String;
      return convId;
    } catch (_) {
      final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      return localId;
    }
  }

  /// Update the title of a conversation.
  Future<void> updateConversationTitle(String conversationId, String title) async {
    final db = _db;
    if (db != null) {
      try {
        await db.from('conversations').update({'title': title}).eq('id', conversationId);
      } catch (_) {}
    }
  }

  /// List all conversations for the current user, most recent first.
  Future<List<Map<String, dynamic>>> listConversations({int limit = 30}) async {
    final db = _db;
    final uid = _userId;
    if (db == null || uid == null) {
      return ChatCacheService.getCachedConversations();
    }

    try {
      final response = await db
          .from('conversations')
          .select('id, title, created_at, updated_at')
          .eq('user_id', uid)
          .order('updated_at', ascending: false)
          .limit(limit);

      final remoteList = List<Map<String, dynamic>>.from(response);
      ChatCacheService.cacheConversations(remoteList);
      return remoteList;
    } catch (_) {
      return ChatCacheService.getCachedConversations();
    }
  }

  /// Delete a conversation and all its messages.
  Future<void> deleteConversation(String conversationId) async {
    final db = _db;
    if (db != null) {
      try {
        await db.from('conversations').delete().eq('id', conversationId);
      } catch (_) {}
    }
  }

  // ──────────────────── Messages ────────────────────

  /// Save a single message to the DB (and local cache).
  Future<void> saveMessage({
    required String conversationId,
    required String role,
    required String content,
  }) async {
    // 1. Cache locally first for instant offline persistence
    final localMsg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      role: role,
      content: content,
      createdAt: DateTime.now(),
    );
    final cached = ChatCacheService.getCachedMessages(conversationId);
    await ChatCacheService.cacheMessages(conversationId, [...cached, localMsg]);

    // 2. Persist to remote Supabase if connected
    final db = _db;
    final uid = _userId;
    if (db == null || uid == null) return;

    try {
      await db.from('messages').insert({
        'conversation_id': conversationId,
        'user_id': uid,
        'role': role,
        'content': content,
      });

      // Bump conversation's updated_at
      await db.from('conversations').update({
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', conversationId);
    } catch (_) {}
  }

  /// Load all messages for a conversation (remote first, falling back to local cache).
  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    final db = _db;
    if (db == null) {
      return ChatCacheService.getCachedMessages(conversationId);
    }

    try {
      final response = await db
          .from('messages')
          .select('id, conversation_id, role, content, created_at')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      final remoteList = (response as List).map((m) {
        return ChatMessage(
          id: m['id'] as String,
          conversationId: m['conversation_id'] as String,
          role: m['role'] as String,
          content: m['content'] as String,
          createdAt: DateTime.parse(m['created_at'] as String),
        );
      }).toList();

      if (remoteList.isNotEmpty) {
        await ChatCacheService.cacheMessages(conversationId, remoteList);
        return remoteList;
      }
    } catch (_) {}

    return ChatCacheService.getCachedMessages(conversationId);
  }
}
