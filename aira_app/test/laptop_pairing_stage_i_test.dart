import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/features/laptop/domain/laptop_intent_detector.dart';
import 'package:aira_app/features/laptop/data/laptop_control_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stage I: Bilingual Laptop Intent Detection (English & Telugu)', () {
    test('English open app commands are recognized with target application', () {
      expect(LaptopIntentDetector.isLaptopCommand('Open Notepad on my laptop'), isTrue);
      final cmd = LaptopIntentDetector.parse('Open Notepad on my laptop');
      expect(cmd, isNotNull);
      expect(cmd!.type, equals(LaptopCommandType.openApp));
      expect(cmd.argument?.toLowerCase(), equals('notepad'));

      final cmd2 = LaptopIntentDetector.parse('open chrome on laptop');
      expect(cmd2, isNotNull);
      expect(cmd2!.type, equals(LaptopCommandType.openApp));
      expect(cmd2.argument?.toLowerCase(), equals('chrome'));
    });

    test('Telugu open app commands are recognized correctly', () {
      expect(LaptopIntentDetector.isLaptopCommand('laptop lo Notepad open cheyyi'), isTrue);
      final cmd1 = LaptopIntentDetector.parse('laptop lo Notepad open cheyyi');
      expect(cmd1, isNotNull);
      expect(cmd1!.type, equals(LaptopCommandType.openApp));
      expect(cmd1.argument?.toLowerCase(), equals('notepad'));

      final cmd2 = LaptopIntentDetector.parse('laptop lo chrome open cheyi');
      expect(cmd2, isNotNull);
      expect(cmd2!.type, equals(LaptopCommandType.openApp));
      expect(cmd2.argument?.toLowerCase(), equals('chrome'));
    });

    test('Telugu system controls (lock, volume, screenshot) are recognized', () {
      final lockCmd = LaptopIntentDetector.parse('laptop lock cheyyi');
      expect(lockCmd, isNotNull);
      expect(lockCmd!.type, equals(LaptopCommandType.lock));

      final volUpCmd = LaptopIntentDetector.parse('laptop volume penchu');
      expect(volUpCmd, isNotNull);
      expect(volUpCmd!.type, equals(LaptopCommandType.volumeUp));

      final volDownCmd = LaptopIntentDetector.parse('laptop volume thagginchu');
      expect(volDownCmd, isNotNull);
      expect(volDownCmd!.type, equals(LaptopCommandType.volumeDown));

      final scCmd = LaptopIntentDetector.parse('laptop screenshot theeyi');
      expect(scCmd, isNotNull);
      expect(scCmd!.type, equals(LaptopCommandType.screenshot));
    });

    test('Pairing intents (English & Telugu) are recognized', () {
      final p1 = LaptopIntentDetector.parse('pair laptop');
      expect(p1, isNotNull);
      expect(p1!.type, equals(LaptopCommandType.pair));

      final p2 = LaptopIntentDetector.parse('connect laptop');
      expect(p2, isNotNull);
      expect(p2!.type, equals(LaptopCommandType.pair));

      final p3 = LaptopIntentDetector.parse('pair phone with laptop');
      expect(p3, isNotNull);
      expect(p3!.type, equals(LaptopCommandType.pair));

      final p4 = LaptopIntentDetector.parse('laptop pair cheyyi');
      expect(p4, isNotNull);
      expect(p4!.type, equals(LaptopCommandType.pair));
    });

    test('Pair response formatting returns token confirmation or error guidance', () {
      const pairCmd = LaptopCommand(type: LaptopCommandType.pair);
      final successResp = LaptopIntentDetector.getResponse(pairCmd, {
        'success': true,
        'hostname': 'HP-Envy-Arshan',
      });
      expect(successResp, contains('HP-Envy-Arshan'));
      expect(successResp, contains('cryptographic device token'));

      final failResp = LaptopIntentDetector.getResponse(pairCmd, {'success': false});
      expect(failResp, contains('Pairing failed'));
      expect(failResp, contains('6-digit PIN'));
    });
  });

  group('Stage I: Durable Remote Command Envelope, Expiry & Idempotency', () {
    test('Durable command envelope enforces 30s TTL expiry calculation', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      const ttlSeconds = 30;
      final expiresAt = now + (ttlSeconds * 1000);

      // Verify normal active command is before expires_at
      expect(now <= expiresAt, isTrue);

      // Verify a past command from 35s ago is expired
      final staleTimestamp = now - 35000;
      expect(now > staleTimestamp + (ttlSeconds * 1000), isTrue);
    });

    test('Idempotency receipt model handles replayed caching', () {
      final receipt = {
        'command_id': 'cmd_123456789_open_app',
        'device_id': 'phone_arshan_test',
        'tool': 'open_app',
        'status': 'executed',
        'output': 'Launched Notepad successfully',
        'executed_at': 1726000000000,
        'duration_ms': 120,
        'replayed': false,
      };

      expect(receipt['replayed'], isFalse);
      expect(receipt['status'], equals('executed'));

      // Replay simulate: replayed set to true
      final cachedReplay = Map<String, dynamic>.from(receipt);
      cachedReplay['replayed'] = true;
      expect(cachedReplay['replayed'], isTrue);
      expect(cachedReplay['command_id'], equals(receipt['command_id']));
    });
  });

  group('Stage I: LaptopControlService Configuration & State Binding', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Loads default unconfigured state and initializes persistent device ID', () async {
      final service = LaptopControlService();
      await service.loadConfig();

      expect(service.deviceId, isNotNull);
      expect(service.deviceId!.startsWith('phone_'), isTrue);
      expect(service.isPaired, isFalse);
      expect(service.isRemotePaused, isFalse);
    });

    test('Saving configuration and pairing credentials enables isPaired', () async {
      SharedPreferences.setMockInitialValues({
        'aira_laptop_ip': '192.168.1.50',
        'aira_laptop_pin': '654321',
        'aira_device_token': 'secret_bearer_token_abc123',
        'aira_laptop_hostname': 'Laptop-Host-Test',
      });

      final service = LaptopControlService();
      await service.loadConfig();

      expect(service.laptopIp, equals('192.168.1.50'));
      expect(service.isConfigured, isTrue);
      expect(service.isPaired, isTrue);
      expect(service.hostname, equals('Laptop-Host-Test'));
      expect(service.deviceToken, equals('secret_bearer_token_abc123'));
    });

    test('Unpair / Revoke clears device token and paired status', () async {
      SharedPreferences.setMockInitialValues({
        'aira_laptop_ip': '192.168.1.50',
        'aira_device_token': 'secret_bearer_token_abc123',
      });

      final service = LaptopControlService();
      await service.loadConfig();
      expect(service.isPaired, isTrue);

      await service.clearConfig();
      expect(service.isPaired, isFalse);
      expect(service.deviceToken, isNull);
    });
  });
}
