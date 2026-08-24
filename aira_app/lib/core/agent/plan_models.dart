/// Models for AIRA Autonomous Goal Planning & Multi-Step Execution
library;

enum PlanStepStatus {
  pending,
  running,
  completed,
  failed,
  waitingApproval,
  skipped,
}

enum ActionTier {
  freeRun,
  approvalRequired,
}

class AgentPlanStep {
  final int stepId;
  final String title;
  final String tool; // e.g. 'calendar_read', 'tasks_list', 'tasks_add', 'web_search', 'laptop_action', 'device_alarm'
  final Map<String, dynamic> params;
  final ActionTier tier;
  PlanStepStatus status;
  String? output;
  String? errorMessage;
  DateTime? startedAt;
  DateTime? completedAt;

  AgentPlanStep({
    required this.stepId,
    required this.title,
    required this.tool,
    required this.params,
    this.tier = ActionTier.freeRun,
    this.status = PlanStepStatus.pending,
    this.output,
    this.errorMessage,
    this.startedAt,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'stepId': stepId,
    'title': title,
    'tool': tool,
    'params': params,
    'tier': tier == ActionTier.approvalRequired ? 'approval_required' : 'free_run',
    'status': status.name,
    'output': output,
    'errorMessage': errorMessage,
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory AgentPlanStep.fromJson(Map<String, dynamic> json) => AgentPlanStep(
    stepId: json['stepId'] as int? ?? 1,
    title: json['title'] as String? ?? 'Subtask',
    tool: json['tool'] as String? ?? 'general',
    params: Map<String, dynamic>.from(json['params'] as Map? ?? {}),
    tier: (json['tier'] as String? ?? '').toLowerCase() == 'approval_required'
        ? ActionTier.approvalRequired
        : ActionTier.freeRun,
    status: PlanStepStatus.values.firstWhere(
      (e) => e.name == (json['status'] as String? ?? 'pending'),
      orElse: () => PlanStepStatus.pending,
    ),
    output: json['output'] as String?,
    errorMessage: json['errorMessage'] as String?,
    startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt'] as String) : null,
    completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'] as String) : null,
  );
}

class AgentGoalPlan {
  final String id;
  final String goal;
  final String rationale;
  final List<AgentPlanStep> steps;
  bool isExecuting;
  bool isCompleted;
  DateTime createdAt;

  AgentGoalPlan({
    required this.id,
    required this.goal,
    required this.rationale,
    required this.steps,
    this.isExecuting = false,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get totalSteps => steps.length;
  int get completedSteps => steps.where((s) => s.status == PlanStepStatus.completed).length;
  bool get hasFailures => steps.any((s) => s.status == PlanStepStatus.failed);

  Map<String, dynamic> toJson() => {
    'id': id,
    'goal': goal,
    'rationale': rationale,
    'steps': steps.map((s) => s.toJson()).toList(),
    'isExecuting': isExecuting,
    'isCompleted': isCompleted,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AgentGoalPlan.fromJson(Map<String, dynamic> json) => AgentGoalPlan(
    id: json['id'] as String? ?? '',
    goal: json['goal'] as String? ?? '',
    rationale: json['rationale'] as String? ?? '',
    steps: ((json['steps'] as List?) ?? [])
        .map((s) => AgentPlanStep.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList(),
    isExecuting: json['isExecuting'] as bool? ?? false,
    isCompleted: json['isCompleted'] as bool? ?? false,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}
