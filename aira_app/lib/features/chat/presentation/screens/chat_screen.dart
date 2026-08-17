import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/services/voice_service.dart';
import 'package:aira_app/core/services/android_device_service.dart';
import 'package:aira_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:aira_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:aira_app/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:aira_app/features/nav_shell/presentation/widgets/app_drawer.dart';
import 'package:aira_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';

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

  final VoiceService _voiceService = VoiceService();
  bool _isListening = false;
  bool _isHandsFreeActive = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    await _voiceService.initialize();
    if (mounted) setState(() {});
  }

  void _listen() async {
    if (!_isListening) {
      setState(() => _isListening = true);
      await _voiceService.startListening(
        onResult: (text, isFinal) {
          if (mounted) {
            setState(() {
              _textController.text = text;
            });
          }
        },
        onCommandTriggered: (cleanCommand) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _textController.text = cleanCommand;
            });
            _sendMessage();
          }
        },
      );
    } else {
      await _voiceService.stopListening();
      if (mounted) setState(() => _isListening = false);
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

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Auto-scroll when new messages arrive
    ref.listen<ChatState>(chatProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(
              Icons.menu_rounded,
              color: theme.colorScheme.onSurface,
              size: 24,
            ),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AIRA',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700,
                fontSize: 21,
                letterSpacing: 0.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AiraColors.claudeTerracotta.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AiraColors.claudeTerracotta.withValues(alpha: isDark ? 0.5 : 0.35),
                  width: 0.8,
                ),
              ),
              child: Text(
                'OS',
                style: GoogleFonts.sourceSerif4(
                  color: AiraColors.claudeTerracotta,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit_square,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              size: 20,
            ),
            tooltip: 'New Chat',
            onPressed: () => ref.read(chatProvider.notifier).clearChat(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Messages or empty state
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState(user?.displayName ?? 'there')
                : _buildMessageList(chatState),
          ),
          // Error banner
          if (chatState.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AiraColors.error.withValues(alpha: isDark ? 0.15 : 0.08),
                border: Border(
                  top: BorderSide(color: AiraColors.error.withValues(alpha: 0.3)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AiraColors.error, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      chatState.error!,
                      style: GoogleFonts.sourceSerif4(
                        color: AiraColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref.read(chatProvider.notifier).clearError(),
                    child: const Icon(Icons.close_rounded, size: 18, color: AiraColors.error),
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

  // ──────────────────── Claude-Style Empty State ────────────────────

  Widget _buildEmptyState(String userName) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Glowing Claude-style Terracotta Sparkle/Orb
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AiraColors.claudeTerracotta.withValues(alpha: isDark ? 0.15 : 0.1),
                border: Border.all(
                  color: AiraColors.claudeTerracotta.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 26,
                  color: AiraColors.claudeTerracotta,
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.85, 0.85), end: const Offset(1.0, 1.0)),
            const SizedBox(height: 18),

            // Warm Greeting
            Text(
              '${_getTimeGreeting()}, $userName',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
            const SizedBox(height: 6),

            Text(
              'How can I help you today?',
              textAlign: TextAlign.center,
              style: GoogleFonts.sourceSerif4(
                fontSize: 15,
                color: isDark ? AiraColors.textSecondary : AiraColors.textSecondaryLight,
                fontStyle: FontStyle.italic,
              ),
            ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
            const SizedBox(height: 28),

            // ── Hands-Free "Hey AIRA" Voice Card ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AiraColors.cardDark : AiraColors.cardLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isHandsFreeActive
                      ? AiraColors.success
                      : (isDark ? AiraColors.borderDark : AiraColors.borderLight),
                  width: _isHandsFreeActive ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isHandsFreeActive
                          ? AiraColors.success.withValues(alpha: 0.15)
                          : AiraColors.claudeTerracotta.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      _isHandsFreeActive ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                      color: _isHandsFreeActive ? AiraColors.success : AiraColors.claudeTerracotta,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isHandsFreeActive ? '🟢 "Hey AIRA" Listening' : 'Hands-Free "Hey AIRA"',
                          style: GoogleFonts.sourceSerif4(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _isHandsFreeActive ? AiraColors.success : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _isHandsFreeActive
                              ? 'Speak "Hey AIRA..." anytime'
                              : 'Tap Enable to activate wake word',
                          style: GoogleFonts.sourceSerif4(
                            fontSize: 12,
                            color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_isHandsFreeActive) {
                        await _voiceService.stopPassiveWakeWordLoop();
                        setState(() => _isHandsFreeActive = false);
                      } else {
                        setState(() => _isHandsFreeActive = true);
                        _voiceService.startPassiveWakeWordLoop(
                          onWakeWordDetected: (_) {},
                          onCommandTriggered: (command) {
                            if (command.isNotEmpty) {
                              _textController.text = command;
                              _sendMessage();
                            }
                          },
                        );
                        AndroidDeviceService().startOverlayService();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isHandsFreeActive
                          ? AiraColors.error
                          : AiraColors.claudeTerracotta,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(60, 34),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      _isHandsFreeActive ? 'Stop' : 'Enable',
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 350.ms, duration: 400.ms),

            const SizedBox(height: 24),

            // ── Claude-Style Prompt Starter Cards ──
            _buildClaudePromptTile(
              '🧠 Check my long-term memory',
              'Review what AIRA remembers about you',
              'show my memories',
              Icons.psychology_outlined,
            ),
            const SizedBox(height: 10),
            _buildClaudePromptTile(
              '🗞️ Read today\'s Daily Briefing',
              'AI news, India hackathons & CSE career tips',
              'show my daily briefing',
              Icons.newspaper_rounded,
            ),
            const SizedBox(height: 10),
            _buildClaudePromptTile(
              '📬 Scan Google Workspace',
              'Check latest emails, Drive files & events',
              'show my emails',
              Icons.email_outlined,
            ),
            const SizedBox(height: 10),
            _buildClaudePromptTile(
              '💡 Code review & problem solving',
              'Explain algorithms, debug code, or plan systems',
              'Help me architect a scalable system architecture',
              Icons.code_rounded,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildClaudePromptTile(String title, String subtitle, String prompt, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        _textController.text = prompt;
        _sendMessage();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AiraColors.cardDark : AiraColors.cardLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AiraColors.borderDark : AiraColors.borderLight,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: AiraColors.claudeTerracotta,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 12,
                      color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_outward_rounded,
              size: 16,
              color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
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
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        final message = chatState.messages[index];

        // Streaming placeholder → show TypingIndicator
        if (message.isStreaming) {
          return const TypingIndicator();
        }

        // Real message → MessageBubble
        return MessageBubble(message: message);
      },
    );
  }

  // ──────────────────── Claude Floating Input Bar ────────────────────

  Widget _buildInputBar(bool isSending) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceFill = isDark ? AiraColors.surfaceDark : AiraColors.surfaceLightWarm;
    final borderColor = isDark ? AiraColors.borderDark : AiraColors.borderLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isListening)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AiraColors.claudeTerracotta.withValues(alpha: isDark ? 0.15 : 0.08),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AiraColors.claudeTerracotta,
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.3, 1.3), duration: 600.ms),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Listening... speak your prompt',
                    style: GoogleFonts.sourceSerif4(
                      color: AiraColors.claudeTerracotta,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _listen,
                  child: const Icon(Icons.close_rounded, size: 18, color: AiraColors.claudeTerracotta),
                ),
              ],
            ),
          ),

        if (_selectedImage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.scaffoldBackgroundColor,
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
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
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // ── Bottom Floating Pill Bar ──
        Container(
          padding: EdgeInsets.fromLTRB(14, 8, 14, MediaQuery.of(context).padding.bottom + 10),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: borderColor, width: 0.8)),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: surfaceFill,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attach button
                IconButton(
                  icon: Icon(
                    Icons.add_circle_outline_rounded,
                    color: isDark ? AiraColors.textSecondary : AiraColors.textSecondaryLight,
                    size: 22,
                  ),
                  tooltip: 'Attach image',
                  onPressed: _pickImage,
                ),
                // Vision camera AI button
                IconButton(
                  icon: const Icon(
                    Icons.remove_red_eye_outlined,
                    color: AiraColors.claudeTerracotta,
                    size: 22,
                  ),
                  tooltip: 'AIRA Vision',
                  onPressed: () => context.push('/vision'),
                ),
                // Input TextField
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                        height: 1.45,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Message AIRA...',
                        hintStyle: GoogleFonts.sourceSerif4(
                          fontSize: 15,
                          color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                        ),
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                // Voice or Send Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 2, right: 4),
                  child: _textController.text.isEmpty && _selectedImage == null
                      ? GestureDetector(
                          onTap: _listen,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isListening
                                  ? AiraColors.error.withValues(alpha: 0.2)
                                  : Colors.transparent,
                            ),
                            child: Center(
                              child: Icon(
                                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                color: _isListening
                                    ? AiraColors.error
                                    : (isDark ? AiraColors.textSecondary : AiraColors.textSecondaryLight),
                                size: 22,
                              ),
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: isSending ? null : _sendMessage,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSending
                                  ? (isDark ? AiraColors.surfaceLight : Colors.black12)
                                  : AiraColors.claudeTerracotta,
                            ),
                            child: Center(
                              child: isSending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
