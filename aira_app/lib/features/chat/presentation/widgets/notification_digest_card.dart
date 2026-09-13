import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/aira_colors.dart';
import '../../../../core/services/notification_monitor_service.dart';
import '../../../../core/services/smart_reply_service.dart';
import '../providers/chat_provider.dart';

class NotificationDigestCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;

  const NotificationDigestCard({
    super.key,
    required this.data,
  });

  @override
  ConsumerState<NotificationDigestCard> createState() => _NotificationDigestCardState();
}

class _NotificationDigestCardState extends ConsumerState<NotificationDigestCard> {
  bool _isExpanded = false;

  Color _getAppColor(String packageName) {
    final lower = packageName.toLowerCase();
    if (lower.contains('whatsapp')) return const Color(0xFF25D366);
    if (lower.contains('telegram')) return const Color(0xFF0088CC);
    if (lower.contains('slack')) return const Color(0xFF4A154B);
    if (lower.contains('gm') || lower.contains('gmail')) return const Color(0xFFEA4335);
    if (lower.contains('messaging') || lower.contains('sms')) return const Color(0xFF1A73E8);
    if (lower.contains('bank') || lower.contains('paytm') || lower.contains('phonepe')) return const Color(0xFF00BAF2);
    if (lower.contains('discord')) return const Color(0xFF5865F2);
    return AiraColors.claudeTerracotta;
  }

  IconData _getAppIcon(String packageName) {
    final lower = packageName.toLowerCase();
    if (lower.contains('whatsapp')) return Icons.chat_bubble_outline;
    if (lower.contains('telegram')) return Icons.send_rounded;
    if (lower.contains('slack')) return Icons.work_outline;
    if (lower.contains('gm') || lower.contains('gmail')) return Icons.mail_outline;
    if (lower.contains('messaging') || lower.contains('sms')) return Icons.message_outlined;
    if (lower.contains('bank') || lower.contains('paytm') || lower.contains('phonepe')) return Icons.account_balance_wallet_outlined;
    if (lower.contains('discord')) return Icons.forum_outlined;
    return Icons.notifications_none_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final summary = widget.data['summary'] as String? ?? 'No notifications captured yet.';
    final notifMaps = (widget.data['notifications'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final totalCount = widget.data['totalCount'] as int? ?? notifMaps.length;
    final isFocusMode = widget.data['isFocusMode'] == true;

    final cardBg = isDark ? AiraColors.cardDark : AiraColors.cardLight;
    final borderColor = isDark ? AiraColors.borderDark : const Color(0xFFDFDAD0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AiraColors.claudeTerracotta.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AiraColors.claudeTerracotta.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(color: borderColor.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AiraColors.claudeTerracotta.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: AiraColors.claudeTerracotta,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notification Intelligence',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        '$totalCount alerts processed • Selected-App Whitelist Active',
                        style: GoogleFonts.sourceSerif4(
                          fontSize: 11,
                          color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                        ),
                      ),
                    ],
                  ),
                ),
                // Privacy / Redaction Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined, size: 12, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Protected',
                        style: GoogleFonts.sourceSerif4(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Focus Mode Indicator (if active) ──
          if (isFocusMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AiraColors.claudeAmber.withValues(alpha: 0.12),
              child: Row(
                children: [
                  const Icon(Icons.do_not_disturb_on_outlined, size: 14, color: AiraColors.claudeAmber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Focus Mode Active: Non-critical notifications silenced.',
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AiraColors.claudeAmber,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Executive Digest Summary ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EXECUTIVE BRIEFING',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: AiraColors.claudeTerracotta,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  summary,
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 13,
                    height: 1.45,
                    color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),

          // ── Notification Items Preview ──
          if (notifMaps.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Alerts (${notifMaps.length})',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isExpanded ? 'Collapse' : 'Show All',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AiraColors.claudeTerracotta,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 16,
                          color: AiraColors.claudeTerracotta,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Show first 2 or all if expanded
            ...((_isExpanded ? notifMaps : notifMaps.take(2)).map((n) {
              final pkg = n['packageName']?.toString() ?? '';
              final appColor = _getAppColor(pkg);
              final appName = n['appName']?.toString() ?? 'App';
              final title = n['title']?.toString() ?? '';
              final text = n['text']?.toString() ?? '';
              final canReply = n['canReply'] == true;
              final replyKey = n['replyKey']?.toString();
              final isRedacted = n['isRedacted'] == true || text.contains('[PROTECTED_AUTH_CODE]');

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor.withValues(alpha: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: appColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getAppIcon(pkg), size: 12, color: appColor),
                              const SizedBox(width: 4),
                              Text(
                                appName,
                                style: GoogleFonts.sourceSerif4(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: appColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRedacted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Code Redacted',
                              style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      text,
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 12,
                        color: isDark ? AiraColors.textSecondary : AiraColors.textSecondaryLight,
                      ),
                      maxLines: _isExpanded ? 4 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Action Buttons: Reply & Follow Up
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Follow Up Reminder Button
                        OutlinedButton.icon(
                          onPressed: () {
                            ref.read(chatProvider.notifier).sendMessage(
                                  'Remind me to follow up with $title in 1 hour regarding "$text"',
                                );
                          },
                          icon: const Icon(Icons.alarm_add_rounded, size: 13, color: AiraColors.claudeTerracotta),
                          label: const Text(
                            'Follow Up',
                            style: TextStyle(fontSize: 11, color: AiraColors.claudeTerracotta),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide(color: AiraColors.claudeTerracotta.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        if (canReply && replyKey != null && replyKey.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          // Safe Reply Button (Drafts with exact human review)
                          ElevatedButton.icon(
                            onPressed: () async {
                              final draft = await SmartReplyService().processNotification(
                                InterceptedNotification(
                                  id: n['id'] is int ? n['id'] : 0,
                                  packageName: pkg,
                                  appName: appName,
                                  title: title,
                                  text: text,
                                  subText: n['subText']?.toString() ?? '',
                                  timestamp: DateTime.now().millisecondsSinceEpoch,
                                  category: n['category']?.toString() ?? 'messaging',
                                  canReply: true,
                                  replyKey: replyKey,
                                ),
                              );
                              if (draft != null) {
                                ref.read(chatProvider.notifier).sendMessage(
                                      'Prepared quick reply draft for $title. Please review before sending.',
                                    );
                              }
                            },
                            icon: const Icon(Icons.reply_rounded, size: 13, color: Colors.white),
                            label: const Text(
                              'Draft Reply',
                              style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appColor,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            })),
            const SizedBox(height: 12),
          ],

          // ── Card Footer with Quick Toggles ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.02),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              border: Border(
                top: BorderSide(color: borderColor.withValues(alpha: 0.4)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    ref.read(chatProvider.notifier).sendMessage(
                          isFocusMode ? 'turn off focus mode' : 'turn on focus mode',
                        );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFocusMode ? Icons.notifications_off_outlined : Icons.do_not_disturb_on_outlined,
                        size: 14,
                        color: AiraColors.claudeTerracotta,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isFocusMode ? 'Disable Focus Mode' : 'Enable Focus Mode',
                        style: const TextStyle(fontSize: 11, color: AiraColors.claudeTerracotta, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(chatProvider.notifier).sendMessage('summarize my notifications');
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 13, color: AiraColors.claudeTerracotta),
                      SizedBox(width: 4),
                      Text('Refresh', style: TextStyle(fontSize: 11, color: AiraColors.claudeTerracotta)),
                    ],
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
