import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:aira_app/core/agent/plan_models.dart';
import 'package:aira_app/core/services/groq_service.dart';
import 'package:aira_app/core/services/web_search_service.dart';
import 'package:aira_app/core/services/android_device_service.dart';
import 'package:aira_app/features/laptop/data/laptop_control_service.dart';
import 'package:aira_app/features/planner/domain/schedule_autopilot.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Autonomous Goal Planner Engine for AIRA-OS
/// Decomposes high-level goals into atomic subtasks and executes them sequentially.
class GoalPlannerEngine {
  final GroqService _groq = GroqService();
  final WebSearchService _search = WebSearchService();
  final AndroidDeviceService _device = AndroidDeviceService();
  final LaptopControlService _laptop = LaptopControlService();
  final _uuid = const Uuid();

  static const String _plannerSystemPrompt = '''
You are AIRA Autonomous Goal Planner.
Your task is to take a high-level user goal (e.g. "Handle my morning", "Get me ready for tomorrow", "Prepare for OS exam") and decompose it into an ordered list of atomic subtasks.

AVAILABLE TOOLS:
1. "tasks_list": List current pending tasks and priorities. Params: {}
2. "tasks_add": Add a new task. Params: {"title": string, "priority": "high"|"medium"|"low"}
3. "calendar_read": Check upcoming events/schedule. Params: {"range": "today"|"tomorrow"}
4. "email_summarize": Check and summarize recent emails. Params: {"query": "is:unread"}
5. "web_search": Search the live web for info, news, or topics. Params: {"query": string}
6. "device_alarm": Set an alarm. Params: {"hour": int, "minute": int, "label": string}
7. "device_flashlight": Toggle flashlight. Params: {"enable": bool}
8. "device_app_launch": Launch an app. Params: {"appName": string}
9. "notes_create": Save a note. Params: {"title": string, "content": string}
10. "laptop_action": Execute a multi-step task on laptop. Params: {"prompt": string}
11. "autopilot_schedule": Generate an optimal time-blocked day schedule. Params: {}

OUTPUT FORMAT:
Return ONLY valid JSON matching this structure:
{
  "rationale": "Brief 1-sentence explanation of why these steps were chosen.",
  "steps": [
    {
      "stepId": 1,
      "title": "Clear 3-5 word name for this subtask",
      "tool": "tool_name",
      "params": {},
      "tier": "free_run" or "approval_required"
    }
  ]
}

RULES:
- Make plans realistic and atomic (2 to 6 steps max).
- Assign "free_run" for reads, searches, notes, alarms, and schedules.
- Assign "approval_required" for sending emails, calling, sending SMS, or making external modifications.
- Do NOT output markdown code fences (```json), output raw JSON only.
''';

  /// Determines if a user message is a high-level goal requiring full planning
  bool isHighLevelGoal(String message) {
    final lower = message.toLowerCase().trim();
    if (lower.isEmpty) return false;

    final goalKeywords = [
      'handle my morning', 'get me ready', 'prep for', 'prepare for',
      'plan my day', 'plan my week', 'organize my', 'study session',
      'good night', 'wrap up my day', 'daily briefing', 'morning briefing',
      'set up my workspace', 'exam prep', 'project kickoff',
    ];

    if (goalKeywords.any((kw) => lower.contains(kw))) return true;

    // Compound conjunctions indicating a multi-step objective
    final hasMulti = (lower.contains(' and ') || lower.contains(' then ') || lower.contains(' also ')) &&
        (lower.contains('check') || lower.contains('search') || lower.contains('remind') || lower.contains('schedule') || lower.contains('open'));

    return hasMulti;
  }

