import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/features/chat/domain/chat_models.dart';
import 'package:aira_app/features/chat/presentation/screens/artifact_canvas_screen.dart';

/// Pure Claude-Style Message Bubble with Live Artifacts:
/// - User messages: Right-aligned compact bubble with warm surface tone and soft border.
/// - Assistant messages: Left-aligned generous layout, markdown typography with Source Serif 4,
///   smooth word-by-word streaming, pulsing glowing orb indicator, clean code blocks,
///   and interactive Claude Artifact Canvas.
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
      duration: const Duration(milliseconds: 750),
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

    _wordTimer = Timer.periodic(const Duration(milliseconds: 26), (timer) {
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

  List<_ArtifactSnippet> _extractArtifacts(String text) {
    final artifacts = <_ArtifactSnippet>[];
    final codeBlockRegex = RegExp(r'```([a-zA-Z0-9_-]*)\n([\s\S]*?)```');
    final matches = codeBlockRegex.allMatches(text);

    for (final m in matches) {
      final lang = m.group(1)?.trim();
      final code = m.group(2)?.trim() ?? '';
      if (code.length > 40) {
        final displayLang = (lang != null && lang.isNotEmpty) ? lang : 'code';
        artifacts.add(_ArtifactSnippet(
          language: displayLang,
          content: code,
          title: '$displayLang snippet (${code.split('\n').length} lines)',
        ));
      }
    }
    return artifacts;
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
                AnimatedBuilder(
                  animation: _glowController,
                  builder: (_, __) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AiraColors.claudeTerracotta,
                      boxShadow: [
                        BoxShadow(
                          color: AiraColors.claudeTerracotta.withValues(
                            alpha: 0.8 * _glowController.value,
                          ),
                          blurRadius: 7 * _glowController.value,
                          spreadRadius: 2 * _glowController.value,
                        ),
                      ],
                    ),
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
          MarkdownBody(
            data: _streamedText,
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
          if (!_isAnimating && artifacts.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...artifacts.map((art) => _buildArtifactCard(art, isDark)),
          ],

          // Pulsing glowing orb indicator while streaming
          if (_isAnimating) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _glowController,
                  builder: (_, __) => Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AiraColors.claudeTerracotta,
                      boxShadow: [
                        BoxShadow(
                          color: AiraColors.claudeTerracotta
                              .withValues(alpha: 0.9 * _glowController.value),
                          blurRadius: 10 * _glowController.value,
                          spreadRadius: 3 * _glowController.value,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Action buttons after message is finished
          if (!_isAnimating && widget.message.content.isNotEmpty) ...[
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
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArtifactCard(_ArtifactSnippet artifact, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? AiraColors.cardDark : AiraColors.cardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AiraColors.claudeTerracotta.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AiraColors.claudeTerracotta.withValues(alpha: 0.12),
          ),
          child: const Icon(
            Icons.code_rounded,
            color: AiraColors.claudeTerracotta,
            size: 18,
          ),
        ),
        title: Text(
          artifact.title,
          style: GoogleFonts.sourceSerif4(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Tap to open in Live Canvas',
          style: GoogleFonts.sourceSerif4(
            fontSize: 11.5,
            color: AiraColors.claudeTerracotta,
          ),
        ),
        trailing: const Icon(
          Icons.open_in_new_rounded,
          size: 18,
          color: AiraColors.claudeTerracotta,
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
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ArtifactSnippet {
  final String title;
  final String language;
  final String content;

  const _ArtifactSnippet({
    required this.title,
    required this.language,
    required this.content,
  });
}
