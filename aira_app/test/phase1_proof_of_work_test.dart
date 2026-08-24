import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/core/agent/goal_planner_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({
    'aira_local_tasks_v2': '[{"id":"t1","title":"OS Deadlock Revision","category":"Study","priority":"high","isCompleted":false}]',
  });

  test('Phase 1 Proof of Work: 3 Distinct Multi-Step Goals Planned and Executed', () async {
    final planner = GoalPlannerEngine();

    final testGoals = [
      'Handle my morning: check today\'s tasks, generate an optimized time-blocked agenda, and check tech news',
      'Prep for my Operating Systems study session: create study note in memory, time block afternoon, and search OS memory management',
      'Good night routine: wrap up today\'s tasks, set wake up alarm for 6:30 AM, and turn off phone flashlight',
    ];

    for (int i = 0; i < testGoals.length; i++) {
      final goal = testGoals[i];
      // 1. Verify Goal Detection
      final isGoal = planner.isHighLevelGoal(goal);
      expect(isGoal, isTrue, reason: 'Goal "$goal" must be detected as a high-level goal');

      // 2. Verify Plan Generation
      final plan = await planner.generatePlan(goal);
      expect(plan.steps, isNotEmpty, reason: 'Plan must have subtasks');
      expect(plan.totalSteps, greaterThanOrEqualTo(2), reason: 'Must decompose into at least 2 atomic steps');
      expect(plan.rationale, isNotEmpty);

      // 3. Verify Step Execution and Status Updates
      final stepUpdates = <int>[];
      final report = await planner.executePlan(
        plan,
        onStepUpdate: (s) {
          stepUpdates.add(s.stepId);
        },
      );

      expect(report, isNotEmpty);
      expect(plan.isCompleted, isTrue);
      expect(plan.completedSteps, greaterThan(0));
      expect(stepUpdates, isNotEmpty);

      print('✅ TEST ${i + 1} PASSED for goal: "$goal" with ${plan.totalSteps} steps.');
    }
  });
}
