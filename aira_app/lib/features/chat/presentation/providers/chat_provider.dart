import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/features/chat/domain/chat_models.dart';
import 'package:aira_app/core/services/groq_service.dart';
import 'package:aira_app/core/services/supabase_chat_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_tts/flutter_tts.dart';

// ──────────────────── Chat State ────────────────────

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final String? activeConversationId;
  final String? activeConversationTitle;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.activeConversationId,
    this.activeConversationTitle,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    String? activeConversationId,
    String? activeConversationTitle,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      activeConversationTitle: activeConversationTitle ?? this.activeConversationTitle,
    );
  }
}

// ──────────────────── Chat Notifier ────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  final GroqService _groq = GroqService();
  final SupabaseChatService _supabase = SupabaseChatService();
  final _uuid = const Uuid();
  final FlutterTts _tts = FlutterTts();
  bool _isVoiceEnabled = true;

  ChatNotifier() : super(const ChatState()) {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
  }

  void toggleVoice(bool enabled) {
    _isVoiceEnabled = enabled;
    if (!enabled) _tts.stop();
  }

  bool get isVoiceEnabled => _isVoiceEnabled;

  /// Load an existing conversation from Supabase.
  Future<void> loadConversation(String conversationId, String title) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final messages = await _supabase.loadMessages(conversationId);
      state = ChatState(
        messages: messages,
        activeConversationId: conversationId,
        activeConversationTitle: title,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load chat: $e');
    }
  }

  /// Send a message — saves to Supabase + gets Groq AI response.
  Future<void> sendMessage(String content, {String? base64Image}) async {
    if (content.trim().isEmpty && base64Image == null) return;

    // Create conversation in Supabase if this is the first message
    String? convId = state.activeConversationId;
    if (convId == null) {
      try {
        // Use first ~40 chars of first message as title
        final title = content.length > 40 ? '${content.substring(0, 40)}...' : content;
        convId = await _supabase.createConversation(title: title.isNotEmpty ? title : 'New Chat');
        state = state.copyWith(
          activeConversationId: convId,
          activeConversationTitle: content.length > 40 ? '${content.substring(0, 40)}...' : content,
        );
      } catch (_) {
        // If Supabase fails (e.g. not logged in), continue with local-only mode
        convId = null;
      }
    }

    // Add user message to UI
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      conversationId: convId ?? 'local',
      role: 'user',
      content: content.trim().isEmpty ? 'Shared an image.' : content.trim(),
      createdAt: DateTime.now(),
      isStreaming: false,
      base64Image: base64Image,
    );

    // Add typing indicator
    final typingMsg = ChatMessage(
      id: 'typing-${_uuid.v4()}',
      conversationId: convId ?? 'local',
      role: 'assistant',
      content: '',
      createdAt: DateTime.now(),
      isStreaming: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg, typingMsg],
      isSending: true,
      error: null,
    );

    // Save user message to Supabase
    if (convId != null) {
      try {
        await _supabase.saveMessage(
          conversationId: convId,
          role: 'user',
          content: userMsg.content,
        );
      } catch (_) {}
    }

    try {
      // Build history for Groq (exclude typing placeholder)
      final history = state.messages
          .where((m) => !m.isStreaming && m.id != userMsg.id)
          .map((m) => <String, dynamic>{
                'role': m.role == 'user' ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList();

      // Call Groq API
      final response = await _groq.chat(
        content.trim().isEmpty ? 'Describe this image.' : content.trim(),
        history,
        base64Image: base64Image,
      );

      // Create assistant message
      final assistantMsg = ChatMessage(
        id: _uuid.v4(),
        conversationId: convId ?? 'local',
        role: 'assistant',
        content: response,
        createdAt: DateTime.now(),
        isStreaming: false,
      );

      // Remove typing indicator, add real response
      final updatedMessages = state.messages
          .where((m) => m.id != typingMsg.id)
          .toList();

      state = state.copyWith(
        messages: [...updatedMessages, assistantMsg],
        isSending: false,
      );

      // Save assistant message to Supabase
      if (convId != null) {
        try {
          await _supabase.saveMessage(
            conversationId: convId,
            role: 'assistant',
            content: response,
          );
        } catch (_) {}
      }

      if (_isVoiceEnabled) {
        final cleanText = response.replaceAll(RegExp(r'[*#_`]'), '');
        await _tts.speak(cleanText);
      }
    } catch (e) {
      final updatedMessages = state.messages
          .where((m) => m.id != typingMsg.id)
          .toList();
      state = state.copyWith(
        messages: updatedMessages,
        isSending: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Start a brand new chat (clears current state).
  void clearChat() {
    state = const ChatState();
  }

  /// Clear error.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ──────────────────── Provider ────────────────────

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
