import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/services/voice_service.dart';

/// Immersive Voice Listening Sheet for Stage F: Voice
///
/// Features:
/// - Breathing concentric glowing rings in Claude Terracotta
/// - Real-time animated audio waveforms
/// - Live interim speech transcript preview
/// - Instant interruption and spoken cancellation handling ("cancel", "vaddu", "oddu")
/// - Manual Send and Cancel controls
class VoiceListeningSheet extends StatefulWidget {
  final Function(String command) onCommandSubmitted;
  final VoidCallback? onCancelled;

  const VoiceListeningSheet({
    super.key,
    required this.onCommandSubmitted,
    this.onCancelled,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(String command) onCommandSubmitted,
    VoidCallback? onCancelled,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceListeningSheet(
        onCommandSubmitted: onCommandSubmitted,
        onCancelled: onCancelled,
      ),
    );
  }

  @override
  State<VoiceListeningSheet> createState() => _VoiceListeningSheetState();
}

class _VoiceListeningSheetState extends State<VoiceListeningSheet>
    with TickerProviderStateMixin {
  final VoiceService _voiceService = VoiceService();
  late AnimationController _pulseController;
  late AnimationController _waveController;

  String _transcribedText = '';
  String _statusText = 'Listening... speak your prompt';
  double _soundLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _startListening();
  }

  Future<void> _startListening() async {
    setState(() {
      _statusText = 'Listening... speak in English or Telugu';
    });

    final success = await _voiceService.startListening(
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() {
          _transcribedText = text;
        });
      },
      onCommandTriggered: (cleanCommand) {
        if (!mounted) return;
        _finishWithCommand(cleanCommand);
      },
      onCancelled: () {
        if (!mounted) return;
        _cancelVoiceInput();
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _statusText = 'Mic error: $error';
        });
      },
      onSoundLevelChange: (level) {
        if (!mounted) return;
        setState(() {
          _soundLevel = (level.clamp(-10.0, 10.0) + 10.0) / 20.0;
        });
      },
    );

    if (!success && mounted) {
      setState(() {
        _statusText = _voiceService.lastError.isNotEmpty
            ? _voiceService.lastError
            : 'Could not access microphone';
      });
    }
  }

  void _finishWithCommand(String command) {
    HapticFeedback.mediumImpact();
    _voiceService.stopListening();
    Navigator.of(context).pop();
    widget.onCommandSubmitted(command.isNotEmpty ? command : _transcribedText);
  }

  void _cancelVoiceInput() {
    HapticFeedback.lightImpact();
    _voiceService.cancelListening();
    if (mounted) {
      Navigator.of(context).pop();
      widget.onCancelled?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Voice cancelled',
            style: GoogleFonts.sourceSerif4(fontSize: 13),
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _voiceService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AiraColors.surfaceDark : AiraColors.surfaceLightWarm,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? AiraColors.borderDark : AiraColors.borderLight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AiraColors.claudeTerracotta.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AiraColors.claudeTerracotta.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.graphic_eq_rounded,
                  size: 14,
                  color: AiraColors.claudeTerracotta,
                ),
                const SizedBox(width: 6),
                Text(
                  'AIRA Voice • English + Telugu',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AiraColors.claudeTerracotta,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Glowing Concentric Voice Orb
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer animated ring
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final scale = 1.0 + (_pulseController.value * 0.25) + (_soundLevel * 0.15);
                  final opacity = (0.25 * (1.0 - _pulseController.value)).clamp(0.05, 0.3);
                  return Container(
                    width: 100 * scale,
                    height: 100 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AiraColors.claudeTerracotta.withValues(alpha: opacity),
                    ),
                  );
                },
              ),
              // Inner glowing core
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      AiraColors.claudeTerracotta,
                      Color(0xFFBF5E3B),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AiraColors.claudeTerracotta.withValues(alpha: 0.45),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dynamic Animated Waveform Bars
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, _) {
              return SizedBox(
                height: 28,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(12, (index) {
                    final waveOffset = index / 12.0;
                    final anim = math.sin((_waveController.value + waveOffset) * 2 * math.pi);
                    final barHeight = (6 + (anim.abs() * 18 * (0.4 + _soundLevel * 0.6))).clamp(5.0, 26.0);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2.2),
                      width: 3.5,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: AiraColors.claudeTerracotta.withValues(
                          alpha: 0.45 + (anim.abs() * 0.55),
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Status & Cancellation Hint
          Text(
            _statusText,
            textAlign: TextAlign.center,
            style: GoogleFonts.sourceSerif4(
              fontSize: 13,
              color: isDark ? AiraColors.textSecondary : AiraColors.textSecondaryLight,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),

          // Live Transcription Display Box
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 64, maxHeight: 110),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AiraColors.cardDark : AiraColors.cardLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _transcribedText.isNotEmpty
                    ? AiraColors.claudeTerracotta.withValues(alpha: 0.5)
                    : (isDark ? AiraColors.borderDark : AiraColors.borderLight),
                width: 1,
              ),
            ),
            child: SingleChildScrollView(
              child: Text(
                _transcribedText.isNotEmpty
                    ? _transcribedText
                    : 'Listening... (say "cancel" or "vaddu" to abort)',
                textAlign: TextAlign.center,
                style: GoogleFonts.sourceSerif4(
                  fontSize: 15,
                  fontWeight: _transcribedText.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                  color: _transcribedText.isNotEmpty
                      ? theme.colorScheme.onSurface
                      : (isDark ? AiraColors.textMuted : AiraColors.textMutedLight),
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons: Cancel and Send
          Row(
            children: [
              // Cancel Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cancelVoiceInput,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(
                    'Cancel',
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AiraColors.textSecondary : AiraColors.textSecondaryLight,
                    side: BorderSide(
                      color: isDark ? AiraColors.borderDark : AiraColors.borderLight,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Send Button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _transcribedText.trim().isNotEmpty
                      ? () => _finishWithCommand(_transcribedText.trim())
                      : null,
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  label: Text(
                    'Send Prompt',
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AiraColors.claudeTerracotta,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? Colors.white12 : Colors.black12,
                    disabledForegroundColor: isDark ? Colors.white38 : Colors.black38,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
