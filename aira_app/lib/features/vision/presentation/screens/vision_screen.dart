import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/features/vision/presentation/providers/vision_provider.dart';

class AiraVisionScreen extends ConsumerStatefulWidget {
  const AiraVisionScreen({super.key});

  @override
  ConsumerState<AiraVisionScreen> createState() => _AiraVisionScreenState();
}

class _AiraVisionScreenState extends ConsumerState<AiraVisionScreen>
    with TickerProviderStateMixin {
  final TextEditingController _queryController = TextEditingController();
  late AnimationController _pulseController;
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _pulseController.dispose();
    _scanController.dispose();
    ref.read(airaVisionProvider.notifier).stopSpeaking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vision = ref.watch(airaVisionProvider);
    final notifier = ref.read(airaVisionProvider.notifier);

    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () {
            notifier.reset();
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (b) => AiraColors.cyanPurpleGradient.createShader(b),
              child: const Text(
                'AIRA Vision',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AiraColors.electricCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AiraColors.electricCyan.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 10, color: AiraColors.electricCyan),
                  const SizedBox(width: 4),
                  Text('AI Powered', style: AiraTypography.overline.copyWith(
                    color: AiraColors.electricCyan,
                    fontSize: 9,
                  )),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (vision.state != VisionState.idle)
            TextButton.icon(
              onPressed: notifier.retake,
              icon: const Icon(Icons.refresh_rounded, size: 16, color: AiraColors.textMuted),
              label: Text('Retake', style: AiraTypography.caption.copyWith(color: AiraColors.textMuted)),
            ),
        ],
      ),
      body: _buildBody(vision, notifier),
    );
  }

  Widget _buildBody(AiraVisionState vision, AiraVisionNotifier notifier) {
    switch (vision.state) {
      case VisionState.idle:
        return _buildIdleState(notifier);
      case VisionState.captured:
        return _buildCapturedState(vision, notifier);
      case VisionState.analyzing:
        return _buildAnalyzingState(vision);
      case VisionState.result:
        return _buildResultState(vision, notifier);
      case VisionState.error:
        return _buildErrorState(vision, notifier);
    }
  }

  // ── Idle: Camera / Gallery options ──────────────────────────────────
  Widget _buildIdleState(AiraVisionNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero illustration
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 160 + (_pulseController.value * 10),
                        height: 160 + (_pulseController.value * 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AiraColors.electricCyan.withValues(alpha: 0.08 + _pulseController.value * 0.05),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: child,
                      );
                    },
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AiraColors.cardDark,
                        border: Border.all(color: AiraColors.electricCyan.withValues(alpha: 0.4), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AiraColors.electricCyan.withValues(alpha: 0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.remove_red_eye_rounded, size: 48, color: AiraColors.electricCyan),
                    ),
                  ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)),
                  const SizedBox(height: 28),
                  Text(
                    'Point. Ask. Understand.',
                    style: AiraTypography.h3.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AiraColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 12),
                  Text(
                    'Take a photo or pick from gallery.\nAIRA will analyze it instantly using AI Vision.',
                    style: AiraTypography.bodyMedium.copyWith(
                      color: AiraColors.textMuted,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 32),
                  // Use cases
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _useCaseChip('📷 Fix code errors'),
                      _useCaseChip('📄 Translate documents'),
                      _useCaseChip('🔍 Identify objects'),
                      _useCaseChip('🍎 Analyze food'),
                      _useCaseChip('📊 Read charts'),
                    ],
                  ).animate().fadeIn(delay: 600.ms),
                ],
              ),
            ),
          ),
          // Action buttons
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _primaryButton(
                icon: Icons.camera_alt_rounded,
                label: 'Open Camera',
                gradient: AiraColors.cyanPurpleGradient,
                onTap: notifier.captureFromCamera,
              ).animate().slideY(begin: 0.3, end: 0, delay: 700.ms, duration: 400.ms),
              const SizedBox(height: 12),
              _secondaryButton(
                icon: Icons.photo_library_rounded,
                label: 'Choose from Gallery',
                onTap: notifier.pickFromGallery,
              ).animate().slideY(begin: 0.3, end: 0, delay: 800.ms, duration: 400.ms),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Captured: show image + quick prompts + custom query ──────────────
  Widget _buildCapturedState(AiraVisionState vision, AiraVisionNotifier notifier) {
    return Column(
      children: [
        // Captured image preview
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                vision.capturedImage!,
                fit: BoxFit.cover,
              ),
              // Gradient overlay on bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 120,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AiraColors.scaffoldDark],
                    ),
                  ),
                ),
              ),
              // Scan line animation
              AnimatedBuilder(
                animation: _scanController,
                builder: (context, _) {
                  return Positioned(
                    top: _scanController.value * MediaQuery.of(context).size.height * 0.55,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AiraColors.electricCyan.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              // AI scanning badge
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AiraColors.electricCyan.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 12, color: AiraColors.electricCyan),
                      const SizedBox(width: 6),
                      Text('Image Captured', style: AiraTypography.overline.copyWith(color: AiraColors.electricCyan)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Query panel
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          color: AiraColors.scaffoldDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Quick Questions', style: AiraTypography.overline.copyWith(color: AiraColors.textMuted)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _quickPrompt('Describe this', notifier),
                    _quickPrompt('Fix the error', notifier),
                    _quickPrompt('Translate to English', notifier),
                    _quickPrompt('What object is this?', notifier),
                    _quickPrompt('Read the text in image', notifier),
                    _quickPrompt('Summarize this document', notifier),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Custom query input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      style: AiraTypography.bodyMedium.copyWith(color: AiraColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Or ask anything about this image...',
                        hintStyle: AiraTypography.bodySmall.copyWith(color: AiraColors.textMuted),
                        filled: true,
                        fillColor: AiraColors.surfaceDark,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
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
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => notifier.analyzeImage(_queryController.text),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AiraColors.cyanPurpleGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AiraColors.electricCyan.withValues(alpha: 0.3),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Analyzing: scanning animation ──────────────────────────────────
  Widget _buildAnalyzingState(AiraVisionState vision) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (vision.capturedImage != null)
                ColorFiltered(
                  colorFilter: const ColorFilter.mode(Colors.black45, BlendMode.darken),
                  child: Image.file(vision.capturedImage!, fit: BoxFit.cover),
                ),
              // Scan lines
              AnimatedBuilder(
                animation: _scanController,
                builder: (context, _) {
                  return Positioned(
                    top: _scanController.value * MediaQuery.of(context).size.height * 0.75,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AiraColors.electricCyan,
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(color: AiraColors.electricCyan.withValues(alpha: 0.5), blurRadius: 10),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Analyzing overlay
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AiraColors.electricCyan.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              color: AiraColors.electricCyan,
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'AIRA is analyzing...',
                            style: AiraTypography.bodyLarge.copyWith(
                              color: AiraColors.electricCyan,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '"${vision.query}"',
                            style: AiraTypography.caption.copyWith(
                              color: AiraColors.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Result: image + AI response ──────────────────────────────────
  Widget _buildResultState(AiraVisionState vision, AiraVisionNotifier notifier) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Captured image (compact)
          if (vision.capturedImage != null)
            Container(
              height: 200,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(vision.capturedImage!, fit: BoxFit.cover),
            ),
          // Query badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 14, color: AiraColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Query: "${vision.query}"',
                    style: AiraTypography.caption.copyWith(
                      color: AiraColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // AI Response card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AiraColors.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AiraColors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: AiraColors.electricCyan.withValues(alpha: 0.05),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AiraColors.cyanPurpleGradient,
                      ),
                      child: const Center(
                        child: Text('A', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'AIRA Vision Analysis',
                      style: AiraTypography.bodySmall.copyWith(
                        color: AiraColors.electricCyan,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: notifier.stopSpeaking,
                      child: const Icon(Icons.stop_circle_outlined, size: 18, color: AiraColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                MarkdownBody(
                  data: vision.result,
                  styleSheet: MarkdownStyleSheet(
                    p: AiraTypography.bodyMedium.copyWith(color: AiraColors.textPrimary, height: 1.7),
                    strong: AiraTypography.bodyMedium.copyWith(color: AiraColors.textPrimary, fontWeight: FontWeight.w700),
                    code: AiraTypography.bodySmall.copyWith(color: AiraColors.electricCyan, backgroundColor: AiraColors.scaffoldDark, fontFamily: 'monospace'),
                    codeblockDecoration: BoxDecoration(color: AiraColors.scaffoldDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: AiraColors.glassBorder)),
                    codeblockPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _secondaryButton(
                    icon: Icons.refresh_rounded,
                    label: 'Ask Again',
                    onTap: notifier.retake,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _primaryButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'New Photo',
                    gradient: AiraColors.cyanPurpleGradient,
                    onTap: notifier.captureFromCamera,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Error state ──────────────────────────────────────────────────
  Widget _buildErrorState(AiraVisionState vision, AiraVisionNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: AiraColors.error),
            const SizedBox(height: 16),
            Text('Something went wrong', style: AiraTypography.h4.copyWith(color: AiraColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              vision.errorMessage ?? 'Unknown error',
              style: AiraTypography.bodySmall.copyWith(color: AiraColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _primaryButton(
              icon: Icons.refresh_rounded,
              label: 'Try Again',
              gradient: AiraColors.cyanPurpleGradient,
              onTap: notifier.reset,
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────
  Widget _useCaseChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AiraColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AiraColors.glassBorder),
      ),
      child: Text(label, style: AiraTypography.caption.copyWith(color: AiraColors.textSecondary)),
    );
  }

  Widget _quickPrompt(String prompt, AiraVisionNotifier notifier) {
    return GestureDetector(
      onTap: () {
        _queryController.text = prompt;
        notifier.analyzeImage(prompt);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AiraColors.electricCyan.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AiraColors.electricCyan.withValues(alpha: 0.3)),
        ),
        child: Text(prompt, style: AiraTypography.caption.copyWith(color: AiraColors.electricCyan)),
      ),
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AiraColors.electricCyan.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(label, style: AiraTypography.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AiraColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AiraColors.glassBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AiraColors.textSecondary, size: 20),
            const SizedBox(width: 10),
            Text(label, style: AiraTypography.bodyMedium.copyWith(color: AiraColors.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
