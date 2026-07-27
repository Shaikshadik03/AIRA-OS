import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/features/chat/domain/chat_models.dart';
import 'package:aira_app/features/chat/domain/workspace_intent.dart';
import 'package:aira_app/features/chat/domain/memory_intent.dart';
import 'package:aira_app/core/services/groq_service.dart';
import 'package:aira_app/core/services/supabase_chat_service.dart';
import 'package:aira_app/core/services/supabase_memory_service.dart';
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
  final SupabaseMemoryService _memoryService = SupabaseMemoryService();
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
        ? '✅ Connected to Google Workspace as **${_workspace.userEmail}**!\n\nYou can now:\n- Say **"list my recent files"** (Google Drive!)\n- Say **"search drive for Project"**\n- Say **"upload note to drive: Ideas with content Hello"**\n- Say **"send email to Rahul saying [message]"** (auto-searches Google Contacts!)\n- Say **"show my emails"**\n- Say **"show my calendar"**\n- Say **"create a sheet called Budget 2026"**'
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

  /// Send a message — handles memory commands, workspace commands, and AI chat.
  Future<void> sendMessage(String content, {String? base64Image}) async {
    if (content.trim().isEmpty && base64Image == null) return;

    // ── Check for Google Workspace connection request ──
    final lower = content.toLowerCase().trim();
    if (lower.contains('connect google') || lower == 'connect workspace' || lower == 'link google') {
      _addUserMessage(content);
      await connectGoogleWorkspace();
      return;
    }

    // ── Check for Memory Intent ──
    final memCommand = MemoryIntentDetector.detect(content);
    if (memCommand.isMemoryCommand) {
      await _handleMemoryCommand(content, memCommand);
      return;
    }

    // ── Check for Google Workspace Intent ──
    final wsCommand = WorkspaceIntentDetector.detect(content);
    if (wsCommand.isWorkspaceCommand) {
      await _handleWorkspaceCommand(content, wsCommand);
      return;
    }

    // ── Normal AI chat flow ──
    await _sendToAI(content, base64Image: base64Image);
  }

  // ──────────────────── Memory Handlers ────────────────────

  Future<void> _handleMemoryCommand(String content, MemoryCommand command) async {
    _addUserMessage(content);

    try {
      String result = '';

      switch (command.intent) {
        case MemoryIntent.saveMemory:
          await _memoryService.saveMemory(
            content: command.content,
            category: command.category,
          );
          result = '🧠 **Memory Saved!**\n\n> I will remember: *"${command.content}"*\n\nThis is now part of my long-term memory across all your chats!';
          break;

        case MemoryIntent.listMemories:
          final memories = await _memoryService.listMemories();
          if (memories.isEmpty) {
            result = '🧠 **No saved memories yet.**\n\nTell me things like:\n- *"Remember that Rahul\'s email is rahul@gmail.com"*\n- *"Remember that I prefer bullet points"*';
          } else {
            result = '🧠 **What I Remember About You:**\n\n';
            for (int i = 0; i < memories.length; i++) {
              result += '${i + 1}. ${memories[i]['content']}\n';
            }
            result += '\n*Say "clear all memories" to wipe memory.*';
          }
          break;

        case MemoryIntent.clearMemories:
          await _memoryService.clearAllMemories();
          result = '🧠 **All memories cleared successfully.**';
          break;

        default:
          result = '🧠 Memory action completed.';
      }

      _addSystemMessage(result);

      if (_isVoiceEnabled && result.isNotEmpty) {
        final clean = result.replaceAll(RegExp(r'[*#_`\[\]>]'), '');
        await _tts.speak(clean);
      }
    } catch (e) {
      _addSystemMessage('❌ Failed to update memory: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  // ──────────────────── Workspace Handlers ────────────────────

  Future<void> _handleWorkspaceCommand(String content, WorkspaceCommand command) async {
    _addUserMessage(content);

    if (!_workspace.isConnected) {
      _addSystemMessage(
        '🔗 **Google Workspace is not connected.**\n\nTo use Drive, Gmail, Calendar, Docs, and Sheets, say **"connect Google Workspace"** first.',
      );
      return;
    }

    _addLoadingMessage('Working on it...');

    try {
      String result = '';

      switch (command.intent) {
        // ── Google Drive Handlers ──
        case WorkspaceIntent.listDriveFiles:
          final files = await _workspace.listRecentDriveFiles();
          if (files.isEmpty) {
            result = '📁 No files found in your Google Drive.';
          } else {
            result = '📁 **Your Recent Google Drive Files:**\n\n';
            for (final f in files) {
              final isFolder = (f['mimeType'] as String).contains('folder');
              final icon = isFolder ? '📁' : '📄';
              result += '$icon **[${f['name']}](${f['link']})** (${f['size']})\n';
            }
          }
          break;

        case WorkspaceIntent.searchDriveFiles:
          final query = command.params['query'] as String? ?? '';
          final files = await _workspace.searchDriveFiles(query);
          if (files.isEmpty) {
            result = '🔍 No files or folders found matching **"$query"** in Google Drive.';
          } else {
            result = '🔍 **Google Drive Search Results for "$query":**\n\n';
            for (final f in files) {
              final icon = (f['isFolder'] as bool) ? '📁' : '📄';
              result += '$icon **[${f['name']}](${f['link']})**\n';
            }
          }
          break;

        case WorkspaceIntent.uploadToDrive:
          final filename = command.params['filename'] as String? ?? 'Note';
          final fileContent = command.params['content'] as String? ?? content;

          final res = await _workspace.uploadTextFileToDrive(
            filename: filename,
            content: fileContent,
          );
          result = '✅ **File Uploaded to Google Drive!**\n\n📄 **${res['name']}**\n[Open File in Drive](${res['link']})';
          break;

        // ── Gmail Handlers ──
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
          String to = command.params['to'] as String? ?? '';
          final rawSubject = command.params['subject'] as String? ?? '';
          final rawBody = command.params['body'] as String? ?? '';
          String lookupNote = '';

          // 📇 SMART CONTACT LOOKUP: Google Contacts API -> AI Memory
          if (to.isNotEmpty && !to.contains('@')) {
            try {
              final contactMatch = await _workspace.searchGoogleContactEmail(to);
              if (contactMatch != null && contactMatch['email'] != null) {
                final cName = contactMatch['name'] ?? to;
                final cEmail = contactMatch['email']!;
                lookupNote = '📇 *Found in Google Contacts: **$cName** (`$cEmail`)*\n\n';
                to = cEmail;
              }
            } catch (_) {}

            if (!to.contains('@')) {
              final memoryEmail = await _memoryService.findEmailForName(to);
              if (memoryEmail != null) {
                lookupNote = '🧠 *Retrieved email for **$to** from AI Memory (`$memoryEmail`)*\n\n';
                to = memoryEmail;
              }
            }
          }

          if (to.isEmpty) {
            result = '❓ Who should I send the email to? Please specify an email address or contact name like:\n> *"send email to Rahul asking about tomorrow\'s meeting"*';
          } else if (!to.contains('@')) {
            final emailSub = rawSubject.isNotEmpty ? rawSubject : "the details";
            result = '📧 I see you want to send an email to **$to** regarding *"$emailSub"*, but I couldn\'t find them in your Google Contacts or AI Memory.\n\nPlease try again with their full email address:\n> *"send email to $to@gmail.com about $emailSub"*';
          } else {
            // 📝 FIX EMAIL COMPOSITION BUG: Generate a real, well-written email body instead of raw command echoing
            String emailBody = rawBody.trim();
            if (emailBody.isEmpty ||
                emailBody == content.trim() ||
                emailBody.toLowerCase().startsWith('send mail') ||
                emailBody.toLowerCase().startsWith('send email') ||
                emailBody.toLowerCase().startsWith('send a mail')) {
              try {
                emailBody = await _groq.chat(
                  'Write a polite, professional, short email body based on this user instruction: "$content". Do NOT include Subject lines, To lines, or placeholders. Write only the email body text ready to send.',
                  [],
                );
              } catch (_) {
                emailBody = rawSubject.isNotEmpty
                    ? 'Hi,\n\nI am writing to inquire regarding $rawSubject.\n\nBest regards,\nAIRA'
                    : 'Hi,\n\nHope you are doing well.\n\nBest regards,\nAIRA';
              }
            }

            final emailSubject = rawSubject.isNotEmpty
                ? rawSubject
                : 'Message regarding ${content.length > 30 ? content.substring(0, 30) : content}';

            await _workspace.sendEmail(
              to: to,
              subject: emailSubject,
              body: emailBody,
            );

            final providerUsed = _groq.lastProviderName;
            result = '$lookupNote✅ **Email sent successfully via Gmail!** *(LLM Provider: $providerUsed)*\n\n**To:** $to\n**Subject:** $emailSubject\n\n> ${emailBody.replaceAll('\n', '\n> ')}';
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
          final title = command.params['title'] as String? ?? 'New Event';
          final now = DateTime.now();
          final start = DateTime(now.year, now.month, now.day + 1, 10, 0);
          final end = start.add(const Duration(hours: 1));

          final event = await _workspace.createEvent(title: title, start: start, end: end);
          result = '✅ **Calendar event created!**\n\n📅 **${event['title']}**\nLink: ${event['link']}';
          break;

        case WorkspaceIntent.createDoc:
          final title = command.params['title'] as String? ?? 'New Document';
          final doc = await _workspace.createDoc(title: title);
          result = '✅ **Google Doc created!**\n\n📄 **${doc['title']}**\n[Open Doc](${doc['link']})';
          break;

        case WorkspaceIntent.createSheet:
          final title = command.params['title'] as String? ?? 'New Spreadsheet';
          final sheet = await _workspace.createSheet(title: title);
          result = '✅ **Google Sheet Created!**\n\n📊 **${sheet['title']}**\n[Open Spreadsheet](${sheet['link']})';
          break;

        case WorkspaceIntent.appendSheetRow:
          final target = command.params['sheetTarget'] as String? ?? '';
          final values = (command.params['values'] as List?)?.cast<String>() ?? [];

          if (values.isEmpty) {
            result = '❓ What values should I add to **$target**? Please provide comma-separated values like:\n> *"add row to $target: Item Name, 100, Completed"*';
          } else {
            final res = await _workspace.appendSheetRow(sheetTarget: target, values: values);
            result = '✅ **Row added to Google Sheet!**\n\n📊 **Sheet:** $target\n📝 **Values Added:** ${values.join(" | ")}\n\n[Open Spreadsheet](${res['link']})';
          }
          break;

        case WorkspaceIntent.readSheet:
        case WorkspaceIntent.openSheet:
          final target = command.params['sheetTarget'] as String? ?? '';
          if (target.isEmpty) {
            result = '❓ Which sheet would you like to view? Say *"show sheet [title]"*';
          } else {
            final res = await _workspace.readSheetData(sheetTarget: target);
            final rows = res['rows'] as List<List<String>>;
            if (rows.isEmpty) {
              result = '📊 **Google Sheet ($target)** is empty.\n\n[Open Spreadsheet](${res['link']})';
            } else {
              result = '📊 **Google Sheet ($target):**\n\n';
              for (int i = 0; i < rows.length; i++) {
                final r = rows[i];
                if (i == 0) {
                  result += '| ${r.join(' | ')} |\n';
                  result += '| ${r.map((_) => '---').join(' | ')} |\n';
                } else {
                  result += '| ${r.join(' | ')} |\n';
                }
              }
              result += '\n[Open Spreadsheet](${res['link']})';
            }
          }
          break;

        default:
          result = '🤔 I understood this as a Google Workspace command but I\'m not sure how to handle it yet.';
      }

      _removeLoadingMessage();
      _addSystemMessage(result);

      if (_isVoiceEnabled && result.isNotEmpty) {
        final clean = result.replaceAll(RegExp(r'[*#_`\[\]|]'), '');
        await _tts.speak(clean);
      }
    } catch (e) {
      _removeLoadingMessage();
      final cleanErr = e.toString().replaceAll('Exception: ', '');
      _addSystemMessage('❌ **Workspace Action Failed**\n\n$cleanErr');
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

      // 🧠 Fetch AI memory context to inject into LLM system prompt
      final memoryContext = await _memoryService.getMemoriesPromptContext();

      final response = await _groq.chat(
        content.trim().isEmpty ? 'Describe this image.' : content.trim(),
        history,
        base64Image: base64Image,
        memoryContext: memoryContext,
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
