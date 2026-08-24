import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/agent/action_guardrail_manager.dart';

/// Interactive Human-in-the-Loop Confirmation Card for Risky Actions
class ActionApprovalCard extends StatelessWidget {
  final PendingApprovalAction action;
  final VoidCallback onApprove;
  final Function(String newContent) onEdit;
  final VoidCallback onReject;

  const ActionApprovalCard({
    super.key,
    required this.action,
    required this.onApprove,
    required this.onEdit,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1A16) : const Color(0xFFFFF9F5);
    final borderColor = isDark ? const Color(0xFF6E3820) : const Color(0xFFE2A888);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AiraColors.claudeTerracotta.withValues(alpha: isDark ? 0.2 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'APPROVAL REQUIRED • GUARDRAIL TIER',
                      style: GoogleFonts.firaCode(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: Colors.amber.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Action: ${action.actionType.toUpperCase()}',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Metadata block
          if (action.recipient.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text('To: ', style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(action.recipient, style: GoogleFonts.sourceSerif4(fontSize: 13, color: AiraColors.claudeTerracotta)),
                ],
              ),
            ),

          if (action.subject.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text('Subject: ', style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.w700, fontSize: 13)),
                  Expanded(child: Text(action.subject, style: GoogleFonts.sourceSerif4(fontSize: 13))),
                ],
              ),
            ),

          // Draft Body
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141310) : const Color(0xFFF3EFEA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: Text(
              action.content,
              style: GoogleFonts.sourceSerif4(fontSize: 13.5, height: 1.45),
            ),
          ),

          // Self-Check Note
          if (action.auditRecord != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.green, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Self-Check: ${action.auditRecord!.critique.critiqueReasoning}',
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // Action Buttons
          if (action.status == ApprovalStatus.pending)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve & Send'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    side: BorderSide(color: Colors.red.shade400.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Reject'),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: action.status == ApprovalStatus.approved
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    action.status == ApprovalStatus.approved ? Icons.check_circle : Icons.cancel,
                    color: action.status == ApprovalStatus.approved ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    action.status == ApprovalStatus.approved ? 'Action Approved & Executed' : 'Action Rejected by User',
                    style: GoogleFonts.sourceSerif4(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: action.status == ApprovalStatus.approved ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
