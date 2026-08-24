import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/core/agent/self_check_reflector.dart';
import 'package:aira_app/core/agent/action_guardrail_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 2 Proof of Work — Self-Check Reflection Loop', () {
    test('Catches placeholders and robotic filler, fixes draft, and logs audit record', () async {
      final reflector = SelfCheckReflector();

      // Error-prone draft with placeholder and robotic filler
      final draft = ActionDraft(
        actionType: 'email',
        recipient: 'prof_sharma@university.edu',
        subject: 'Assignment Extension Request',
        content: 'I hope this email finds you well. I need an extension until [Insert Date] due to health reasons.',
      );

      final auditRecord = await reflector.reviewAndRefineDraft(draft);

      expect(auditRecord.critique.hasErrors, isTrue, reason: 'Must detect errors in raw draft');
      expect(auditRecord.critique.issuesFound, isNotEmpty);
      expect(auditRecord.finalDraft.contains('[Insert Date]'), isFalse, reason: 'Placeholder must be removed');
      expect(auditRecord.finalDraft.contains('I hope this email finds you well'), isFalse, reason: 'Robotic filler must be removed');

      // Verify Audit Logging
      final logs = await reflector.getAuditLogs();
      expect(logs, isNotEmpty, reason: 'Audit log must persist in storage');
      expect(logs.first.originalDraft.recipient, equals('prof_sharma@university.edu'));

      print('✅ Phase 2 Proof of Work PASSED: Self-check caught & fixed errors, audit trail logged.');
    });
  });

  group('Phase 3 Proof of Work — Human-in-the-Loop Guardrail Tiers', () {
    test('Confirms 5 approval-tier actions pause for confirmation & none execute without it', () async {
      final guardrail = ActionGuardrailManager();

      final approvalTierActions = [
        {'type': 'send_email', 'to': 'client@company.com', 'subject': 'Contract Draft', 'body': 'Attached is the contract.'},
        {'type': 'send_sms', 'to': '+919876543210', 'subject': '', 'body': 'Meeting at 5 PM.'},
        {'type': 'make_call', 'to': '+919876543210', 'subject': '', 'body': 'Voice Call'},
        {'type': 'workspace_delete', 'to': 'Google Drive', 'subject': 'Delete File', 'body': 'Delete document old_notes.docx'},
        {'type': 'payment_send', 'to': 'UPI / Vendor', 'subject': 'Invoice Payment', 'body': 'Transfer INR 500'},
      ];

      for (int i = 0; i < approvalTierActions.length; i++) {
        final act = approvalTierActions[i];
        final type = act['type']!;

        // 1. Verify Action Tier Classification
        final requiresApproval = guardrail.isApprovalRequired(type);
        expect(requiresApproval, isTrue, reason: 'Action "$type" must be strictly classified as Approval-Required');

        // 2. Register Pending Action
        final pending = await guardrail.createApprovalRequest(
          actionType: type,
          recipient: act['to']!,
          subject: act['subject']!,
          content: act['body']!,
        );

        // 3. Confirm paused state (NEVER fires blind)
        expect(pending.status, equals(ApprovalStatus.pending), reason: 'Must pause in pending state awaiting user');

        // 4. Test explicit approval transition
        final approved = await guardrail.approveAction(pending.id);
        expect(approved, isTrue);
        expect(guardrail.getPending(pending.id)!.status, equals(ApprovalStatus.approved));

        print('  • Approval Tier Action ${i + 1} ($type) correctly paused for confirmation and approved.');
      }

      // Verify Free-Run actions bypass approval
      expect(guardrail.isApprovalRequired('calendar_read'), isFalse);
      expect(guardrail.isApprovalRequired('tasks_list'), isFalse);
      expect(guardrail.isApprovalRequired('web_search'), isFalse);

      print('✅ Phase 3 Proof of Work PASSED: All 5 approval actions paused for confirmation.');
    });
  });
}
