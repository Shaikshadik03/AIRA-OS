import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:aira_app/core/services/supabase_chat_service.dart';
import 'package:aira_app/core/services/chat_cache_service.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('aira_chat_cache_test_');
    Hive.init(tempDir.path);
    await ChatCacheService.init();
  });

  tearDownAll(() async {
    await ChatCacheService.clearAll();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('Item 23 — Supabase Chat & Offline Local Persistence Tests', () {
    final chatService = SupabaseChatService();

    test('Conversation creation generates valid conversationId and caches it', () async {
      final convId = await chatService.createConversation(title: 'Sprint Planning 2026');
      expect(convId, isNotEmpty);

      final conversations = await chatService.listConversations();
      expect(conversations, isNotEmpty);
      expect(conversations.any((c) => c['id'] == convId), isTrue);
    });

    test('Message saving persists to local cache and is retrievable via loadMessages', () async {
      const convId = 'conv_test_123';
      
      await chatService.saveMessage(
        conversationId: convId,
        role: 'user',
        content: 'Hey AIRA, what is my agenda today?',
      );

      await chatService.saveMessage(
        conversationId: convId,
        role: 'assistant',
        content: 'You have 3 meetings scheduled on your Google Calendar today.',
      );

      final loaded = await chatService.loadMessages(convId);
      expect(loaded.length, equals(2));
      expect(loaded[0].role, equals('user'));
      expect(loaded[0].content, equals('Hey AIRA, what is my agenda today?'));
      expect(loaded[1].role, equals('assistant'));
      expect(loaded[1].content, contains('3 meetings'));
    });

    test('Chat messages persist across simulated app restart (fresh service reload)', () async {
      const restartConvId = 'conv_restart_test_456';

      // Turn 1: Save message before app restart
      await chatService.saveMessage(
        conversationId: restartConvId,
        role: 'user',
        content: 'Remember that my favorite programming language is Dart.',
      );

      // Simulate app restart by querying fresh cache retrieval
      final messagesAfterRestart = ChatCacheService.getCachedMessages(restartConvId);
      expect(messagesAfterRestart, isNotEmpty);
      expect(messagesAfterRestart.length, equals(1));
      expect(messagesAfterRestart.first.content, contains('favorite programming language is Dart'));

      // Also verify via fresh SupabaseChatService instance
      final freshService = SupabaseChatService();
      final reloaded = await freshService.loadMessages(restartConvId);
      expect(reloaded.length, equals(1));
      expect(reloaded.first.content, contains('favorite programming language is Dart'));
    });
  });
}
