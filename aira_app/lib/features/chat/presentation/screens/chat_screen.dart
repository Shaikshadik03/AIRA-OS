import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:aira_app/features/nav_shell/presentation/widgets/app_drawer.dart';
import 'package:aira_app/features/auth/presentation/providers/auth_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    await _speech.initialize();
    setState(() {});
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _textController.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

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

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;
    
    _textController.clear();
    String? base64String;
    if (_selectedImage != null) {
      final bytes = await _selectedImage!.readAsBytes();
      base64String = base64Encode(bytes);
      setState(() {
        _selectedImage = null;
      });
    }
    
    ref.read(chatProvider.notifier).sendMessage(text, base64Image: base64String);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final user = ref.watch(currentUserProvider);

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            Text(
              "What's on your mind today, ${user?.displayName ?? 'User'}?",
              style: AiraTypography.caption.copyWith(
                color: AiraColors.textMuted,
                fontFamily: 'Source Serif 4',
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          // Google Workspace status chip
          GestureDetector(
            onTap: () {
              if (!chatState.isGoogleConnected) {
                ref.read(chatProvider.notifier).connectGoogleWorkspace();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Google Workspace connected ✓')),
                );
              }
            },
            child: Container(
              margin: const EdgeInsets.only(right: 4, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: chatState.isGoogleConnected
                    ? AiraColors.success.withValues(alpha: 0.15)
                    : AiraColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: chatState.isGoogleConnected
                      ? AiraColors.success.withValues(alpha: 0.4)
                      : AiraColors.glassBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    chatState.isGoogleConnected ? Icons.check_circle_rounded : Icons.g_mobiledata_rounded,
                    size: 16,
                    color: chatState.isGoogleConnected ? AiraColors.success : AiraColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    chatState.isGoogleConnected ? 'Google' : 'Connect',
                    style: AiraTypography.caption.copyWith(
                      color: chatState.isGoogleConnected ? AiraColors.success : AiraColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (chatState.messages.isNotEmpty)
            IconButton(
              icon: Icon(
                ref.read(chatProvider.notifier).isVoiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: AiraColors.textSecondary,
              ),
              onPressed: () {
                final notifier = ref.read(chatProvider.notifier);
                notifier.toggleVoice(!notifier.isVoiceEnabled);
                setState(() {});
              },
            ),
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
                _suggestionChip('Remember Rahul\'s email 🧠', Icons.psychology_rounded),
                _suggestionChip('Show my emails 📬', Icons.email_rounded),
                _suggestionChip('Create sheet Expenses 📊', Icons.table_chart_rounded),
                _suggestionChip('Show my calendar 📅', Icons.calendar_today_rounded),


              ],
            ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
            const SizedBox(height: 16),
            Text(
              'Tip: Say "connect Google Workspace" to enable Gmail & Calendar',
              style: AiraTypography.caption.copyWith(color: AiraColors.textMuted),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 800.ms, duration: 400.ms),

          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String label, [IconData? icon]) {
    return GestureDetector(
      onTap: () {
        _textController.text = label.replaceAll(RegExp(r'[📬📅]'), '').trim();
        _sendMessage();
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
            if (icon != null) ...[
              Icon(icon, size: 14, color: AiraColors.electricCyan),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AiraTypography.caption.copyWith(color: AiraColors.textSecondary),
            ),
          ],
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
            ? _buildUserBubble(message.content, message.base64Image)
            : _buildAssistantBubble(message.content);
      },
    );
  }

  Widget _buildUserBubble(String content, String? base64Image) {
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (base64Image != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: MemoryImage(base64Decode(base64Image)),
                          fit: BoxFit.cover,
                        ),
                      ),
                      width: double.infinity,
                      height: 150,
                    ),
                  Text(
                    content,
                    style: AiraTypography.bodyMedium.copyWith(
                      color: AiraColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedImage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AiraColors.scaffoldDark,
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      top: -4,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImage = null),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Container(
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
                tooltip: 'Attach photo',
                onPressed: _pickImage,
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
              // Voice / Send button
              if (_textController.text.isEmpty && _selectedImage == null)
                GestureDetector(
                  onTap: _listen,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? AiraColors.error.withValues(alpha: 0.2) : AiraColors.surfaceDark,
                      border: Border.all(color: _isListening ? AiraColors.error : AiraColors.glassBorder),
                    ),
                    child: Center(
                      child: Icon(
                        _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: _isListening ? AiraColors.error : AiraColors.electricCyan,
                        size: 20,
                      ),
                    ),
                  ),
                )
              else
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
                                valueColor: AlwaysStoppedAnimation<Color>(AiraColors.electricCyan),
                              ),
                            )
                          : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
