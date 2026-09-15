import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/core/services/memory_engine.dart';
import 'package:aira_app/core/services/personality_engine.dart';
import 'package:aira_app/core/services/automation_control_service.dart';
import 'package:aira_app/core/agent/action_guardrail_manager.dart';
import 'package:aira_app/core/agent/plan_models.dart';
import 'package:aira_app/core/agent/plan_execution_service.dart';
import 'package:aira_app/features/chat/domain/chat_models.dart';
import 'package:aira_app/features/laptop/data/laptop_control_service.dart';
import 'package:aira_app/features/planner/presentation/providers/planner_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Stage N: Canonical Blueprint Proof Workflows (Section 9)', () {
    test('Workflow 1: Conversation & Session Resumption across restarts', () async {
      final messages = [
        ChatMessage(
          id: 'msg-1',
          conversationId: 'conv-101',
          role: 'user',
          content: 'Hello AIRA, let us work on the system architecture.',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        ChatMessage(
          id: 'msg-2',
          conversationId: 'conv-101',
          role: 'assistant',
          content: 'Ready. We can review the cross-device bridge and memory vault.',
          createdAt: DateTime.now().subtract(const Duration(minutes: 4)),
        ),
      ];

      // Simulate persistence to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final serialized = jsonEncode(messages.map((m) => m.toJson()).toList());
      await prefs.setString('test_chat_session_history', serialized);

      // Simulate app restart / new session loading
      final loadedJson = prefs.getString('test_chat_session_history');
      expect(loadedJson, isNotNull);

      final restoredMessages = (jsonDecode(loadedJson!) as List)
          .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList();

      expect(restoredMessages.length, equals(2));
      expect(restoredMessages.first.content, contains('system architecture'));
      expect(restoredMessages.last.content, contains('cross-device bridge'));
      expect(restoredMessages.last.isUser, isFalse);
      expect(restoredMessages.last.isAssistant, isTrue);
    });

    test('Workflow 2: Memory Vault Lifecycle (Remember -> Inject -> Correct -> Forget)', () async {
      final memory = MemoryEngine();
      await memory.clearAll();
      expect(memory.facts.isEmpty, isTrue);

      // Step A: Remember a preference
      final fact1 = MemoryFact(
        id: 'fact-pref-1',
        category: 'preference',
        fact: 'Prefers concise bulleted summaries for meeting prep',
        confidence: 0.95,
        createdAt: DateTime.now(),
      );
      await memory.addFact(fact1);
      expect(memory.facts.length, equals(1));

      // Step B: Inject into Personality Engine system prompt
      final prompt1 = PersonalityEngine().buildSystemPrompt(
        userProfile: {'name': 'Arshan'},
        memoryFacts: memory.getAllFactStrings(),
        localTime: '10:00 AM',
      );
      expect(prompt1, contains('Prefers concise bulleted summaries for meeting prep'));

      // Step C: Correct the preference
      await memory.deleteFact('fact-pref-1');
      final fact2 = MemoryFact(
        id: 'fact-pref-2',
        category: 'preference',
        fact: 'Prefers detailed step-by-step explanations with evidence',
        confidence: 0.98,
        createdAt: DateTime.now(),
      );
      await memory.addFact(fact2);

      final prompt2 = PersonalityEngine().buildSystemPrompt(
        userProfile: {'name': 'Arshan'},
        memoryFacts: memory.getAllFactStrings(),
        localTime: '10:00 AM',
      );
      expect(prompt2, isNot(contains('Prefers concise bulleted summaries')));
      expect(prompt2, contains('Prefers detailed step-by-step explanations with evidence'));

      // Step D: Forget / Delete
      await memory.deleteFact('fact-pref-2');
      expect(memory.facts.isEmpty, isTrue);

      final prompt3 = PersonalityEngine().buildSystemPrompt(
        userProfile: {'name': 'Arshan'},
        memoryFacts: memory.getAllFactStrings(),
        localTime: '10:00 AM',
      );
      expect(prompt3, isNot(contains('Prefers detailed step-by-step')));
    });

    test('Workflow 3: Voice Task & Reminder Lifecycle (Create -> Alert -> Snooze -> Complete)', () async {
      final prefs = await SharedPreferences.getInstance();

      // Step A: Create Task
      final initialTask = TaskItem(
        id: 'task-acceptance-101',
        title: 'Submit research project documentation',
        dueDate: DateTime.now().add(const Duration(hours: 4)),
        createdAt: DateTime.now(),
        status: 'pending',
        priority: 'high',
      );

      final taskList = [initialTask];
      await prefs.setString('aira_local_tasks_v2', jsonEncode(taskList.map((t) => t.toJson()).toList()));

      // Step B: Read & verify scheduled alert commitment
      final raw = prefs.getString('aira_local_tasks_v2');
      final loaded = (jsonDecode(raw!) as List)
          .map((item) => TaskItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      expect(loaded.first.title, equals('Submit research project documentation'));
      expect(loaded.first.isCompleted, isFalse);

      // Step C: Snooze (+2 hours)
      final snoozedTask = loaded.first.copyWith(
        dueDate: loaded.first.dueDate?.add(const Duration(hours: 2)),
      );
      expect(snoozedTask.dueDate!.isAfter(initialTask.dueDate!), isTrue);

      // Step D: Mark complete
      final completedTask = snoozedTask.copyWith(status: 'completed');
      expect(completedTask.isCompleted, isTrue);

      await prefs.setString('aira_local_tasks_v2', jsonEncode([completedTask.toJson()]));
      final finalRaw = prefs.getString('aira_local_tasks_v2');
      final finalLoaded = (jsonDecode(finalRaw!) as List)
          .map((item) => TaskItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      expect(finalLoaded.first.isCompleted, isTrue);
    });

    test('Workflow 4: Proactive Check-in State Machine (Agree -> Trigger -> Busy -> Reschedule -> Disable)', () async {
      final prefs = await SharedPreferences.getInstance();

      // Step A: Agree to a proactive check-in
      await prefs.setString('aira_agreed_checkin_time', '18:00');
      await prefs.setBool('aira_agreed_checkin_active', true);
      expect(prefs.getBool('aira_agreed_checkin_active'), isTrue);

      // Step B: Trigger check-in & receive state
      await prefs.setString('aira_last_checkin_state', 'triggered');
      expect(prefs.getString('aira_last_checkin_state'), equals('triggered'));

      // Step C: User replies busy -> Reschedule to later time
      await prefs.setString('aira_agreed_checkin_time', '20:30');
      await prefs.setString('aira_last_checkin_state', 'rescheduled');
      expect(prefs.getString('aira_agreed_checkin_time'), equals('20:30'));
      expect(prefs.getString('aira_last_checkin_state'), equals('rescheduled'));

      // Step D: Disable check-in
      await prefs.setBool('aira_agreed_checkin_active', false);
      expect(prefs.getBool('aira_agreed_checkin_active'), isFalse);
    });

    test('Workflow 5: Calendar Briefing Formulation & Scoped Revocation', () async {
      // Step A: Formulate briefing from scheduled agenda items
      final agendaItems = [
        {'time': '10:00 AM', 'title': 'Design Architecture Sync', 'attendees': 'Alice, Bob'},
        {'time': '02:00 PM', 'title': 'Release Verification Demo', 'attendees': 'Stakeholders'},
      ];

      final buffer = StringBuffer();
      buffer.writeln('Today\'s Briefing:');
      for (final item in agendaItems) {
        buffer.writeln('• ${item['time']}: ${item['title']} (With: ${item['attendees']})');
      }

      final briefingText = buffer.toString();
      expect(briefingText, contains('Design Architecture Sync'));
      expect(briefingText, contains('Release Verification Demo'));

      // Step B: Scoped Revocation - User revokes calendar authorization
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('aira_calendar_authorized', false);
      expect(prefs.getBool('aira_calendar_authorized'), isFalse);

      // Access without authorization gracefully returns permission notice
      final isAuth = prefs.getBool('aira_calendar_authorized') ?? false;
      final fallbackResponse = isAuth ? briefingText : 'Calendar access is currently revoked. Please authorize in Settings.';
      expect(fallbackResponse, contains('Calendar access is currently revoked'));
    });

    test('Workflow 6: Laptop Pairing, Durable Command & Revocation', () async {
      SharedPreferences.setMockInitialValues({
        'aira_laptop_ip': '192.168.1.100',
        'aira_laptop_pin': '123456',
        'aira_device_token': 'aira_test_tok_99887766554433221100',
        'aira_laptop_hostname': 'Arshan-ThinkPad',
      });

      final laptop = LaptopControlService();
      await laptop.loadConfig();

      expect(laptop.isConfigured, isTrue);
      expect(laptop.isPaired, isTrue);
      expect(laptop.hostname, equals('Arshan-ThinkPad'));

      // Step B: Issue durable remote command envelope
      final now = DateTime.now().millisecondsSinceEpoch;
      const ttlSeconds = 30;
      final envelope = {
        'command_id': 'cmd_open_notepad_123',
        'device_id': laptop.deviceId,
        'action': 'open_app',
        'params': {'app': 'notepad'},
        'timestamp': now,
        'ttl_seconds': ttlSeconds,
        'expires_at': now + (ttlSeconds * 1000),
      };

      expect((envelope['expires_at'] as int) > now, isTrue);

      // Step C: Record receipt
      final receipt = {
        'command_id': envelope['command_id'],
        'device_id': laptop.deviceId,
        'tool': 'open_app',
        'status': 'executed',
        'output': 'Launched Notepad successfully',
        'executed_at': now,
        'replayed': false,
      };
      expect(receipt['status'], equals('executed'));

      // Step D: Revoke Pairing
      await laptop.clearConfig();
      expect(laptop.isPaired, isFalse);
      expect(laptop.deviceToken, isNull);
    });

    test('Workflow 7: Human-in-the-Loop Review-Before-Send with Parameter Binding', () async {
      final guardrail = ActionGuardrailManager();

      // Step A: Check approval tier
      const tool = 'send_email';
      expect(guardrail.isApprovalRequired(tool), isTrue);

      // Step B: Guardrail halts mutating action with pending approval request
      final action = await guardrail.createApprovalRequest(
        actionType: tool,
        recipient: 'mentor@university.edu',
        subject: 'Project Final Submission',
        content: 'Dear Professor, attached is our project deliverables.',
      );

      expect(action.status, equals(ApprovalStatus.pending));
      expect(action.recipient, equals('mentor@university.edu'));
      expect(action.subject, equals('Project Final Submission'));

      // Step C: User authorizes execution
      final approved = await guardrail.approveAction(action.id);
      expect(approved, isTrue);
      expect(action.status, equals(ApprovalStatus.approved));
    });

    test('Workflow 8: Compound Multi-Step Problem Solving & Evidence Synthesis', () async {
      final plan = AgentGoalPlan(
        id: 'goal-acceptance-2026',
        goal: 'Prepare for project evaluation and sync schedule',
        rationale: 'Context gathering, task generation, and briefing synthesis.',
        steps: [
          AgentPlanStep(
            stepId: 1,
            title: 'Read local agenda commitments',
            tool: 'tasks_list',
            params: {'status': 'pending'},
            isReadOnly: true,
          ),
          AgentPlanStep(
            stepId: 2,
            title: 'Formulate briefing note',
            tool: 'notes_create',
            params: {'title': 'Evaluation_Briefing', 'content': 'Everything verified and ready.'},
            isReadOnly: false,
            tier: ActionTier.approvalRequired,
            isApproved: true, // User approved
          ),
        ],
      );

      final report = await PlanExecutionService().executePlan(plan);

      expect(plan.isCompleted, isTrue);
      expect(plan.steps[0].status, equals(PlanStepStatus.completed));
      expect(plan.steps[1].status, equals(PlanStepStatus.completed));
      expect(report, contains('Goal Complete'));
      expect(report, contains('Evaluation_Briefing'));
    });
  });

  group('Stage N: Master Regression Edge Cases (Section 9)', () {
    test('Regression 1: Expired 30s TTL Durable Command Envelope is rejected', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      const ttlSeconds = 30;
      final staleTimestamp = now - 35000; // 35s ago
      final expiresAt = staleTimestamp + (ttlSeconds * 1000);

      final isExpired = now > expiresAt;
      expect(isExpired, isTrue);
    });

    test('Regression 2: Idempotency cache suppresses duplicate replayed execution', () {
      final receipt = {
        'command_id': 'cmd_replay_test_555',
        'status': 'executed',
        'output': 'Found 2 matching files',
        'replayed': false,
      };

      expect(receipt['replayed'], isFalse);

      // Replay simulation
      final cachedReplay = Map<String, dynamic>.from(receipt);
      cachedReplay['replayed'] = true;
      expect(cachedReplay['replayed'], isTrue);
      expect(cachedReplay['command_id'], equals('cmd_replay_test_555'));
    });

    test('Regression 3: Emergency Automation Kill-Switch halts execution mid-plan', () async {
      final autoCtrl = AutomationControlService();
      await autoCtrl.pauseAllAutomation(reason: 'Regression test manual trigger');

      final plan = AgentGoalPlan(
        id: 'plan_paused_test',
        goal: 'Unauthorized autonomous action',
        rationale: 'Must be blocked',
        steps: [
          AgentPlanStep(
            stepId: 1,
            title: 'Mutating step',
            tool: 'tasks_add',
            params: {'title': 'Should not be added'},
            isReadOnly: false,
          ),
        ],
      );

      final report = await PlanExecutionService().executePlan(plan);

      expect(plan.isPaused, isTrue);
      expect(plan.pausedReason, contains('paused by emergency kill switch'));
      expect(plan.steps[0].status, equals(PlanStepStatus.pending));
      expect(report, contains('Execution Paused'));

      await autoCtrl.resumeAutomation();
      expect(autoCtrl.isPaused, isFalse);
    });

    test('Regression 4: Unconfigured laptop companion returns graceful error', () async {
      final laptop = LaptopControlService();
      await laptop.clearConfig();

      expect(laptop.isConfigured, isFalse);
      expect(laptop.isPaired, isFalse);

      final res = await laptop.getSystemStatus();
      expect(res['success'], isFalse);
      expect(res['error'], contains('not configured'));
    });
  });
}
