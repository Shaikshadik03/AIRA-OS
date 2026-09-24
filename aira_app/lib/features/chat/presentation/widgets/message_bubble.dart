import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/features/chat/domain/chat_models.dart';
import 'package:aira_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:aira_app/features/chat/presentation/screens/artifact_canvas_screen.dart';
import 'package:aira_app/features/chat/presentation/widgets/plan_execution_card.dart';
import 'package:aira_app/features/chat/presentation/widgets/action_approval_card.dart';
import 'package:aira_app/features/chat/presentation/widgets/workspace_calendar_card.dart';
import 'package:aira_app/features/chat/presentation/widgets/workspace_event_preview_card.dart';
import 'package:aira_app/features/chat/presentation/widgets/workspace_email_digest_card.dart';
import 'package:aira_app/features/chat/presentation/widgets/notification_digest_card.dart';
import 'package:aira_app/features/chat/presentation/widgets/android_action_card.dart';
import 'package:aira_app/core/agent/action_guardrail_manager.dart';
import 'package:aira_app/core/artifacts/artifact_model.dart';
import 'package:aira_app/core/artifacts/artifact_parser.dart';

/// Pure Claude-Style Message Bubble with Live Artifacts:
/// - User messages: Right-aligned compact bubble with warm surface tone and soft border.
/// - Assistant messages: Left-aligned generous layout, markdown typography with Source Serif 4,
///   smooth word-by-word streaming, pulsing glowing orb indicator, clean code blocks,
///   and interactive Claude Artifact Canvas.
class MessageBubble extends ConsumerStatefulWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {

  List<AiraArtifact> _extractArtifacts(String text) {
    return ArtifactParser.extractArtifacts(text);
  }

  @override
  Widget build(BuildContext context) {
    return widget.message.isUser ? _buildUserBubble() : _buildAssistantBubble();
  }

  // ── USER BUBBLE ──────────────────────────────────────────────────────────

  Widget _buildUserBubble() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bubbleBg = isDark ? AiraColors.surfaceDark : AiraColors.surfaceRaisedLight;
    final bubbleBorder = isDark ? AiraColors.borderDark : const Color(0xFFDFDAD0);
    final textColor = isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight;

