import 'package:flutter_test/flutter_test.dart';
import 'package:aira_app/features/chat/domain/phone_intent.dart';

void main() {
  group('Milestone 3 Phone & SMS Intent Detector Tests', () {
    test('Detects phone call to contact name (e.g. Call Mummy)', () {
      final cmd = PhoneIntentDetector.detect('Call Mummy');
      expect(cmd.intent, equals(PhoneIntent.makeCall));
      expect(cmd.params['recipient'], equals('Mummy'));
    });

    test('Detects phone call to person name (e.g. Call Rahul)', () {
      final cmd = PhoneIntentDetector.detect('Call Rahul');
      expect(cmd.intent, equals(PhoneIntent.makeCall));
      expect(cmd.params['recipient'], equals('Rahul'));
    });

    test('Detects phone call to raw phone number', () {
      final cmd = PhoneIntentDetector.detect('Call +91 9876543210');
      expect(cmd.intent, equals(PhoneIntent.makeCall));
      expect(cmd.params['recipient'], contains('9876543210'));
    });

    test('Detects make a call phrase', () {
      final cmd = PhoneIntentDetector.detect('Make a call to Rahul');
      expect(cmd.intent, equals(PhoneIntent.makeCall));
      expect(cmd.params['recipient'], equals('Rahul'));
    });

    test('Detects SMS to contact with message', () {
      final cmd = PhoneIntentDetector.detect('Send SMS to Rahul saying I will be late');
      expect(cmd.intent, equals(PhoneIntent.sendSms));
      expect(cmd.params['recipient'], equals('Rahul'));
      expect(cmd.params['body'], equals('I will be late'));
    });

    test('Detects text message command', () {
      final cmd = PhoneIntentDetector.detect('Text 9876543210 saying Hello from AIRA');
      expect(cmd.intent, equals(PhoneIntent.sendSms));
      expect(cmd.params['recipient'], contains('9876543210'));
      expect(cmd.params['body'], equals('Hello from AIRA'));
    });
  });
}
