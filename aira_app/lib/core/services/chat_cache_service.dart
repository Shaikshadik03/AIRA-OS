import 'package:hive_flutter/hive_flutter.dart';
import 'package:aira_app/features/chat/domain/chat_models.dart';

/// Hive-based offline cache for chat messages.
class ChatCacheService {
  static const String _messagesBoxName = 'chat_messages';
  static const String _conversationsBoxName = 'cached_conversations';

  static Box? _messagesBox;
  static Box? _conversationsBox;

  /// Initialize Hive boxes for chat caching.
  static Future<void> init() async {
    _messagesBox = await Hive.openBox(_messagesBoxName);
    _conversationsBox = await Hive.openBox(_conversationsBoxName);
  }

  /// Cache messages for a conversation.
  static Future<void> cacheMessages(
    String conversationId,
    List<ChatMessage> messages,
  ) async {
    final box = _messagesBox;
    if (box == null) return;

    final jsonList = messages
        .map((m) => {
              'id': m.id,
              'conversation_id': m.conversationId,
              'role': m.role,
              'content': m.content,
              'created_at': m.createdAt.toIso8601String(),
            })
        .toList();

    await box.put(conversationId, jsonList);
  }

  /// Get cached messages for a conversation.
  static List<ChatMessage> getCachedMessages(String conversationId) {
    final box = _messagesBox;
    if (box == null) return [];

    final jsonList = box.get(conversationId);
    if (jsonList == null) return [];

    return (jsonList as List).map((json) {
      return ChatMessage.fromJson(Map<String, dynamic>.from(json));
    }).toList();
  }

  /// Cache conversation list metadata.
  static Future<void> cacheConversations(
    List<Map<String, dynamic>> conversations,
  ) async {
    final box = _conversationsBox;
    if (box == null) return;
    await box.put('list', conversations);
  }

  /// Get cached conversation list.
  static List<Map<String, dynamic>> getCachedConversations() {
    final box = _conversationsBox;
    if (box == null) return [];

    final data = box.get('list');
    if (data == null) return [];

    return (data as List)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Clear all cached data.
  static Future<void> clearAll() async {
    await _messagesBox?.clear();
    await _conversationsBox?.clear();
  }
}
