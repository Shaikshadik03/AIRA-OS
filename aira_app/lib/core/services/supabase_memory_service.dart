import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles saving, loading, and deleting user memories directly from Supabase DB.
/// Includes in-memory fallback for offline/unauthenticated mode.
class SupabaseMemoryService {
  static final SupabaseMemoryService _instance = SupabaseMemoryService._internal();
  factory SupabaseMemoryService() => _instance;
  SupabaseMemoryService._internal();

  final _db = Supabase.instance.client;
  final List<Map<String, dynamic>> _localCache = [];

  String? get _userId => _db.auth.currentUser?.id;

  /// Save a new memory (e.g. "Rahul's email is rahul@gmail.com").
  Future<Map<String, dynamic>> saveMemory({
    required String content,
    String category = 'general',
  }) async {
    final cleanContent = content.trim();
    if (cleanContent.isEmpty) throw Exception('Memory content cannot be empty');

    final uid = _userId;
    final item = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'content': cleanContent,
      'category': category,
      'created_at': DateTime.now().toIso8601String(),
    };

    if (uid != null) {
      try {
        final resp = await _db.from('memories').insert({
          'user_id': uid,
          'content': cleanContent,
          'category': category,
        }).select('id, content, category, created_at').single();
        _localCache.add(Map<String, dynamic>.from(resp));
        return Map<String, dynamic>.from(resp);
      } catch (_) {
        _localCache.add(item);
        return item;
      }
    } else {
      _localCache.add(item);
      return item;
    }
  }

  /// List all memories stored for the current user.
  Future<List<Map<String, dynamic>>> listMemories() async {
    final uid = _userId;
    if (uid != null) {
      try {
        final response = await _db
            .from('memories')
            .select('id, content, category, created_at')
            .eq('user_id', uid)
            .order('created_at', ascending: false);

        final list = List<Map<String, dynamic>>.from(response);
        _localCache.clear();
        _localCache.addAll(list);
        return list;
      } catch (_) {
        return List.from(_localCache);
      }
    }
    return List.from(_localCache);
  }

  /// Delete a memory by ID.
  Future<void> deleteMemory(String memoryId) async {
    final uid = _userId;
    if (uid != null) {
      try {
        await _db.from('memories').delete().eq('id', memoryId);
      } catch (_) {}
    }
    _localCache.removeWhere((m) => m['id'] == memoryId);
  }

  /// Clear all stored memories for the user.
  Future<void> clearAllMemories() async {
    final uid = _userId;
    if (uid != null) {
      try {
        await _db.from('memories').delete().eq('user_id', uid);
      } catch (_) {}
    }
    _localCache.clear();
  }

  /// Find an email address associated with a person's name in memories.
  /// Example: name = "Rahul" -> returns "rahul@gmail.com" if found in memories.
  Future<String?> findEmailForName(String name) async {
    final memories = await listMemories();
    final lowerName = name.toLowerCase().trim();

    // Look for email regex in memories containing the person's name
    final emailRegex = RegExp(r'([A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,})');

    for (final m in memories) {
      final content = (m['content'] as String? ?? '').toLowerCase();
      if (content.contains(lowerName)) {
        final match = emailRegex.firstMatch(m['content'] as String);
        if (match != null) {
          return match.group(1);
        }
      }
    }

    // Fallback: search any memory containing an email if name appears anywhere
    for (final m in memories) {
      final content = m['content'] as String? ?? '';
      final match = emailRegex.firstMatch(content);
      if (match != null && content.toLowerCase().contains(lowerName)) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Build prompt string of all stored memories to pass to Groq AI system prompt.
  Future<String> getMemoriesPromptContext() async {
    final memories = await listMemories();
    if (memories.isEmpty) return '';

    final lines = memories.map((m) => '- ${m['content']}').join('\n');
    return '\n\n[USER MEMORIES & SAVED FACTS]:\n$lines\nUse these memories to inform your responses naturally and remember details about the user and their contacts.';
  }
}
