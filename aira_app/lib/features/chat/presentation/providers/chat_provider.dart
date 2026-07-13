
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/features/chat/domain/chat_models.dart';
import 'package:aira_app/core/services/api_service.dart';

// ──────────────────── Chat State ────────────────────

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final String? currentConversationId;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.currentConversationId,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    String? currentConversationId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
      currentConversationId: currentConversationId ?? this.currentConversationId,
    );
  }
}

// ──────────────────── Chat Notifier ────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  final ApiService _api;

  ChatNotifier(this._api) : super(const ChatState());

  /// Create a new conversation and set it as current.
  Future<void> createNewConversation() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final conv = await _api.createConversation();
      state = state.copyWith(
        currentConversationId: conv['id'],
        messages: [],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load an existing conversation's messages.
  Future<void> loadConversation(String conversationId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final conv = await _api.getConversation(conversationId);
      final messages = (conv['messages'] as List?)
              ?.map((m) => ChatMessage.fromJson(m))
              .toList() ??
          [];
      state = state.copyWith(
        currentConversationId: conversationId,
        messages: messages,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Send a message and receive AI response.
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    String? convId = state.currentConversationId;

    // Auto-create conversation if none exists
    if (convId == null) {
      try {
        final conv = await _api.createConversation();
        convId = conv['id'] as String;
        state = state.copyWith(currentConversationId: convId);
      } catch (e) {
        state = state.copyWith(error: 'Failed to create conversation: $e');
        return;
      }
    }

    // Add user message optimistically
    final userMsg = ChatMessage.userTemp(content);
    final typingMsg = ChatMessage.streamingPlaceholder();

    state = state.copyWith(
      messages: [...state.messages, userMsg, typingMsg],
      isSending: true,
      error: null,
    );

    try {
      final result = await _api.sendMessage(convId, content);

      // Replace temp messages with real ones
      final realUserMsg = ChatMessage.fromJson(result['user_message']);
      final assistantMsg = ChatMessage.fromJson(result['assistant_message']);

      final updatedMessages = state.messages
          .where((m) => m.id != userMsg.id && m.id != typingMsg.id)
          .toList();

      state = state.copyWith(
        messages: [...updatedMessages, realUserMsg, assistantMsg],
        isSending: false,
      );
    } catch (e) {
      // Remove typing indicator on error, keep user message
      final updatedMessages =
          state.messages.where((m) => m.id != typingMsg.id).toList();
      state = state.copyWith(
        messages: updatedMessages,
        isSending: false,
        error: 'Failed to get response. Check your connection.',
      );
    }
  }

  /// Clear the current conversation.
  void clearChat() {
    state = const ChatState();
  }

  /// Clear any error.
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ──────────────────── Conversation List ────────────────────

class ConversationListNotifier extends StateNotifier<List<Conversation>> {
  final ApiService _api;

  ConversationListNotifier(this._api) : super([]);

  Future<void> loadConversations() async {
    try {
      final data = await _api.listConversations();
      state = data.map((json) => Conversation.fromJson(json)).toList();
    } catch (e) {
      // Silently fail — conversations just won't show
    }
  }

  Future<void> deleteConversation(String id) async {
    try {
      await _api.deleteConversation(id);
      state = state.where((c) => c.id != id).toList();
    } catch (_) {}
  }
}

// ──────────────────── Providers ────────────────────

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ApiService());
});

final conversationListProvider =
    StateNotifierProvider<ConversationListNotifier, List<Conversation>>((ref) {
  return ConversationListNotifier(ApiService());
});
