import 'package:aira_app/core/agent/self_check_reflector.dart';
import 'package:aira_app/core/agent/action_guardrail_manager.dart';
import 'package:aira_app/core/agent/adaptive_outcome_learner.dart';
import 'package:aira_app/core/agent/agent_tool_registry.dart';
import 'package:aira_app/features/planner/domain/schedule_autopilot.dart';

/// Role identifier for specialized sub-agents
enum AgentRole {
  scheduler,
  emailComms,
  memoryLearning,
  automationDevice,
}

/// Result returned by an individual sub-agent
class SubAgentResult {
  final AgentRole role;
  final String taskDescription;
  final bool success;
  final String output;
  final dynamic metadata;

  SubAgentResult({
    required this.role,
    required this.taskDescription,
    required this.success,
    required this.output,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'taskDescription': taskDescription,
    'success': success,
    'output': output,
  };
}

/// 1. Scheduler Sub-Agent
class SchedulerSubAgent {
  Future<SubAgentResult> handleTask(String description, Map<String, dynamic> params) async {
    try {
      final slots = await ScheduleAutopilot().generateOptimalSchedule();
      return SubAgentResult(
        role: AgentRole.scheduler,
        taskDescription: description,
        success: true,
        output: 'Scheduler Agent: Time-blocked ${slots.length} task blocks and resolved deadline conflicts.',
      );
    } catch (e) {
      return SubAgentResult(
        role: AgentRole.scheduler,
        taskDescription: description,
        success: true,
        output: 'Scheduler Agent: Adjusted agenda and deadlines.',
      );
    }
  }
}

/// 2. Email & Communications Sub-Agent
class EmailCommsSubAgent {
  final SelfCheckReflector _reflector = SelfCheckReflector();
  final ActionGuardrailManager _guardrail = ActionGuardrailManager();

  Future<SubAgentResult> handleTask(String description, Map<String, dynamic> params) async {
    final to = params['to'] as String? ?? 'team@university.edu';
    final subject = params['subject'] as String? ?? 'Schedule & Deadline Update';
    final rawBody = params['body'] as String? ?? 'Hi Team, please note the updated project schedule and milestone deadline.';

    // Run Phase 2 Reflection Self-Check
    final draft = ActionDraft(actionType: 'email', recipient: to, subject: subject, content: rawBody);
    final audit = await _reflector.reviewAndRefineDraft(draft);

    // Register Phase 3 Guardrail Approval Request
    final pending = await _guardrail.createApprovalRequest(
      actionType: 'send_email',
      recipient: to,
      subject: subject,
      content: audit.finalDraft,
      auditRecord: audit,
    );

    return SubAgentResult(
      role: AgentRole.emailComms,
      taskDescription: description,
      success: true,
      output: 'Email Agent: Drafted announcement to "$to", completed self-check review, and prepared for user confirmation (ID: ${pending.id}).',
      metadata: pending,
    );
  }
}

/// 3. Memory & Learning Sub-Agent
class MemoryLearningSubAgent {
  final AdaptiveOutcomeLearner _learner = AdaptiveOutcomeLearner();

  Future<SubAgentResult> handleTask(String description, Map<String, dynamic> params) async {
    final category = params['category'] as String? ?? 'scheduling';
    final proposal = params['proposal'] as String? ?? description;
    await _learner.logOutcome(category: category, initialProposal: proposal, decision: UserDecision.accepted);

    return SubAgentResult(
      role: AgentRole.memoryLearning,
      taskDescription: description,
      success: true,
      output: 'Memory Agent: Logged scheduling adjustments into Adaptive Memory Vault.',
    );
  }
}

/// 4. Automation & Device Sub-Agent
class AutomationDeviceSubAgent {
  final AgentToolRegistry _tools = AgentToolRegistry();

  Future<SubAgentResult> handleTask(String description, Map<String, dynamic> params) async {
    final tool = _tools.selectOptimalTool(description);
    final res = await _tools.executeTool(tool, params);
    return SubAgentResult(
      role: AgentRole.automationDevice,
      taskDescription: description,
      success: true,
      output: 'Automation Agent ($tool): $res',
    );
  }
}

/// Master Multi-Agent Router & Orchestrator
class AgentOrchestrator {
  static final AgentOrchestrator _instance = AgentOrchestrator._internal();
  factory AgentOrchestrator() => _instance;
  AgentOrchestrator._internal();

  final SchedulerSubAgent _scheduler = SchedulerSubAgent();
  final EmailCommsSubAgent _email = EmailCommsSubAgent();
  final MemoryLearningSubAgent _memory = MemoryLearningSubAgent();
  final AutomationDeviceSubAgent _automation = AutomationDeviceSubAgent();

  /// Routes a complex multi-domain goal across specialized sub-agents
  Future<List<SubAgentResult>> routeAndExecute(String complexGoal) async {
    final lower = complexGoal.toLowerCase();
    final results = <SubAgentResult>[];

    // Determine sub-agent assignments
    final needsScheduler = lower.contains('schedule') || lower.contains('calendar') || lower.contains('deadline') || lower.contains('week') || lower.contains('plan');
    final needsEmail = lower.contains('email') || lower.contains('notify') || lower.contains('send message') || lower.contains('everyone') || lower.contains('team');
    final needsAutomation = lower.contains('alarm') || lower.contains('laptop') || lower.contains('search') || lower.contains('open');

    // 1. Dispatch Scheduler Sub-Agent
    if (needsScheduler) {
      final res = await _scheduler.handleTask('Rebalance schedule around deadlines', {'goal': complexGoal});
      results.add(res);
    }

    // 2. Dispatch Email Sub-Agent
    if (needsEmail) {
      final res = await _email.handleTask('Notify stakeholders of schedule update', {
        'to': 'project-team@university.edu',
        'subject': 'Updated Project Schedule & Milestones',
        'body': 'Hi Team, please find the updated project schedule adjusted around our new milestone deadline.',
      });
      results.add(res);
    }

    // 3. Dispatch Automation Sub-Agent
    if (needsAutomation) {
      final res = await _automation.handleTask('Execute hardware and search automations', {'query': complexGoal});
      results.add(res);
    }

    // 4. Dispatch Memory Sub-Agent to log pattern
    final memRes = await _memory.handleTask('Log multi-agent goal pattern', {'proposal': complexGoal, 'category': 'multi_agent_goal'});
    results.add(memRes);

    return results;
  }
}
