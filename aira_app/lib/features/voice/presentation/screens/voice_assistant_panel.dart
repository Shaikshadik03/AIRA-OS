import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/features/voice/presentation/providers/voice_provider.dart';

class VoiceAssistantPanel extends ConsumerStatefulWidget {
  const VoiceAssistantPanel({super.key});

  @override
  ConsumerState<VoiceAssistantPanel> createState() => _VoiceAssistantPanelState();
}

class _VoiceAssistantPanelState extends ConsumerState<VoiceAssistantPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceProvider);

    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            ref.read(voiceProvider.notifier).cancelVoice();
            Navigator.pop(context);
          },
        ),
        title: Text('Voice Assistant', style: AiraTypography.h4),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glowing waveform indicator
              SizedBox(
                height: 200,
                width: double.infinity,
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: WavePainter(
                        waveValue: _waveController.value,
                        isRecording: state.isRecording,
                        isSpeaking: state.isSpeaking,
                        isLoading: state.isLoading,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
              // AI transcription log text
              if (state.transcript.isNotEmpty) ...[
                Text(
                  'YOU SAID:',
                  style: AiraTypography.overline.copyWith(color: AiraColors.electricCyan),
                ),
                const SizedBox(height: 8),
                Text(
                  state.transcript,
                  style: AiraTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ],
              // AI Response bubble
              if (state.responseText.isNotEmpty) ...[
                Text(
                  'AIRA:',
                  style: AiraTypography.overline.copyWith(color: AiraColors.purple),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AiraColors.cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AiraColors.glassBorder),
                  ),
                  child: Text(
                    state.responseText,
                    style: AiraTypography.bodyMedium.copyWith(height: 1.4, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
              ],
              // Empty description text
              if (state.transcript.isEmpty && state.responseText.isEmpty && !state.isLoading) ...[
                Text(
                  'Tap the button below to start talking with AIRA',
                  style: AiraTypography.bodySmall.copyWith(color: AiraColors.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
              ],
              // Micro Loading Spinner
              if (state.isLoading) ...[
                const CircularProgressIndicator(color: AiraColors.electricCyan),
                const SizedBox(height: 40),
              ],
              // Talk Action Button
              GestureDetector(
                onTapDown: (_) {
                  ref.read(voiceProvider.notifier).startRecording();
                },
                onTapUp: (_) {
                  ref.read(voiceProvider.notifier).stopRecordingAndProcess();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: state.isRecording
                        ? AiraColors.primaryGradient
                        : AiraColors.cyanPurpleGradient,
                    boxShadow: [
                      BoxShadow(
                        color: (state.isRecording ? AiraColors.electricCyan : AiraColors.purple)
                            .withValues(alpha: 0.4),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    state.isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                state.isRecording ? 'RELEASE TO SEND' : 'HOLD TO TALK',
                style: AiraTypography.overline.copyWith(
                  color: state.isRecording ? AiraColors.electricCyan : AiraColors.textMuted,
                  letterSpacing: 1.5,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double waveValue;
  final bool isRecording;
  final bool isSpeaking;
  final bool isLoading;

  WavePainter({
    required this.waveValue,
    required this.isRecording,
    required this.isSpeaking,
    required this.isLoading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final centerY = size.height / 2;
    final width = size.width;

    double amplitude = 5.0; // Idle state amplitude
    Color waveColor = AiraColors.textMuted.withValues(alpha: 0.3);

    if (isRecording) {
      amplitude = 25.0;
      waveColor = AiraColors.electricCyan;
    } else if (isSpeaking) {
      amplitude = 18.0;
      waveColor = AiraColors.purple;
    } else if (isLoading) {
      amplitude = 10.0;
      waveColor = AiraColors.warning;
    }

    final path = Path();
    path.moveTo(0, centerY);

    // Draw three wave phases to represent dynamic waveform overlay
    for (int waveNum = 0; waveNum < 3; waveNum++) {
      paint.color = waveColor.withValues(alpha: 1.0 - (waveNum * 0.3));
      final double phaseShift = waveNum * math.pi / 2;
      path.reset();
      path.moveTo(0, centerY);

      for (double x = 0; x <= width; x++) {
        final double relativeX = x / width;
        // Dampen waves on the edges so it fits within screen limits nicely
        final double edgeDampening = math.sin(relativeX * math.pi);
        
        final double y = centerY +
            amplitude *
                edgeDampening *
                math.sin((relativeX * 3 * 2 * math.pi) - (waveValue * 2 * math.pi) + phaseShift);

        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) => true;
}
