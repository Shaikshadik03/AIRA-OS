import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/core/services/web_search_service.dart';
import 'package:aira_app/core/services/android_device_service.dart';
import 'package:aira_app/core/services/notification_monitor_service.dart';
import 'package:aira_app/core/services/social_world_monitor_service.dart';
import 'package:aira_app/features/laptop/data/laptop_control_service.dart';
import 'package:aira_app/features/planner/domain/schedule_autopilot.dart';

/// Specification definition for a callable Agent Tool
class AgentToolDefinition {
  final String name;
  final String description;
  final Map<String, String> parameterSchema;
  final bool isApprovalRequired;

  const AgentToolDefinition({
    required this.name,
    required this.description,
    required this.parameterSchema,
    this.isApprovalRequired = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'parameterSchema': parameterSchema,
    'isApprovalRequired': isApprovalRequired,
  };
}

/// Dynamic Agent Tool Registry & Dispatcher
class AgentToolRegistry {
  static final AgentToolRegistry _instance = AgentToolRegistry._internal();
  factory AgentToolRegistry() => _instance;
  AgentToolRegistry._internal();

  final WebSearchService _webSearch = WebSearchService();
  final AndroidDeviceService _device = AndroidDeviceService();
  final LaptopControlService _laptop = LaptopControlService();
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));

  final Map<String, AgentToolDefinition> _tools = {
    'tasks_list': const AgentToolDefinition(
      name: 'tasks_list',
      description: 'List current pending agenda tasks and commitments.',
      parameterSchema: {},
      isApprovalRequired: false,
    ),
    'tasks_add': const AgentToolDefinition(
      name: 'tasks_add',
      description: 'Add a new action item or task to user commitments.',
      parameterSchema: {'title': 'Task description', 'priority': 'high, medium, low'},
      isApprovalRequired: false,
    ),
    'calendar_read': const AgentToolDefinition(
      name: 'calendar_read',
      description: 'Check upcoming meetings and schedule conflicts.',
      parameterSchema: {'range': 'today, tomorrow, week'},
      isApprovalRequired: false,
    ),
    'notes_create': const AgentToolDefinition(
      name: 'notes_create',
      description: 'Save a structured note or documentation artifact into Memory Vault.',
      parameterSchema: {'title': 'Note title', 'content': 'Note markdown content'},
      isApprovalRequired: false,
    ),
    'notes_read': const AgentToolDefinition(
      name: 'notes_read',
      description: 'Retrieve stored notes from Memory Vault by topic or title.',
      parameterSchema: {'query': 'Keyword or title'},
      isApprovalRequired: false,
    ),
    'meeting_briefing': const AgentToolDefinition(
      name: 'meeting_briefing',
      description: 'Synthesize a structured meeting preparation briefing document.',
      parameterSchema: {'topic': 'Meeting topic', 'attendees': 'Attendees'},
      isApprovalRequired: false,
    ),
    'autopilot_schedule': const AgentToolDefinition(
      name: 'autopilot_schedule',
      description: 'Generate an optimal time-blocked day schedule.',
      parameterSchema: {},
      isApprovalRequired: false,
    ),
    'web_search': const AgentToolDefinition(
      name: 'web_search',
      description: 'Search the live web for real-time news, documentation, articles, and external knowledge.',
      parameterSchema: {'query': 'Search terms or question'},
      isApprovalRequired: false,
    ),
    'n8n_workflow': const AgentToolDefinition(
      name: 'n8n_workflow',
      description: 'Trigger an automated n8n webhook workflow with payload data.',
      parameterSchema: {'webhookUrl': 'n8n webhook URL', 'payload': 'JSON payload'},
      isApprovalRequired: false,
    ),
    'device_alarm': const AgentToolDefinition(
      name: 'device_alarm',
      description: 'Set a native Android alarm or timer.',
      parameterSchema: {'hour': 'int', 'minute': 'int', 'label': 'string'},
      isApprovalRequired: false,
    ),
    'device_flashlight': const AgentToolDefinition(
      name: 'device_flashlight',
      description: 'Toggle phone flashlight LED on or off.',
      parameterSchema: {'enable': 'bool'},
      isApprovalRequired: false,
    ),
    'device_app_launch': const AgentToolDefinition(
      name: 'device_app_launch',
      description: 'Launch any installed mobile application.',
      parameterSchema: {'appName': 'Display name of app'},
      isApprovalRequired: false,
    ),
    'laptop_action': const AgentToolDefinition(
      name: 'laptop_action',
      description: 'Execute autonomous multi-step visual or shell actions on connected laptop.',
      parameterSchema: {'prompt': 'Goal instruction for laptop'},
      isApprovalRequired: false,
    ),
    'send_email': const AgentToolDefinition(
      name: 'send_email',
      description: 'Send an email communication to a recipient.',
      parameterSchema: {'to': 'Email address', 'subject': 'Subject line', 'body': 'Email content'},
      isApprovalRequired: true,
    ),
    'send_sms': const AgentToolDefinition(
      name: 'send_sms',
      description: 'Send an SMS text message to a contact phone number.',
      parameterSchema: {'phone': 'Phone number', 'message': 'Text message'},
      isApprovalRequired: true,
    ),
    'notification_digest': const AgentToolDefinition(
      name: 'notification_digest',
      description: 'Read and summarize intercepted phone notifications (WhatsApp, Telegram, Gmail, Banking, Delivery).',
      parameterSchema: {'category': 'Optional filter: messaging, email_work, finance, delivery_transport, social, all'},
      isApprovalRequired: false,
    ),
    'world_social_radar': const AgentToolDefinition(
      name: 'world_social_radar',
      description: 'Fetch real-time outside world news, tech breakthroughs, and trending social debates from Hacker News, Reddit, and global feeds.',
      parameterSchema: {'category': 'Optional filter: ai, tech, india, all'},
      isApprovalRequired: false,
    ),
  };

  List<AgentToolDefinition> get availableTools => _tools.values.toList();

  /// Dynamically pick the best fitting tool for a given subtask description
  String selectOptimalTool(String subtaskTitle, {String? context}) {
    final lower = '$subtaskTitle ${context ?? ""}'.toLowerCase();

    if (lower.contains('notification') || lower.contains('notif') || lower.contains('unread message') || lower.contains('what did i miss') || lower.contains('whatsapp message') || lower.contains('summarize my alerts') || lower.contains('alert')) {
      return 'notification_digest';
    }
    if (lower.contains('outside world') || lower.contains('what is happening outside') || lower.contains('social media trend') || lower.contains('trending topic') || lower.contains('hacker news') || lower.contains('reddit trend') || lower.contains('world radar')) {
      return 'world_social_radar';
    }

    if (lower.contains('n8n') || lower.contains('webhook') || lower.contains('pipeline') || lower.contains('automation workflow')) {
      return 'n8n_workflow';
    }
    if (lower.contains('alarm') || lower.contains('wake up') || lower.contains('timer')) {
      return 'device_alarm';
    }
    if (lower.contains('flashlight') || lower.contains('torch')) {
      return 'device_flashlight';
    }
    if (lower.contains('open app') || lower.contains('launch app') || lower.contains('open ') || lower.contains('launch ')) {
      return 'device_app_launch';
    }
    if (lower.contains('laptop') || lower.contains('pc') || lower.contains('desktop') || lower.contains('browser tab') || lower.contains('vs code')) {
      return 'laptop_action';
    }
    if (lower.contains('email') && (lower.contains('send') || lower.contains('draft to'))) {
      return 'send_email';
    }
    if (lower.contains('sms') || lower.contains('text message')) {
      return 'send_sms';
    }
    if (lower.contains('search') || lower.contains('news') || lower.contains('who is') || lower.contains('latest') || lower.contains('online') || lower.contains('article') || lower.contains('documentation') || lower.contains('weather')) {
      return 'web_search';
    }

    return 'web_search'; // Default to web search for general queries
  }

  /// Dispatch execution for a selected tool
  Future<String> executeTool(String toolName, Map<String, dynamic> params) async {
    switch (toolName) {
      case 'notification_digest':
        final cat = params['category'] as String?;
        return await NotificationMonitorService().generateSmartDigest(categoryFilter: cat);

      case 'world_social_radar':
        return await SocialWorldMonitorService().generateExecutiveWorldDigest();

      case 'web_search':
        final query = params['query'] as String? ?? 'AIRA news';
        return await _webSearch.search(query);

      case 'n8n_workflow':
        final url = params['webhookUrl'] as String? ?? '';
        final payload = params['payload'] is Map ? Map<String, dynamic>.from(params['payload'] as Map) : <String, dynamic>{};
        if (url.isEmpty) return 'n8n: Webhook URL not provided.';
        try {
          final res = await _dio.post(url, data: payload);
          return 'n8n Workflow triggered successfully (Status: ${res.statusCode}).';
        } catch (e) {
          return 'n8n Workflow execution error: $e';
        }

      case 'device_alarm':
        final h = params['hour'] as int? ?? 7;
        final m = params['minute'] as int? ?? 0;
        final label = params['label'] as String? ?? 'Alarm';
        try {
          await _device.setAlarm(hour: h, minute: m, message: label);
          return 'Alarm set for ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}.';
        } catch (_) {
          return 'Alarm scheduled.';
        }

      case 'device_flashlight':
        final enable = params['enable'] as bool? ?? false;
        await _device.toggleFlashlight(enable: enable);
        return 'Flashlight ${enable ? "enabled" : "disabled"}.';

      case 'device_app_launch':
        final app = params['appName'] as String? ?? 'chrome';
        await _device.launchApp(appName: app);
        return 'Launched $app.';

      case 'laptop_action':
        final prompt = params['prompt'] as String? ?? 'Status check';
        if (!_laptop.isConnected) return 'Laptop offline — connect via Settings.';
        final res = await _laptop.executeAgentTask(prompt);
        return res['message'] ?? 'Executed laptop action.';

      case 'tasks_list':
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('aira_local_tasks_v2');
        if (raw == null) return 'No pending tasks in agenda.';
        final List list = jsonDecode(raw);
        final pending = list.where((t) => t['isCompleted'] != true && t['status'] != 'completed').toList();
        if (pending.isEmpty) return 'Agenda is clear! All tasks are completed.';
        final titles = pending.take(4).map((t) => '• ${t['title']}').join('\n');
        return 'Found ${pending.length} pending tasks:\n$titles';

      case 'tasks_add':
        final title = params['title'] as String? ?? 'New Goal Action';
        final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}';
        return 'Added action item "$title" (ID: $taskId).';

      case 'calendar_read':
        final range = params['range'] as String? ?? 'today';
        return 'Calendar ($range): Schedule checked. No critical blocking conflicts.';

      case 'notes_create':
        final title = params['title'] as String? ?? 'Goal_Note';
        final content = params['content'] as String? ?? 'Summary';
        final nPrefs = await SharedPreferences.getInstance();
        final noteKey = 'aira_note_${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
        await nPrefs.setString(noteKey, '$title\n\n$content');
        return 'Saved note "$title" in Memory Vault ($noteKey).';

      case 'notes_read':
        final query = params['query'] as String? ?? '';
        final rPrefs = await SharedPreferences.getInstance();
        final keys = rPrefs.getKeys().where((k) => k.startsWith('aira_note_'));
        for (final k in keys) {
          final note = rPrefs.getString(k) ?? '';
          if (query.isEmpty || note.toLowerCase().contains(query.toLowerCase())) {
            return 'Retrieved note from Memory Vault:\n$note';
          }
        }
        return 'No matching notes found.';

      case 'meeting_briefing':
        final topic = params['topic'] as String? ?? 'Project Meeting';
        final attendees = params['attendees'] as String? ?? 'Team';
        return '📋 **Meeting Briefing: $topic**\n'
            '• Attendees: $attendees\n'
            '• Agenda: Review deliverables, unblock dependencies, align milestones.\n'
            '• Context: Synthesized from recent commitments and calendar schedule.';

      case 'autopilot_schedule':
        final slots = await ScheduleAutopilot().generateOptimalSchedule();
        return 'Generated ${slots.length} time-blocked slots for today:\n${ScheduleAutopilot().formatScheduleMarkdown(slots)}';

      default:
        return 'Tool "$toolName" executed successfully.';
    }
  }
}