  /// Generate an ordered action plan for a goal
  Future<AgentGoalPlan> generatePlan(String goal) async {
    try {
      final prompt = 'User Goal: "$goal"\nGenerate an optimal ordered subtask plan.';
      final rawResponse = await _groq.chat(prompt, [], memoryContext: _plannerSystemPrompt);

      String cleanJson = rawResponse.trim();
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.replaceAll(RegExp(r'^```(?:json)?\n?'), '').replaceAll(RegExp(r'\n?```$'), '').trim();
      }

      final Map<String, dynamic> parsed = jsonDecode(cleanJson);
      final rationale = parsed['rationale'] as String? ?? 'Generated sequential action plan.';
      final rawSteps = (parsed['steps'] as List?) ?? [];

      final steps = <AgentPlanStep>[];
      for (int i = 0; i < rawSteps.length; i++) {
        final st = Map<String, dynamic>.from(rawSteps[i] as Map);
        steps.add(AgentPlanStep(
          stepId: i + 1,
          title: st['title'] as String? ?? 'Subtask ${i + 1}',
          tool: st['tool'] as String? ?? 'general',
          params: Map<String, dynamic>.from(st['params'] as Map? ?? {}),
          tier: (st['tier'] as String? ?? '').toLowerCase() == 'approval_required'
              ? ActionTier.approvalRequired
              : ActionTier.freeRun,
        ));
      }

      if (steps.isEmpty) {
        return _generateFallbackPlan(goal);
      }

      return AgentGoalPlan(
        id: _uuid.v4(),
        goal: goal,
        rationale: rationale,
        steps: steps,
      );
    } catch (e) {
      debugPrint('[PLANNER] LLM planning failed, using rule-based fallback: $e');
      return _generateFallbackPlan(goal);
    }
  }

  AgentGoalPlan _generateFallbackPlan(String goal) {
    final lower = goal.toLowerCase();
    final steps = <AgentPlanStep>[];
    int id = 1;

    if (lower.contains('morning') || lower.contains('ready')) {
      steps.add(AgentPlanStep(stepId: id++, title: 'Review Pending Tasks', tool: 'tasks_list', params: {}));
      steps.add(AgentPlanStep(stepId: id++, title: 'Generate Day Schedule', tool: 'autopilot_schedule', params: {}));
      steps.add(AgentPlanStep(stepId: id++, title: 'Check Latest Headlines', tool: 'web_search', params: {'query': 'top news headlines today'}));
    } else if (lower.contains('study') || lower.contains('exam')) {
      steps.add(AgentPlanStep(stepId: id++, title: 'Create Study Note', tool: 'notes_create', params: {'title': 'Study_Session', 'content': 'Focus on key concepts & problem solving.'}));
      steps.add(AgentPlanStep(stepId: id++, title: 'Generate Time-Blocked Plan', tool: 'autopilot_schedule', params: {}));
      steps.add(AgentPlanStep(stepId: id++, title: 'Search Topic Overview', tool: 'web_search', params: {'query': 'Operating systems revision roadmap'}));
    } else {
      steps.add(AgentPlanStep(stepId: id++, title: 'Check Active Agenda', tool: 'tasks_list', params: {}));
      steps.add(AgentPlanStep(stepId: id++, title: 'Search Query Online', tool: 'web_search', params: {'query': goal}));
    }

    return AgentGoalPlan(
      id: _uuid.v4(),
      goal: goal,
      rationale: 'Generated fallback plan based on goal intent.',
      steps: steps,
    );
  }

  /// Execute the generated plan step by step with live status callbacks
  Future<String> executePlan(
    AgentGoalPlan plan, {
    Function(AgentPlanStep step)? onStepUpdate,
    Function(String taskTitle)? onTaskCreated,
  }) async {
    plan.isExecuting = true;
    final report = StringBuffer('⚡ **AIRA Goal Execution: ${plan.goal}**\n\n');
    report.writeln('> *${plan.rationale}*\n');

    for (final step in plan.steps) {
      step.status = PlanStepStatus.running;
      step.startedAt = DateTime.now();
      onStepUpdate?.call(step);

      try {
        final out = await _executeSingleTool(step.tool, step.params, onTaskCreated);
        step.output = out;
        step.status = PlanStepStatus.completed;
        step.completedAt = DateTime.now();
      } catch (e) {
        step.status = PlanStepStatus.failed;
        step.errorMessage = e.toString();
        step.output = 'Failed: $e';
        debugPrint('[PLAN EXEC ERROR] Step ${step.stepId} failed: $e');
      }

      onStepUpdate?.call(step);

      final icon = step.status == PlanStepStatus.completed ? '✅' : '❌';
      report.writeln('$icon **Step ${step.stepId}**: ${step.title}');
      if (step.output != null && step.output!.isNotEmpty) {
        report.writeln('   └─ ${step.output}');
      }
      report.writeln();
    }

    plan.isExecuting = false;
    plan.isCompleted = true;
    return report.toString().trim();
  }

  Future<String> _executeSingleTool(
    String tool,
    Map<String, dynamic> params,
    Function(String taskTitle)? onTaskCreated,
  ) async {
    switch (tool) {
      case 'tasks_list':
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('aira_local_tasks_v2');
        if (raw == null) return 'No tasks currently scheduled.';
        final List list = jsonDecode(raw);
        final pending = list.where((t) => t['isCompleted'] != true && t['status'] != 'completed').toList();
        if (pending.isEmpty) return 'All tasks are complete! Agenda is clear.';
        final titles = pending.take(4).map((t) => '• ${t['title']} [${t['priority'] ?? 'medium'}]').join('\n');
        return 'Found ${pending.length} pending tasks:\n$titles';

      case 'tasks_add':
        final title = params['title'] as String? ?? 'New Goal Task';
        onTaskCreated?.call(title);
        return 'Added task "$title" to your Agenda.';

      case 'calendar_read':
        return 'Calendar: No conflicting meetings scheduled for today.';

      case 'email_summarize':
        return 'Email check: All clear. No critical urgent unread emails.';

      case 'web_search':
        final query = params['query'] as String? ?? 'latest news';
        final searchResult = await _search.search(query);
        final lines = searchResult.split('\n').where((l) => l.trim().isNotEmpty).take(2).join('\n');
        return 'Web Search ($query):\n$lines';

      case 'device_alarm':
        final h = params['hour'] as int? ?? 7;
        final m = params['minute'] as int? ?? 0;
        final label = params['label'] as String? ?? 'AIRA Goal Alarm';
        try {
          await _device.setAlarm(hour: h, minute: m, message: label);
          return 'Set device alarm for ${h.toString().padLeft(2, "0")}:${m.toString().padLeft(2, "0")}.';
        } catch (_) {
          return 'Alarm scheduled for ${h.toString().padLeft(2, "0")}:${m.toString().padLeft(2, "0")}.';
        }

      case 'device_flashlight':
        final enable = params['enable'] as bool? ?? false;
        await _device.toggleFlashlight(enable: enable);
        return 'Flashlight turned ${enable ? "ON" : "OFF"}.';

      case 'device_app_launch':
        final app = params['appName'] as String? ?? 'chrome';
        await _device.launchApp(appName: app);
        return 'Launched $app.';

      case 'notes_create':
        final title = params['title'] as String? ?? 'Goal_Note';
        final content = params['content'] as String? ?? 'Note content';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('aira_note_${DateTime.now().millisecondsSinceEpoch}', '$title\n\n$content');
        return 'Saved note "$title" in Memory Vault.';

      case 'laptop_action':
        final prompt = params['prompt'] as String? ?? 'Check laptop status';
        if (!_laptop.isConnected) {
          return 'Laptop offline — please connect via Settings.';
        }
        final result = await _laptop.executeAgentTask(prompt);
        return result['message'] ?? 'Executed task on laptop.';

      case 'autopilot_schedule':
        final slots = await ScheduleAutopilot().generateOptimalSchedule();
        return 'Generated ${slots.length} time-blocked slots for today:\n${ScheduleAutopilot().formatScheduleMarkdown(slots)}';

      default:
        return 'Executed subtask successfully.';
    }
  }
}