    return Padding(
      padding: const EdgeInsets.only(left: 60, right: 18, bottom: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attached image (if any)
            if (widget.message.base64Image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  base64Decode(widget.message.base64Image!),
                  width: 220,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 6),
            ],
            // User message bubble
            if (widget.message.content.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: bubbleBg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(
                    color: bubbleBorder,
                    width: 1,
                  ),
                ),
                child: SelectableText(
                  widget.message.content,
                  style: GoogleFonts.sourceSerif4(
                    color: textColor,
                    height: 1.5,
                    fontSize: 15,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── ASSISTANT BUBBLE ─────────────────────────────────────────────────────

  Widget _buildAssistantBubble() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight;
    final mutedColor = isDark ? AiraColors.textMuted : AiraColors.textMutedLight;
    final codeBg = isDark ? const Color(0xFF1C1B19) : const Color(0xFF262523);
    final codeBorder = isDark ? AiraColors.borderDark : const Color(0xFF3C3A36);

    final artifacts = _extractArtifacts(widget.message.content);

    return Padding(
      padding: const EdgeInsets.only(left: 18, right: 28, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "AIRA" label with glowing terracotta orb
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AiraColors.claudeTerracotta,
                    boxShadow: [
                      BoxShadow(
                        color: AiraColors.claudeTerracotta.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'AIRA',
                  style: GoogleFonts.sourceSerif4(
                    color: mutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // Rendered Markdown
          // ── Autonomous Goal Execution Plan Card ──
          if (widget.message.plan != null)
            PlanExecutionCard(
              plan: widget.message.plan!,
              onResume: () {
                ref.read(chatProvider.notifier).resumeActivePlan(widget.message.plan!.id);
              },
              onApproveStep: (stepId) {
                ref.read(chatProvider.notifier).approvePlanStep(widget.message.plan!.id, stepId);
              },
              onRetryStep: (stepId) {
                ref.read(chatProvider.notifier).approvePlanStep(widget.message.plan!.id, stepId);
              },
            ),

          // ── Human-in-the-Loop Action Approval Card ──
          if (widget.message.pendingApproval != null)
            ActionApprovalCard(
              action: widget.message.pendingApproval!,
              onApprove: () {
                widget.message.pendingApproval!.status = ApprovalStatus.approved;
                ref.read(chatProvider.notifier).approveWorkspaceDraft(widget.message.pendingApproval!);
                setState(() {});
              },
              onEdit: (newContent) {
                widget.message.pendingApproval!.status = ApprovalStatus.approved;
                ref.read(chatProvider.notifier).approveWorkspaceDraft(widget.message.pendingApproval!, editedContent: newContent);
                setState(() {});
              },
              onReject: () {
                widget.message.pendingApproval!.status = ApprovalStatus.rejected;
                ref.read(chatProvider.notifier).rejectWorkspaceDraft(widget.message.pendingApproval!);
                setState(() {});
              },
            ),

          // ── Google Workspace Calendar Card (Agenda, Next Meeting, Free Time) ──
          if (widget.message.workspaceCalendarData != null) ...[
            Builder(builder: (context) {
              final data = widget.message.workspaceCalendarData!;
              final typeStr = data['type'] as String? ?? 'agenda';
              final cardType = typeStr == 'nextMeeting'
                  ? CalendarCardType.nextMeeting
                  : (typeStr == 'freeTime' ? CalendarCardType.freeTime : CalendarCardType.agenda);
              final title = data['title'] as String? ?? 'Calendar';
              final events = (data['events'] as List?)?.cast<Map<String, dynamic>>() ?? [];
              final freeSlots = (data['freeSlots'] as List?)?.cast<String>() ?? [];
              return WorkspaceCalendarCard(
                type: cardType,
                title: title,
                events: events,
                freeSlots: freeSlots,
                onPrepTap: () {
                  ref.read(chatProvider.notifier).sendMessage('Prepare for my next meeting');
                },
              );
            }),
            const SizedBox(height: 8),
          ],

          // ── Google Workspace Unread Email Digest Card ──
          if (widget.message.workspaceEmails != null) ...[
            WorkspaceEmailDigestCard(
              emails: widget.message.workspaceEmails!,
              onDraftReply: (email) {
                ref.read(chatProvider.notifier).draftEmailReply(email);
              },
            ),
            const SizedBox(height: 8),
          ],

          // ── Google Workspace Calendar Event Preview Card ──
          if (widget.message.workspaceEventPreview != null) ...[
            Builder(builder: (context) {
              final preview = widget.message.workspaceEventPreview!;
              return WorkspaceEventPreviewCard(
                title: preview['title'] ?? 'New Event',
                date: preview['date'] ?? 'Today',
                startTime: preview['startTime'] ?? '10:00 AM',
                endTime: preview['endTime'] ?? '11:00 AM',
                timezone: preview['timezone'] ?? 'Asia/Kolkata (IST)',
                attendees: (preview['attendees'] as List?)?.cast<String>() ?? [],
                description: preview['description'],
                onConfirm: () {
                  ref.read(chatProvider.notifier).confirmCreateEvent(preview);
                },
                onCancel: () {
                  ref.read(chatProvider.notifier).cancelCreateEvent(preview);
                },
              );
            }),
            const SizedBox(height: 8),
          ],

          // ── Notification Intelligence Digest Card (Stage H) ──
          if (widget.message.notificationDigestData != null) ...[
            NotificationDigestCard(data: widget.message.notificationDigestData!),
            const SizedBox(height: 8),
          ],

          // ── Android Actions & Boundaries Card (Stage K) ──
          if (widget.message.androidActionData != null) ...[
            AndroidActionCard(data: widget.message.androidActionData!),
            const SizedBox(height: 8),
          ],

          MarkdownBody(
            data: widget.message.content,
            styleSheet: MarkdownStyleSheet(
              p: GoogleFonts.sourceSerif4(
                color: textColor,
                height: 1.65,
                fontSize: 15,
              ),
              h1: GoogleFonts.playfairDisplay(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                height: 1.3,
              ),
              h2: GoogleFonts.playfairDisplay(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 19,
                height: 1.3,
              ),
              h3: GoogleFonts.playfairDisplay(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 17,
                height: 1.3,
              ),
              strong: GoogleFonts.sourceSerif4(
                fontWeight: FontWeight.w700,
                color: textColor,
                fontSize: 15,
              ),
              em: GoogleFonts.sourceSerif4(
                fontStyle: FontStyle.italic,
                color: isDark ? const Color(0xFFD6D4CD) : const Color(0xFF383733),
                fontSize: 15,
              ),
              code: GoogleFonts.firaCode(
                color: AiraColors.claudeTerracotta,
                backgroundColor: isDark ? const Color(0xFF262522) : const Color(0xFFECE9E0),
                fontSize: 13,
              ),
              codeblockDecoration: BoxDecoration(
                color: codeBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: codeBorder),
              ),
              codeblockPadding: const EdgeInsets.all(14),
              listBullet: GoogleFonts.sourceSerif4(
                color: AiraColors.claudeTerracotta,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              blockquoteDecoration: BoxDecoration(
                border: const Border(
                  left: BorderSide(color: AiraColors.claudeTerracotta, width: 3),
                ),
                color: isDark
                    ? AiraColors.claudeTerracotta.withValues(alpha: 0.06)
                    : AiraColors.claudeTerracotta.withValues(alpha: 0.04),
              ),
              blockquotePadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
            ),
            selectable: true,
          ),

          // ── Claude Artifacts Live Cards (if code blocks are present) ──
          if (artifacts.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...artifacts.map((art) => _buildArtifactCard(art, isDark)),
          ],

          // Action buttons after message is rendered
          if (widget.message.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Clipboard.setData(ClipboardData(text: widget.message.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Copied to clipboard',
                          style: GoogleFonts.sourceSerif4(fontSize: 13),
                        ),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: mutedColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Copy',
                          style: GoogleFonts.sourceSerif4(
                            color: mutedColor,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Consumer(
                  builder: (context, ref, _) {
                    final chatState = ref.watch(chatProvider);
                    final isSpeaking = chatState.isSpeaking;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        final notifier = ref.read(chatProvider.notifier);
                        if (isSpeaking) {
                          notifier.stopTts();
                        } else {
                          notifier.speakText(widget.message.content);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSpeaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                              size: 14,
                              color: isSpeaking ? AiraColors.claudeTerracotta : mutedColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isSpeaking ? 'Stop' : 'Read Aloud',
                              style: GoogleFonts.sourceSerif4(
                                color: isSpeaking ? AiraColors.claudeTerracotta : mutedColor,
                                fontSize: 11.5,
                                fontWeight: isSpeaking ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArtifactCard(AiraArtifact artifact, bool isDark) {
    IconData icon;
    Color accentColor;

    switch (artifact.type) {
      case ArtifactType.pdf:
        icon = Icons.picture_as_pdf_rounded;
        accentColor = const Color(0xFFD9381E);
        break;
      case ArtifactType.docx:
        icon = Icons.article_rounded;
        accentColor = const Color(0xFF1E88E5);
        break;
      case ArtifactType.pptx:
        icon = Icons.slideshow_rounded;
        accentColor = const Color(0xFFFB8C00);
        break;
      case ArtifactType.sheet:
      case ArtifactType.csv:
        icon = Icons.table_chart_rounded;
        accentColor = const Color(0xFF2E7D32);
        break;
      case ArtifactType.html:
      case ArtifactType.svg:
        icon = Icons.web_rounded;
        accentColor = const Color(0xFF8E24AA);
        break;
      case ArtifactType.markdown:
        icon = Icons.format_align_left_rounded;
        accentColor = AiraColors.claudeTerracotta;
        break;
      case ArtifactType.code:
        icon = Icons.code_rounded;
        accentColor = AiraColors.claudeTerracotta;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? AiraColors.cardDark : AiraColors.cardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor.withValues(alpha: 0.12),
          ),
          child: Icon(
            icon,
            color: accentColor,
            size: 20,
          ),
        ),
        title: Text(
          artifact.title,
          style: GoogleFonts.sourceSerif4(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                artifact.type.displayName.toUpperCase(),
                style: GoogleFonts.firaCode(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Tap to preview & export',
              style: GoogleFonts.sourceSerif4(
                fontSize: 11,
                color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.open_in_new_rounded,
          size: 18,
          color: accentColor,
        ),
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ArtifactCanvasScreen(
                title: artifact.title,
                content: artifact.content,
                language: artifact.language,
                artifact: artifact,
              ),
            ),
          );
        },
      ),
    );
  }
}
