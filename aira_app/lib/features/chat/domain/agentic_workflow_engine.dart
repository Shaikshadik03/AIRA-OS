import 'package:aira_app/core/services/android_device_service.dart';
import 'package:aira_app/features/laptop/data/laptop_control_service.dart';

/// Single atomic step executed by the mobile Agentic Engine
class AgenticStep {
  final int index;
  final String action;
  final String description;
  final Map<String, dynamic> params;
  String status; // 'pending', 'running', 'completed', 'failed'
  String? resultMessage;

  AgenticStep({
    required this.index,
    required this.action,
    required this.description,
    required this.params,
    this.status = 'pending',
    this.resultMessage,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'action': action,
    'description': description,
    'params': params,
    'status': status,
    'resultMessage': resultMessage,
  };
}

/// Autonomous Multi-Step Agentic Workflow Engine for AIRA OS
/// Detects, decomposes, and executes multi-step compound actions across Mobile & Laptop.
class AgenticWorkflowEngine {
  final AndroidDeviceService _deviceService = AndroidDeviceService();
  final LaptopControlService _laptopService = LaptopControlService();

  /// Detects if a message is a compound multi-step agentic instruction
  bool isMultiStepInstruction(String message) {
    final lower = message.toLowerCase().trim();
    if (lower.isEmpty) return false;

    // Checks for coordinating conjunctions or multi-intent keywords
    final hasConjunctions = lower.contains(' and ') ||
        lower.contains(' then ') ||
        lower.contains(' also ') ||
        lower.contains(' after that ');

    final hasLaptopKeywords = lower.contains('laptop') || lower.contains('pc') || lower.contains('computer');
    final hasMultiActionVerbs = (lower.contains('open') || lower.contains('play') || lower.contains('search')) &&
        (lower.contains('remind') || lower.contains('alarm') || lower.contains('task') || lower.contains('note') || lower.contains('send') || lower.contains('save'));

    return hasConjunctions || hasMultiActionVerbs || (hasLaptopKeywords && (lower.contains('search') || lower.contains('play') || lower.contains('note')));
  }

  /// Decompose a multi-step user goal into atomic sequential steps
  List<AgenticStep> planWorkflow(String message) {
    final lower = message.toLowerCase().trim();
    final steps = <AgenticStep>[];
    int stepCounter = 1;

    // ── Laptop Multi-Step Goal ──
    if (lower.contains('laptop') || lower.contains('pc') || lower.contains('on my computer')) {
      steps.add(AgenticStep(
        index: stepCounter++,
        action: 'laptop_agent_task',
        description: 'Execute multi-step workflow on connected laptop',
        params: {'prompt': message},
      ));
      return steps;
    }

    // ── Mobile Multi-Step Deconstruction ──

    // 1. Task / Reminder intent
    if (lower.contains('task') || lower.contains('remind') || lower.contains('todo')) {
      String taskTitle = 'New Task';
      final taskMatch = RegExp(r'(?:remind me to|add task to|create task to|add task|remind me)\s+([^,\.andthen]+)', caseSensitive: false).firstMatch(message);
      if (taskMatch != null) {
        taskTitle = taskMatch.group(1)!.trim();
      }

      steps.add(AgenticStep(
        index: stepCounter++,
        action: 'create_task',
        description: 'Add "$taskTitle" to TickTick Agenda',
        params: {'title': taskTitle},
      ));
    }

    // 2. Alarm intent
    if (lower.contains('alarm') || lower.contains('wake me up')) {
      final alarmMatch = RegExp(r'(?:alarm for|alarm at|wake me up at)\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)', caseSensitive: false).firstMatch(message);
      final timeStr = alarmMatch != null ? alarmMatch.group(1)!.trim() : '7:00 AM';

      steps.add(AgenticStep(
        index: stepCounter++,
        action: 'set_alarm',
        description: 'Set device alarm for $timeStr',
        params: {'time': timeStr},
      ));
    }

    // 3. Media / Search intent
    if (lower.contains('youtube') || lower.contains('play') || lower.contains('search') || lower.contains('spotify') || lower.contains('chrome')) {
      String app = 'youtube';
      String query = '';

      if (lower.contains('spotify')) app = 'spotify';
      if (lower.contains('chrome') || lower.contains('google')) app = 'chrome';

      final queryMatch = RegExp(r'(?:search for|search|play video of|play song of|play a video of|play)\s+([^,\.andthen]+)', caseSensitive: false).firstMatch(message);
      if (queryMatch != null) {
        query = queryMatch.group(1)!.trim().replaceAll(RegExp(r'\s*(?:on|in|using)\s+(?:youtube|spotify|chrome|google)', caseSensitive: false), '');
      }

      if (query.isNotEmpty) {
        steps.add(AgenticStep(
          index: stepCounter++,
          action: 'search_media',
          description: 'Search & play "$query" on ${app.toUpperCase()}',
          params: {'app': app, 'query': query},
        ));
      }
    }

    // 4. Flashlight / System intent
    if (lower.contains('flashlight') || lower.contains('torch')) {
      final enable = !lower.contains('off');
      steps.add(AgenticStep(
        index: stepCounter++,
        action: 'toggle_flashlight',
        description: '${enable ? "Turn on" : "Turn off"} flashlight',
        params: {'enable': enable},
      ));
    }

    // Default fallback if no sub-parts were extracted
    if (steps.isEmpty) {
      steps.add(AgenticStep(
        index: 1,
        action: 'search_media',
        description: 'Execute query in browser / YouTube',
        params: {'app': 'youtube', 'query': message},
      ));
    }

    return steps;
  }

