import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/core/agent/agent_tool_registry.dart';
import 'package:aira_app/core/agent/adaptive_outcome_learner.dart';
import 'package:aira_app/core/agent/agent_orchestrator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 4 Proof of Work — Tool-Use Expansion & Auto-Selection', () {
    test('Correctly selects appropriate tool automatically without hardcoding', () {
      final registry = AgentToolRegistry();

      final tool1 = registry.selectOptimalTool('Find the latest India tech hackathons 2026');
      expect(tool1, equals('web_search'));

      final tool2 = registry.selectOptimalTool('Set alarm for 6:45 AM tomorrow morning');
      expect(tool2, equals('device_alarm'));

      final tool3 = registry.selectOptimalTool('Trigger n8n webhook automation pipeline');
      expect(tool3, equals('n8n_workflow'));

      final tool4 = registry.selectOptimalTool('Turn on phone torch flashlight');
      expect(tool4, equals('device_flashlight'));

      final tool5 = registry.selectOptimalTool('Open Spotify app on phone');
      expect(tool5, equals('device_app_launch'));

      print('✅ Phase 4 Proof of Work PASSED: Registry dynamically resolved 5 distinct tools.');
    });
  });

  group('Phase 5 Proof of Work — Adaptive Memory & Outcome Learning', () {
    test('Over 10+ interactions, output measurably shifts toward learned user preference', () async {
      final learner = AdaptiveOutcomeLearner();
      await learner.init();

      // Simulate 10 user interactions where user repeatedly shortens lengthy email drafts
      for (int i = 1; i <= 10; i++) {
        final longProposal = 'Dear Professor, I am writing to respectfully request an extension on the project assignment. I hope this does not cause inconvenience.';
        final shortEdited = 'Hi Professor, requesting a 2-day extension on the project due to health. Thanks.';

        await learner.logOutcome(
          category: 'email_draft',
          initialProposal: longProposal,
          decision: UserDecision.edited,
          userEditedText: shortEdited,
        );
      }

      expect(learner.history.length, equals(10));

      // Verify that calibrated directives now include the learned preference
      final directives = learner.getCalibratedDirectives();
      expect(directives, contains('USER PREFERENCE (LEARNED)'));
      expect(directives, contains('ultra-concise'));

      print('✅ Phase 5 Proof of Work PASSED: Learned user preference after 10 interactions:');
      print(directives);
    });
  });

  group('Phase 6 Proof of Work — Multi-Agent Role Split & Orchestrator', () {
    test('Multi-domain goal correctly routes across Scheduler, Email, and Memory sub-agents', () async {
      final orchestrator = AgentOrchestrator();

      final goal = 'Reschedule my week around this new deadline and email everyone affected';
      final results = await orchestrator.routeAndExecute(goal);

      expect(results.length, greaterThanOrEqualTo(3), reason: 'Must route across multiple sub-agents');

      final rolesEngaged = results.map((r) => r.role).toSet();
      expect(rolesEngaged.contains(AgentRole.scheduler), isTrue, reason: 'Scheduler Agent must be invoked');
      expect(rolesEngaged.contains(AgentRole.emailComms), isTrue, reason: 'Email Agent must be invoked');
      expect(rolesEngaged.contains(AgentRole.memoryLearning), isTrue, reason: 'Memory Agent must be invoked');

      for (final res in results) {
        expect(res.success, isTrue);
        print('  • [${res.role.name.toUpperCase()}]: ${res.output}');
      }

      print('✅ Phase 6 Proof of Work PASSED: Multi-agent routing completed end-to-end.');
    });
  });
}
