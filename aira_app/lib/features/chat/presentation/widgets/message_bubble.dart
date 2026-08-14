import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/features/chat/domain/chat_models.dart';

/// Claude-style message bubble.
/// - User messages: right-aligned, compact, no sender label
/// - Assistant messages: left-aligned, full-width, "AIRA" label + word-by-word streaming + pulsing orb
class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  Timer? _wordTimer;
  List<String> _words = [];
  int _displayedWordCount = 0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    if (widget.message.isAssistant) {
      _initWordStreaming();
    }
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.isAssistant &&
        oldWidget.message.content != widget.message.content) {
      _initWordStreaming();
    }
  }

  void _initWordStreaming() {
    if (widget.message.content.isEmpty) return;

    _words = widget.message.content.split(' ');
    if (_words.isEmpty) return;

    _displayedWordCount = 1;
    _isAnimating = true;
    _wordTimer?.cancel();

    _wordTimer = Timer.periodic(const Duration(milliseconds: 28), (timer) {
      if (!mounted) return;
      if (_displayedWordCount < _words.length) {
        setState(() => _displayedWordCount++);
      } else {
        timer.cancel();
        if (mounted) setState(() => _isAnimating = false);
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _wordTimer?.cancel();
    super.dispose();
  }

  String get _streamedText {
    if (!_isAnimating) return widget.message.content;
    return _words.take(_displayedWordCount).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return widget.message.isUser ? _buildUserBubble() : _buildAssistantBubble();
  }

  // ── USER BUBBLE ──────────────────────────────────────────────────────────

  Widget _buildUserBubble() {
    return Padding(
      padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
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
                  width: 200,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 4),
            ],
            // Message text
            if (widget.message.content.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A28),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(
                    color: const Color(0xFF3A3A38),
                    width: 1,
                  ),
                ),
                child: SelectableText(
                  widget.message.content,
                  style: AiraTypography.bodyMedium.copyWith(
                    color: const Color(0xFFECEBE6),
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
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 56, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "AIRA" label with animated orb
          Padding(
            padding: const EdgeInsets.only(bottom: 5, left: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _glowController,
                  builder: (_, __) => Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(
                              alpha: 0.7 * _glowController.value),
                          blurRadius: 6 * _glowController.value,
                          spreadRadius: 2 * _glowController.value,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'AIRA',
                  style: AiraTypography.caption.copyWith(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Message content
          MarkdownBody(
            data: _streamedText,
            styleSheet: MarkdownStyleSheet(
              p: AiraTypography.bodyMedium.copyWith(
                color: const Color(0xFFECEBE6),
                height: 1.7,
                fontSize: 15,
              ),
              h1: AiraTypography.h4.copyWith(color: const Color(0xFFECEBE6)),
              h2: AiraTypography.h5.copyWith(color: const Color(0xFFECEBE6)),
              h3: AiraTypography.h6.copyWith(color: const Color(0xFFECEBE6)),
              strong: AiraTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFECEBE6),
                fontSize: 15,
              ),
              em: AiraTypography.bodyMedium.copyWith(
                fontStyle: FontStyle.italic,
                color: Colors.white70,
                fontSize: 15,
              ),
              code: AiraTypography.bodySmall.copyWith(
                color: AiraColors.electricCyan,
                backgroundColor: const Color(0xFF1A1A18),
                fontFamily: 'monospace',
              ),
              codeblockDecoration: BoxDecoration(
                color: const Color(0xFF1A1A18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF33322E)),
              ),
              codeblockPadding: const EdgeInsets.all(14),
              listBullet: AiraTypography.bodyMedium.copyWith(
                color: AiraColors.electricCyan,
                fontSize: 15,
              ),
              blockquoteDecoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: AiraColors.electricCyan, width: 3),
                ),
              ),
              blockquotePadding: const EdgeInsets.only(left: 12),
            ),
            selectable: true,
          ),

          // Pulsing white orb indicator while streaming
          if (_isAnimating) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _glowController,
                  builder: (_, __) => Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white
                              .withValues(alpha: 0.9 * _glowController.value),
                          blurRadius: 12 * _glowController.value,
                          spreadRadius: 4 * _glowController.value,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Copy button after streaming done
          if (!_isAnimating && widget.message.content.isNotEmpty) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(
                    ClipboardData(text: widget.message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy_rounded,
                      size: 12, color: Colors.white30),
                  const SizedBox(width: 4),
                  Text(
                    'Copy',
                    style: AiraTypography.caption.copyWith(
                      color: Colors.white30,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
