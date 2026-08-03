import 'package:flutter/material.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';

class EmailCard extends StatelessWidget {
  final String sender;
  final String subject;
  final String snippet;
  final VoidCallback? onReply;
  final VoidCallback? onMarkRead;

  const EmailCard({
    super.key,
    required this.sender,
    required this.subject,
    required this.snippet,
    this.onReply,
    this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AiraColors.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AiraColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AiraColors.electricCyan.withValues(alpha: 0.2),
                child: Text(
                  sender.isNotEmpty ? sender[0].toUpperCase() : 'M',
                  style: AiraTypography.bodySmall.copyWith(
                    color: AiraColors.electricCyan,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sender,
                      style: AiraTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AiraColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Gmail Briefing',
                      style: AiraTypography.caption.copyWith(color: AiraColors.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.email_rounded, color: AiraColors.electricCyan, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subject,
            style: AiraTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AiraColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            snippet,
            style: AiraTypography.caption.copyWith(color: AiraColors.textMuted, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: onReply,
                icon: const Icon(Icons.reply_rounded, size: 14),
                label: const Text('Reply'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AiraColors.electricCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: AiraTypography.caption.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onMarkRead,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                label: const Text('Mark Read'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AiraColors.textSecondary,
                  side: BorderSide(color: AiraColors.glassBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: AiraTypography.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
