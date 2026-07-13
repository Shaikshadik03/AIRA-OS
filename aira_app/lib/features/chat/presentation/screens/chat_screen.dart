import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:aira_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:aira_app/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:aira_app/features/chat/presentation/widgets/chat_input_bar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AiraColors.success,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Online',
              style: AiraTypography.overline.copyWith(
                color: AiraColors.success,
                fontSize: 9,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AiraColors.textSecondary),
            tooltip: 'New Chat',
            onPressed: () {
              ref.read(chatProvider.notifier).clearChat();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
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
                      style: AiraTypography.caption.copyWith(
                        color: AiraColors.error,
                      ),
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
          ChatInputBar(
            isLoading: chatState.isSending,
            onSend: (text) {
              ref.read(chatProvider.notifier).sendMessage(text);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AiraColors.electricCyan.withValues(alpha: 0.15),
                    AiraColors.electricCyan.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 40,
                color: AiraColors.electricCyan.withValues(alpha: 0.6),
              ),
            ).animate().fadeIn(duration: 500.ms).scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: 500.ms,
                ),
            const SizedBox(height: 24),
            Text(
              'How can I help you today?',
              style: AiraTypography.h4.copyWith(
                color: AiraColors.textSecondary,
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            const SizedBox(height: 8),
            Text(
              'Ask me anything — I remember everything!',
              style: AiraTypography.bodySmall.copyWith(
                color: AiraColors.textMuted,
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
            const SizedBox(height: 32),
            // Suggestion chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _suggestionChip('📝 Plan my day', Icons.today_rounded),
                _suggestionChip('💡 Give me an idea', Icons.lightbulb_outline),
                _suggestionChip('🧠 What do you know?', Icons.psychology_rounded),
                _suggestionChip('💻 Help me code', Icons.code_rounded),
              ],
            ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String label, IconData icon) {
    return GestureDetector(
      onTap: () {
        ref.read(chatProvider.notifier).sendMessage(label.substring(2).trim());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AiraColors.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AiraColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AiraColors.electricCyan),
            const SizedBox(width: 6),
            Text(
              label.substring(2).trim(),
              style: AiraTypography.caption.copyWith(
                color: AiraColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ChatState chatState) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        final message = chatState.messages[index];

        // Show typing indicator for streaming placeholder
        if (message.isStreaming) {
          return const TypingIndicator();
        }

        return MessageBubble(message: message);
      },
    );
  }
}
