import 'package:flutter_test/flutter_test.dart';
import 'package:aira_app/core/services/android_action_registry.dart';
import 'package:aira_app/core/services/android_action_service.dart';
import 'package:aira_app/features/chat/domain/android_action_detector.dart';
import 'package:aira_app/features/chat/domain/chat_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stage K: AndroidActionRegistry Allowlist & Safety Boundary Tests', () {
    test('allApps catalog contains allowlisted apps across all key categories', () {
      final apps = AndroidActionRegistry.allApps;
      expect(apps.isNotEmpty, isTrue);

      final categories = apps.map((a) => a.category).toSet();
      expect(categories.contains(AndroidActionCategory.communication), isTrue);
      expect(categories.contains(AndroidActionCategory.navigation), isTrue);
      expect(categories.contains(AndroidActionCategory.entertainment), isTrue);
      expect(categories.contains(AndroidActionCategory.foodCommerce), isTrue);
      expect(categories.contains(AndroidActionCategory.productivity), isTrue);
      expect(categories.contains(AndroidActionCategory.protectedSecurity), isTrue);

      // Verify every app has required metadata
      for (final app in apps) {
        expect(app.id.isNotEmpty, isTrue);
        expect(app.name.isNotEmpty, isTrue);
        expect(app.packageName.isNotEmpty, isTrue);
        expect(app.supportedActions.isNotEmpty, isTrue);
      }
    });

    test('findApp retrieves apps by name or alias', () {
      final whatsapp = AndroidActionRegistry.findApp('whatsapp');
      expect(whatsapp, isNotNull);
      expect(whatsapp!.packageName, equals('com.whatsapp'));

      final swiggy = AndroidActionRegistry.findApp('swiggy');
      expect(swiggy, isNotNull);
      expect(swiggy!.category, equals(AndroidActionCategory.foodCommerce));

      final uber = AndroidActionRegistry.findApp('uber');
      expect(uber, isNotNull);
      expect(uber!.category, equals(AndroidActionCategory.navigation));

      final gpay = AndroidActionRegistry.findApp('google pay');
      expect(gpay, isNotNull);
      expect(gpay!.category, equals(AndroidActionCategory.protectedSecurity));
    });

    test('isProtectedSecurityBoundary identifies sensitive apps and critical actions', () {
      expect(AndroidActionRegistry.isProtectedSecurityBoundary('google pay'), isTrue);
      expect(AndroidActionRegistry.isProtectedSecurityBoundary('phonepe'), isTrue);
      expect(AndroidActionRegistry.isProtectedSecurityBoundary('paytm'), isTrue);
      expect(AndroidActionRegistry.isProtectedSecurityBoundary('sbi yono'), isTrue);
      expect(AndroidActionRegistry.isProtectedSecurityBoundary('hdfc bank'), isTrue);
      expect(AndroidActionRegistry.isProtectedSecurityBoundary('bypass lock screen'), isTrue);
      expect(AndroidActionRegistry.isProtectedSecurityBoundary('enter my upi pin'), isTrue);
      expect(AndroidActionRegistry.isProtectedSecurityBoundary('unlock my phone'), isTrue);

      // Normal actions are NOT protected boundaries
      expect(AndroidActionRegistry.isProtectedSecurityBoundary('whatsapp'), isFalse);
      expect(AndroidActionRegistry.isProtectedSecurityBoundary('google maps'), isFalse);
      expect(AndroidActionRegistry.isProtectedSecurityBoundary('swiggy'), isFalse);
    });

    test('getFinishSteps generates actionable guided handoff steps', () {
      final swiggySteps = AndroidActionRegistry.getFinishSteps('Swiggy', 'Biryani');
      expect(swiggySteps.isNotEmpty, isTrue);
      expect(swiggySteps.first, contains('Swiggy'));

      final uberSteps = AndroidActionRegistry.getFinishSteps('Uber', 'Airport');
      expect(uberSteps.isNotEmpty, isTrue);
      expect(uberSteps.any((s) => s.toLowerCase().contains('pickup') || s.toLowerCase().contains('ride')), isTrue);

      final fallbackSteps = AndroidActionRegistry.getFinishSteps('UnknownApp', 'Item');
      expect(fallbackSteps.length, greaterThanOrEqualTo(3));
    });

    test('getSafetyBoundaryExplanation provides explicit boundary reasons', () {
      final upiExpl = AndroidActionRegistry.getSafetyBoundaryExplanation('transfer money via UPI');
      expect(upiExpl, contains('Financial and banking transactions'));
      expect(upiExpl, contains('credentials'));

      final lockExpl = AndroidActionRegistry.getSafetyBoundaryExplanation('bypass screen lock');
      expect(lockExpl, contains('Lock screens, PINs, biometrics'));
    });
  });

  group('Stage K: AndroidActionService Model & Preparation Separation Tests', () {
    final service = AndroidActionService();

    test('prepareMessageDraft creates an un-transmitted draft requiring authorization', () {
      final draft = service.prepareMessageDraft(
        app: 'WhatsApp',
        recipient: 'Rahul',
        message: 'Running 10 mins late',
      );

      expect(draft['actionType'], equals(AndroidActionType.composeMessage.name));
      expect(draft['app'], equals('WhatsApp'));
      expect(draft['recipient'], equals('Rahul'));
      expect(draft['body'], equals('Running 10 mins late'));
      expect(draft['status'], equals('prepared'));
      expect(draft['requiresAuthorization'], isTrue);
    });

    test('prepareCalendarAction pre-populates event data without silent execution', () {
      final startTime = DateTime.now().add(const Duration(hours: 2));
      final event = service.prepareCalendarAction(
        title: 'Project Standup',
        startTime: startTime,
        location: 'Office Room A',
        description: 'Sprint planning',
      );

      expect(event['actionType'], equals(AndroidActionType.calendarEvent.name));
      expect(event['title'], equals('Project Standup'));
      expect(event['startTime'], equals(startTime.millisecondsSinceEpoch));
      expect(event['location'], equals('Office Room A'));
      expect(event['description'], equals('Sprint planning'));
      expect(event['status'], equals('prepared'));
    });

    test('prepareAppTaskHandoff constructs guided handoff structure', () {
      final handoff = service.prepareAppTaskHandoff(
        targetApp: 'Zomato',
        goal: 'Paneer Butter Masala',
        searchQuery: 'Paneer Butter Masala',
      );

      expect(handoff['actionType'], equals(AndroidActionType.taskHandoff.name));
      expect(handoff['targetApp'], equals('Zomato'));
      expect(handoff['goal'], equals('Paneer Butter Masala'));
      expect(handoff['status'], equals('ready_to_launch'));
      expect((handoff['steps'] as List).isNotEmpty, isTrue);
    });

    test('prepareSecurityBoundaryNotice halts protected actions with guardrail notice', () {
      final notice = service.prepareSecurityBoundaryNotice(
        requestedAction: 'transfer money via PhonePe',
        targetApp: 'PhonePe',
      );

      expect(notice['actionType'], equals(AndroidActionType.safetyBoundaryHalted.name));
      expect(notice['targetApp'], equals('PhonePe'));
      expect(notice['status'], equals('halted_by_guardrail'));
      expect(notice['explanation'], isNotEmpty);
    });
  });

  group('Stage K: Bilingual Intent Detection (English & Telugu)', () {
    test('English messaging triggers are parsed accurately', () {
      const q1 = 'draft whatsapp message to Rahul saying I will be late';
      expect(AndroidActionDetector.isAndroidAction(q1), isTrue);
      final cmd1 = AndroidActionDetector.parse(q1);
      expect(cmd1, isNotNull);
      expect(cmd1!.type, equals(AndroidActionType.composeMessage));
      expect(cmd1.actionData, isNotNull);
      expect(cmd1.actionData!['app'], equals('WhatsApp'));
      expect(cmd1.actionData!['recipient'], equals('Rahul'));
      expect(cmd1.actionData!['body'], contains('late'));

      const q2 = 'send text message to Priya saying reached home';
      expect(AndroidActionDetector.isAndroidAction(q2), isTrue);
      final cmd2 = AndroidActionDetector.parse(q2);
      expect(cmd2, isNotNull);
      expect(cmd2!.type, equals(AndroidActionType.composeMessage));
      expect(cmd2.actionData, isNotNull);
      expect(cmd2.actionData!['app'], equals('SMS'));

      const q3 = 'send email to boss@corp.com subject Weekly Report body Here is my report';
      expect(AndroidActionDetector.isAndroidAction(q3), isTrue);
      final cmd3 = AndroidActionDetector.parse(q3);
      expect(cmd3, isNotNull);
      expect(cmd3!.type, equals(AndroidActionType.composeMessage));
      expect(cmd3.actionData, isNotNull);
      expect(cmd3.actionData!['app'], equals('Email'));
      expect(cmd3.actionData!['subject'], equals('Weekly Report'));
    });

    test('Telugu messaging triggers are parsed accurately', () {
      const q1 = 'Rahul ki whatsapp message pampu repu call chesta ani';
      expect(AndroidActionDetector.isAndroidAction(q1), isTrue);
      final cmd1 = AndroidActionDetector.parse(q1);
      expect(cmd1, isNotNull);
      expect(cmd1!.type, equals(AndroidActionType.composeMessage));
      expect(cmd1.actionData, isNotNull);
      expect(cmd1.actionData!['app'], equals('WhatsApp'));
      expect(cmd1.actionData!['recipient'], equals('Rahul'));

      const q2 = 'Priya ki sms pampu reached safely ani';
      expect(AndroidActionDetector.isAndroidAction(q2), isTrue);
      final cmd2 = AndroidActionDetector.parse(q2);
      expect(cmd2, isNotNull);
      expect(cmd2!.type, equals(AndroidActionType.composeMessage));
      expect(cmd2.actionData, isNotNull);
      expect(cmd2.actionData!['app'], equals('SMS'));
    });

    test('English & Telugu calendar event triggers are parsed', () {
      const q1 = 'schedule meeting with client tomorrow at 4pm';
      expect(AndroidActionDetector.isAndroidAction(q1), isTrue);
      final cmd1 = AndroidActionDetector.parse(q1);
      expect(cmd1, isNotNull);
      expect(cmd1!.type, equals(AndroidActionType.calendarEvent));
      expect(cmd1.actionData, isNotNull);
      expect(cmd1.actionData!['title'], contains('client'));

      const q2 = 'repu 10am ki doctor appointment calendar lo add cheyyi';
      expect(AndroidActionDetector.isAndroidAction(q2), isTrue);
      final cmd2 = AndroidActionDetector.parse(q2);
      expect(cmd2, isNotNull);
      expect(cmd2!.type, equals(AndroidActionType.calendarEvent));
      expect(cmd2.actionData, isNotNull);
      expect(cmd2.actionData!['title'].toString().toLowerCase(), contains('doctor appointment'));
    });

    test('English & Telugu navigation triggers are parsed', () {
      const q1 = 'navigate to Rajiv Gandhi International Airport';
      expect(AndroidActionDetector.isAndroidAction(q1), isTrue);
      final cmd1 = AndroidActionDetector.parse(q1);
      expect(cmd1, isNotNull);
      expect(cmd1!.type, equals(AndroidActionType.navigateMaps));
      expect(cmd1.actionData, isNotNull);
      expect(cmd1.actionData!['destination'], contains('Airport'));

      const q2 = 'Charminar ki route chupinchu';
      expect(AndroidActionDetector.isAndroidAction(q2), isTrue);
      final cmd2 = AndroidActionDetector.parse(q2);
      expect(cmd2, isNotNull);
      expect(cmd2!.type, equals(AndroidActionType.navigateMaps));
      expect(cmd2.actionData, isNotNull);
      expect(cmd2.actionData!['destination'], contains('Charminar'));
    });

    test('English & Telugu media playback triggers are parsed', () {
      const q1 = 'pause music';
      expect(AndroidActionDetector.isAndroidAction(q1), isTrue);
      final cmd1 = AndroidActionDetector.parse(q1);
      expect(cmd1, isNotNull);
      expect(cmd1!.type, equals(AndroidActionType.controlMedia));
      expect(cmd1.actionData, isNotNull);
      expect(cmd1.actionData!['action'], equals('pause'));

      const q2 = 'patalu play cheyyi';
      expect(AndroidActionDetector.isAndroidAction(q2), isTrue);
      final cmd2 = AndroidActionDetector.parse(q2);
      expect(cmd2, isNotNull);
      expect(cmd2!.type, equals(AndroidActionType.controlMedia));
      expect(cmd2.actionData, isNotNull);
      expect(cmd2.actionData!['action'], equals('play'));
    });

    test('English & Telugu guided task handoffs are parsed', () {
      const q1 = 'order Biryani on Swiggy';
      expect(AndroidActionDetector.isAndroidAction(q1), isTrue);
      final cmd1 = AndroidActionDetector.parse(q1);
      expect(cmd1, isNotNull);
      expect(cmd1!.type, equals(AndroidActionType.taskHandoff));
      expect(cmd1.actionData, isNotNull);
      expect(cmd1.actionData!['targetApp'], equals('Swiggy'));

      const q2 = 'Uber lo cab book cheyyi';
      expect(AndroidActionDetector.isAndroidAction(q2), isTrue);
      final cmd2 = AndroidActionDetector.parse(q2);
      expect(cmd2, isNotNull);
      expect(cmd2!.type, equals(AndroidActionType.taskHandoff));
      expect(cmd2.actionData, isNotNull);
      expect(cmd2.actionData!['targetApp'], equals('Uber'));
    });

    test('Protected banking and lockscreen requests trigger safety guardrail halts', () {
      const q1 = 'transfer 5000 rupees using google pay';
      expect(AndroidActionDetector.isAndroidAction(q1), isTrue);
      final cmd1 = AndroidActionDetector.parse(q1);
      expect(cmd1, isNotNull);
      expect(cmd1!.type, equals(AndroidActionType.safetyBoundaryHalted));
      expect(cmd1.actionData, isNotNull);
      expect(cmd1.actionData!['status'], equals('halted_by_guardrail'));

      const q2 = 'phonepe lo dabbulu pampu';
      expect(AndroidActionDetector.isAndroidAction(q2), isTrue);
      final cmd2 = AndroidActionDetector.parse(q2);
      expect(cmd2, isNotNull);
      expect(cmd2!.type, equals(AndroidActionType.safetyBoundaryHalted));

      const q3 = 'bypass phone lock screen';
      expect(AndroidActionDetector.isAndroidAction(q3), isTrue);
      final cmd3 = AndroidActionDetector.parse(q3);
      expect(cmd3, isNotNull);
      expect(cmd3!.type, equals(AndroidActionType.safetyBoundaryHalted));
      expect(cmd3.actionData, isNotNull);
      expect(cmd3.actionData!['explanation'], contains('Lock screens'));
    });
  });

  group('Stage K: ChatMessage Serialization with androidActionData', () {
    test('ChatMessage serializes and deserializes androidActionData correctly', () {
      final msg = ChatMessage(
        id: 'msg-k-1',
        conversationId: 'c1',
        role: 'assistant',
        content: 'Prepared WhatsApp draft',
        createdAt: DateTime.now(),
        androidActionData: {
          'actionType': 'composeMessage',
          'app': 'WhatsApp',
          'recipient': 'Alice',
          'body': 'Meeting at 5',
          'status': 'prepared',
          'requiresAuthorization': true,
        },
      );

      final json = msg.toJson();
      expect(json['androidActionData'], isNotNull);
      expect(json['androidActionData']['app'], equals('WhatsApp'));

      final restored = ChatMessage.fromJson(json);
      expect(restored.androidActionData, isNotNull);
      expect(restored.androidActionData!['app'], equals('WhatsApp'));
      expect(restored.androidActionData!['requiresAuthorization'], isTrue);
    });

    test('ChatMessage copyWith preserves or updates androidActionData', () {
      final msg = ChatMessage(
        id: 'msg-k-2',
        conversationId: 'c1',
        role: 'assistant',
        content: 'Initial message',
        createdAt: DateTime.now(),
      );

      final updated = msg.copyWith(
        androidActionData: {
          'actionType': 'navigateMaps',
          'destination': 'Hyderabad',
          'status': 'launched',
        },
      );

      expect(updated.androidActionData, isNotNull);
      expect(updated.androidActionData!['destination'], equals('Hyderabad'));
    });
  });
}
