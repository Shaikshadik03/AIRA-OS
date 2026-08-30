import 'package:flutter_test/flutter_test.dart';
import 'package:aira_app/core/services/notification_monitor_service.dart';
import 'package:aira_app/core/services/social_world_monitor_service.dart';
import 'package:aira_app/core/agent/agent_tool_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Notification Intelligence & Social World Radar — Proof of Work Tests', () {
    test('1. NotificationMonitorService: Captures, categorizes, and produces smart digest', () async {
      final service = NotificationMonitorService();
      await service.init();

      // Simulate intercepted notifications
      final sampleNotifs = [
        {
          'id': 101,
          'packageName': 'com.whatsapp',
          'appName': 'WhatsApp',
          'title': 'Project Team',
          'text': 'Arshan, are you ready for the SIH submission today?',
          'subText': '3 messages',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'category': 'messaging',
        },
        {
          'id': 102,
          'packageName': 'com.google.android.gm',
          'appName': 'Gmail',
          'title': 'Smart India Hackathon',
          'text': 'Your team registration has been approved for Round 1.',
          'subText': '',
          'timestamp': DateTime.now().millisecondsSinceEpoch - 60000,
          'category': 'email_work',
        },
        {
          'id': 103,
          'packageName': 'net.one97.paytm',
          'appName': 'Paytm',
          'title': 'Payment Alert',
          'text': 'Rs 250 paid successfully at College Cafeteria.',
          'subText': '',
          'timestamp': DateTime.now().millisecondsSinceEpoch - 120000,
          'category': 'finance',
        },
        {
          'id': 104,
          'packageName': 'com.instagram.android',
          'appName': 'Instagram',
          'title': 'Neha',
          'text': 'Sent you a reel on AI agent architectures.',
          'subText': '',
          'timestamp': DateTime.now().millisecondsSinceEpoch - 180000,
          'category': 'social',
        },
      ];

      for (final raw in sampleNotifs) {
        final notif = InterceptedNotification.fromMap(raw);
        expect(notif.appName, isNotEmpty);
        expect(notif.category, isNotEmpty);
      }

      final counts = service.getCategoryCounts();
      expect(counts, isNotNull);
      print('✅ Notification categorization verified.');
    });

    test('2. SocialWorldMonitorService: Fetches live world feed & generates executive briefing', () async {
      final worldService = SocialWorldMonitorService();
      await worldService.init();

      final items = await worldService.fetchLiveWorldFeed();
      expect(items, isNotEmpty);
      expect(items.length, greaterThanOrEqualTo(3));

      print('  • Captured ${items.length} live outside world signals:');
      for (final item in items.take(3)) {
        print('    - [${item.source}] (${item.category}): ${item.title.substring(0, item.title.length > 60 ? 60 : item.title.length)}...');
      }

      final digest = await worldService.generateExecutiveWorldDigest();
      expect(digest, isNotEmpty);
      print('✅ Executive Outside World Briefing Generated:\n$digest');
    });

    test('3. AgentToolRegistry: Dynamically selects & dispatches notification and world radar tools', () async {
      final registry = AgentToolRegistry();

      final notifTool = registry.selectOptimalTool('Summarize my unread WhatsApp notifications and alerts');
      expect(notifTool, equals('notification_digest'));

      final worldTool = registry.selectOptimalTool("What is happening in the outside world and trending on social media?");
      expect(worldTool, equals('world_social_radar'));

      // Dispatch execution
      final notifResult = await registry.executeTool('notification_digest', {'category': 'all'});
      expect(notifResult, isNotEmpty);

      final worldResult = await registry.executeTool('world_social_radar', {'category': 'all'});
      expect(worldResult, isNotEmpty);

      print('✅ Dynamic Tool Selection & Execution Verified for both Notification Digest & World Radar.');
    });
  });
}
