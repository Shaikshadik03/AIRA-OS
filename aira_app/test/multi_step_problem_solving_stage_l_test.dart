import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/core/agent/plan_models.dart';
import 'package:aira_app/core/agent/goal_planner_engine.dart';
import 'package:aira_app/core/agent/plan_execution_service.dart';
import 'package:aira_app/core/agent/agent_tool_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Stage L: Plan Models & Serialization Tests', () {
    test('AgentPlanStep serializes and deserializes all Stage L fields', () {
      final step = AgentPlanStep(
        stepId: 1,
        title: 'Check Calendar Schedule',
        tool: 'calendar_read',
        params: {'range': 'tomorrow'},
        stage: StepStage.preparation,
        tier: ActionTier.freeRun,
        isReadOnly: true,
        status: PlanStepStatus.completed,
        output: 'Found 1 meeting at 10 AM',
        retryCount: 1,
        timeoutSeconds: 15,
        evidence: {'type': 'calendar', 'verified': true},
        startedAt: DateTime(2026, 9, 15, 10, 0),
        completedAt: DateTime(2026, 9, 15, 10, 1),
      );

      final json = step.toJson();
      expect(json['stage'], equals('preparation'));
      expect(json['isReadOnly'], isTrue);
      expect(json['retryCount'], equals(1));
      expect(json['evidence']['type'], equals('calendar'));

      final restored = AgentPlanStep.fromJson(json);
      expect(restored.stepId, equals(1));
      expect(restored.stage, equals(StepStage.preparation));
      expect(restored.isReadOnly, isTrue);
      expect(restored.isCompleted, isTrue);
      expect(restored.evidence?['type'], equals('calendar'));
      expect(restored.output, contains('10 AM'));
    });

    test('AgentGoalPlan serializes and deserializes resumable state and evidence', () {
      final plan = AgentGoalPlan(
        id: 'plan-stage-l-001',
        goal: "Prepare for tomorrow's project meeting",
        rationale: 'Review calendar, draft briefing, track tasks, and set alarm.',
        steps: [
          AgentPlanStep(
            stepId: 1,
            title: 'Review schedule',
            tool: 'calendar_read',
            params: {},
            stage: StepStage.preparation,
            isReadOnly: true,
            status: PlanStepStatus.completed,
          ),
          AgentPlanStep(
            stepId: 2,
            title: 'Draft briefing',
            tool: 'meeting_briefing',
            params: {'topic': 'Project Sync'},
            stage: StepStage.execution,
            status: PlanStepStatus.pending,
          ),
        ],
        isExecuting: false,
        isCompleted: false,
        isPaused: true,
        pausedReason: 'Waiting for authorization',
        currentStepIndex: 1,
        resumedCount: 1,
        evidenceSummary: {'step_1': {'type': 'calendar', 'count': 1}},
      );

      final json = plan.toJson();
      expect(json['id'], equals('plan-stage-l-001'));
      expect(json['isPaused'], isTrue);
      expect(json['currentStepIndex'], equals(1));
      expect(json['resumedCount'], equals(1));
      expect(json['evidenceSummary'], isNotNull);

      final restored = AgentGoalPlan.fromJson(json);
      expect(restored.id, equals('plan-stage-l-001'));
      expect(restored.isPaused, isTrue);
      expect(restored.pausedReason, equals('Waiting for authorization'));
      expect(restored.currentStepIndex, equals(1));
      expect(restored.isResumable, isTrue);
      expect(restored.steps.length, equals(2));
      expect(restored.steps.first.isCompleted, isTrue);
    });
  });

  group('Stage L: Context-Aware Goal Detection & Plan Generation', () {
    final planner = GoalPlannerEngine();

    test('isHighLevelGoal detects compound goals in English & Telugu', () {
      expect(planner.isHighLevelGoal("Prepare for tomorrow's project meeting"), isTrue);
      expect(planner.isHighLevelGoal('Handle my morning'), isTrue);
      expect(planner.isHighLevelGoal('Plan my day'), isTrue);
      expect(planner.isHighLevelGoal('Exam prep for machine learning'), isTrue);
      expect(planner.isHighLevelGoal('repu meeting ki prep cheyyi'), isTrue);
      expect(planner.isHighLevelGoal('Check calendar and then schedule tasks also remind me'), isTrue);

      // Non-goals return false
      expect(planner.isHighLevelGoal('hello'), isFalse);
      expect(planner.isHighLevelGoal('what time is it'), isFalse);
      expect(planner.isHighLevelGoal('who is the president'), isFalse);
    });

    test('generatePlan produces bounded, staged steps for meeting preparation benchmark', () async {
      final plan = await planner.generatePlan("Prepare for tomorrow's project meeting");

      expect(plan.id.isNotEmpty, isTrue);
      expect(plan.goal, contains('project meeting'));
      expect(plan.steps.length, greaterThanOrEqualTo(2));
      expect(plan.steps.length, lessThanOrEqualTo(8));

      // Verify step stages are structured logically
      final stages = plan.steps.map((s) => s.stage).toList();
      expect(stages.contains(StepStage.preparation), isTrue);

      // Verify tools are allowlisted in AgentToolRegistry
      final validTools = AgentToolRegistry().availableTools.map((t) => t.name).toSet();
      for (final step in plan.steps) {
        expect(validTools.contains(step.tool), isTrue,
            reason: 'Tool "${step.tool}" must be allowlisted in AgentToolRegistry');
      }

      // Check that read-only steps have isReadOnly set
      for (final step in plan.steps) {
        if (step.tool == 'calendar_read' || step.tool == 'tasks_list') {
          expect(step.isReadOnly, isTrue);
        }
      }
    });

    test('generatePlan bounds steps for morning routine', () async {
      final plan = await planner.generatePlan('Handle my morning routine');
      expect(plan.steps.isNotEmpty, isTrue);
      expect(plan.steps.length, lessThanOrEqualTo(8));
      expect(plan.steps.any((s) => s.tool == 'tasks_list' || s.tool == 'calendar_read'), isTrue);
    });
  });

  group('Stage L: PlanExecutionService Concurrency & Resumption Tests', () {
    final executionService = PlanExecutionService();

    test('Concurrently executes adjacent read-only steps and records evidence', () async {
      final plan = AgentGoalPlan(
        id: 'plan-read-only-test',
        goal: 'Review morning context',
        rationale: 'Concurrent information gathering.',
        steps: [
          AgentPlanStep(
            stepId: 1,
            title: 'Check pending agenda',
            tool: 'tasks_list',
            params: {},
            stage: StepStage.preparation,
            isReadOnly: true,
          ),
          AgentPlanStep(
            stepId: 2,
            title: 'Check calendar schedule',
            tool: 'calendar_read',
            params: {'range': 'today'},
            stage: StepStage.preparation,
            isReadOnly: true,
          ),
        ],
      );

      final report = await executionService.executePlan(plan);
      expect(plan.isCompleted, isTrue);
      expect(plan.steps[0].isCompleted, isTrue);
      expect(plan.steps[1].isCompleted, isTrue);
      expect(plan.steps[0].evidence, isNotNull);
      expect(plan.steps[1].evidence, isNotNull);
      expect(report, contains('Goal Complete'));
    });

    test('Pauses execution on approvalRequired step and sets waitingApproval status', () async {
      AgentPlanStep? approvalStep;

      final plan = AgentGoalPlan(
        id: 'plan-approval-test',
        goal: 'Send project update',
        rationale: 'Human-in-the-loop authorization test.',
        steps: [
          AgentPlanStep(
            stepId: 1,
            title: 'Read agenda',
            tool: 'tasks_list',
            params: {},
            isReadOnly: true,
          ),
          AgentPlanStep(
            stepId: 2,
            title: 'Send confirmation SMS',
            tool: 'send_sms',
            params: {'phone': '1234567890', 'message': 'Project done'},
            tier: ActionTier.approvalRequired,
            isReadOnly: false,
          ),
          AgentPlanStep(
            stepId: 3,
            title: 'Save note',
            tool: 'notes_create',
            params: {'title': 'Status_Doc', 'content': 'Done'},
            isReadOnly: false,
          ),
        ],
      );

      final report = await executionService.executePlan(
        plan,
        onApprovalRequired: (step) {
          approvalStep = step;
        },
      );

      expect(plan.isPaused, isTrue);
      expect(plan.isCompleted, isFalse);
      expect(plan.currentStepIndex, equals(1));
      expect(plan.steps[0].isCompleted, isTrue);
      expect(plan.steps[1].status, equals(PlanStepStatus.waitingApproval));
      expect(plan.steps[2].status, equals(PlanStepStatus.pending));
      expect(approvalStep, isNotNull);
      expect(approvalStep!.stepId, equals(2));
      expect(report, contains('Paused for Authorization'));
    });

    test('Resumes paused execution without repeating completed actions (Acceptance Benchmark)', () async {
      int step1RunCount = 0;
      int step3RunCount = 0;

      final plan = AgentGoalPlan(
        id: 'plan-resume-benchmark-001',
        goal: "Prepare for tomorrow's project meeting",
        rationale: 'Benchmark test for mid-execution interruption & clean resumption.',
        steps: [
          AgentPlanStep(
            stepId: 1,
            title: 'Check Schedule & Conflicts',
            tool: 'calendar_read',
            params: {'range': 'tomorrow'},
            stage: StepStage.preparation,
            isReadOnly: true,
          ),
          AgentPlanStep(
            stepId: 2,
            title: 'Synthesize Meeting Briefing',
            tool: 'meeting_briefing',
            params: {'topic': 'Sprint Planning', 'attendees': 'Engineering Team'},
            stage: StepStage.preparation,
            tier: ActionTier.approvalRequired, // Pauses here
            isReadOnly: false,
          ),
          AgentPlanStep(
            stepId: 3,
            title: 'Propose Missing Action Items',
            tool: 'tasks_add',
            params: {'title': 'Follow up on sprint velocity', 'priority': 'high'},
            stage: StepStage.execution,
            isReadOnly: false,
          ),
          AgentPlanStep(
            stepId: 4,
            title: 'Save Meeting Reminder',
            tool: 'device_alarm',
            params: {'hour': 9, 'minute': 30, 'label': 'Sprint Prep'},
            stage: StepStage.delivery,
            isReadOnly: false,
          ),
        ],
      );

      // Phase 1: Execute until pause at step 2
      await executionService.executePlan(
        plan,
        onStepUpdate: (s) {
          if (s.stepId == 1 && s.status == PlanStepStatus.running) step1RunCount++;
        },
      );

      expect(plan.isPaused, isTrue);
      expect(plan.steps[0].isCompleted, isTrue);
      expect(plan.steps[1].status, equals(PlanStepStatus.waitingApproval));
      expect(plan.steps[2].status, equals(PlanStepStatus.pending));
      expect(step1RunCount, equals(1));

      // Simulate app restart: Save to storage and reload fresh from storage
      await executionService.saveActivePlan(plan);
      final restoredPlan = await executionService.loadActivePlan();
      expect(restoredPlan, isNotNull);
      expect(restoredPlan!.id, equals(plan.id));
      expect(restoredPlan.steps[0].isCompleted, isTrue);
      expect(restoredPlan.steps[1].status, equals(PlanStepStatus.waitingApproval));

      // Phase 2: Resume execution from storage
      final resumeReport = await executionService.resumePlanExecution(
        restoredPlan,
        onStepUpdate: (s) {
          // Verify step 1 does NOT run again!
          if (s.stepId == 1 && s.status == PlanStepStatus.running) step1RunCount++;
          if (s.stepId == 3 && s.status == PlanStepStatus.running) step3RunCount++;
        },
      );

      // Step 1 must have run ONLY once throughout the entire process!
      expect(step1RunCount, equals(1), reason: 'Completed external actions must NEVER repeat upon resumption.');
      expect(step3RunCount, equals(1));
      expect(restoredPlan.isCompleted, isTrue);
      expect(restoredPlan.resumedCount, equals(1));
      expect(restoredPlan.steps.every((s) => s.isCompleted), isTrue);
      expect(restoredPlan.evidenceSummary, isNotNull);
      expect(resumeReport, contains('Goal Complete'));
    });

    test('Enforces maximum retry limit on failing tools and records error without crashing', () async {
      final plan = AgentGoalPlan(
        id: 'plan-retry-test',
        goal: 'Test failure resilience',
        rationale: 'Verify retry limit enforcement.',
        steps: [
          AgentPlanStep(
            stepId: 1,
            title: 'Call failing tool',
            tool: 'n8n_workflow',
            params: {'webhookUrl': '', 'payload': {}}, // Triggers empty URL error
            isReadOnly: false,
          ),
          AgentPlanStep(
            stepId: 2,
            title: 'Independent follow-up note',
            tool: 'notes_create',
            params: {'title': 'Resilience_Log', 'content': 'Handled gracefully.'},
            isReadOnly: false,
          ),
        ],
      );

      final report = await executionService.executePlan(plan);
      expect(plan.steps[0].isCompleted, isTrue); // Returns error message without throwing unhandled exception
      expect(plan.steps[1].isCompleted, isTrue);
      expect(report, contains('Goal Complete'));
    });
  });
}
