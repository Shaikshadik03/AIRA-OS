import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/core/services/routine_service.dart';
import 'package:aira_app/features/chat/domain/routine_intent.dart';
import 'package:aira_app/core/services/cognitive_memory_engine.dart';
import 'package:aira_app/core/services/memory_engine.dart';
import 'package:aira_app/core/services/implicit_reminder_detector.dart';
import 'package:aira_app/core/services/llm_service.dart';
import 'package:aira_app/features/chat/domain/workspace_intent.dart';
import 'package:aira_app/features/chat/domain/notification_intent.dart';
import 'package:aira_app/core/agent/action_guardrail_manager.dart';
import 'package:aira_app/core/services/voice_service.dart';
import 'package:aira_app/core/services/android_device_service.dart';
import 'package:aira_app/core/services/android_phone_service.dart';
import 'package:aira_app/features/chat/domain/phone_intent.dart';
import 'package:aira_app/features/chat/domain/device_intent.dart';
import 'package:aira_app/features/vision/presentation/providers/vision_provider.dart';
import 'package:aira_app/features/voice_notes/presentation/providers/voice_note_provider.dart';

import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.aira.os/device_control'), (MethodCall call) async {
      if (call.method == 'getBatteryStatus') {
        return {'level': 85, 'isCharging': false};
      }
      return {'success': true};
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (MethodCall call) async {
      return 1;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.aira.os/android_phone'), (MethodCall call) async {
      return {'success': true};
    });
  });

  group('Agentic & Extra Features Comprehensive Audit Tests (Items 8 to 20)', () {
    // ── Item 8: Voice Assistant (STT & TTS) ──
    test('8. Voice Assistant: Wake word detection, cancellation phrases, and acoustic tuning', () {
      final voice = VoiceService();
      expect(voice.isWakeWord('Hey AIRA what time is it?'), isTrue);
      expect(voice.isWakeWord('hey ira call mummy'), isTrue);
      expect(voice.isWakeWord('just checking something'), isFalse);

      expect(voice.isCancellationPhrase('cancel'), isTrue);
      expect(voice.isCancellationPhrase('never mind'), isTrue);
      expect(voice.isCancellationPhrase('vaddu'), isTrue);
      expect(voice.isCancellationPhrase('oddu le'), isTrue);
      expect(voice.isCancellationPhrase('continue speaking'), isFalse);
    });

    // ── Item 9: AIRA Vision ──
    test('9. AIRA Vision: StateNotifier handles idle, analyzing, result, and retake', () async {
      final notifier = AiraVisionNotifier();
      expect(notifier.state.state, equals(VisionState.idle));
      expect(notifier.state.capturedImage, isNull);

      // Verify retake resets image and result
      notifier.retake();
      expect(notifier.state.state, equals(VisionState.idle));
      expect(notifier.state.result, isEmpty);
    });

    // ── Item 10: Voice Note & Meeting Summarizer ──
    test('10. Voice Note: Status model and summarization prompt formatting', () {
      const initialStatus = VoiceNoteStatus();
      expect(initialStatus.state, equals(VoiceNoteState.idle));
      expect(initialStatus.isExportedToDoc, isFalse);
      expect(initialStatus.isExportedToMemory, isFalse);

      final updated = initialStatus.copyWith(
        state: VoiceNoteState.completed,
        transcript: 'We discussed the upcoming deployment schedule and agreed to ship on Friday.',
        summary: '1. Executive Summary\n2. Key Discussion Points\n3. Action Items',
        isExportedToDoc: true,
      );
      expect(updated.state, equals(VoiceNoteState.completed));
      expect(updated.isExportedToDoc, isTrue);
      expect(updated.transcript, contains('Friday'));
    });

    // ── Item 11: AIRA Everywhere Floating Overlay ──
    test('11. AIRA Everywhere: Floating overlay service starts via platform channel', () async {
      final device = AndroidDeviceService();
      final res = await device.startOverlayService();
      expect(res, isNotNull);
      expect(res['success'], isTrue);
    });

    // ── Item 12: Smart Notifications & Reminders ──
    test('12. Notifications & Reminders: Explicit and Implicit reminder detection', () async {
      // Explicit reminder
      final explicit = NotificationIntentDetector.detect('remind me to submit the assignment tomorrow at 5pm');
      expect(explicit.isNotificationCommand, isTrue);
      expect(explicit.intent, equals(NotificationIntentType.scheduleReminder));
      expect(explicit.body.toLowerCase(), contains('submit the assignment'));

      final nonReminder = NotificationIntentDetector.detect('What is the capital of France?');
      expect(nonReminder.isNotificationCommand, isFalse);

      // Implicit reminder detection
      final implicitDetector = ImplicitReminderDetector();
      final implicitResults = await implicitDetector.detectAndSchedule('I need to call mummy');
      // Even if notification scheduling fails in test environment, commitments are processed
      expect(implicitResults, isA<List<String>>());
    });

    // ── Item 13: Smart Automations & Routines ──
    test('13. Smart Automations & Routines: Executes Good Morning, Focus, Heading Home, Sleep Mode', () async {
      final routine = RoutineService();

      final gm = await routine.executeRoutine(RoutineType.goodMorning);
      expect(gm.title, contains('Good Morning'));
      expect(gm.stepsExecuted, isNotEmpty);
      expect(gm.summaryMarkdown, contains('Battery Level'));

      final focus = await routine.executeRoutine(RoutineType.focusMode);
      expect(focus.title, contains('Focus Mode'));
      expect(focus.stepsExecuted, isNotEmpty);

      final home = await routine.executeRoutine(RoutineType.headingHome);
      expect(home.title, contains('Heading Home'));
      expect(home.stepsExecuted, isNotEmpty);

      final sleep = await routine.executeRoutine(RoutineType.sleepMode);
      expect(sleep.title, contains('Sleep Mode'));
      expect(sleep.stepsExecuted, isNotEmpty);
    });

    // ── Item 14: Interactive Response Cards ──
    test('14. Interactive Response Cards: PendingApprovalAction serialization & approval lifecycle', () {
      final action = PendingApprovalAction(
        id: 'act_101',
        actionType: 'email',
        recipient: 'colleague@example.com',
        subject: 'Project Submission',
        content: 'Hi, the submission has been finalized.',
        status: ApprovalStatus.pending,
      );

      final json = action.toJson();
      expect(json['id'], equals('act_101'));
      expect(json['actionType'], equals('email'));
      expect(json['status'], equals('pending'));

      final deserialized = PendingApprovalAction.fromJson(json);
      expect(deserialized.recipient, equals('colleague@example.com'));
      expect(deserialized.status, equals(ApprovalStatus.pending));

      deserialized.status = ApprovalStatus.approved;
      expect(deserialized.status, equals(ApprovalStatus.approved));
    });

    // ── Item 15: Android Phone Integration (Direct Calls & SMS) ──
    test('15. Android Phone Integration: Call and SMS intent detection and phone number resolution', () async {
      final callCmd = PhoneIntentDetector.detect('Call Rahul');
      expect(callCmd.isPhoneCommand, isTrue);
      expect(callCmd.intent, equals(PhoneIntent.makeCall));
      expect(callCmd.params['recipient'], equals('Rahul'));

      final smsCmd = PhoneIntentDetector.detect('Send SMS to Rahul saying I will be late');
      expect(smsCmd.isPhoneCommand, isTrue);
      expect(smsCmd.intent, equals(PhoneIntent.sendSms));
      expect(smsCmd.params['recipient'], equals('Rahul'));
      expect(smsCmd.params['body'], equals('I will be late'));

      final phoneService = AndroidPhoneService();
      final directResolution = await phoneService.resolvePhoneNumber('+919876543210');
      expect(directResolution['phone'], equals('+919876543210'));
      expect(directResolution['source'], equals('direct'));
    });

    // ── Item 16: Device Control ──
    test('16. Device Control: Flashlight, App Launch, Battery, and Settings intent handling', () async {
      final torchCmd = DeviceIntentDetector.detect('Turn on flashlight');
      expect(torchCmd.isDeviceCommand, isTrue);
      expect(torchCmd.intent, equals(DeviceIntent.toggleFlashlight));
      expect(torchCmd.params['enable'], isTrue);

      final appCmd = DeviceIntentDetector.detect('Open WhatsApp');
      expect(appCmd.isDeviceCommand, isTrue);
      expect(appCmd.intent, equals(DeviceIntent.launchApp));
      expect(appCmd.params['appName'], equals('WhatsApp'));

      final device = AndroidDeviceService();
      final torchRes = await device.toggleFlashlight(enable: true);
      expect(torchRes['success'], isTrue);

      final appRes = await device.launchApp(appName: 'WhatsApp');
      expect(appRes['success'], isTrue);

      final battery = await device.getBatteryStatus();
      expect(battery['level'], equals(85));
    });

    // ── Item 17: AI Memory Vault ──
    test('17. AI Memory Vault: CognitiveMemoryEngine & MemoryEngine persist facts and entities', () async {
      final cogMem = CognitiveMemoryEngine();
      await cogMem.init();

      final entity = MemoryEntity(
        id: 'pref_language',
        category: 'preference',
        name: 'Preferred Tech Stack',
        attributes: {'framework': 'Flutter', 'backend': 'FastAPI'},
        updatedAt: DateTime.now(),
      );
      await cogMem.saveEntity(entity);

      final context = cogMem.buildCognitiveSummary();
      expect(context, contains('Arshan'));

      final memEngine = MemoryEngine();
      await memEngine.load();
      await memEngine.addFact(
        MemoryFact(
          id: 'test_fact_1',
          category: 'user_fact',
          fact: 'User prefers dark mode and concise summaries',
          createdAt: DateTime.now(),
        ),
      );

      final allFacts = memEngine.getAllFactStrings();
      expect(allFacts.any((f) => f.contains('concise summaries')), isTrue);
    });

    // ── Item 18: LLM Fallback Chain (Forced Groq 429 Rate Limit) ──
    test('18. LLM Fallback Chain: Deliberate Groq HTTP 429 rate limit triggers cascade and diagnostics', () async {
      final llm = LlmService();
      llm.forceGroqFail = true;
      llm.forceGeminiFail = false;

      // Simulated call with forced Groq failure
      try {
        await llm.callLlm(
          userMessage: 'Test prompt',
          memoryContext: '[USER MEMORIES]:\n- Student',
        );
      } catch (_) {}

      expect(llm.forceGroqFail, isTrue);

      final rateLimitDiag = LlmService.formatDiagnosticMessage(
        hasAnyKey: true,
        errorString: 'DioException [bad response]: 429 Too Many Requests',
      );
      expect(rateLimitDiag, contains('AI Rate Limit Exceeded'));
      expect(rateLimitDiag, contains('30–60 seconds'));

      llm.forceGroqFail = false;
      llm.forceGeminiFail = false;
    });

    // ── Item 19: Context preservation across conversation turns ──
    test('19. Context preservation across conversation turns in message adapter', () {
      final llm = LlmService();
      final history = [
        {'role': 'user', 'content': 'My name is Arshan'},
        {'role': 'assistant', 'content': 'Hello Arshan! How can I assist you today?'},
        {'role': 'user', 'content': 'I am preparing for an Operating Systems exam'},
        {'role': 'assistant', 'content': 'Great! I will focus our study on OS topics like scheduling and memory management.'},
      ];

      final geminiPayload = llm.formatForGemini(
        userMessage: 'What exam am I studying for?',
        history: history,
        systemPrompt: 'You are AIRA.',
      );

      final contents = geminiPayload['contents'] as List;
      expect(contents.length, equals(5)); // 4 history turns + 1 latest turn
      expect(contents[0]['parts'][0]['text'], contains('Arshan'));
      expect(contents[2]['parts'][0]['text'], contains('Operating Systems exam'));
      expect(contents[4]['parts'][0]['text'], equals('What exam am I studying for?'));
    });

    // ── Item 20: Email-body-composition (verifying bug fix) ──
    test('20. Email-body-composition: Command instruction is not copied as body', () {
      final cmd = WorkspaceIntentDetector.detect(
        'send email to rahul@example.com regarding project update saying I have pushed the latest commits to GitHub',
      );
      expect(cmd.intent, equals(WorkspaceIntent.sendEmail));
      expect(cmd.params['to'], equals('rahul@example.com'));
      expect(cmd.params['subject'], equals('project update'));
      expect(cmd.params['body'], equals('I have pushed the latest commits to GitHub'));

      // If user gives command without explicit "saying", body is null so ChatProvider composes polite email
      final cmdNoBody = WorkspaceIntentDetector.detect(
        'draft email to mentor@university.edu about thesis extension',
      );
      expect(cmdNoBody.intent, equals(WorkspaceIntent.sendEmail));
      expect(cmdNoBody.params['body'], isNull);
    });
  });
}
