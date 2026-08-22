import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/features/chat/domain/chat_models.dart';
import 'package:aira_app/features/chat/domain/workspace_intent.dart';
import 'package:aira_app/features/chat/domain/memory_intent.dart';
import 'package:aira_app/features/chat/domain/phone_intent.dart';
import 'package:aira_app/features/chat/domain/device_intent.dart';
import 'package:aira_app/features/chat/domain/notification_intent.dart';
import 'package:aira_app/features/chat/domain/routine_intent.dart';
import 'package:aira_app/features/chat/domain/whatsapp_intent.dart';
import 'package:aira_app/features/chat/domain/task_intent.dart';
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
  }

  Future<void> _initWorkspaceConnection() async {
    final connected = await _workspace.trySilentSignIn();
    if (connected) {
      state = state.copyWith(isGoogleConnected: true);
    }
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
        await _tts.speak('WhatsApp message prepared.');
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
      final plannerNotifier = PlannerNotifier();
      await plannerNotifier.loadAll();

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
        final clean = result.replaceAll(RegExp(r'[*#_`~]'), '').replaceAll(RegExp(r'[✅📋⏳🎉🗑️⚠️🔔]'), '');
        await _tts.speak(clean);
      }
    } catch (e) {
      _removeLoadingMessage();
      _addSystemMessage('❌ **Failed to update tasks:** $e');
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
        final speechText = responseText
            .replaceAll(RegExp(r'[*#_`\[\]>]'), '')
            .replaceAll(RegExp(r'[📸🔒😴🔴🔄🔇🔊🔉🚀✅⌨️💻📊🖥️💾💿🔋⚡]'), '');
        await _tts.speak(speechText);
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
        final clean = result.replaceAll(RegExp(r'[*#_`\[\]>]'), '');
        await _tts.speak(clean);
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
        await _tts.speak(res.spokenText);
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
        final clean = result.replaceAll(RegExp(r'[*#_`\[\]>]'), '');
        await _tts.speak(clean);
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
        final clean = result.replaceAll(RegExp(r'[*#_`\[\]>]'), '');
        await _tts.speak(clean);
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
        final clean = result.replaceAll(RegExp(r'[*#_`\[\]>]'), '');
        await _tts.speak(clean);
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

    _addLoadingMessage('Working on it...');

    try {
      String result = '';

      switch (command.intent) {
        case WorkspaceIntent.listDriveFiles:
          final files = await _workspace.listRecentDriveFiles();
          if (files.isEmpty) {
            result = 'No files found in your Google Drive.';
          } else {
            result = 'Your Recent Google Drive Files:\n\n';
            for (final f in files) {
              final isFolder = (f['mimeType'] as String).contains('folder');
              final icon = isFolder ? '[Folder]' : '[File]';
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
              final icon = (f['isFolder'] as bool) ? '[Folder]' : '[File]';
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

        case WorkspaceIntent.sendEmail:
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
                lookupNote = '*Found in Google Contacts: **$cName** (`$cEmail`)*\n\n';
                to = cEmail;
              }
            } catch (_) {}

            if (!to.contains('@')) {
              final memoryEmail = await _memoryService.findEmailForName(to);
              if (memoryEmail != null) {
                lookupNote = '*Retrieved email for **$to** from AI Memory (`$memoryEmail`)*\n\n';
                to = memoryEmail;
              }
            }
          }

          if (to.isEmpty) {
            result = 'Who should I send the email to? Please specify an email address or contact name like:\n> *"send email to Rahul asking about tomorrow\'s meeting"*';
          } else if (!to.contains('@')) {
            final emailSub = rawSubject.isNotEmpty ? rawSubject : "the details";
            result = 'I see you want to send an email to **$to** regarding *"$emailSub"*, but I couldn\'t find them in your Google Contacts or AI Memory.\n\nPlease try again with their full email address:\n> *"send email to $to@gmail.com about $emailSub"*';
          } else {
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
            result = '$lookupNote sent successfully via Gmail! *(LLM Provider: $providerUsed)*\n\n**To:** $to\n**Subject:** $emailSubject\n\n> ${emailBody.replaceAll('\n', '\n> ')}';
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
              result += '**${e['title']}**\nLocation: $start\n${e['location'] != '' ? 'Location: ${e['location']}\n' : ''}\n';
            }
          }
          break;

        case WorkspaceIntent.createEvent:
          final title = command.params['title'] as String? ?? 'New Event';
          final now = DateTime.now();
          final start = DateTime(now.year, now.month, now.day + 1, 10, 0);
          final end = start.add(const Duration(hours: 1));

          final event = await _workspace.createEvent(title: title, start: start, end: end);
          result = 'Calendar event created!\n\n**${event['title']}**\nLink: ${event['link']}';
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
      _addSystemMessage(result);

      if (_isVoiceEnabled && result.isNotEmpty) {
        final clean = result.replaceAll(RegExp(r'[*#_`\[\]|]'), '');
        await _tts.speak(clean);
      }
    } catch (e) {
      _removeLoadingMessage();
      final cleanErr = e.toString().replaceAll('Exception: ', '');
      _addSystemMessage('Workspace Action Failed\n\n$cleanErr');
    }
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
        final cleanText = response.replaceAll(RegExp(r'[*#_`]'), '');
        await _tts.speak(cleanText);
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
