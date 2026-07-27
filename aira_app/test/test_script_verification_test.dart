import 'package:flutter_test/flutter_test.dart';
import 'package:aira_app/features/chat/domain/workspace_intent.dart';
import 'package:aira_app/features/chat/domain/memory_intent.dart';

void main() {
  group('15-Step Test Script Verification Suite', () {
    test('Test 1: Send Email prompt parsing', () {
      final cmd = WorkspaceIntentDetector.detect('Send an email to test@gmail.com saying this is a test.');
      expect(cmd.intent, equals(WorkspaceIntent.sendEmail));
      expect(cmd.params['to'], equals('test@gmail.com'));
    });

    test('Test 2: Read/Summarize Inbox prompt parsing', () {
      final cmd = WorkspaceIntentDetector.detect('Summarize my last 5 emails.');
      expect(cmd.intent, equals(WorkspaceIntent.readEmails));
    });

    test('Test 3: Calendar Add prompt parsing', () {
      final cmd = WorkspaceIntentDetector.detect('Add an event tomorrow at 5 PM called Test Event.');
      expect(cmd.intent, equals(WorkspaceIntent.createEvent));
    });

    test('Test 4: Calendar Read prompt parsing', () {
      final cmd = WorkspaceIntentDetector.detect("What's on my calendar this week?");
      expect(cmd.intent, equals(WorkspaceIntent.listEvents));
    });

    test('Test 5: Docs Create prompt parsing', () {
      final cmd = WorkspaceIntentDetector.detect('Create a doc titled AIRA Test with one line of text.');
      expect(cmd.intent, equals(WorkspaceIntent.createDoc));
    });

    test('Test 6: Contacts resolution prompt parsing', () {
      final cmd = WorkspaceIntentDetector.detect('Send an email to Rahul asking details.');
      expect(cmd.intent, equals(WorkspaceIntent.sendEmail));
      expect(cmd.params['to'], equals('Rahul'));
    });

    test('Test 7: Long-term memory prompt parsing', () {
      final cmd = MemoryIntentDetector.detect('Remember that my favorite color is teal.');
      expect(cmd.intent, equals(MemoryIntent.saveMemory));
      expect(cmd.content, contains('favorite color is teal'));
    });

    test('Test 8a: Drive List prompt parsing', () {
      final cmd = WorkspaceIntentDetector.detect('List my recent Drive files');
      expect(cmd.intent, equals(WorkspaceIntent.listDriveFiles));
    });

    test('Test 8b: Drive Search prompt parsing', () {
      final cmd = WorkspaceIntentDetector.detect('Search Drive for AIRA');
      expect(cmd.intent, equals(WorkspaceIntent.searchDriveFiles));
      expect(cmd.params['query'], equals('AIRA'));
    });

    test('Test 9: Drive Upload prompt parsing', () {
      final cmd = WorkspaceIntentDetector.detect('Upload a text note to Drive saying hello from AIRA.');
      expect(cmd.intent, equals(WorkspaceIntent.uploadToDrive));
    });

    test('Test 10: Sheets Create prompt parsing', () {
      final cmd = WorkspaceIntentDetector.detect('Create a spreadsheet called AIRA Test Sheet.');
      expect(cmd.intent, equals(WorkspaceIntent.createSheet));
    });

    test('Test 11: Sheets Append Row prompt parsing', () {
      final cmd = WorkspaceIntentDetector.detect('Add a row to AIRA Test Sheet with values Test and 123.');
      expect(cmd.intent, equals(WorkspaceIntent.appendSheetRow));
      expect(cmd.params['sheetTarget'], contains('AIRA Test Sheet'));
      final values = cmd.params['values'] as List<String>;
      expect(values, contains('Test'));
      expect(values, contains('123'));
    });

    test('Test 12: Sheets Read prompt parsing', () {
      final cmd = WorkspaceIntentDetector.detect('Read the data from AIRA Test Sheet.');
      expect(cmd.intent, equals(WorkspaceIntent.readSheet));
    });
  });
}
