import 'package:flutter/material.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';

/// Chat input bar with text field and send button.
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
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 24),
      decoration: BoxDecoration(
        color: AiraColors.cardDark.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: AiraColors.glassBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AiraColors.surfaceDark,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _hasText
                      ? AiraColors.electricCyan.withValues(alpha: 0.3)
                      : AiraColors.glassBorder,
                ),
              ),
              child: TextField(
                controller: _controller,
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                style: AiraTypography.bodyMedium.copyWith(
                  color: AiraColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Message AIRA...',
                  hintStyle: AiraTypography.bodyMedium.copyWith(
                    color: AiraColors.textMuted,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (text) {
                  final hasText = text.trim().isNotEmpty;
                  if (hasText != _hasText) {
                    setState(() => _hasText = hasText);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: _hasText && !widget.isLoading
                  ? AiraColors.primaryGradient
                  : null,
              color: _hasText && !widget.isLoading
                  ? null
                  : AiraColors.surfaceDark,
              borderRadius: BorderRadius.circular(23),
            ),
            child: widget.isLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AiraColors.electricCyan,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      Icons.send_rounded,
                      size: 20,
                      color: _hasText ? Colors.white : AiraColors.textMuted,
                    ),
                    onPressed: _hasText ? _handleSend : null,
                  ),
          ),
        ],
      ),
    );
  }
}
