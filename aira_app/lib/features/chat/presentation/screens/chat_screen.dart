import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:aira_app/features/nav_shell/presentation/widgets/app_drawer.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    ref.read(chatProvider.notifier).sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    // Auto-scroll when new messages arrive
    ref.listen<ChatState>(chatProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AiraColors.cardDark,
        surfaceTintColor: Colors.transparent,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AiraColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  AiraColors.cyanPurpleGradient.createShader(bounds),
              child: Text(
                'AIRA',
                style: AiraTypography.h4.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AiraColors.success,
              ),
            ),
          ],
        ),
        actions: [
          if (chatState.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_rounded, color: AiraColors.textSecondary),
              tooltip: 'New Chat',
              onPressed: () => ref.read(chatProvider.notifier).clearChat(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages or empty state
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState()
                : _buildMessageList(chatState),
          ),
          // Error banner
          if (chatState.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AiraColors.error.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AiraColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatState.error!,
                      style: AiraTypography.caption.copyWith(color: AiraColors.error),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AiraColors.error),
                    onPressed: () => ref.read(chatProvider.notifier).clearError(),
                  ),
                ],
              ),
            ),
          // Input bar
          _buildInputBar(chatState.isSending),
        ],
      ),
    );
  }

  // ──────────────────── Empty State ────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AiraColors.electricCyan.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 36,
                color: AiraColors.electricCyan.withValues(alpha: 0.6),
              ),
            ).animate().fadeIn(duration: 500.ms).scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: 500.ms,
                ),
            const SizedBox(height: 24),
            Text(
              'How can I help you?',
              style: AiraTypography.h3.copyWith(color: AiraColors.textSecondary),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            const SizedBox(height: 8),
            Text(
              'Ask me anything — I\'m powered by Llama 3.3',
              style: AiraTypography.bodySmall.copyWith(color: AiraColors.textMuted),
            ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _suggestionChip('Plan my day'),
                _suggestionChip('Explain quantum computing'),
                _suggestionChip('Help me write code'),
                _suggestionChip('Summarize a topic'),
              ],
            ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String label) {
    return GestureDetector(
      onTap: () {
        _textController.text = label;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AiraColors.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AiraColors.glassBorder),
        ),
        child: Text(
          label,
          style: AiraTypography.caption.copyWith(color: AiraColors.textSecondary),
        ),
      ),
    );
  }

  // ──────────────────── Message List ────────────────────

  Widget _buildMessageList(ChatState chatState) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        final message = chatState.messages[index];

        if (message.isStreaming) {
          return _buildTypingIndicator();
        }

        return message.isUser
            ? _buildUserBubble(message.content)
            : _buildAssistantBubble(message.content);
      },
    );
  }

  Widget _buildUserBubble(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AiraColors.surfaceDark,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                content,
                style: AiraTypography.bodyMedium.copyWith(
                  color: AiraColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2, right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AiraColors.cyanPurpleGradient,
            ),
            child: const Center(
              child: Text('A', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          Flexible(
            child: MarkdownBody(
              data: content,
              styleSheet: MarkdownStyleSheet(
                p: AiraTypography.bodyMedium.copyWith(
                  color: AiraColors.textPrimary,
                  height: 1.6,
                ),
                h1: AiraTypography.h3.copyWith(color: AiraColors.textPrimary),
                h2: AiraTypography.h4.copyWith(color: AiraColors.textPrimary),
                h3: AiraTypography.h5.copyWith(color: AiraColors.textPrimary),
                strong: AiraTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AiraColors.textPrimary,
                ),
                em: AiraTypography.bodyMedium.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AiraColors.textSecondary,
                ),
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
                listBullet: AiraTypography.bodyMedium.copyWith(color: AiraColors.electricCyan),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AiraColors.cyanPurpleGradient,
            ),
            child: const Center(
              child: Text('A', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          ...[0, 1, 2].map((i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AiraColors.electricCyan.withValues(alpha: 0.6),
                  ),
                )
                    .animate(
                      onPlay: (controller) => controller.repeat(),
                    )
                    .fadeIn(delay: Duration(milliseconds: i * 200), duration: 400.ms)
                    .then()
                    .fadeOut(duration: 400.ms),
              )),
          const SizedBox(width: 4),
          Text(
            'Thinking...',
            style: AiraTypography.caption.copyWith(color: AiraColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ──────────────────── Input Bar ────────────────────

  Widget _buildInputBar(bool isSending) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: AiraColors.cardDark,
        border: Border(top: BorderSide(color: AiraColors.glassBorder)),
      ),
      child: Row(
        children: [
          // Attachment button
          IconButton(
            icon: const Icon(Icons.attach_file_rounded, color: AiraColors.textMuted, size: 22),
            tooltip: 'Attach file',
            onPressed: () {
              // TODO: image_picker integration
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('File sharing coming soon!', style: AiraTypography.bodySmall),
                  backgroundColor: AiraColors.surfaceDark,
                ),
              );
            },
          ),
          // Text field
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              style: AiraTypography.bodyMedium.copyWith(color: AiraColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Message AIRA...',
                hintStyle: AiraTypography.bodyMedium.copyWith(color: AiraColors.textMuted),
                filled: true,
                fillColor: AiraColors.surfaceDark,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AiraColors.electricCyan, width: 1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          GestureDetector(
            onTap: isSending ? null : _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSending ? null : AiraColors.cyanPurpleGradient,
                color: isSending ? AiraColors.surfaceDark : null,
              ),
              child: Center(
                child: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AiraColors.electricCyan,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