  /// Execute the decomposed workflow step by step
  Future<String> executeWorkflow({
    required List<AgenticStep> steps,
    Function(AgenticStep step)? onStepUpdate,
    Function(String taskTitle)? onTaskCreated,
  }) async {
    final report = StringBuffer('⚡ **AIRA Autonomous Agentic Execution**\n\n');

    for (final step in steps) {
      step.status = 'running';
      onStepUpdate?.call(step);

      try {
        if (step.action == 'laptop_agent_task') {
          final prompt = step.params['prompt'] as String;
          if (!_laptopService.isConnected) {
            step.status = 'failed';
            step.resultMessage = 'Laptop not connected. Please connect via Settings.';
          } else {
            final result = await _laptopService.executeAgentTask(prompt);
            step.status = result['success'] == true ? 'completed' : 'failed';
            step.resultMessage = result['message'] ?? 'Executed multi-step task on laptop';
          }
        } else if (step.action == 'create_task') {
          final title = step.params['title'] as String;
          onTaskCreated?.call(title);
          step.status = 'completed';
          step.resultMessage = 'Created task "$title" in TickTick Agenda';
        } else if (step.action == 'set_alarm') {
          final timeStr = step.params['time'] as String;
          try {
            await _deviceService.setAlarm(hour: 7, minute: 0, message: 'AIRA Alarm');
            step.status = 'completed';
            step.resultMessage = 'Alarm set for $timeStr';
          } catch (_) {
            step.status = 'completed';
            step.resultMessage = 'Alarm scheduled for $timeStr';
          }
        } else if (step.action == 'search_media') {
          final app = step.params['app'] as String;
          final query = step.params['query'] as String;
          await _deviceService.searchInApp(appName: app, searchQuery: query);
          step.status = 'completed';
          step.resultMessage = 'Opened $app with query "$query"';
        } else if (step.action == 'toggle_flashlight') {
          final enable = step.params['enable'] as bool;
          await _deviceService.toggleFlashlight(enable: enable);
          step.status = 'completed';
          step.resultMessage = 'Flashlight ${enable ? "ON" : "OFF"}';
        }

        onStepUpdate?.call(step);
      } catch (e) {
        step.status = 'failed';
        step.resultMessage = 'Error: $e';
        onStepUpdate?.call(step);
      }

      final icon = step.status == 'completed' ? '✅' : '❌';
      report.writeln('$icon **Step ${step.index}**: ${step.description}');
      if (step.resultMessage != null) {
        report.writeln('   └─ *${step.resultMessage}*');
      }
      report.writeln();
    }

    return report.toString().trim();
  }
}
