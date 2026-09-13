import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/core/agent/goal_planner_engine.dart';
import 'package:aira_app/core/agent/action_guardrail_manager.dart';
import 'package:aira_app/features/chat/domain/agentic_workflow_engine.dart';
import 'package:aira_app/features/chat/domain/chat_models.dart';
import 'package:aira_app/features/chat/domain/workspace_intent.dart';
import 'package:aira_app/features/chat/domain/memory_intent.dart';
import 'package:aira_app/features/chat/domain/phone_intent.dart';
import 'package:aira_app/features/chat/domain/device_intent.dart';
import 'package:aira_app/features/chat/domain/notification_intent.dart';
import 'package:aira_app/features/chat/domain/routine_intent.dart';
import 'package:aira_app/features/chat/domain/whatsapp_intent.dart';
import 'package:aira_app/features/chat/domain/task_intent.dart';
import 'package:aira_app/features/chat/domain/check_in_item.dart';
import 'package:aira_app/features/chat/domain/check_in_intent.dart';
import 'package:aira_app/core/services/check_in_service.dart';
import 'package:aira_app/features/planner/presentation/providers/planner_provider.dart';
import 'package:aira_app/features/laptop/domain/laptop_intent_detector.dart';
import 'package:aira_app/features/laptop/data/laptop_control_service.dart';
import 'dart:convert';
import 'package:aira_app/core/services/web_search_service.dart';
import 'package:aira_app/core/services/notification_service.dart';
import 'package:aira_app/core/services/routine_service.dart';
import 'package:aira_app/core/services/groq_service.dart';
import 'package:aira_app/core/services/supabase_chat_service.dart';
import 'package:aira_app/core/services/supabase_memory_service.dart';
import 'package:aira_app/core/services/google_workspace_service.dart';
import 'package:aira_app/core/services/android_phone_service.dart';
import 'package:aira_app/core/services/android_device_service.dart';
import 'package:aira_app/core/services/fact_extractor.dart';
import 'package:aira_app/core/services/memory_engine.dart';
import 'package:aira_app/core/services/implicit_reminder_detector.dart';
import 'package:aira_app/core/services/proactive_engine.dart';
import 'package:aira_app/core/services/notification_monitor_service.dart';
import 'package:aira_app/core/services/social_world_monitor_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final String? activeConversationId;
  final String? activeConversationTitle;
  final bool isGoogleConnected;
  final bool isSpeaking;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.activeConversationId,
    this.activeConversationTitle,
    this.isGoogleConnected = false,
    this.isSpeaking = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    String? activeConversationId,
    String? activeConversationTitle,
    bool? isGoogleConnected,
    bool? isSpeaking,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      activeConversationTitle: activeConversationTitle ?? this.activeConversationTitle,
      isGoogleConnected: isGoogleConnected ?? this.isGoogleConnected,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final GroqService _groq = GroqService();
  final SupabaseChatService _supabase = SupabaseChatService();
  final SupabaseMemoryService _memoryService = SupabaseMemoryService();
  final GoogleWorkspaceService _workspace = GoogleWorkspaceService();
  final AndroidPhoneService _phoneService = AndroidPhoneService();
  final AndroidDeviceService _deviceService = AndroidDeviceService();
  final NotificationService _notificationService = NotificationService();
  final RoutineService _routineService = RoutineService();
  final LaptopControlService _laptopService = LaptopControlService();
  final _uuid = const Uuid();
  final FlutterTts _tts = FlutterTts();
  bool _isVoiceEnabled = true;

  ChatNotifier() : super(const ChatState()) {
    _initTts();
    _initWorkspaceConnection();
    _initProactiveListener();
  }

  void _initProactiveListener() {
    ProactiveEngine.onProactiveChatMessage = (title, body) {
      _addSystemMessage('🔔 **AIRA · $title**\n\n$body');
    };
    ProactiveEngine.popPendingChatMessages().then((pending) {
      for (final msg in pending) {
        final title = msg['title'] ?? '';
        final body = msg['body'] ?? '';
        if (body.isNotEmpty) {
          _addSystemMessage('🔔 **AIRA · $title**\n\n$body');
        }
      }
    });
  }

  Future<void> _initWorkspaceConnection() async {
    final connected = await _workspace.trySilentSignIn();
    if (connected) {
      state = state.copyWith(isGoogleConnected: true);
    }
  }

  Future<void> _initTts() async {
    try {
      final languages = await _tts.getLanguages;
      if (languages is List && languages.any((l) => l.toString().contains('en-IN') || l.toString().contains('en_IN'))) {
        await _tts.setLanguage("en-IN");
      } else {
        await _tts.setLanguage("en-US");
      }
    } catch (_) {
      await _tts.setLanguage("en-US");
    }

    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      if (mounted) state = state.copyWith(isSpeaking: true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) state = state.copyWith(isSpeaking: false);
    });
    _tts.setCancelHandler(() {
      if (mounted) state = state.copyWith(isSpeaking: false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) state = state.copyWith(isSpeaking: false);
    });
  }

  void toggleVoice(bool enabled) {
    _isVoiceEnabled = enabled;
    if (!enabled) stopTts();
  }

  bool get isVoiceEnabled => _isVoiceEnabled;

  /// Stop active TTS speech immediately (Interruption)
  Future<void> stopTts() async {
    try {
      await _tts.stop();
    } catch (_) {}
    if (mounted) state = state.copyWith(isSpeaking: false);
  }

  /// Clean raw text for human-like spoken output (stripping markdown, code blocks, URLs, and emojis)
  String cleanTextForSpeech(String raw) {
    var text = raw;
    // Strip markdown code blocks and replace with conversational cue
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), " I have displayed the code on your screen. ");
    // Strip inline code formatting
    text = text.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    // Strip markdown links [text](url) -> text
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1');
    // Strip URLs
    text = text.replaceAll(RegExp(r'https?:\/\/[^\s]+'), " a link ");
    // Strip markdown headers and emphasis
    text = text.replaceAll(RegExp(r'[*#_~>]'), '');
    // Strip list dashes and bullets
    text = text.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
    // Strip common emojis that TTS spells out awkwardly
    text = text.replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true), '');
    // Collapse excess whitespace
    text = text.replaceAll(RegExp(r'\n+'), ' ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return text;
  }

  /// Speak text aloud with automatic formatting cleanup
  Future<void> speakText(String text) async {
    if (!_isVoiceEnabled) return;
    final clean = cleanTextForSpeech(text);
    if (clean.isEmpty) return;
    try {
      await _tts.stop();
      if (mounted) state = state.copyWith(isSpeaking: true);
      await _tts.speak(clean);
    } catch (_) {
      if (mounted) state = state.copyWith(isSpeaking: false);
    }
  }

  Future<void> connectGoogleWorkspace() async {
    final success = await _workspace.signInWithWorkspaceScopes();
    state = state.copyWith(isGoogleConnected: success);

    final resultMsg = success
        ? 'Connected to Google Workspace as **${_workspace.userEmail}**!'
        : 'Could not connect to Google Workspace. Please try again.';

    _addSystemMessage(resultMsg);
  }

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

  Future<void> sendMessage(String content, {String? base64Image}) async {
    if (content.trim().isEmpty && base64Image == null) return;

    // Immediately stop active TTS speech (Interruption on user input)
    await stopTts();

    // Record interaction for proactive idle check-in tracking
    ProactiveEngine.recordInteraction();

    // Detect implicit time commitments and auto-schedule reminders
    // (runs async, non-blocking — user doesn't see this)
    ImplicitReminderDetector().detectAndSchedule(content);

    final lower = content.toLowerCase().trim();
    if (lower.contains('connect google') || lower == 'connect workspace' || lower == 'link google') {
      _addUserMessage(content);
      await connectGoogleWorkspace();
      return;
    }

    // ── Check for Device Control Intent (Milestone 4) ──
    final deviceCommand = DeviceIntentDetector.detect(content);
    if (deviceCommand.isDeviceCommand) {
      await _handleDeviceCommand(content, deviceCommand);
      return;
    }

    // ── Check for Smart Routine Intent (Milestone 6 - Feature 3) ──
    final routineCommand = RoutineIntentDetector.detect(content);
    if (routineCommand.isRoutineCommand) {
      await _handleRoutineCommand(content, routineCommand);
      return;
    }

    // ── Check for Notification / Reminder Intent (Milestone 6 - Feature 2) ──
    final notifCommand = NotificationIntentDetector.detect(content);
    if (notifCommand.isNotificationCommand) {
      await _handleNotificationCommand(content, notifCommand);
      return;
    }

    // ── Check for Phone / SMS Intent (Milestone 3) ──
    final phoneCommand = PhoneIntentDetector.detect(content);
    if (phoneCommand.isPhoneCommand) {
      await _handlePhoneCommand(content, phoneCommand);
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

    // ── Check for Proactive Follow-up & Check-In Intent (Stage E) ──
    final activeCheckIn = await CheckInService().getLastDeliveredCheckIn();
    if (CheckInIntentDetector.isCheckInCommand(content, hasActiveCheckIn: activeCheckIn != null)) {
      final checkInCommand = CheckInIntentDetector.parse(content, hasActiveCheckIn: activeCheckIn != null);
      if (checkInCommand != null) {
        await _handleCheckInCommand(content, checkInCommand, activeCheckIn);
        return;
      }
    }

    // ── Check for Task / Reminder Intent (Built-in TickTick System) ──
    if (TaskIntentDetector.isTaskCommand(content)) {
      final taskCommand = TaskIntentDetector.parse(content);
      if (taskCommand != null) {
        await _handleTaskCommand(content, taskCommand);
        return;
      }
    }

    // ── Check for WhatsApp Intent (Milestone Upgrade) ──
    final waCommand = WhatsAppIntentDetector.detect(content);
    if (waCommand.isWhatsAppCommand) {
      await _handleWhatsAppCommand(content, waCommand);
      return;
    }

    // ── Check for Laptop Control Intent (Milestone 3) ──
    if (LaptopIntentDetector.isLaptopCommand(content)) {
      final laptopCommand = LaptopIntentDetector.parse(content);
      if (laptopCommand != null) {
        await _handleLaptopCommand(content, laptopCommand);
        return;
      }
    }

    // ── Check for Notification Intelligence / Digest Intent ──
    if (_isNotificationDigestQuery(content)) {
      await _handleNotificationDigestCommand(content);
      return;
    }

    // ── Check for Social World Radar Intent ──
    if (_isWorldSocialRadarQuery(content)) {
      await _handleWorldSocialRadarCommand(content);
      return;
    }

    // ── Phase 1: High-Level Autonomous Goal Planning & Live Stream ──
    final goalPlanner = GoalPlannerEngine();
    if (goalPlanner.isHighLevelGoal(content)) {
      _addUserMessage(content);
      _addLoadingMessage('🧠 Formulating multi-step execution plan...');
      try {
        final plan = await goalPlanner.generatePlan(content);
        _removeLoadingMessage();

        // Create a live message with the plan attached
        final messageId = _uuid.v4();
        final initialMsg = ChatMessage(
          id: messageId,
          conversationId: state.activeConversationId ?? 'local',
          role: 'assistant',
          content: 'I have formulated an execution plan for your goal. Executing subtasks...',
          createdAt: DateTime.now(),
          plan: plan,
        );

        state = state.copyWith(messages: [...state.messages, initialMsg]);

        // Execute plan with live UI step updates
        final report = await goalPlanner.executePlan(
          plan,
          onStepUpdate: (updatedStep) {
            final updatedMessages = state.messages.map((m) {
              if (m.id == messageId) {
                return ChatMessage(
                  id: m.id,
                  conversationId: m.conversationId,
                  role: m.role,
                  content: m.content,
                  createdAt: m.createdAt,
                  plan: plan,
                );
              }
              return m;
            }).toList();
            state = state.copyWith(messages: updatedMessages);
          },
          onTaskCreated: (title) async {
            await PlannerNotifier.active.addTask(title: title);
          },
        );

        // Update with final execution report
        final finalMessages = state.messages.map((m) {
          if (m.id == messageId) {
            return ChatMessage(
              id: m.id,
              conversationId: m.conversationId,
              role: m.role,
              content: report,
              createdAt: m.createdAt,
              plan: plan,
            );
          }
          return m;
        }).toList();
        state = state.copyWith(messages: finalMessages);

        if (_isVoiceEnabled) {
          await speakText('Goal plan executed successfully.');
        }
        return;
      } catch (e) {
        _removeLoadingMessage();
        _addSystemMessage('❌ **Goal planning error:** $e');
        return;
      }
    }

    // ── Check for Multi-Step Agentic Workflow (Milestone 16) ──
    final agenticEngine = AgenticWorkflowEngine();
    if (agenticEngine.isMultiStepInstruction(content)) {
      _addUserMessage(content);
      _addLoadingMessage('Planning and executing autonomous agentic workflow...');
      try {
        final steps = agenticEngine.planWorkflow(content);
        final report = await agenticEngine.executeWorkflow(
          steps: steps,
          onTaskCreated: (title) async {
            await PlannerNotifier.active.addTask(title: title);
          },
        );
        _removeLoadingMessage();
        _addSystemMessage(report);
        if (_isVoiceEnabled) {
          await speakText('Executed your multi step task successfully.');
        }
        return;
      } catch (e) {
        _removeLoadingMessage();
        _addSystemMessage('❌ **Agentic execution error:** $e');
        return;
      }
    }

    // ── Normal AI chat flow (with auto web search) ──
    await _sendToAI(content, base64Image: base64Image);
  }

  // ──────────────────── WhatsApp Handlers ────────────────────

  Future<void> _handleWhatsAppCommand(String content, WhatsAppCommand command) async {
    _addUserMessage(content);
    _addLoadingMessage('Drafting WhatsApp message...');

    try {
      String draftedMessage = command.message;
      if (command.intent == WhatsAppIntentType.draftMessage || draftedMessage.length < 10) {
        try {
          draftedMessage = await _groq.chat(
            'Draft a clear, polite, natural WhatsApp message for this instruction: "$content". Write ONLY the message body text ready to send. No quotes, no intro.',
            [],
          );
        } catch (_) {
          draftedMessage = command.message;
        }
      }

      String? phone;
      String recipientLabel = command.recipient;

      if (command.recipient.isNotEmpty) {
        // Try looking up in Google Contacts / AI Memory
        try {
          final contact = await _phoneService.resolvePhoneNumber(command.recipient);
          if (contact['phone'] != null && contact['phone']!.isNotEmpty) {
            phone = contact['phone'];
            recipientLabel = '${contact['name']} ($phone)';
          }
        } catch (_) {}
      }

      // Launch WhatsApp
      final opened = await WhatsAppIntentDetector.openWhatsApp(
        phone: phone,
        message: draftedMessage,
      );

      _removeLoadingMessage();

      final result = opened
          ? '💬 **WhatsApp Opened!**\n\n'
            '${recipientLabel.isNotEmpty ? '**To:** $recipientLabel\n' : ''}'
            '**Drafted Message:**\n> "${draftedMessage.replaceAll('\n', '\n> ')}"\n\n'
            '✅ *Message prefilled in WhatsApp ready to send.*'
          : '💬 **WhatsApp Message Drafted:**\n\n'
            '${recipientLabel.isNotEmpty ? '**To:** $recipientLabel\n' : ''}'
            '**Drafted Message:**\n> "${draftedMessage.replaceAll('\n', '\n> ')}"\n\n'
            '⚠️ *Could not open WhatsApp app directly. Please copy the text above.*';

      _addSystemMessage(result);

      if (_isVoiceEnabled && draftedMessage.isNotEmpty) {
        await speakText('WhatsApp message prepared.');
      }
    } catch (e) {
      _removeLoadingMessage();
      _addSystemMessage('❌ **Failed to prepare WhatsApp message:** $e');
    }
  }


  // ──────────────────── Task & Planner Handlers (In-built TickTick System) ────────────────────

  Future<void> _handleTaskCommand(String content, TaskCommand command) async {
    _addUserMessage(content);
    _addLoadingMessage('Updating task manager...');

    try {
      final plannerNotifier = PlannerNotifier.active;

      String result = '';

      switch (command.type) {
        case TaskCommandType.addTask:
          final created = await plannerNotifier.addTask(
            title: command.title,
            dueDate: command.dueDate,
            hasAlarm: command.hasAlarm,
            priority: command.priority,
            category: command.category,
          );
          final timeStr = created.dueDate != null
              ? '${created.dueDate!.hour.toString().padLeft(2, "0")}:${created.dueDate!.minute.toString().padLeft(2, "0")}'
              : 'No specific time';
          final alarmBadge = created.hasAlarm ? '🔔 *Android Alarm & Notification Active*' : '';

          result = '✅ **Task Added to Agenda!**\n\n'
              '• **Task:** ${created.title}\n'
              '• **Category:** ${created.category}\n'
              '• **Priority:** ${created.priority.toUpperCase()}\n'
              '• **Due:** $timeStr\n'
              '$alarmBadge\n\n'
              '👉 *View and edit in Planner anytime.*';
          break;

        case TaskCommandType.listTasks:
          final tasks = plannerNotifier.state.tasks;
          if (tasks.isEmpty) {
            result = '📋 **Your task list is empty.**\n\nSay *"Add task Study OS at 5 PM"* to create one!';
          } else {
            result = '📋 **Your Current Tasks:**\n\n';
            for (final t in tasks) {
              final check = t.isCompleted ? '~~' : '';
              final icon = t.isCompleted ? '✅' : '⏳';
              final time = t.dueDate != null ? ' (${t.dueDate!.hour.toString().padLeft(2, "0")}:${t.dueDate!.minute.toString().padLeft(2, "0")})' : '';
              result += '$icon $check**${t.title}**$check — *${t.category}* [${t.priority}]$time\n';
            }
          }
          break;

        case TaskCommandType.completeTask:
          final match = plannerNotifier.state.tasks.firstWhere(
            (t) => t.title.toLowerCase().contains(command.title.toLowerCase()),
            orElse: () => TaskItem(id: '', title: '', priority: '', status: '', category: '', createdAt: DateTime.now()),
          );
          if (match.id.isNotEmpty) {
            await plannerNotifier.toggleTask(match.id, true);
            result = '🎉 **Completed Task:** "${match.title}" marked as done!';
          } else {
            result = '⚠️ Could not find a task matching "${command.title}".';
          }
          break;

        case TaskCommandType.deleteTask:
          final match = plannerNotifier.state.tasks.firstWhere(
            (t) => t.title.toLowerCase().contains(command.title.toLowerCase()),
            orElse: () => TaskItem(id: '', title: '', priority: '', status: '', category: '', createdAt: DateTime.now()),
          );
          if (match.id.isNotEmpty) {
            await plannerNotifier.deleteTask(match.id);
            result = '🗑️ **Task Deleted:** "${match.title}" removed from your list.';
          } else {
            result = '⚠️ Could not find a task matching "${command.title}".';
          }
          break;
      }

      _removeLoadingMessage();
      _addSystemMessage(result);

      if (_isVoiceEnabled && result.isNotEmpty) {
        await speakText(result);
      }
    } catch (e) {
      _removeLoadingMessage();
      _addSystemMessage('❌ **Failed to update tasks:** $e');
    }
  }

  // ──────────────────── Proactive Check-in & Follow-up Handlers (Stage E) ────────────────────

  Future<void> _handleCheckInCommand(
    String content,
    CheckInCommand command,
    CheckInItem? activeCheckIn,
  ) async {
    _addUserMessage(content);
    _addLoadingMessage('Processing follow-up...');

    try {
      final checkInService = CheckInService();
      String result = '';

      switch (command.type) {
        case CheckInCommandType.createCheckIn:
          final created = await checkInService.createCheckIn(
            title: command.title,
            reason: command.reason,
            targetTime: command.targetTime ?? DateTime.now().add(const Duration(hours: 2)),
            category: command.category,
          );
          final timeStr = '${created.targetTime.hour.toString().padLeft(2, "0")}:${created.targetTime.minute.toString().padLeft(2, "0")}';
          final isTomorrow = created.targetTime.day != DateTime.now().day;
          final dateStr = isTomorrow ? 'Tomorrow' : 'Today';

          result = '🤝 **Agreed Check-In Scheduled!**\n\n'
              '• **Topic:** ${created.reason}\n'
              '• **Scheduled for:** $dateStr at $timeStr\n\n'
              '🔔 *AIRA will follow up with you at this time. You can reply "Done", "Busy", "Ask tomorrow", or "Stop" anytime.*';
          break;

        case CheckInCommandType.respondDone:
          if (activeCheckIn != null) {
            await checkInService.markCompleted(activeCheckIn.id);
            result = '🎉 **Awesome job!**\n\n'
                'Marked your follow-up on **"${activeCheckIn.reason}"** as completed! Any linked tasks have been checked off in your Agenda. Keep crushing it! 💪';
          } else {
            result = '🎉 **Great job!** Progress noted and saved. Keep the momentum going!';
          }
          break;

        case CheckInCommandType.respondBusy:
          if (activeCheckIn != null) {
            await checkInService.snooze(activeCheckIn.id, const Duration(hours: 2));
            result = '⏳ **Snoozed for 2 hours.**\n\n'
                'No stress! I\'ll check back with you on **"${activeCheckIn.reason}"** in 2 hours.';
          } else {
            result = '⏳ **Got it!** Focus on what you\'re doing, I\'ll let you work in peace.';
          }
          break;

        case CheckInCommandType.respondAskTomorrow:
          if (activeCheckIn != null) {
            final now = DateTime.now();
            final tomorrow9am = DateTime(now.year, now.month, now.day + 1, 9, 0);
            await checkInService.snooze(activeCheckIn.id, tomorrow9am.difference(now));
            result = '🌅 **Moved to Tomorrow Morning (9:00 AM).**\n\n'
                'Have a great rest of your day. We will tackle **"${activeCheckIn.reason}"** fresh tomorrow!';
          } else {
            result = '🌅 **Understood!** We\'ll pick this up tomorrow morning.';
          }
          break;

        case CheckInCommandType.respondStop:
          if (activeCheckIn != null) {
            await checkInService.cancel(activeCheckIn.id);
            result = '🛑 **Follow-Up Cancelled.**\n\n'
                'I won\'t check in on **"${activeCheckIn.reason}"** again. Let me know if you want to set a new follow-up anytime!';
          } else {
            result = '🛑 **Cancelled.** I\'ve stopped active follow-ups for now.';
          }
          break;

        case CheckInCommandType.triggerMorningPlanning:
          final tasks = PlannerNotifier.active.state.tasks.where((t) => !t.isCompleted).toList();
          final count = tasks.length;
          final taskListStr = tasks.isEmpty
              ? '✨ *No pending tasks on your agenda! What would you like to accomplish today?*'
              : tasks.take(4).map((t) => '• **${t.title}** *[${t.priority.toUpperCase()}]*').join('\n');

          result = '☀️ **AIRA Morning Kick-Off & Planning**\n\n'
              'Good morning! You have **$count pending tasks** scheduled.\n\n'
              '$taskListStr\n\n'
              '💡 *Say "Add task <name> at <time>" or "Plan my day" to time-block your study sessions.*';
          break;

        case CheckInCommandType.triggerEveningReflection:
          final allTasks = PlannerNotifier.active.state.tasks;
          final completed = allTasks.where((t) => t.isCompleted).toList();
          final pending = allTasks.where((t) => !t.isCompleted).toList();

          result = '🌙 **AIRA Evening Reflection & Day Wrap-Up**\n\n'
              '• **Completed today:** ${completed.length} tasks ✅\n'
              '• **Remaining:** ${pending.length} tasks\n\n'
              '${pending.isNotEmpty ? "Pending tasks can be moved to tomorrow automatically or continued now.\n\n" : "Incredible job clearing your entire agenda today! 🏆\n\n"}'
              '🛌 *Get ready for restful sleep to recharge.*';
          break;

        case CheckInCommandType.listCheckIns:
          final checkIns = await checkInService.getActiveCheckIns();
          if (checkIns.isEmpty) {
            result = '📋 **No active check-ins.**\n\nSay *"Check on me tonight about the project"* to schedule one!';
          } else {
            result = '📋 **Your Active Check-Ins & Follow-Ups:**\n\n';
            for (final c in checkIns) {
              final isTomorrow = c.targetTime.day != DateTime.now().day;
              final dayStr = isTomorrow ? 'Tomorrow' : 'Today';
              final timeStr = '${c.targetTime.hour.toString().padLeft(2, "0")}:${c.targetTime.minute.toString().padLeft(2, "0")}';
              result += '• 🔔 **${c.title}** ($dayStr at $timeStr) — *[${c.status.name}]*\n';
            }
          }
          break;
      }

      _removeLoadingMessage();
      _addSystemMessage(result);

      if (_isVoiceEnabled && result.isNotEmpty) {
        await speakText(result);
      }
    } catch (e) {
      _removeLoadingMessage();
      _addSystemMessage('❌ **Failed to process check-in:** $e');
    }
  }

  // ──────────────────── Laptop Control Handlers (Milestone 3) ────────────────────

  Future<void> _handleLaptopCommand(String content, LaptopCommand command) async {
    _addUserMessage(content);
    _addLoadingMessage('Sending command to laptop...');

    await _laptopService.loadConfig();
    if (!_laptopService.isConfigured) {
      _removeLoadingMessage();
      _addSystemMessage(
        '⚠️ **Laptop not configured yet.**\n\n'
        'Please go to **Drawer ☰ → Laptop Remote** to enter your laptop\'s Wi-Fi IP address and PIN.',
      );
      return;
    }

    try {
      Map<String, dynamic>? result;
      String? base64Image;

      switch (command.type) {
        case LaptopCommandType.agentTask:
          result = await _laptopService.executeAgentTask(command.argument ?? content);
          break;
        case LaptopCommandType.screenshot:
          final bytes = await _laptopService.captureScreenshot();
          if (bytes != null) {
            base64Image = base64Encode(bytes);
            result = {'success': true};
          }
          break;
        case LaptopCommandType.lock:
          await _laptopService.lockScreen();
          result = {'success': true};
          break;
        case LaptopCommandType.sleep:
          await _laptopService.sleepLaptop();
          result = {'success': true};
          break;
        case LaptopCommandType.shutdown:
          await _laptopService.shutdownLaptop();
          result = {'success': true};
          break;
        case LaptopCommandType.restart:
          await _laptopService.restartLaptop();
          result = {'success': true};
          break;
        case LaptopCommandType.mute:
          await _laptopService.muteVolume();
          result = {'success': true};
          break;
        case LaptopCommandType.volumeUp:
          await _laptopService.volumeUp();
          result = {'success': true};
          break;
        case LaptopCommandType.volumeDown:
          await _laptopService.volumeDown();
          result = {'success': true};
          break;
        case LaptopCommandType.openApp:
          result = await _laptopService.openApp(command.argument ?? '');
          break;
        case LaptopCommandType.closeApp:
          result = await _laptopService.closeApp(command.argument ?? '');
          break;
        case LaptopCommandType.type:
          await _laptopService.typeText(command.argument ?? '');
          result = {'success': true};
          break;
        case LaptopCommandType.terminal:
          result = await _laptopService.runCommand(command.argument ?? '');
          break;
        case LaptopCommandType.systemStats:
          result = await _laptopService.getSystemStats();
          break;
        case LaptopCommandType.organizeDownloads:
          result = await _laptopService.organizeDownloads();
          break;
        case LaptopCommandType.saveNote:
          result = await _laptopService.saveQuickNote('AIRA_Note_${DateTime.now().millisecondsSinceEpoch}', command.argument ?? '');
          break;
        case LaptopCommandType.webSearch:
          result = await _laptopService.autoWebSearch(command.argument ?? '');
          break;
        case LaptopCommandType.cancelShutdown:
          await _laptopService.cancelShutdown();
          result = {'success': true};
          break;
        case LaptopCommandType.setBrightness:
          final arg = command.argument ?? '70';
          if (arg == 'up') {
            result = await _laptopService.runCommand('powershell -Command "(Get-WmiObject -Namespace root/wmi -Class WmiMonitorBrightnessMethods).WmiSetBrightness(1, [math]::min(100, (Get-WmiObject -Namespace root/wmi -Class WmiMonitorBrightness).CurrentBrightness + 20))"');
          } else if (arg == 'down') {
            result = await _laptopService.runCommand('powershell -Command "(Get-WmiObject -Namespace root/wmi -Class WmiMonitorBrightnessMethods).WmiSetBrightness(1, [math]::max(0, (Get-WmiObject -Namespace root/wmi -Class WmiMonitorBrightness).CurrentBrightness - 20))"');
          } else {
            await _laptopService.setBrightness(int.tryParse(arg) ?? 70);
            result = {'success': true};
          }
          break;
        case LaptopCommandType.setVolume:
          await _laptopService.setVolume(int.tryParse(command.argument ?? '50') ?? 50);
          result = {'success': true};
          break;
        case LaptopCommandType.paste:
          await _laptopService.sendHotkey(['ctrl', 'v']);
          result = {'success': true};
          break;
        case LaptopCommandType.copy:
          await _laptopService.sendHotkey(['ctrl', 'c']);
          result = {'success': true};
          break;
        case LaptopCommandType.minimizeWindow:
          await _laptopService.sendHotkey(['super', 'down']);
          result = {'success': true};
          break;
        case LaptopCommandType.maximizeWindow:
          await _laptopService.sendHotkey(['super', 'up']);
          result = {'success': true};
          break;
        case LaptopCommandType.closeWindow:
          await _laptopService.sendHotkey(['alt', 'f4']);
          result = {'success': true};
          break;
        case LaptopCommandType.scrollDown:
          await _laptopService.scrollMouse(-5);
          result = {'success': true};
          break;
        case LaptopCommandType.scrollUp:
          await _laptopService.scrollMouse(5);
          result = {'success': true};
          break;
      }

      _removeLoadingMessage();
      final responseText = LaptopIntentDetector.getResponse(command, result);

      if (base64Image != null) {
        final assistantMsg = ChatMessage(
          id: _uuid.v4(),
          conversationId: state.activeConversationId ?? 'local',
          role: 'assistant',
          content: responseText,
          createdAt: DateTime.now(),
          base64Image: base64Image,
        );
        state = state.copyWith(messages: [...state.messages, assistantMsg]);
      } else {
        _addSystemMessage(responseText);
      }

      if (_isVoiceEnabled) {
        await speakText(responseText);
      }
    } catch (e) {
      _removeLoadingMessage();
      _addSystemMessage('❌ **Failed to execute laptop command:** $e');
    }
  }

  // ──────────────────── Device Control Handlers (Milestone 4) ────────────────────

  Future<void> _handleDeviceCommand(String content, DeviceCommand command) async {
    _addUserMessage(content);
    _addLoadingMessage('Processing device action...');

    try {
      String result = '';

      switch (command.intent) {
        case DeviceIntent.toggleFlashlight:
          final enable = command.params['enable'] as bool? ?? true;
          await _deviceService.toggleFlashlight(enable: enable);
          result = enable
              ? '🔦 **Flashlight Turned ON**\n\n> Android LED torch is active.'
              : '🔦 **Flashlight Turned OFF**\n\n> Android LED torch disabled.';
          break;

        case DeviceIntent.launchApp:
          final appName = command.params['appName'] as String? ?? 'App';
          final res = await _deviceService.launchApp(appName: appName);
          final launchedLabel = res['appName'] ?? appName;
          final pkg = res['packageName'] != null ? ' (`${res['packageName']}`)' : '';
          result = '🚀 **Opening $launchedLabel...**$pkg\n\n> Launching app via Android OS.';
          break;

        case DeviceIntent.searchInApp:
          final appName = command.params['appName'] as String? ?? 'YouTube';
          final searchQuery = command.params['query'] as String? ?? '';
          await _deviceService.searchInApp(appName: appName, searchQuery: searchQuery);
          final capitalApp = appName.substring(0, 1).toUpperCase() + appName.substring(1);
          result = '🔍 **Opening $capitalApp...**\n\n> Searching for: "$searchQuery"';
          break;

        case DeviceIntent.openSettings:
          final type = command.params['settingType'] as String? ?? 'default';
          await _deviceService.openSettings(settingType: type);
          result = '⚙️ **Opening ${type.toUpperCase()} Settings...**\n\n> Launching Android System Settings.';
          break;

        case DeviceIntent.getBatteryStatus:
          final bat = await _deviceService.getBatteryStatus();
          final level = bat['level'] ?? 0;
          final isCharging = bat['isCharging'] == true;
          final statusStr = isCharging ? '⚡ Charging' : '🔋 Discharging';
          result = '🔋 **Battery Status:**\n\n- **Level:** $level%\n- **Status:** $statusStr';
          break;

        case DeviceIntent.setAlarm:
          final hour = command.params['hour'] as int? ?? 7;
          final minute = command.params['minute'] as int? ?? 0;
          final msg = command.params['message'] as String? ?? 'AIRA Alarm';
          await _deviceService.setAlarm(hour: hour, minute: minute, message: msg);
          final timeFormatted = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
          result = '⏰ **Setting Alarm for $timeFormatted...**\n\n- **Label:** "$msg"\n\n> Launching Android Alarm Clock.';
          break;

        case DeviceIntent.setTimer:
          final seconds = command.params['seconds'] as int? ?? 60;
          final msg = command.params['message'] as String? ?? 'AIRA Timer';
          await _deviceService.setTimer(seconds: seconds, message: msg);
          final hrs = seconds ~/ 3600;
          final mins = (seconds % 3600) ~/ 60;
          final secs = seconds % 60;
          final parts = <String>[];
          if (hrs > 0) parts.add('$hrs hour${hrs == 1 ? '' : 's'}');
          if (mins > 0) parts.add('$mins minute${mins == 1 ? '' : 's'}');
          if (secs > 0 && hrs == 0) parts.add('$secs second${secs == 1 ? '' : 's'}');
          final timeStr = parts.join(' ');
          result = '⏱️ **Setting Timer for $timeStr...**\n\n- **Label:** "$msg"\n\n> Launching Android Clock Timer.';
          break;

        case DeviceIntent.adjustVolume:
          final direction = command.params['direction'] as String? ?? 'up';
          final stream = command.params['stream'] as String? ?? 'media';
          final volRes = await _deviceService.adjustVolume(direction: direction, stream: stream);
          final curVol = volRes['currentVolume'] ?? '?';
          final maxVol = volRes['maxVolume'] ?? '?';
          final dirLabel = {'up': '🔊 Volume Up', 'down': '🔉 Volume Down', 'mute': '🔇 Muted', 'unmute': '🔊 Unmuted', 'max': '🔊 Max Volume', 'min': '🔇 Min Volume'}[direction] ?? '🔊 Volume Changed';
          result = '$dirLabel\n\n- **Stream:** ${stream.toUpperCase()}\n- **Level:** $curVol / $maxVol';
          break;

        case DeviceIntent.controlMedia:
          final action = command.params['action'] as String? ?? 'play_pause';
          await _deviceService.controlMedia(action: action);
          final actionLabel = {'play_pause': '⏯️ Play/Pause toggled', 'play': '▶️ Resuming playback', 'pause': '⏸️ Playback paused', 'next': '⏭️ Skipped to next track', 'previous': '⏮️ Went to previous track', 'stop': '⏹️ Playback stopped'}[action] ?? '🎵 Media command sent';
          result = '$actionLabel\n\n> Media key dispatched to Android AudioManager.';
          break;

        case DeviceIntent.copyToClipboard:
          final text = command.params['text'] as String? ?? '';
          if (text.isEmpty) {
            result = '📋 What text should I copy to clipboard? Say:\n> *"Copy this to clipboard: [your text]"*';
          } else {
            await _deviceService.copyToClipboard(text: text);
            result = '📋 **Copied to Clipboard!**\n\n> "$text"';
          }
          break;

        case DeviceIntent.getDeviceInfo:
          final info = await _deviceService.getDeviceInfo();
          final manufacturer = info['manufacturer'] ?? 'Unknown';
          final model = info['model'] ?? 'Unknown';
          final version = info['androidVersion'] ?? 'Unknown';
          final sdk = info['sdkVersion'] ?? '?';
          final battery = info['batteryLevel'] ?? '?';
          final charging = info['isCharging'] == true ? '⚡ Charging' : '🔋 Discharging';
          final totalGB = info['totalStorageGB'] ?? '?';
          final availMB = info['availStorageMB'] ?? '?';
          result = '📱 **Device Information**\n\n'
              '- **Model:** $manufacturer $model\n'
              '- **Android:** $version (SDK $sdk)\n'
              '- **Battery:** $battery% — $charging\n'
              '- **Storage:** ${totalGB}GB total · ${availMB}MB available';
          break;

        default:
          result = '📱 Device command executed.';
      }

      _removeLoadingMessage();
      _addSystemMessage(result);

      if (_isVoiceEnabled && result.isNotEmpty) {
        await speakText(result);
      }
    } catch (e) {
      _removeLoadingMessage();
      final cleanErr = e.toString().replaceAll('Exception: ', '');
      _addSystemMessage('❌ **Device Control Action Failed**\n\n$cleanErr');
    }
  }

  // ──────────────────── Smart Routine Handlers (Milestone 6 - Feature 3) ────────────────────

  Future<void> _handleRoutineCommand(String content, RoutineCommand command) async {
    _addUserMessage(content);
    _addLoadingMessage('Executing ${command.name} automation...');

    try {
      final res = await _routineService.executeRoutine(command.type);

      _removeLoadingMessage();
      _addSystemMessage(res.summaryMarkdown);

      if (_isVoiceEnabled && res.spokenText.isNotEmpty) {
        await speakText(res.spokenText);
      }
    } catch (e) {
      _removeLoadingMessage();
      _addSystemMessage('❌ **Routine Execution Failed:** ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  // ──────────────────── Notification & Reminder Handlers (Milestone 6 - Feature 2) ────────────────────

  Future<void> _handleNotificationCommand(String content, NotificationCommand command) async {
    _addUserMessage(content);

    try {
      String result = '';
      final notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      switch (command.intent) {
        case NotificationIntentType.scheduleReminder:
          if (command.scheduledDate != null) {
            final date = command.scheduledDate!;
            final hourStr = (date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour)).toString().padLeft(2, '0');
            final minStr = date.minute.toString().padLeft(2, '0');
            final ampm = date.hour >= 12 ? 'PM' : 'AM';
            final dayStr = date.day.toString().padLeft(2, '0');
            final monthStr = date.month.toString().padLeft(2, '0');
            final yearStr = date.year.toString();

            final formattedDate = '$dayStr/$monthStr/$yearStr at $hourStr:$minStr $ampm';

            await _notificationService.scheduleNotification(
              id: notifId,
              title: command.title,
              body: command.body,
              scheduledDate: date,
            );

            result = '🔔 **Exact Reminder Scheduled!**\n\n'
                '- **Topic:** "${command.body}"\n'
                '- **Exact Target Time:** $formattedDate\n'
                '- **Alarm Mode:** ExactAllowWhileIdle (Doze-Proof) ✓\n'
                '- **Cloud Sync:** Supabase Backup Saved ✓\n\n'
                '> AIRA will deliver a high-priority alarm notification at the exact minute, even if your phone is in deep sleep at 2 AM.';
          } else {
            result = 'Please specify a time for your reminder (e.g., *"remind me at 2 AM to check logs"*).';
          }
          break;

        case NotificationIntentType.scheduleDailyAlert:
          final h = command.hour ?? 7;
          final m = command.minute ?? 0;
          await _notificationService.scheduleDailyNotification(
            id: notifId,
            title: command.title,
            body: 'Daily AIRA alert: Top news & agenda ready!',
            hour: h,
            minute: m,
          );

          final timeStr = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
          result = '🌅 **Daily Alert Scheduled!**\n\n'
              '- **Time:** Every day at $timeStr\n'
              '- **Action:** AIRA will deliver your top news and daily agenda.\n\n'
              '> Recurring daily background task initialized.';
          break;

        case NotificationIntentType.cancelAllReminders:
          await _notificationService.cancelAll();
          result = '🗑️ **All Pending Reminders Cancelled**';
          break;

        case NotificationIntentType.listReminders:
          final pending = await _notificationService.getPendingNotifications();
          if (pending.isEmpty) {
            result = '🔔 **No Active Reminders**\n\nSay *"remind me at 9 AM to call Rahul"* to set one.';
          } else {
            result = '📋 **Active Scheduled Reminders (${pending.length}):**\n\n';
            for (final p in pending) {
              result += '- **[${p.title}]** ${p.body}\n';
            }
          }
          break;

        default:
          result = 'Notification command executed.';
      }

      _addSystemMessage(result);

      if (_isVoiceEnabled && result.isNotEmpty) {
        await speakText(result);
      }
    } catch (e) {
      _addSystemMessage('❌ **Failed to schedule notification:** ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  // ──────────────────── Phone & SMS Handlers (Milestone 3) ────────────────────

  Future<void> _handlePhoneCommand(String content, PhoneCommand command) async {
    _addUserMessage(content);
    _addLoadingMessage('Processing phone action...');

    try {
      String result = '';

      switch (command.intent) {
        case PhoneIntent.makeCall:
          final recipient = command.params['recipient'] as String? ?? 'Contact';
          final res = await _phoneService.makePhoneCall(recipient: recipient);
          final name = res['name'] ?? recipient;
          final phone = res['phone'] ?? '';
          final source = (res['source'] != null && res['source'] != '' && res['source'] != 'none' && res['source'] != 'direct')
              ? ' *(Source: ${res['source']})*'
              : '';

          result = 'Placing Phone Call...$source\n\n**Contact:** $name\n**Number:** `$phone`';
          break;

        case PhoneIntent.sendSms:
          final recipient = command.params['recipient'] as String? ?? 'Contact';
          final body = command.params['body'] as String? ?? '';
          final res = await _phoneService.sendSms(recipient: recipient, body: body);
          final name = res['name'] ?? recipient;
          final phone = res['phone'] ?? '';
          final smsBody = res['body'] ?? body;
          final source = (res['source'] != null && res['source'] != '' && res['source'] != 'none' && res['source'] != 'direct')
              ? ' *(Source: ${res['source']})*'
              : '';

          result = 'Preparing SMS Message...$source\n\n**To:** $name (`$phone`)\n**Message:** "$smsBody"';
          break;

        default:
          result = 'Phone command executed.';
      }

      _removeLoadingMessage();
      _addSystemMessage(result);

      if (_isVoiceEnabled && result.isNotEmpty) {
        await speakText(result);
      }
    } catch (e) {
      _removeLoadingMessage();
      final cleanErr = e.toString().replaceAll('Exception: ', '');
      _addSystemMessage('Phone Action Failed\n\n$cleanErr');
    }
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
          result = 'Memory Saved!\n\n> I will remember: *"${command.content}"*\n\nThis is now part of my long-term memory across all your chats!';
          break;

        case MemoryIntent.listMemories:
          final memories = await _memoryService.listMemories();
          if (memories.isEmpty) {
            result = 'No saved memories yet.\n\nTell me things like:\n- *"Remember that Rahul\'s email is rahul@gmail.com"*\n- *"Remember that I prefer bullet points"*';
          } else {
            result = 'What I Remember About You:\n\n';
            for (int i = 0; i < memories.length; i++) {
              result += '${i + 1}. ${memories[i]['content']}\n';
            }
            result += '\n*Say "clear all memories" to wipe memory.*';
          }
          break;

        case MemoryIntent.clearMemories:
          await _memoryService.clearAllMemories();
          result = 'All memories cleared successfully.';
          break;

        default:
          result = 'Memory action completed.';
      }

      _addSystemMessage(result);

      if (_isVoiceEnabled && result.isNotEmpty) {
        await speakText(result);
      }
    } catch (e) {
      _addSystemMessage('Failed to update memory: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  // ──────────────────── Workspace Handlers ────────────────────

  Future<void> _handleWorkspaceCommand(String content, WorkspaceCommand command) async {
    _addUserMessage(content);

    if (!_workspace.isConnected) {
      _addSystemMessage(
        'Google Workspace is not connected.\n\nTo use Drive, Gmail, Calendar, Docs, and Sheets, say **"connect Google Workspace"** first.',
      );
      return;
    }

    _addLoadingMessage('Consulting Google Workspace...');

    try {
      String result = '';
      PendingApprovalAction? pendingAction;
      Map<String, dynamic>? calendarData;
      List<Map<String, dynamic>>? emailsData;
      Map<String, dynamic>? eventPreview;

      switch (command.intent) {
        // ── Stage G: Calendar Agenda ──
        case WorkspaceIntent.todayAgenda:
          final agenda = await _workspace.getTodayAgenda();
          if (agenda.isEmpty) {
            result = 'You have a clear schedule today! No meetings are on your Google Calendar.';
          } else {
            result = 'Here is your Google Calendar agenda for today with ${agenda.length} scheduled event(s):';
            calendarData = {
              'type': 'agenda',
              'title': "Today's Agenda",
              'events': agenda,
            };
          }
          break;

        // ── Stage G: Next Meeting ──
        case WorkspaceIntent.nextMeeting:
          final next = await _workspace.getNextMeeting();
          if (next == null) {
            result = 'You have no more upcoming meetings scheduled for today.';
          } else {
            final startStr = _formatTimeString(next['start']);
            result = 'Your next upcoming meeting is **${next['title']}** at $startStr.';
            calendarData = {
              'type': 'nextMeeting',
              'title': 'Next Upcoming Meeting',
              'events': [next],
            };
          }
          break;

        // ── Stage G: Free Time Slots ──
        case WorkspaceIntent.freeTimeSlots:
          final slots = await _workspace.findFreeTimeSlots();
          if (slots.isEmpty) {
            result = 'Your calendar is fully booked today without any 30+ minute open gaps between 9 AM and 6 PM.';
          } else {
            result = 'Here are your available free-time focus windows today:';
            calendarData = {
              'type': 'freeTime',
              'title': 'Available Free-Time Slots',
              'freeSlots': slots,
            };
          }
          break;

        // ── Stage G: Meeting Preparation ──
        case WorkspaceIntent.meetingPrep:
          final next = await _workspace.getNextMeeting();
          if (next == null) {
            result = 'You have no upcoming meetings to prepare for today.';
          } else {
            result = _workspace.generateMeetingPrep(next);
          }
          break;

        // ── Stage G: Gmail Unread Digest ──
        case WorkspaceIntent.unreadDigest:
          final unread = await _workspace.getUnreadEmailsDigest(maxResults: 5);
          if (unread.isEmpty) {
            result = 'Your Gmail inbox is completely caught up! No unread messages.';
          } else {
            result = 'Here are your recent unread emails. Tap **"Draft Reply"** on any email to prepare a safe response:';
            emailsData = unread;
          }
          break;

        // ── Stage G: Calendar Create Event Preview (Human-in-the-Loop) ──
        case WorkspaceIntent.createEvent:
          final title = command.params['title'] as String? ?? 'New Event';
          final dateParam = command.params['date'] as String? ?? 'tomorrow';
          final timeParam = command.params['time'] as String? ?? '10:00 AM';

          final now = DateTime.now();
          final eventDate = _parseDateParam(dateParam, now);
          final startDateTime = _parseTimeParam(timeParam, eventDate);
          final endDateTime = startDateTime.add(const Duration(hours: 1));

          eventPreview = {
            'title': title,
            'date': '${eventDate.day}/${eventDate.month}/${eventDate.year}',
            'startTime': _formatTimeClock(startDateTime),
            'endTime': _formatTimeClock(endDateTime),
            'timezone': 'Asia/Kolkata (IST)',
            'attendees': <String>[],
            'description': 'Scheduled via AIRA Assistant',
            'startIso': startDateTime.toIso8601String(),
            'endIso': endDateTime.toIso8601String(),
          };

          result = 'I have prepared this event proposal for you. **Please review the details below and tap confirm to add it to your Google Calendar:**';
          break;

        // ── Stage G: Gmail Draft & Review-Before-Send (Human-in-the-Loop) ──
        case WorkspaceIntent.sendEmail:
        case WorkspaceIntent.draftEmail:
          String to = command.params['to'] as String? ?? '';
          final rawSubject = command.params['subject'] as String? ?? '';
          final rawBody = command.params['body'] as String? ?? '';
          String lookupNote = '';

          if (to.isNotEmpty && !to.contains('@')) {
            try {
              final contactMatch = await _workspace.searchGoogleContactEmail(to);
              if (contactMatch != null && contactMatch['email'] != null) {
                final cName = contactMatch['name'] ?? to;
                final cEmail = contactMatch['email']!;
                lookupNote = '*(Contact found: $cName <$cEmail>)* ';
                to = cEmail;
              }
            } catch (_) {}

            if (!to.contains('@')) {
              final memoryEmail = await _memoryService.findEmailForName(to);
              if (memoryEmail != null) {
                lookupNote = '*(Email retrieved from AI Memory)* ';
                to = memoryEmail;
              }
            }
          }

          if (to.isEmpty || !to.contains('@')) {
            result = 'Who should I draft the email to? Please specify a contact name or email address like:\n> *"draft email to Rahul asking about tomorrow\'s meeting"*';
          } else {
            String emailBody = rawBody.trim();
            if (emailBody.isEmpty ||
                emailBody == content.trim() ||
                emailBody.toLowerCase().startsWith('send mail') ||
                emailBody.toLowerCase().startsWith('send email') ||
                emailBody.toLowerCase().startsWith('draft email') ||
                emailBody.toLowerCase().startsWith('draft a mail')) {
              try {
                emailBody = await _groq.chat(
                  'Write a polite, concise, professional email body based on this user instruction: "$content". Do NOT include Subject lines, To lines, greetings placeholders, or bracketed blanks. Output only the email body text ready to send.',
                  [],
                );
              } catch (_) {
                emailBody = rawSubject.isNotEmpty
                    ? 'Hi,\n\nI am writing to inquire regarding $rawSubject.\n\nPlease let me know your thoughts.\n\nBest regards,\nArsha'
                    : 'Hi,\n\nHope you are having a productive day.\n\nBest regards,\nArsha';
              }
            }

            final emailSubject = rawSubject.isNotEmpty
                ? rawSubject
                : 'Follow up regarding ${content.length > 25 ? content.substring(0, 25) : content}';

            pendingAction = PendingApprovalAction(
              id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
              actionType: 'email',
              recipient: to,
              subject: emailSubject,
              content: emailBody,
              status: ApprovalStatus.pending,
            );

            result = '$lookupNote I have prepared your email draft. **AIRA requires your explicit review and approval before sending.** Please review the details below:';
          }
          break;

        case WorkspaceIntent.readEmails:
          final emails = await _workspace.listEmails();
          if (emails.isEmpty) {
            result = 'No emails found in your inbox.';
          } else {
            result = 'Your recent emails:\n\n';
            for (final e in emails) {
              result += '**${e['subject']}**\nFrom: ${e['from']}\n${e['snippet']}\n\n';
            }
          }
          break;

        case WorkspaceIntent.listEvents:
          final events = await _workspace.listEvents();
          if (events.isEmpty) {
            result = 'No upcoming events found.';
          } else {
            result = 'Your upcoming events:\n\n';
            for (final e in events) {
              final start = e['start'].toString().isNotEmpty ? e['start'] : 'No time set';
              result += '**${e['title']}**\nTime: $start\n${e['location'] != '' ? 'Location: ${e['location']}\n' : ''}\n';
            }
          }
          break;

        case WorkspaceIntent.listDriveFiles:
          final files = await _workspace.listRecentDriveFiles();
          if (files.isEmpty) {
            result = 'No files found in your Google Drive.';
          } else {
            result = 'Your Recent Google Drive Files:\n\n';
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
            result = 'No files or folders found matching **"$query"** in Google Drive.';
          } else {
            result = 'Google Drive Search Results for "$query":\n\n';
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
          result = 'File Uploaded to Google Drive!\n\n**${res['name']}**\n[Open File in Drive](${res['link']})';
          break;

        case WorkspaceIntent.createDoc:
          final title = command.params['title'] as String? ?? 'New Document';
          final doc = await _workspace.createDoc(title: title);
          result = 'Google Doc created!\n\n**${doc['title']}**\n[Open Doc](${doc['link']})';
          break;

        case WorkspaceIntent.createSheet:
          final title = command.params['title'] as String? ?? 'New Spreadsheet';
          final sheet = await _workspace.createSheet(title: title);
          result = 'Google Sheet Created!\n\n**${sheet['title']}**\n[Open Spreadsheet](${sheet['link']})';
          break;

        case WorkspaceIntent.appendSheetRow:
          final target = command.params['sheetTarget'] as String? ?? '';
          final values = (command.params['values'] as List?)?.cast<String>() ?? [];

          if (values.isEmpty) {
            result = 'What values should I add to **$target**? Please provide comma-separated values like:\n> *"add row to $target: Item Name, 100, Completed"*';
          } else {
            final res = await _workspace.appendSheetRow(sheetTarget: target, values: values);
            result = 'Row added to Google Sheet!\n\n**Sheet:** $target\n**Values Added:** ${values.join(" | ")}\n\n[Open Spreadsheet](${res['link']})';
          }
          break;

        case WorkspaceIntent.readSheet:
        case WorkspaceIntent.openSheet:
          final target = command.params['sheetTarget'] as String? ?? '';
          if (target.isEmpty) {
            result = 'Which sheet would you like to view? Say *"show sheet [title]"*';
          } else {
            final res = await _workspace.readSheetData(sheetTarget: target);
            final rows = res['rows'] as List<List<String>>;
            if (rows.isEmpty) {
              result = 'Google Sheet ($target) is empty.\n\n[Open Spreadsheet](${res['link']})';
            } else {
              result = 'Google Sheet ($target):\n\n';
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
          result = 'I understood this as a Google Workspace command but I am not sure how to handle it yet.';
      }

      _removeLoadingMessage();
      _addSystemMessage(
        result,
        pendingApproval: pendingAction,
        workspaceCalendarData: calendarData,
        workspaceEmails: emailsData,
        workspaceEventPreview: eventPreview,
      );

      if (_isVoiceEnabled && result.isNotEmpty) {
        await speakText(result);
      }
    } catch (e) {
      _removeLoadingMessage();
      final cleanErr = e.toString().replaceAll('Exception: ', '');
      _addSystemMessage('Workspace Action Failed\n\n$cleanErr');
    }
  }

  /// Approve and send an email draft via Gmail API (Human-in-the-Loop)
  Future<void> approveWorkspaceDraft(PendingApprovalAction action, {String? editedContent}) async {
    final finalContent = editedContent ?? action.content;
    try {
      await _workspace.sendEmail(
        to: action.recipient,
        subject: action.subject,
        body: finalContent,
      );
      _addSystemMessage(
        '✅ **Email Sent via Gmail!**\n\n**To:** ${action.recipient}\n**Subject:** ${action.subject}\n\n> ${finalContent.replaceAll('\n', '\n> ')}',
      );
      if (_isVoiceEnabled) {
        await speakText('Your email to ${action.recipient} has been sent successfully.');
      }
    } catch (e) {
      final cleanErr = e.toString().replaceAll('Exception: ', '');
      _addSystemMessage('❌ **Failed to send email via Gmail:** $cleanErr');
    }
  }

  /// Reject and cancel an email draft
  void rejectWorkspaceDraft(PendingApprovalAction action) {
    _addSystemMessage('🚫 Email draft to **${action.recipient}** was cancelled.');
  }

  /// Confirm and add a calendar event to Google Calendar
  Future<void> confirmCreateEvent(Map<String, dynamic> preview) async {
    try {
      final title = preview['title'] as String? ?? 'New Event';
      final start = DateTime.tryParse(preview['startIso'] ?? '') ?? DateTime.now().add(const Duration(days: 1));
      final end = DateTime.tryParse(preview['endIso'] ?? '') ?? start.add(const Duration(hours: 1));
      final desc = preview['description'] as String?;

      final event = await _workspace.createEvent(
        title: title,
        start: start,
        end: end,
        description: desc,
      );

      final link = event['link'] ?? '';
      _addSystemMessage(
        '✅ **Calendar Event Confirmed!**\n\n**${event['title']}** has been added to your Google Calendar.\n${link.isNotEmpty ? '[Open in Calendar]($link)' : ''}',
      );
      if (_isVoiceEnabled) {
        await speakText('Event $title has been added to your Google Calendar.');
      }
    } catch (e) {
      final cleanErr = e.toString().replaceAll('Exception: ', '');
      _addSystemMessage('❌ **Failed to create calendar event:** $cleanErr');
    }
  }

  /// Cancel calendar event proposal
  void cancelCreateEvent(Map<String, dynamic> preview) {
    _addSystemMessage('🚫 Event proposal for **${preview['title']}** was cancelled.');
  }

  /// Draft a reply to an incoming email
  Future<void> draftEmailReply(Map<String, dynamic> email) async {
    final sender = email['from'] as String? ?? '';
    final subject = email['subject'] as String? ?? '';
    final snippet = email['snippet'] as String? ?? '';

    String recipient = sender;
    if (sender.contains('<') && sender.contains('>')) {
      final match = RegExp(r'<([^>]+)>').firstMatch(sender);
      if (match != null) recipient = match.group(1)!;
    }

    final replySubject = subject.toLowerCase().startsWith('re:') ? subject : 'Re: $subject';

    _addLoadingMessage('Formulating polite response draft...');

    try {
      final safeSnippet = GoogleWorkspaceService.sanitizeUntrustedContent(snippet);
      final draftBody = await _groq.chat(
        'Write a polite, professional, concise reply to this email snippet: $safeSnippet. Do NOT include Subject lines, To lines, or placeholder brackets. Write only the reply body ready to send.',
        [],
      );

      _removeLoadingMessage();

      final pendingAction = PendingApprovalAction(
        id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
        actionType: 'email',
        recipient: recipient,
        subject: replySubject,
        content: draftBody,
        status: ApprovalStatus.pending,
      );

      _addSystemMessage(
        'I have drafted a response to **$sender**. **Please review and approve before sending:**',
        pendingApproval: pendingAction,
      );
    } catch (e) {
      _removeLoadingMessage();
      _addSystemMessage('❌ Could not generate draft reply: $e');
    }
  }

  static DateTime _parseDateParam(String dateStr, DateTime fallback) {
    final d = dateStr.toLowerCase().trim();
    if (d.contains('tomorrow')) return fallback.add(const Duration(days: 1));
    if (d.contains('today')) return fallback;
    final daysOfWeek = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    for (int i = 0; i < daysOfWeek.length; i++) {
      if (d.contains(daysOfWeek[i])) {
        final targetWeekday = i + 1;
        var diff = targetWeekday - fallback.weekday;
        if (diff <= 0) diff += 7;
        return fallback.add(Duration(days: diff));
      }
    }
    return fallback.add(const Duration(days: 1));
  }

  static DateTime _parseTimeParam(String timeStr, DateTime baseDate) {
    final t = timeStr.toLowerCase().replaceAll(' ', '');
    final isPm = t.contains('pm');
    final digits = RegExp(r'(\d{1,2})(?::(\d{2}))?').firstMatch(t);
    if (digits != null) {
      var hour = int.tryParse(digits.group(1) ?? '10') ?? 10;
      final min = int.tryParse(digits.group(2) ?? '0') ?? 0;
      if (isPm && hour < 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, min);
    }
    return DateTime(baseDate.year, baseDate.month, baseDate.day, 10, 0);
  }

  static String _formatTimeClock(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $period';
  }

  static String _formatTimeString(dynamic dtVal) {
    if (dtVal == null) return '';
    final dt = DateTime.tryParse(dtVal.toString());
    if (dt == null) return dtVal.toString();
    return _formatTimeClock(dt);
  }

  // ──────────────────── AI Chat ────────────────────

  Future<void> _sendToAI(String content, {String? base64Image}) async {
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

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      conversationId: convId ?? 'local',
      role: 'user',
      content: content.trim().isEmpty ? 'Shared an image.' : content.trim(),
      createdAt: DateTime.now(),
      base64Image: base64Image,
    );

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

      final memoryContext = await _memoryService.getMemoriesPromptContext();

      // ── Live Web Search Trigger (Live Web Search Agent) ──
      String? webSearchContext;
      final webSearch = WebSearchService();
      if (webSearch.shouldSearchWeb(content)) {
        try {
          webSearchContext = await webSearch.search(content);
        } catch (_) {}
      }

      // Inject relevant memory facts from MemoryEngine
      final memoryEngine = MemoryEngine();
      final relevantFacts = memoryEngine.getRelevantFacts(content, limit: 5);

      final combinedContext = [
        if (memoryContext.isNotEmpty) memoryContext,
        if (webSearchContext != null && webSearchContext.isNotEmpty) webSearchContext,
        if (relevantFacts.isNotEmpty) '\n<local_memory>\n${relevantFacts.map((f) => '- $f').join('\n')}\n</local_memory>',
      ].join('\n\n');

      final response = await _groq.chat(
        content.trim().isEmpty ? 'Describe this image.' : content.trim(),
        history,
        base64Image: base64Image,
        memoryContext: combinedContext.isNotEmpty ? combinedContext : null,
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

      if (convId != null) {
        try {
          await _supabase.saveMessage(conversationId: convId, role: 'assistant', content: response);
        } catch (_) {}
      }

      if (_isVoiceEnabled) {
        await speakText(response);
      }

      // ── Background Fact Extraction (learn about user) ──
      // Every 5 messages, extract durable facts from the conversation
      final userMessages = state.messages.where((m) => m.role == 'user').toList();
      if (userMessages.length % 5 == 0 && userMessages.isNotEmpty) {
        // Run fact extraction asynchronously (don't await — non-blocking)
        final recentTurns = state.messages
            .where((m) => !m.isStreaming)
            .toList()
            .reversed
            .take(10)
            .toList()
            .reversed
            .map((m) => {'role': m.role, 'content': m.content})
            .toList();
        FactExtractor().extractFromConversation(recentTurns);
      }
    } catch (e) {
      final updatedMessages = state.messages.where((m) => m.id != typingMsg.id).toList();
      // Show a short, friendly error — not the raw DioException stack
      String friendlyError = 'Could not reach AI. Please check your internet connection.';
      final raw = e.toString();
      if (raw.contains('401') || raw.contains('API key') || raw.contains('Unauthorized')) {
        friendlyError = 'AI service authentication failed. Please check your API key.';
      } else if (raw.contains('timeout') || raw.contains('SocketException') || raw.contains('connection')) {
        friendlyError = 'No internet connection. Please try again.';
      } else if (raw.contains('503') || raw.contains('502') || raw.contains('unavailable')) {
        friendlyError = 'AI service is temporarily busy. Please try again in a moment.';
      }
      state = state.copyWith(
        messages: updatedMessages,
        isSending: false,
        error: friendlyError,
      );
    }
  }

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

  void _addSystemMessage(
    String content, {
    PendingApprovalAction? pendingApproval,
    Map<String, dynamic>? workspaceCalendarData,
    List<Map<String, dynamic>>? workspaceEmails,
    Map<String, dynamic>? workspaceEventPreview,
  }) {
    final msg = ChatMessage(
      id: _uuid.v4(),
      conversationId: state.activeConversationId ?? 'local',
      role: 'assistant',
      content: content,
      createdAt: DateTime.now(),
      pendingApproval: pendingApproval,
      workspaceCalendarData: workspaceCalendarData,
      workspaceEmails: workspaceEmails,
      workspaceEventPreview: workspaceEventPreview,
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

  // ──────────────────── Notification & World Radar Handlers ────────────────────

  bool _isNotificationDigestQuery(String text) {
    final lower = text.toLowerCase().trim();
    return lower.contains('summarize my notification') ||
        lower.contains('summarise my notification') ||
        lower.contains('summarize notification') ||
        lower.contains('summarise notification') ||
        lower.contains('what notifications') ||
        lower.contains('check my notifications') ||
        lower.contains('check notifications') ||
        lower.contains('check my alerts') ||
        lower.contains('any unread message') ||
        lower.contains('what did i miss on whatsapp') ||
        lower.contains('what did i miss') ||
        lower.contains('my notifs');
  }

  bool _isWorldSocialRadarQuery(String text) {
    final lower = text.toLowerCase().trim();
    return lower.contains('outside world') ||
        lower.contains('happening in outside') ||
        lower.contains('happening outside') ||
        lower.contains('trending on social') ||
        lower.contains('social media trend') ||
        lower.contains('world radar') ||
        lower.contains('world briefing') ||
        lower.contains('whats trending') ||
        lower.contains("what's trending") ||
        lower.contains('what is trending') ||
        lower.contains('hacker news trend') ||
        lower.contains('tech news today');
  }

  Future<void> _handleNotificationDigestCommand(String content) async {
    _addUserMessage(content);
    _addLoadingMessage('🔔 Reading incoming notifications & synthesizing AI digest...');

    try {
      final notifService = NotificationMonitorService();
      final hasPerm = await notifService.isPermissionGranted();
      if (!hasPerm) {
        _removeLoadingMessage();
        _addSystemMessage(
          '⚠️ **Notification Access Required**\n\n'
          'AIRA needs permission to read notifications on your device.\n'
          'Please open **Intelligence & Monitor** from the menu or settings and tap **Grant Notification Access**.',
        );
        if (_isVoiceEnabled) {
          await speakText('Please grant notification access in AIRA settings to summarize your alerts.');
        }
        return;
      }

      final digest = await notifService.generateSmartDigest();
      _removeLoadingMessage();
      _addSystemMessage('### 🔔 AIRA Notification Intelligence Digest\n\n$digest');

      if (_isVoiceEnabled) {
        // Speak first 2 sentences
        final spoken = digest.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => 'Here is your notification summary.');
        await speakText(spoken);
      }
    } catch (e) {
      _removeLoadingMessage();
      _addSystemMessage('❌ **Notification Digest Error:** $e');
    }
  }

  Future<void> _handleWorldSocialRadarCommand(String content) async {
    _addUserMessage(content);
    _addLoadingMessage('🌐 Scanning Hacker News, Reddit & India tech signals...');

    try {
      final worldService = SocialWorldMonitorService();
      final digest = await worldService.generateExecutiveWorldDigest();
      _removeLoadingMessage();
      _addSystemMessage('### 🌐 Outside World & Social Radar\n\n$digest');

      if (_isVoiceEnabled) {
        final spoken = digest.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => 'Here is what is happening in the outside world.');
        await speakText(spoken);
      }
    } catch (e) {
      _removeLoadingMessage();
      _addSystemMessage('❌ **World Radar Error:** $e');
    }
  }

  void clearChat() {
    state = ChatState(isGoogleConnected: _workspace.isConnected);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
