import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/features/chat/presentation/widgets/drive_file_picker_sheet.dart';
import 'package:aira_app/core/services/google_workspace_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleWorkspaceService().enableSandboxMode(true);
  });

  group('Google Drive File Picker Sheet Tests', () {
    testWidgets('Renders Google Drive File Picker with header, search bar, and files', (tester) async {
      Map<String, dynamic>? selectedFile;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriveFilePickerSheet(
              onFileSelected: (file) {
                selectedFile = file;
              },
            ),
          ),
        ),
      );

      // Initial pump
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Header
      expect(find.text('Google Drive Files'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Verify at least one file loaded from sandbox
      expect(find.textContaining('AIRA OS Master Blueprint 2026.pdf'), findsOneWidget);

      // Tap on the file item
      await tester.tap(find.textContaining('AIRA OS Master Blueprint 2026.pdf'));
      await tester.pump();

      // Verify callback was triggered with file map
      expect(selectedFile, isNotNull);
      expect(selectedFile!['name'], equals('AIRA OS Master Blueprint 2026.pdf'));
    });
  });
}
