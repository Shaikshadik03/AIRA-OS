/// Models for AIRA Autonomous Goal Planning & Multi-Step Execution (Stage L / Master Blueprint Stage 11)
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

enum StepStage {
  preparation,
  execution,
  delivery,
}

class AgentPlanStep {
  final int stepId;
  final String title;
  final String tool; // e.g. 'calendar_read', 'tasks_list', 'tasks_add', 'web_search', 'notes_create', 'meeting_briefing'
  final Map<String, dynamic> params;
  final ActionTier tier;
  final StepStage stage;
  final bool isReadOnly;
  PlanStepStatus status;
  String? output;
  String? errorMessage;
  DateTime? startedAt;
  DateTime? completedAt;
  int retryCount;
  final int timeoutSeconds;
  Map<String, dynamic>? evidence;
  bool isApproved;

  AgentPlanStep({
    required this.stepId,
    required this.title,
    required this.tool,
    required this.params,
    this.tier = ActionTier.freeRun,
    this.stage = StepStage.execution,
    this.isReadOnly = false,
    this.status = PlanStepStatus.pending,
    this.output,
    this.errorMessage,
    this.startedAt,
    this.completedAt,
    this.retryCount = 0,
    this.timeoutSeconds = 20,
    this.evidence,
    this.isApproved = false,
  });

  bool get requiresApproval => tier == ActionTier.approvalRequired && !isApproved;
  bool get isCompleted => status == PlanStepStatus.completed;
  bool get isFailed => status == PlanStepStatus.failed;

  AgentPlanStep copyWith({
    int? stepId,
    String? title,
    String? tool,
    Map<String, dynamic>? params,
    ActionTier? tier,
    StepStage? stage,
    bool? isReadOnly,
    PlanStepStatus? status,
    String? output,
    String? errorMessage,
    DateTime? startedAt,
    DateTime? completedAt,
    int? retryCount,
    int? timeoutSeconds,
      Map<String, dynamic>? evidence,
      bool? isApproved,
    }) {
      return AgentPlanStep(
        stepId: stepId ?? this.stepId,
        title: title ?? this.title,
        tool: tool ?? this.tool,
        params: params ?? this.params,
        tier: tier ?? this.tier,
        stage: stage ?? this.stage,
        isReadOnly: isReadOnly ?? this.isReadOnly,
        status: status ?? this.status,
        output: output ?? this.output,
        errorMessage: errorMessage ?? this.errorMessage,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        retryCount: retryCount ?? this.retryCount,
        timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
        evidence: evidence ?? this.evidence,
        isApproved: isApproved ?? this.isApproved,
      );
    }

    Map<String, dynamic> toJson() => {
      'stepId': stepId,
      'title': title,
      'tool': tool,
      'params': params,
      'tier': tier == ActionTier.approvalRequired ? 'approval_required' : 'free_run',
      'stage': stage.name,
      'isReadOnly': isReadOnly,
      'status': status.name,
      'output': output,
      'errorMessage': errorMessage,
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'retryCount': retryCount,
      'timeoutSeconds': timeoutSeconds,
      'evidence': evidence,
      'isApproved': isApproved,
    };

    factory AgentPlanStep.fromJson(Map<String, dynamic> json) => AgentPlanStep(
      stepId: json['stepId'] as int? ?? 1,
      title: json['title'] as String? ?? 'Subtask',
      tool: json['tool'] as String? ?? 'general',
      params: Map<String, dynamic>.from(json['params'] as Map? ?? {}),
      tier: (json['tier'] as String? ?? '').toLowerCase() == 'approval_required'
          ? ActionTier.approvalRequired
          : ActionTier.freeRun,
      stage: StepStage.values.firstWhere(
        (e) => e.name == (json['stage'] as String? ?? 'execution'),
        orElse: () => StepStage.execution,
      ),
      isReadOnly: json['isReadOnly'] as bool? ?? _inferReadOnly(json['tool'] as String? ?? ''),
      status: PlanStepStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'pending'),
        orElse: () => PlanStepStatus.pending,
      ),
      output: json['output'] as String?,
      errorMessage: json['errorMessage'] as String?,
      startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt'] as String) : null,
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'] as String) : null,
      retryCount: json['retryCount'] as int? ?? 0,
      timeoutSeconds: json['timeoutSeconds'] as int? ?? 20,
      evidence: json['evidence'] != null ? Map<String, dynamic>.from(json['evidence'] as Map) : null,
      isApproved: json['isApproved'] as bool? ?? false,
    );

  static bool _inferReadOnly(String tool) {
    const readOnlyTools = {
      'tasks_list',
      'calendar_read',
      'email_summarize',
      'web_search',
      'notes_read',
      'notification_digest',
      'world_social_radar',
    };
    return readOnlyTools.contains(tool);
  }
}

