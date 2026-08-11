import 'package:flutter/material.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';

/// Claude.ai Minimalist Floating Input Pill with Amber Glow.
class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final bool isLoading;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.isLoading = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isLoading) return;
    widget.onSend(text);
    _controller.clear();
    setState(() => _hasText = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: BoxDecoration(
        color: AiraColors.scaffoldDark,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AiraColors.cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _hasText
                ? AiraColors.electricCyan.withValues(alpha: 0.5)
                : AiraColors.glassBorder,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                style: AiraTypography.bodyMedium.copyWith(
                  color: AiraColors.textPrimary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Reply to AIRA...',
                  hintStyle: AiraTypography.bodyMedium.copyWith(
                    color: AiraColors.textMuted,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (text) {
                  final hasText = text.trim().isNotEmpty;
                  if (hasText != _hasText) {
                    setState(() => _hasText = hasText);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _hasText && !widget.isLoading
                    ? AiraColors.electricCyan
                    : AiraColors.surfaceDark,
                boxShadow: _hasText && !widget.isLoading
                    ? [
                        BoxShadow(
                          color: AiraColors.electricCyan.withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              child: IconButton(
                icon: widget.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Icon(
                        Icons.arrow_upward_rounded,
                        color: _hasText ? Colors.black : AiraColors.textMuted,
                        size: 20,
                      ),
                onPressed: _hasText && !widget.isLoading ? _handleSend : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
