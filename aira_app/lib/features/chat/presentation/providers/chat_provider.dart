import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/features/chat/domain/chat_models.dart';
import 'package:aira_app/features/chat/domain/workspace_intent.dart';
import 'package:aira_app/core/services/groq_service.dart';
import 'package:aira_app/core/services/supabase_chat_service.dart';
import 'package:aira_app/core/services/google_workspace_service.dart';
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
  final bool isGoogleConnected;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.activeConversationId,
    this.activeConversationTitle,
    this.isGoogleConnected = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    String? activeConversationId,
    String? activeConversationTitle,
    bool? isGoogleConnected,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      activeConversationTitle: activeConversationTitle ?? this.activeConversationTitle,
      isGoogleConnected: isGoogleConnected ?? this.isGoogleConnected,
    );
  }
}

// ──────────────────── Chat Notifier ────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  final GroqService _groq = GroqService();
  final SupabaseChatService _supabase = SupabaseChatService();
  final GoogleWorkspaceService _workspace = GoogleWorkspaceService();
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

  /// Connect to Google Workspace.
  Future<void> connectGoogleWorkspace() async {
    final success = await _workspace.signInWithWorkspaceScopes();
    state = state.copyWith(isGoogleConnected: success);

    final resultMsg = success
        ? '✅ Connected to Google Workspace as **${_workspace.userEmail}**!\n\nYou can now:\n- Say **"send email to [name] saying [message]"**\n- Say **"show my emails"**\n- Say **"show my calendar"**\n- Say **"create event [title] on [date] at [time]"**\n- Say **"create a Google Doc called [title]"**'
        : '❌ Could not connect to Google Workspace. Please try again.';

    _addSystemMessage(resultMsg);
  }

  /// Load an existing conversation from Supabase.
  Future<void> loadConversation(String conversationId, String title) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final messages = await _supabase.loadMessages(conversationId);
      state = ChatState(
        messages: messages,
        activeConversationId: conversationId,
        activeConversationTitle: title,
        isGoogleConnected: _workspace.isConnected,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load chat: $e');
    }
  }

  /// Send a message — detects workspace commands, saves to Supabase, gets AI response.
  Future<void> sendMessage(String content, {String? base64Image}) async {
    if (content.trim().isEmpty && base64Image == null) return;

    // ── Check if this is a Google Workspace connection request ──
    final lower = content.toLowerCase().trim();
    if (lower.contains('connect google') || lower == 'connect workspace' || lower == 'link google') {
      _addUserMessage(content);
      await connectGoogleWorkspace();
      return;
    }

    // ── Check for Google Workspace intent ──
    final wsCommand = WorkspaceIntentDetector.detect(content);
    if (wsCommand.isWorkspaceCommand) {
      await _handleWorkspaceCommand(content, wsCommand);
      return;
    }

    // ── Normal AI chat flow ──
    await _sendToAI(content, base64Image: base64Image);
  }

  // ──────────────────── Workspace Handlers ────────────────────

  Future<void> _handleWorkspaceCommand(String content, WorkspaceCommand command) async {
    _addUserMessage(content);

    if (!_workspace.isConnected) {
      _addSystemMessage(
        '🔗 **Google Workspace is not connected.**\n\nTo use Gmail, Calendar, and Docs, say **"connect Google Workspace"** first.\n\nI\'ll ask you to sign in to your Google account.',
      );
      return;
    }

    _addLoadingMessage('Working on it...');

    try {
      String result = '';

      switch (command.intent) {
        case WorkspaceIntent.readEmails:
          final emails = await _workspace.listEmails();
          if (emails.isEmpty) {
            result = '📬 No emails found in your inbox.';
          } else {
            result = '📬 **Your recent emails:**\n\n';
            for (final e in emails) {
              result += '**${e['subject']}**\nFrom: ${e['from']}\n${e['snippet']}\n\n';
            }
          }
          break;

        case WorkspaceIntent.sendEmail:
          final to = command.params['to'] ?? '';
          final subject = command.params['subject'] ?? 'Message from AIRA';
          final body = command.params['body'] ?? content;

          if (to.isEmpty) {
            result = '❓ Who should I send the email to? Please say: *"send email to [email address] saying [message]"*';
          } else {
            await _workspace.sendEmail(to: to, subject: subject, body: body);
            result = '✅ **Email sent successfully!**\n\nTo: $to\nSubject: $subject\n\n> $body';
          }
          break;

        case WorkspaceIntent.listEvents:
          final events = await _workspace.listEvents();
          if (events.isEmpty) {
            result = '📅 No upcoming events found.';
          } else {
            result = '📅 **Your upcoming events:**\n\n';
            for (final e in events) {
              final start = e['start'].toString().isNotEmpty ? e['start'] : 'No time set';
              result += '**${e['title']}**\n📍 $start\n${e['location'] != '' ? '📍 ${e['location']}\n' : ''}\n';
            }
          }
          break;

        case WorkspaceIntent.createEvent:
          final title = command.params['title'] ?? 'New Event';
          // Default to tomorrow 10am-11am
          final now = DateTime.now();
          final start = DateTime(now.year, now.month, now.day + 1, 10, 0);
          final end = start.add(const Duration(hours: 1));

          final event = await _workspace.createEvent(title: title, start: start, end: end);
          result = '✅ **Calendar event created!**\n\n📅 **${event['title']}**\nLink: ${event['link']}';
          break;

        case WorkspaceIntent.createDoc:
          final title = command.params['title'] ?? 'New Document';
          final doc = await _workspace.createDoc(title: title);
          result = '✅ **Google Doc created!**\n\n📄 **${doc['title']}**\n[Open Doc](${doc['link']})';
          break;

        default:
          result = '🤔 I understood this as a Google Workspace command but I\'m not sure how to handle it yet. Try being more specific.';
      }

      _removeLoadingMessage();
      _addSystemMessage(result);

      if (_isVoiceEnabled && result.isNotEmpty) {
        final clean = result.replaceAll(RegExp(r'[*#_`\[\]]'), '');
        await _tts.speak(clean);
      }
    } catch (e) {
      _removeLoadingMessage();
      _addSystemMessage('❌ Error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  // ──────────────────── AI Chat ────────────────────

  Future<void> _sendToAI(String content, {String? base64Image}) async {
    // Create conversation in Supabase if this is the first message
    String? convId = state.activeConversationId;
    if (convId == null) {
      try {
        final title = content.length > 40 ? '${content.substring(0, 40)}...' : content;
        convId = await _supabase.createConversation(title: title.isNotEmpty ? title : 'New Chat');
        state = state.copyWith(
          activeConversationId: convId,
          activeConversationTitle: title,
        );
      } catch (_) {
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

    // Save user message
    if (convId != null) {
      try {
        await _supabase.saveMessage(conversationId: convId, role: 'user', content: userMsg.content);
      } catch (_) {}
    }

    try {
      final history = state.messages
          .where((m) => !m.isStreaming && m.id != userMsg.id)
          .map((m) => <String, dynamic>{'role': m.role == 'user' ? 'user' : 'assistant', 'content': m.content})
          .toList();

      final response = await _groq.chat(
        content.trim().isEmpty ? 'Describe this image.' : content.trim(),
        history,
        base64Image: base64Image,
      );

      final assistantMsg = ChatMessage(
        id: _uuid.v4(),
        conversationId: convId ?? 'local',
        role: 'assistant',
        content: response,
        createdAt: DateTime.now(),
      );

      final updatedMessages = state.messages.where((m) => m.id != typingMsg.id).toList();
      state = state.copyWith(messages: [...updatedMessages, assistantMsg], isSending: false);

      // Save assistant message
      if (convId != null) {
        try {
          await _supabase.saveMessage(conversationId: convId, role: 'assistant', content: response);
        } catch (_) {}
      }

      if (_isVoiceEnabled) {
        final cleanText = response.replaceAll(RegExp(r'[*#_`]'), '');
        await _tts.speak(cleanText);
      }
    } catch (e) {
      final updatedMessages = state.messages.where((m) => m.id != typingMsg.id).toList();
      state = state.copyWith(
        messages: updatedMessages,
        isSending: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ──────────────────── Helpers ────────────────────

  void _addUserMessage(String content) {
    final msg = ChatMessage(
      id: _uuid.v4(),
      conversationId: state.activeConversationId ?? 'local',
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  void _addSystemMessage(String content) {
    final msg = ChatMessage(
      id: _uuid.v4(),
      conversationId: state.activeConversationId ?? 'local',
      role: 'assistant',
      content: content,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, msg], isSending: false);
  }

  void _addLoadingMessage(String hint) {
    final msg = ChatMessage(
      id: 'workspace-loading',
      conversationId: state.activeConversationId ?? 'local',
      role: 'assistant',
      content: hint,
      createdAt: DateTime.now(),
      isStreaming: true,
    );
    state = state.copyWith(messages: [...state.messages, msg], isSending: true);
  }

  void _removeLoadingMessage() {
    final msgs = state.messages.where((m) => m.id != 'workspace-loading').toList();
    state = state.copyWith(messages: msgs, isSending: false);
  }

  /// Start a brand new chat.
  void clearChat() {
    state = ChatState(isGoogleConnected: _workspace.isConnected);
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
