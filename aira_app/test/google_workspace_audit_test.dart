import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/core/services/google_workspace_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 1 — Google Workspace Automated Audit Tests', () {
    late GoogleWorkspaceService workspace;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'workspace_sandbox_mode': true,
        'workspace_connected': true,
      });
      workspace = GoogleWorkspaceService();
      workspace.enableSandboxMode(true);
      workspace.setCapability(calendar: true, gmail: true, drive: true);
    });

    // ── Item 1: Send email ──
    test('1. Send email: sends valid email in sandbox mode and validates addresses', () async {
      expect(workspace.isConnected, isTrue);

      final success = await workspace.sendEmail(
        to: 'colleague@example.com',
        subject: 'Project Sync',
        body: 'Hi, let us connect tomorrow regarding the submission.',
      );
      expect(success, isTrue);

      // Verify invalid email throws error
      expect(
        () => workspace.sendEmail(
          to: 'invalid-email-address',
          subject: 'Test',
          body: 'Hello',
        ),
        throwsA(isA<Exception>()),
      );

      // Verify capability revocation
      workspace.revokeCapability('gmail');
      expect(
        () => workspace.sendEmail(
          to: 'test@example.com',
          subject: 'Test',
          body: 'Hello',
        ),
        throwsA(isA<Exception>()),
      );
      workspace.setCapability(gmail: true);
    });

    // ── Item 2: Read / summarize inbox ──
    test('2. Read/summarize inbox: fetches recent emails and unread digest', () async {
      final emails = await workspace.listEmails(maxResults: 5);
      expect(emails, isNotEmpty);
      expect(emails.first, containsPair('from', isNotEmpty));
      expect(emails.first, containsPair('subject', isNotEmpty));

      final unread = await workspace.getUnreadEmailsDigest(maxResults: 3);
      expect(unread.length, inInclusiveRange(1, 3));
      expect(unread.first['snippet'], isNotEmpty);
    });

    // ── Item 3: Calendar add / read ──
    test('3. Calendar add/read: list events, create event, agenda, next meeting, free slots', () async {
      final events = await workspace.listEvents();
      expect(events, isNotEmpty);
      expect(events.first['title'], isNotEmpty);

      final now = DateTime.now();
      final newEvent = await workspace.createEvent(
        title: 'AIRA Sprint Review',
        start: now.add(const Duration(hours: 2)),
        end: now.add(const Duration(hours: 3)),
        description: 'Automated audit verification meeting',
      );
      expect(newEvent['id'], isNotEmpty);
      expect(newEvent['title'], equals('AIRA Sprint Review'));
      expect(newEvent['link'], contains('calendar.google.com'));

      final agenda = await workspace.getTodayAgenda();
      expect(agenda, isNotEmpty);

      final next = await workspace.getNextMeeting();
      expect(next, isNotNull);
      expect(next!['title'], isNotEmpty);

      final freeSlots = await workspace.findFreeTimeSlots();
      expect(freeSlots, isA<List<String>>());
    });

    // ── Item 4: Docs create ──
    test('4. Docs create: creates document and returns valid documentId and edit link', () async {
      final doc = await workspace.createDoc(title: 'AIRA System Architecture Report');
      expect(doc['id'], isNotEmpty);
      expect(doc['title'], equals('AIRA System Architecture Report'));
      expect(doc['link'], contains('docs.google.com/document/d/'));
    });

    // ── Item 5: Google Contacts resolution ──
    test('5. Google Contacts resolution: resolves phone number and email by contact name', () async {
      final phoneContact = await workspace.searchGoogleContactPhone('Rahul');
      expect(phoneContact, isNotNull);
      expect(phoneContact!['name'], contains('Rahul'));
      expect(phoneContact['phone'], contains('9876543210'));

      final emailContact = await workspace.searchGoogleContactEmail('Priya');
      expect(emailContact, isNotNull);
      expect(emailContact!['name'], contains('Priya'));
      expect(emailContact['email'], contains('priya.patel@example.com'));

      final unknown = await workspace.searchGoogleContactPhone('UnknownPersonXYZ');
      expect(unknown, isNull);
    });

    // ── Item 6: Google Drive integration ──
    test('6. Google Drive integration: list files, search files, upload text note', () async {
      final files = await workspace.listRecentDriveFiles();
      expect(files, isNotEmpty);
      expect(files.first['name'], isNotEmpty);
      expect(files.first['link'], contains('drive.google.com'));

      final searchResults = await workspace.searchDriveFiles('Blueprint');
      expect(searchResults, isNotEmpty);
      expect(searchResults.first['name'], contains('Blueprint'));

      final uploaded = await workspace.uploadTextFileToDrive(
        filename: 'AIRA_Audit_Notes',
        content: 'Verification notes for Google Workspace Milestone 1.',
      );
      expect(uploaded['id'], isNotEmpty);
      expect(uploaded['link'], contains('drive.google.com'));
    });

    // ── Item 7: Google Sheets integration ──
    test('7. Google Sheets integration: create sheet, append row, read sheet data', () async {
      final sheet = await workspace.createSheet(title: 'Sprint Backlog 2026');
      expect(sheet['id'], isNotEmpty);
      expect(sheet['title'], equals('Sprint Backlog 2026'));
      expect(sheet['link'], contains('docs.google.com/spreadsheets/d/'));

      final appendResult = await workspace.appendSheetRow(
        sheetTarget: 'Sprint Backlog 2026',
        values: ['Task 1', 'Audit Workspace', 'Passed'],
      );
      expect(appendResult['spreadsheetId'], isNotEmpty);
      expect(appendResult['updatedRows'], equals(1));

      final readResult = await workspace.readSheetData(
        sheetTarget: 'Sprint Backlog 2026',
      );
      expect(readResult['rows'], isNotEmpty);
      final rows = readResult['rows'] as List;
      expect(rows.any((r) => (r as List).contains('Audit Workspace')), isTrue);
    });
  });
}
