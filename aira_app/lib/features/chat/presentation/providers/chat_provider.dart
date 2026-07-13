import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/features/chat/domain/chat_models.dart';
import 'package:aira_app/core/services/groq_service.dart';
import 'package:uuid/uuid.dart';

// ──────────────────── Chat State ────────────────────

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

// ──────────────────── Chat Notifier ────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  final GroqService _groq = GroqService();
  final _uuid = const Uuid();

  ChatNotifier() : super(const ChatState());



  /// Send a message and get an actual AI response from Groq.
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    // Add user message
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      conversationId: 'local',
      role: 'user',
      content: content.trim(),
      createdAt: DateTime.now(),
      isStreaming: false,
    );

    // Add typing indicator
    final typingMsg = ChatMessage(
      id: 'typing-${_uuid.v4()}',
      conversationId: 'local',
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

    try {
      // Build history (exclude the typing placeholder)
      final history = state.messages
          .where((m) => !m.isStreaming && m.id != userMsg.id)
          .map((m) => {
                'role': m.role == 'user' ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList();

      // Call Groq API directly
      final response = await _groq.chat(content.trim(), history);

      // Create assistant message
      final assistantMsg = ChatMessage(
        id: _uuid.v4(),
        conversationId: 'local',
        role: 'assistant',
        content: response,
        createdAt: DateTime.now(),
        isStreaming: false,
      );

      // Replace typing indicator with real response
      final updatedMessages = state.messages
          .where((m) => m.id != typingMsg.id)
          .toList();

      state = state.copyWith(
        messages: [...updatedMessages, assistantMsg],
        isSending: false,
      );
    } catch (e) {
      // Remove typing indicator, keep user message
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

  /// Clear chat.
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
