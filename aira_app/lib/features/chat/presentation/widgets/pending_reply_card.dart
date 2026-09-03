import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/aira_colors.dart';
import '../../../../core/services/smart_reply_service.dart';

class PendingReplyCard extends StatefulWidget {
  final PendingReplyDraft draft;
  final VoidCallback? onDismissed;

  const PendingReplyCard({
    super.key,
    required this.draft,
    this.onDismissed,
  });

  @override
  State<PendingReplyCard> createState() => _PendingReplyCardState();
}

class _PendingReplyCardState extends State<PendingReplyCard> {
  late TextEditingController _textController;
  final SmartReplyService _service = SmartReplyService();
  bool _isRegenerating = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.draft.draftedReply);
  }

  @override
  void didUpdateWidget(covariant PendingReplyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.draftedReply != widget.draft.draftedReply) {
      _textController.text = widget.draft.draftedReply;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Color _getAppColor(String packageName) {
    if (packageName.contains('whatsapp')) return const Color(0xFF25D366);
    if (packageName.contains('telegram')) return const Color(0xFF0088CC);
    if (packageName.contains('signal')) return const Color(0xFF3A76F0);
    return AiraColors.claudeTerracotta;
  }

  IconData _getAppIcon(String packageName) {
    if (packageName.contains('whatsapp')) return Icons.chat_bubble_outline;
    if (packageName.contains('telegram')) return Icons.send_rounded;
    if (packageName.contains('signal')) return Icons.lock_outline;
    return Icons.message_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final draft = widget.draft;
    final appColor = _getAppColor(draft.packageName);
    final isSending = draft.status == ReplyDraftStatus.sending;
    final isSent = draft.status == ReplyDraftStatus.sent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AiraColors.cardDark : AiraColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSent
              ? Colors.green.withValues(alpha: 0.5)
              : isSending
                  ? appColor.withValues(alpha: 0.6)
                  : AiraColors.claudeTerracotta.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: App & Sender ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: appColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: appColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getAppIcon(draft.packageName), size: 14, color: appColor),
                    const SizedBox(width: 5),
                    Text(
                      draft.appName.isNotEmpty ? draft.appName : 'WhatsApp',
                      style: GoogleFonts.sourceSerif4(
                        color: appColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Review-Before-Send',
                style: GoogleFonts.sourceSerif4(
                  color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const Spacer(),
              if (!isSending && !isSent)
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                  ),
                  tooltip: 'Dismiss Draft',
                  onPressed: () {
                    _service.dismissDraft(draft.id);
                    widget.onDismissed?.call();
                  },
                ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Sender Name & Incoming Message Bubble ──
          Row(
            children: [
              const Icon(Icons.person_pin_outlined, size: 16, color: AiraColors.claudeTerracotta),
              const SizedBox(width: 6),
              Text(
                draft.sender,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Text(
              '"${draft.incomingMessage}"',
              style: GoogleFonts.sourceSerif4(
                color: isDark ? AiraColors.textSecondary : AiraColors.textSecondaryLight,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Drafted Reply Section (Editable) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI Draft (Telugu + English Casual):',
                style: GoogleFonts.sourceSerif4(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AiraColors.claudeTerracotta,
                ),
              ),
              if (!isSending && !isSent)
                InkWell(
                  onTap: _isRegenerating
                      ? null
                      : () async {
                          setState(() => _isRegenerating = true);
                          await _service.regenerateDraft(draft.id);
                          if (mounted) setState(() => _isRegenerating = false);
                        },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: _isRegenerating ? Colors.grey : AiraColors.claudeTerracotta,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isRegenerating ? 'Drafting...' : 'Regenerate',
                        style: TextStyle(
                          fontSize: 11,
                          color: _isRegenerating ? Colors.grey : AiraColors.claudeTerracotta,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // ── Text Field for editing ──
          TextField(
            controller: _textController,
            enabled: !isSending && !isSent,
            maxLines: 3,
            minLines: 1,
            style: GoogleFonts.sourceSerif4(
              color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
              fontSize: 14,
              height: 1.4,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1D1B) : const Color(0xFFF6F5F0),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AiraColors.claudeTerracotta, width: 1.5),
              ),
            ),
            onChanged: (val) {
              _service.updateDraftText(draft.id, val);
            },
          ),

          const SizedBox(height: 12),

          // ── Action Footer ──
          if (isSent)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Reply sent via Android RemoteInput!',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            )
          else if (isSending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AiraColors.claudeAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AiraColors.claudeAmber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AiraColors.claudeAmber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Anti-bot natural delay (${draft.delayRemainingSeconds}s remaining)...',
                      style: GoogleFonts.sourceSerif4(
                        color: AiraColors.claudeAmber,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final replyText = _textController.text.trim();
                      if (replyText.isEmpty) return;
                      await _service.sendReply(
                        draftId: draft.id,
                        finalReplyText: replyText,
                      );
                    },
                    icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                    label: Text(
                      'Reply via ${draft.appName.isNotEmpty ? draft.appName : "WhatsApp"}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () {
                    _service.dismissDraft(draft.id);
                    widget.onDismissed?.call();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Dismiss',
                    style: TextStyle(
                      color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
