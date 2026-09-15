import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/core/services/automation_control_service.dart';
import 'package:aira_app/core/services/diagnostic_logger.dart';
import 'package:aira_app/core/services/usage_metrics_service.dart';
import 'package:aira_app/core/services/setup_checklist_service.dart';
import 'package:aira_app/core/services/data_backup_service.dart';
import 'package:aira_app/core/services/user_profile_service.dart';
import 'package:aira_app/core/services/memory_engine.dart';
import 'package:aira_app/core/agent/plan_models.dart';
import 'package:aira_app/core/agent/plan_execution_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Stage M: Setup Checklist & Readiness Tests', () {
    test('evaluateReadiness accurately scores pillars and calculates readiness percentage', () async {
      SharedPreferences.setMockInitialValues({
        'aira_custom_groq_key': 'gsk_test_mock_groq_key_1234567890',
        'aira_user_profile': jsonEncode({
          'displayName': 'Arshan',
          'dailyWakeTime': '07:00 AM',
        }),
      });

      await UserProfileService().load();
      final report = await SetupChecklistService().evaluateReadiness();

      expect(report.totalCount, equals(6));
      expect(report.items.any((i) => i.id == 'ai_brain_key' && i.isCompleted), isTrue);
      expect(report.items.any((i) => i.id == 'user_profile' && i.isCompleted), isTrue);
      expect(report.completedCount, greaterThanOrEqualTo(2));
      expect(report.readinessPercentage, greaterThan(0));
    });
  });

  group('Stage M: Redacted Diagnostic Logger Tests', () {
    test('DiagnosticLogger sanitizes API keys, bearer tokens, emails and phone numbers', () {
      final logger = DiagnosticLogger();
      logger.clear();

      const rawSecretMessage =
          'User arshan@test.com with phone +91 9876543210 used key gsk_abcdef1234567890_groq_secret and Gemini AIzaSyABCDEF1234567890_key with header Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';

      logger.info('AUTH_TEST', rawSecretMessage);

      final exported = logger.exportRedactedLogs();
      expect(exported, isNot(contains('gsk_abcdef1234567890_groq_secret')));
      expect(exported, isNot(contains('AIzaSyABCDEF1234567890_key')));
      expect(exported, isNot(contains('arshan@test.com')));
      expect(exported, isNot(contains('+91 9876543210')));
      expect(exported, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')));

      expect(exported, contains('[REDACTED_GROQ_KEY]'));
      expect(exported, contains('[REDACTED_GEMINI_KEY]'));
      expect(exported, contains('[REDACTED_EMAIL]'));
      expect(exported, contains('[REDACTED_PHONE]'));
      expect(exported, contains('[REDACTED_TOKEN]'));
    });

    test('DiagnosticLogger preserves severity and tags in circular buffer', () {
      final logger = DiagnosticLogger();
      logger.clear();

      logger.warn('NETWORK', 'Latency spike detected on Groq endpoint.');
      logger.error('STORAGE', 'Failed disk check', 'I/O Timeout');
      logger.automation('PLANNER', 'Executed 3 goal steps.');

      expect(logger.logs.length, equals(3));
      expect(logger.logs[0].severity, equals(LogSeverity.warn));
      expect(logger.logs[1].severity, equals(LogSeverity.error));
      expect(logger.logs[2].severity, equals(LogSeverity.automation));
    });
  });

  group('Stage M: Reliability & Usage Metrics Tests', () {
    test('UsageMetricsService records and computes queries, latency, and success rates', () async {
      final metrics = UsageMetricsService();
      await metrics.resetMetrics();

      metrics.recordQuery();
      metrics.recordQuery();
      expect(metrics.totalQueries, equals(2));

      metrics.recordToolOutcome(success: true);
      metrics.recordToolOutcome(success: true);
      metrics.recordToolOutcome(success: false);

      expect(metrics.successfulToolExecutions, equals(2));
      expect(metrics.failedToolExecutions, equals(1));
      expect(metrics.errorRatePercent, closeTo(33.3, 0.5));
      expect(metrics.toolSuccessRatePercent, closeTo(66.7, 0.5));

      metrics.recordLlmCall(latencyMs: 300, success: true);
      metrics.recordLlmCall(latencyMs: 500, success: true);
      expect(metrics.totalLlmCalls, equals(2));
      expect(metrics.averageLatencyMs, equals(400));
    });
  });

  group('Stage M: Emergency Automation Kill-Switch Tests', () {
    test('pauseAllAutomation immediately blocks plan execution and sets paused reason', () async {
      final autoCtrl = AutomationControlService();
      await autoCtrl.init();
      expect(autoCtrl.isPaused, isFalse);

      await autoCtrl.pauseAllAutomation(reason: 'Critical user manual pause');
      expect(autoCtrl.isPaused, isTrue);
      expect(autoCtrl.pausedReason, equals('Critical user manual pause'));
      expect(autoCtrl.isPausedNotifier.value, isTrue);

      // Verify that goal plan execution is immediately blocked
      final plan = AgentGoalPlan(
        id: 'blocked-plan-1',
        goal: 'Attempt autonomous task during pause',
        rationale: 'Must be blocked by kill-switch.',
        steps: [
          AgentPlanStep(
            stepId: 1,
            title: 'Unauthorized step',
            tool: 'notes_create',
            params: {'title': 'Should_Not_Exist', 'content': 'Blocked'},
            isReadOnly: false,
          ),
        ],
      );

      final report = await PlanExecutionService().executePlan(plan);
      expect(plan.isPaused, isTrue);
      expect(plan.pausedReason, contains('paused by emergency kill switch'));
      expect(report, contains('Execution Paused'));
      expect(plan.steps[0].status, equals(PlanStepStatus.pending)); // Step was NOT executed!

      // Resume automations
      await autoCtrl.resumeAutomation();
      expect(autoCtrl.isPaused, isFalse);
      expect(autoCtrl.isPausedNotifier.value, isFalse);
    });
  });

  group('Stage M: Data Backup, Restore & GDPR Data Wipe Tests', () {
    test('exportBackupJson exports versioned envelope with profile, memories, and tasks', () async {
      SharedPreferences.setMockInitialValues({
        'aira_local_tasks_v2': jsonEncode([
          {'id': 't1', 'title': 'Ship Stage M', 'isCompleted': false},
        ]),
        'aira_note_Demo_Note_123': 'Demo_Note\n\nSecret testing briefing',
      });

      await UserProfileService().updateProfile({
        'name': 'Arshan',
        'role': 'AI Engineer',
        'wake_time': '06:30 AM',
        'sleep_time': '11:00 PM',
        'style': 'Deep work',
        'habits': ['Running', 'Reading'],
        'goals': ['Master AIRA OS'],
      });

      await MemoryEngine().addFact(MemoryFact(
        id: 'fact-1',
        category: 'work',
        fact: 'Arshan is building AIRA OS',
        createdAt: DateTime.now(),
      ));

      final backupJson = await DataBackupService().exportBackupJson();
      final decoded = jsonDecode(backupJson) as Map<String, dynamic>;

      expect(decoded['aira_backup_version'], equals(1));
      expect(decoded['data']['profile']['name'], equals('Arshan'));
      expect((decoded['data']['memory_facts'] as List).length, equals(1));
      expect((decoded['data']['tasks'] as List).length, equals(1));
      expect((decoded['data']['notes'] as Map).containsKey('aira_note_Demo_Note_123'), isTrue);
    });

    test('restoreBackupJson cleanly restores state and deleteAllData erases all storage', () async {
      final testBackup = jsonEncode({
        'aira_backup_version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'data': {
          'profile': {'name': 'Restored User', 'workStyle': 'Focus'},
          'memory_facts': [
            {'id': 'm1', 'category': 'lifestyle', 'fact': 'Loves dark roast coffee', 'confidence': 0.95, 'created_at': DateTime.now().toIso8601String()}
          ],
          'tasks': [
            {'id': 't_restored', 'title': 'Complete Review', 'isCompleted': false}
          ],
          'notes': {
            'aira_note_Restored_Note': 'Restored_Note\n\nContent restored from cloud backup'
          },
        }
      });

      final restoreResult = await DataBackupService().restoreBackupJson(testBackup);
      expect(restoreResult['success'], isTrue);
      expect(UserProfileService().displayName, equals('Restored User'));
      expect(MemoryEngine().facts.any((f) => f.fact.contains('dark roast coffee')), isTrue);

      // Now verify GDPR Complete Wipe
      final wipeResult = await DataBackupService().deleteAllData();
      expect(wipeResult, isTrue);

      expect(MemoryEngine().facts.isEmpty, isTrue);
      expect(UserProfileService().displayName, equals('there'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('aira_local_tasks_v2'), isNull);
      expect(prefs.getString('aira_note_Restored_Note'), isNull);
    });
  });
}
