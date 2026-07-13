import 'package:flutter_test/flutter_test.dart';
import 'package:aira_app/app.dart';

void main() {
  testWidgets('AIRA OS app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AiraApp());
    // Verify the app starts without crashing
    expect(find.text('AIRA'), findsWidgets);
  });
}