class AgentGoalPlan {
  final String id;
  final String goal;
  final String rationale;
  final List<AgentPlanStep> steps;
  bool isExecuting;
  bool isCompleted;
  bool isPaused;
  String? pausedReason;
  int currentStepIndex;
  int resumedCount;
  int totalDurationMs;
  Map<String, dynamic>? evidenceSummary;
  DateTime createdAt;
  DateTime? finishedAt;

  AgentGoalPlan({
    required this.id,
    required this.goal,
    required this.rationale,
    required this.steps,
    this.isExecuting = false,
    this.isCompleted = false,
    this.isPaused = false,
    this.pausedReason,
    this.currentStepIndex = 0,
    this.resumedCount = 0,
    this.totalDurationMs = 0,
    this.evidenceSummary,
    DateTime? createdAt,
    this.finishedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get totalSteps => steps.length;
  int get completedSteps => steps.where((s) => s.status == PlanStepStatus.completed).length;
  bool get hasFailures => steps.any((s) => s.status == PlanStepStatus.failed);
  bool get isResumable => !isCompleted && steps.any((s) => s.status != PlanStepStatus.completed);

  AgentGoalPlan copyWith({
    String? id,
    String? goal,
    String? rationale,
    List<AgentPlanStep>? steps,
    bool? isExecuting,
    bool? isCompleted,
    bool? isPaused,
    String? pausedReason,
    int? currentStepIndex,
    int? resumedCount,
    int? totalDurationMs,
    Map<String, dynamic>? evidenceSummary,
    DateTime? createdAt,
    DateTime? finishedAt,
  }) {
    return AgentGoalPlan(
      id: id ?? this.id,
      goal: goal ?? this.goal,
      rationale: rationale ?? this.rationale,
      steps: steps ?? this.steps,
      isExecuting: isExecuting ?? this.isExecuting,
      isCompleted: isCompleted ?? this.isCompleted,
      isPaused: isPaused ?? this.isPaused,
      pausedReason: pausedReason ?? this.pausedReason,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      resumedCount: resumedCount ?? this.resumedCount,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
      evidenceSummary: evidenceSummary ?? this.evidenceSummary,
      createdAt: createdAt ?? this.createdAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'goal': goal,
    'rationale': rationale,
    'steps': steps.map((s) => s.toJson()).toList(),
    'isExecuting': isExecuting,
    'isCompleted': isCompleted,
    'isPaused': isPaused,
    'pausedReason': pausedReason,
    'currentStepIndex': currentStepIndex,
    'resumedCount': resumedCount,
    'totalDurationMs': totalDurationMs,
    'evidenceSummary': evidenceSummary,
    'createdAt': createdAt.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
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
    isPaused: json['isPaused'] as bool? ?? false,
    pausedReason: json['pausedReason'] as String?,
    currentStepIndex: json['currentStepIndex'] as int? ?? 0,
    resumedCount: json['resumedCount'] as int? ?? 0,
    totalDurationMs: json['totalDurationMs'] as int? ?? 0,
    evidenceSummary: json['evidenceSummary'] != null
        ? Map<String, dynamic>.from(json['evidenceSummary'] as Map)
        : null,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    finishedAt: json['finishedAt'] != null ? DateTime.tryParse(json['finishedAt'] as String) : null,
  );
}
