import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';

class WorkspaceEmailDigestCard extends StatelessWidget {
  final List<Map<String, dynamic>> emails;
  final Function(Map<String, dynamic> email) onDraftReply;

  const WorkspaceEmailDigestCard({
    super.key,
    required this.emails,
    required this.onDraftReply,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1B1A17) : const Color(0xFFF9F7F3);
    final borderColor = isDark ? const Color(0xFF33312B) : const Color(0xFFE2DDD5);
    final textColor = isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight;
    final mutedColor = isDark ? AiraColors.textMuted : AiraColors.textMutedLight;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_unread_rounded, color: Colors.redAccent, size: 16),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Unread Inbox Digest',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'GMAIL',
                  style: GoogleFonts.firaCode(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.redAccent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (emails.isEmpty)
            Text(
              'No unread emails in your inbox.',
              style: GoogleFonts.sourceSerif4(color: mutedColor, fontSize: 13),
            )
          else
            ...emails.map((email) => _buildEmailItem(email, isDark, textColor, mutedColor)),
        ],
      ),
    );
  }

  Widget _buildEmailItem(
    Map<String, dynamic> email,
    bool isDark,
    Color textColor,
    Color mutedColor,
  ) {
    final sender = email['from'] as String? ?? 'Unknown';
    final subject = email['subject'] as String? ?? '(no subject)';
    final date = email['date'] as String? ?? '';
    final snippet = email['snippet'] as String? ?? '';

    // Extract clean display name
    String displayName = sender;
    if (sender.contains('<')) {
      displayName = sender.split('<').first.trim().replaceAll('"', '');
    }
    if (displayName.isEmpty) displayName = sender;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131210) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AiraColors.claudeTerracotta.withValues(alpha: 0.2),
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'M',
                  style: GoogleFonts.sourceSerif4(
                    color: AiraColors.claudeTerracotta,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (date.isNotEmpty)
                      Text(
                        date,
                        style: GoogleFonts.firaCode(fontSize: 10, color: mutedColor),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subject,
            style: GoogleFonts.sourceSerif4(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            snippet,
            style: GoogleFonts.sourceSerif4(
              fontSize: 12,
              color: mutedColor,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => onDraftReply(email),
              icon: const Icon(Icons.reply_rounded, size: 14),
              label: const Text('Draft Reply'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AiraColors.claudeTerracotta,
                side: BorderSide(color: AiraColors.claudeTerracotta.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: GoogleFonts.sourceSerif4(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
