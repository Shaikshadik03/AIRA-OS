import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/features/chat/domain/chat_models.dart';

/// Claude-Style Message Bubble with Word-by-Word Streaming Animation & Pulsing White Glowing Orb Indicator.
class MessageBubble extends StatefulWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with SingleTickerProviderStateMixin {
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

    _initWordStreaming();
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.content != widget.message.content) {
      _initWordStreaming();
    }
  }

  void _initWordStreaming() {
    if (!widget.message.isAssistant || widget.message.content.isEmpty) {
      _isAnimating = false;
      return;
    }

    _words = widget.message.content.split(' ');
    if (_words.isEmpty) {
      _isAnimating = false;
      return;
    }

    // Always start streaming animation for assistant messages
    _displayedWordCount = 1;
    _isAnimating = true;
    _wordTimer?.cancel();

    _wordTimer = Timer.periodic(const Duration(milliseconds: 28), (timer) {
      if (!mounted) return;
      if (_displayedWordCount < _words.length) {
        setState(() {
          _displayedWordCount++;
        });
      } else {
        timer.cancel();
        setState(() {
          _isAnimating = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _wordTimer?.cancel();
    super.dispose();
  }

  String get _currentText {
    if (!widget.message.isAssistant || !_isAnimating) {
      return widget.message.content;
    }
    return _words.take(_displayedWordCount).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 12,
        right: isUser ? 12 : 60,
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Header Label
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isUser) ...[
                  AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, child) {
                      return Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.8 * _glowController.value),
                              blurRadius: 8 * _glowController.value,
                              spreadRadius: 2 * _glowController.value,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  isUser ? 'YOU' : 'AIRA • CLAUDE MODE',
                  style: AiraTypography.overline.copyWith(
                    color: isUser
                        ? AiraColors.electricCyan.withValues(alpha: 0.8)
                        : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // Message Bubble
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isUser
                  ? AiraColors.electricCyan.withValues(alpha: 0.14)
                  : const Color(0xFF1F1E1B),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              border: Border.all(
                color: isUser
                    ? AiraColors.electricCyan.withValues(alpha: 0.3)
                    : const Color(0xFF33322E),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.message.isAssistant) ...[
                  MarkdownBody(
                    data: _currentText,
                    styleSheet: MarkdownStyleSheet(
                      p: AiraTypography.bodyMedium.copyWith(
                        color: const Color(0xFFF4F3EE),
                        height: 1.6,
                        fontSize: 15,
                      ),
                      h1: AiraTypography.h4.copyWith(color: const Color(0xFFF4F3EE)),
                      h2: AiraTypography.h5.copyWith(color: const Color(0xFFF4F3EE)),
                      h3: AiraTypography.h6.copyWith(color: const Color(0xFFF4F3EE)),
                      code: AiraTypography.bodySmall.copyWith(
                        color: AiraColors.electricCyan,
                        backgroundColor: const Color(0xFF141413),
                        fontFamily: 'monospace',
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: const Color(0xFF141413),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF33322E)),
                      ),
                      codeblockPadding: const EdgeInsets.all(12),
                      listBullet: AiraTypography.bodyMedium.copyWith(
                        color: AiraColors.electricCyan,
                      ),
                      blockquoteDecoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: AiraColors.electricCyan,
                            width: 3,
                          ),
                        ),
                      ),
                      blockquotePadding: const EdgeInsets.only(left: 12),
                      strong: AiraTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF4F3EE),
                      ),
                      em: AiraTypography.bodyMedium.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AiraColors.textSecondary,
                      ),
                    ),
                    selectable: true,
                  ),

                  // White Glowing Orb Indicator during streaming
                  if (_isAnimating || widget.message.isStreaming) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _glowController,
                          builder: (context, child) {
                            return Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.9 * _glowController.value),
                                    blurRadius: 12 * _glowController.value,
                                    spreadRadius: 4 * _glowController.value,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'typing words live...',
                          style: AiraTypography.caption.copyWith(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ] else ...[
                  // User message with optional image
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (widget.message.base64Image != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: MemoryImage(base64Decode(widget.message.base64Image!)),
                              fit: BoxFit.cover,
                            ),
                          ),
                          width: double.infinity,
                          height: 150,
                        ),
                      ],
                      SelectableText(
                        widget.message.content,
                        style: AiraTypography.bodyMedium.copyWith(
                          color: const Color(0xFFF4F3EE),
                          height: 1.5,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],

                // Action Buttons
                if (widget.message.isAssistant && widget.message.content.isNotEmpty && !_isAnimating) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.message.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.copy_rounded, size: 13, color: AiraColors.textMuted),
                              const SizedBox(width: 4),
                              Text('Copy', style: AiraTypography.caption.copyWith(color: AiraColors.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
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
}
