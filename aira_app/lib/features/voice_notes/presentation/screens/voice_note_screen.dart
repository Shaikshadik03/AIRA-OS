import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/features/voice_notes/presentation/providers/voice_note_provider.dart';

class VoiceNoteScreen extends ConsumerStatefulWidget {
  const VoiceNoteScreen({super.key});

  @override
  ConsumerState<VoiceNoteScreen> createState() => _VoiceNoteScreenState();
}

class _VoiceNoteScreenState extends ConsumerState<VoiceNoteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(voiceNoteProvider);
    final notifier = ref.read(voiceNoteProvider.notifier);

    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (b) => AiraColors.cyanPurpleGradient.createShader(b),
              child: const Text(
                'Meeting Summarizer',
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
                color: AiraColors.purple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AiraColors.purpleLight.withValues(alpha: 0.4)),
              ),
              child: Text(
                'AI Record',
                style: AiraTypography.overline.copyWith(color: AiraColors.purpleLight, fontSize: 9),
              ),
            ),
          ],
        ),
        actions: [
          if (status.state != VoiceNoteState.idle)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AiraColors.textMuted),
              tooltip: 'New Note',
              onPressed: notifier.reset,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Timer header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AiraColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AiraColors.glassBorder),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final isRec = status.state == VoiceNoteState.recording;
                      return Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isRec ? AiraColors.error : AiraColors.textMuted,
                          boxShadow: isRec
                              ? [
                                  BoxShadow(
                                    color: AiraColors.error.withValues(alpha: _pulseController.value * 0.8),
                                    blurRadius: 10,
                                    spreadRadius: 3,
                                  ),
                                ]
                              : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Text(
                    status.state == VoiceNoteState.recording
                        ? 'RECORDING LIVE'
                        : status.state == VoiceNoteState.processing
                            ? 'SUMMARIZING WITH AI...'
                            : status.state == VoiceNoteState.completed
                                ? 'SUMMARY READY'
                                : 'READY TO RECORD',
                    style: AiraTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: status.state == VoiceNoteState.recording
                          ? AiraColors.error
                          : AiraColors.electricCyan,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDuration(status.durationSeconds),
                    style: AiraTypography.h4.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AiraColors.textPrimary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Content panel (Live transcript or AI Summary)
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AiraColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AiraColors.glassBorder),
                ),
                child: status.state == VoiceNoteState.processing
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: AiraColors.electricCyan),
                            const SizedBox(height: 16),
                            Text(
                              'Analyzing meeting transcript with AIRA AI...',
                              style: AiraTypography.bodyMedium.copyWith(color: AiraColors.electricCyan),
                            ),
                          ],
                        ),
                      )
                    : status.summary.isNotEmpty
                        ? SingleChildScrollView(
                            child: MarkdownBody(
                              data: status.summary,
                              styleSheet: MarkdownStyleSheet(
                                p: AiraTypography.bodyMedium.copyWith(color: AiraColors.textPrimary, height: 1.6),
                                h1: AiraTypography.h3.copyWith(color: AiraColors.electricCyan),
                                h2: AiraTypography.h4.copyWith(color: AiraColors.electricCyan),
                                strong: AiraTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AiraColors.textPrimary),
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live Speech Transcript:',
                                  style: AiraTypography.overline.copyWith(color: AiraColors.textMuted),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  status.transcript.isNotEmpty
                                      ? status.transcript
                                      : 'Tap the microphone button below to start recording your meeting or lecture. AIRA will transcribe in real-time.',
                                  style: AiraTypography.bodyMedium.copyWith(
                                    color: status.transcript.isNotEmpty
                                        ? AiraColors.textPrimary
                                        : AiraColors.textMuted,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 16),
            // Action bar
            if (status.state == VoiceNoteState.completed) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: status.isExportedToDoc
                          ? null
                          : () => notifier.exportToGoogleDoc('Meeting Notes'),
                      icon: Icon(
                        status.isExportedToDoc ? Icons.check_rounded : Icons.description_rounded,
                        size: 16,
                      ),
                      label: Text(status.isExportedToDoc ? 'Exported to Doc' : 'Save to Docs'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AiraColors.electricCyan,
                        side: const BorderSide(color: AiraColors.electricCyan),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: status.isExportedToMemory
                          ? null
                          : notifier.saveToMemory,
                      icon: Icon(
                        status.isExportedToMemory ? Icons.check_rounded : Icons.psychology_rounded,
                        size: 16,
                      ),
                      label: Text(status.isExportedToMemory ? 'Saved in Memory' : 'Save to Memory'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AiraColors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            // Record / Stop Record Button
            GestureDetector(
              onTap: () {
                if (status.state == VoiceNoteState.recording) {
                  notifier.stopRecordingAndSummarize();
                } else if (status.state == VoiceNoteState.idle || status.state == VoiceNoteState.completed) {
                  notifier.startRecording();
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: status.state == VoiceNoteState.recording
                      ? const LinearGradient(colors: [AiraColors.error, Colors.redAccent])
                      : AiraColors.cyanPurpleGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (status.state == VoiceNoteState.recording ? AiraColors.error : AiraColors.electricCyan)
                          .withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      status.state == VoiceNoteState.recording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      status.state == VoiceNoteState.recording
                          ? 'Stop & Generate AI Summary'
                          : 'Start Meeting Recording',
                      style: AiraTypography.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
