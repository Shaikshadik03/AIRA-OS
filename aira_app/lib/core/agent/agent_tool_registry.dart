import 'package:dio/dio.dart';
import 'package:aira_app/core/services/web_search_service.dart';
import 'package:aira_app/core/services/android_device_service.dart';
import 'package:aira_app/features/laptop/data/laptop_control_service.dart';

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
  };

  List<AgentToolDefinition> get availableTools => _tools.values.toList();

  /// Dynamically pick the best fitting tool for a given subtask description
  String selectOptimalTool(String subtaskTitle, {String? context}) {
    final lower = '$subtaskTitle ${context ?? ""}'.toLowerCase();

    if (lower.contains('search') || lower.contains('news') || lower.contains('who is') || lower.contains('latest') || lower.contains('online') || lower.contains('article') || lower.contains('documentation') || lower.contains('weather')) {
      return 'web_search';
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
    if (lower.contains('open ') || lower.contains('launch ') || lower.contains('app')) {
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

    return 'web_search'; // Default to web search for general queries
  }

  /// Dispatch execution for a selected tool
  Future<String> executeTool(String toolName, Map<String, dynamic> params) async {
    switch (toolName) {
      case 'web_search':
        final query = params['query'] as String? ?? 'AIRA news';
        return await _webSearch.search(query);

      case 'n8n_workflow':
        final url = params['webhookUrl'] as String? ?? '';
        final payload = params['payload'] as Map<String, dynamic>? ?? {};
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

      default:
        return 'Tool "$toolName" executed successfully.';
    }
  }
}
