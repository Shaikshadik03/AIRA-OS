import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/features/chat/domain/chat_models.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: message.isUser ? 60 : 12,
        right: message.isUser ? 12 : 60,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Label
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
            child: Text(
              message.isUser ? 'You' : 'AIRA',
              style: AiraTypography.overline.copyWith(
                color: message.isUser
                    ? AiraColors.electricCyan.withValues(alpha: 0.7)
                    : AiraColors.purple.withValues(alpha: 0.7),
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ),
          // Bubble
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: message.isUser
                  ? LinearGradient(
                      colors: [
                        AiraColors.electricCyan.withValues(alpha: 0.15),
                        AiraColors.neonBlue.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        AiraColors.cardDark,
                        AiraColors.surfaceDark.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                bottomRight: Radius.circular(message.isUser ? 4 : 16),
              ),
              border: Border.all(
                color: message.isUser
                    ? AiraColors.electricCyan.withValues(alpha: 0.2)
                    : AiraColors.glassBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Markdown content for assistant, plain text for user
                if (message.isAssistant)
                  MarkdownBody(
                    data: message.content,
                    styleSheet: MarkdownStyleSheet(
                      p: AiraTypography.bodyMedium.copyWith(
                        color: AiraColors.textPrimary,
                        height: 1.5,
                      ),
                      h1: AiraTypography.h4.copyWith(color: AiraColors.textPrimary),
                      h2: AiraTypography.h5.copyWith(color: AiraColors.textPrimary),
                      h3: AiraTypography.h6.copyWith(color: AiraColors.textPrimary),
                      code: AiraTypography.bodySmall.copyWith(
                        color: AiraColors.electricCyan,
                        backgroundColor: AiraColors.scaffoldDark,
                        fontFamily: 'monospace',
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: AiraColors.scaffoldDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AiraColors.glassBorder),
                      ),
                      codeblockPadding: const EdgeInsets.all(12),
                      listBullet: AiraTypography.bodyMedium.copyWith(
                        color: AiraColors.electricCyan,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: AiraColors.electricCyan.withValues(alpha: 0.5),
                            width: 3,
                          ),
                        ),
                      ),
                      blockquotePadding: const EdgeInsets.only(left: 12),
                      strong: AiraTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AiraColors.textPrimary,
                      ),
                      em: AiraTypography.bodyMedium.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AiraColors.textSecondary,
                      ),
                    ),
                    selectable: true,
                  )
                else
                  SelectableText(
                    message.content,
                    style: AiraTypography.bodyMedium.copyWith(
                      color: AiraColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                // Action buttons for assistant messages
                if (message.isAssistant && message.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionButton(
                        Icons.copy_rounded,
                        'Copy',
                        () {
                          Clipboard.setData(
                            ClipboardData(text: message.content),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Copied to clipboard'),
                              backgroundColor: AiraColors.cardDark,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: AiraColors.textMuted),
        ),
      ),
    );
  }
}
