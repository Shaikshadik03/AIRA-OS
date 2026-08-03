import 'package:flutter_test/flutter_test.dart';
import 'package:aira_app/features/chat/domain/device_intent.dart';

void main() {
  group('Milestone 4 Android Device Intent Detector Tests', () {
    test('Detects Flashlight ON command', () {
      final cmd = DeviceIntentDetector.detect('Turn on flashlight');
      expect(cmd.intent, equals(DeviceIntent.toggleFlashlight));
      expect(cmd.params['enable'], isTrue);
    });

    test('Detects Flashlight OFF command', () {
      final cmd = DeviceIntentDetector.detect('Turn off torch');
      expect(cmd.intent, equals(DeviceIntent.toggleFlashlight));
      expect(cmd.params['enable'], isFalse);
    });

    test('Detects App Launching command (e.g. Open WhatsApp)', () {
      final cmd = DeviceIntentDetector.detect('Open WhatsApp');
      expect(cmd.intent, equals(DeviceIntent.launchApp));
      expect(cmd.params['appName'], equals('WhatsApp'));
    });

    test('Detects App Launching command (e.g. Launch Spotify)', () {
      final cmd = DeviceIntentDetector.detect('Launch Spotify');
      expect(cmd.intent, equals(DeviceIntent.launchApp));
      expect(cmd.params['appName'], equals('Spotify'));
    });

    test('Detects Wi-Fi Settings command', () {
      final cmd = DeviceIntentDetector.detect('Open Wi-Fi settings');
      expect(cmd.intent, equals(DeviceIntent.openSettings));
      expect(cmd.params['settingType'], equals('wifi'));
    });

    test('Detects Bluetooth Settings command', () {
      final cmd = DeviceIntentDetector.detect('Turn on bluetooth');
      expect(cmd.intent, equals(DeviceIntent.openSettings));
      expect(cmd.params['settingType'], equals('bluetooth'));
    });

    test('Detects Battery status query', () {
      final cmd = DeviceIntentDetector.detect('Check battery level');
      expect(cmd.intent, equals(DeviceIntent.getBatteryStatus));
    });

    test('Detects Alarm command', () {
      final cmd = DeviceIntentDetector.detect('Set alarm for 7:30 AM');
      expect(cmd.intent, equals(DeviceIntent.setAlarm));
      expect(cmd.params['hour'], equals(7));
      expect(cmd.params['minute'], equals(30));
    });

    test('Detects Timer command', () {
      final cmd = DeviceIntentDetector.detect('Set a timer for 10 minutes');
      expect(cmd.intent, equals(DeviceIntent.setTimer));
      expect(cmd.params['seconds'], equals(600));
    });
  });
}
