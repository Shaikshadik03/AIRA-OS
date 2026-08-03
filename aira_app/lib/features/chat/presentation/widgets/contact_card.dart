import 'package:flutter/material.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';

class ContactActionCard extends StatelessWidget {
  final String name;
  final String phone;
  final String? source;
  final VoidCallback onCall;
  final VoidCallback onSms;

  const ContactActionCard({
    super.key,
    required this.name,
    required this.phone,
    this.source,
    required this.onCall,
    required this.onSms,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AiraColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AiraColors.electricCyan.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AiraColors.electricCyan.withValues(alpha: 0.1),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AiraColors.electricCyan.withValues(alpha: 0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'C',
              style: AiraTypography.h4.copyWith(color: AiraColors.electricCyan, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AiraTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AiraColors.textPrimary,
                  ),
                ),
                Text(
                  phone,
                  style: AiraTypography.caption.copyWith(color: AiraColors.textMuted),
                ),
                if (source != null && source!.isNotEmpty)
                  Text(
                    'Found via $source',
                    style: AiraTypography.overline.copyWith(color: AiraColors.electricCyan, fontSize: 9),
                  ),
              ],
            ),
          ),
          // Action buttons
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: onCall,
                icon: const Icon(Icons.call_rounded, size: 20, color: Colors.greenAccent),
                style: IconButton.styleFrom(backgroundColor: Colors.green.withValues(alpha: 0.2)),
                tooltip: 'Call Now',
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                onPressed: onSms,
                icon: const Icon(Icons.sms_rounded, size: 20, color: AiraColors.electricCyan),
                style: IconButton.styleFrom(backgroundColor: AiraColors.electricCyan.withValues(alpha: 0.2)),
                tooltip: 'Send SMS',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
