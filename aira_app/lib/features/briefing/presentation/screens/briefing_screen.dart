import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/services/supabase_briefing_service.dart';
import 'package:aira_app/core/widgets/organic_waveform.dart';

class BriefingScreen extends StatefulWidget {
  const BriefingScreen({super.key});

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
  final _service = SupabaseBriefingService();
  final FlutterTts _tts = FlutterTts();
  bool _loading = true;
  bool _isPlayingAudio = false;
  double _speechRate = 0.5; // 1.0x standard TTS speed
  Map<String, Map<String, dynamic>?> _briefings = {
    'morning': null,
    'night': null,
  };

  @override
  void initState() {
    super.initState();
    _initTts();
    _fetch();
  }

  void _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(1.0);

    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlayingAudio = false);
    });

    _tts.setCancelHandler(() {
      if (mounted) setState(() => _isPlayingAudio = false);
    });

    _tts.setErrorHandler((msg) {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final data = await _service.getLatestBriefings();
    if (mounted) {
      setState(() {
        _briefings = data;
        _loading = false;
      });
    }
  }

  void _toggleAudioBriefing() async {
    if (_isPlayingAudio) {
      await _tts.stop();
      if (mounted) setState(() => _isPlayingAudio = false);
    } else {
      final morningContent = _briefings['morning']?['content'] as String?;
      final nightContent = _briefings['night']?['content'] as String?;
      final contentToRead = morningContent ?? nightContent ?? 'No daily briefing has been generated yet.';

      // Clean markdown tags & symbols for natural voice narration
      final cleanText = contentToRead
          .replaceAll(RegExp(r'[*#_`\[\]>]'), '')
          .replaceAll(RegExp(r'https?:\/\/\S+'), '')
          .replaceAll(RegExp(r'[🌅🌙📰🏆💼🎓📚📬✨]'), '');

      if (mounted) setState(() => _isPlayingAudio = true);
      await _tts.setSpeechRate(_speechRate);
      await _tts.speak(cleanText);
    }
  }

  void _cycleSpeechRate() async {
    double nextRate = 0.5;
    if (_speechRate == 0.5) {
      nextRate = 0.6; // 1.25x
    } else if (_speechRate == 0.6) {
      nextRate = 0.7; // 1.5x
    } else {
      nextRate = 0.5; // 1.0x
    }

    setState(() => _speechRate = nextRate);
    await _tts.setSpeechRate(nextRate);
  }

  String _getSpeedLabel() {
    if (_speechRate == 0.5) return '1.0x';
    if (_speechRate == 0.6) return '1.25x';
    return '1.5x';
  }

  @override
  Widget build(BuildContext context) {
    final morning = _briefings['morning'];
    final night = _briefings['night'];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? AiraColors.cardDark : AiraColors.cardLight;
    final borderColor = isDark ? AiraColors.borderDark : AiraColors.borderLight;
    final mutedColor = isDark ? AiraColors.textMuted : AiraColors.textMutedLight;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Daily Intelligence',
          style: GoogleFonts.playfairDisplay(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AiraColors.claudeTerracotta),
            onPressed: _fetch,
            tooltip: 'Refresh briefings',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AiraColors.claudeTerracotta,
                strokeWidth: 2.5,
              ),
            )
          : RefreshIndicator(
              color: AiraColors.claudeTerracotta,
              backgroundColor: cardBg,
              onRefresh: _fetch,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
                children: [
                  // ── Audio Podcast Player Card ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isPlayingAudio
                            ? AiraColors.claudeTerracotta
                            : borderColor,
                        width: _isPlayingAudio ? 1.4 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AiraColors.claudeTerracotta,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _isPlayingAudio ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                onPressed: _toggleAudioBriefing,
                                tooltip: _isPlayingAudio ? 'Pause' : 'Play Briefing Podcast',
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isPlayingAudio ? '🎙️ Playing Audio Briefing' : 'Morning Podcast Briefing',
                                    style: GoogleFonts.sourceSerif4(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isPlayingAudio
                                        ? 'AIRA is reading today\'s brief aloud'
                                        : 'Listen to today\'s news & agenda on the go',
                                    style: GoogleFonts.sourceSerif4(
                                      fontSize: 12,
                                      color: mutedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: _cycleSpeechRate,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? AiraColors.surfaceDark : AiraColors.surfaceLightWarm,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Text(
                                  _getSpeedLabel(),
                                  style: GoogleFonts.sourceSerif4(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AiraColors.claudeTerracotta,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isPlayingAudio) ...[
                          const SizedBox(height: 12),
                          OrganicVoiceVisualizer(
                            isActive: _isPlayingAudio,
                            height: 36,
                            primaryColor: AiraColors.claudeTerracotta,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'AIRA Intelligence Feed',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Curated AI intelligence, India hackathons, & CSE career updates.',
                    style: GoogleFonts.sourceSerif4(
                      color: mutedColor,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Morning Brief Card
                  _BriefingCard(
                    title: '🌅 Morning Briefing',
                    scheduledTime: '7:00 AM IST',
                    accentColor: AiraColors.claudeAmber,
                    data: morning,
                    emptyFallback: 'No morning briefing generated yet.\nAIRA prepares your brief daily at 7:00 AM IST.',
                  ),

                  const SizedBox(height: 16),

                  // Night Brief Card
                  _BriefingCard(
                    title: '🌙 Night Recap & Q&A',
                    scheduledTime: '10:00 PM IST',
                    accentColor: AiraColors.claudeTerracotta,
                    data: night,
                    emptyFallback: 'No night briefing generated yet.\nAIRA prepares your day recap daily at 10:00 PM IST.',
                  ),
                ],
              ),
            ),
    );
  }
}

class _BriefingCard extends StatefulWidget {
  final String title;
  final String scheduledTime;
  final Color accentColor;
  final Map<String, dynamic>? data;
  final String emptyFallback;

  const _BriefingCard({
    required this.title,
    required this.scheduledTime,
    required this.accentColor,
    required this.data,
    required this.emptyFallback,
  });

  @override
  State<_BriefingCard> createState() => _BriefingCardState();
}

class _BriefingCardState extends State<_BriefingCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final content = widget.data?['content'] as String?;
    final createdAt = widget.data?['created_at'] as String?;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AiraColors.cardDark : AiraColors.cardLight;
    final contentBg = isDark ? AiraColors.surfaceDark : AiraColors.surfaceLightWarm;
    final borderColor = isDark ? AiraColors.borderDark : AiraColors.borderLight;
    final mutedColor = isDark ? AiraColors.textMuted : AiraColors.textMutedLight;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: isDark ? 0.35 : 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 38,
                    decoration: BoxDecoration(
                      color: widget.accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.sourceSerif4(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          createdAt != null
                              ? 'Updated ${_formatTime(createdAt)}'
                              : widget.scheduledTime,
                          style: GoogleFonts.sourceSerif4(
                            color: mutedColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: mutedColor,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: contentBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: SelectableText(
                  content ?? widget.emptyFallback,
                  style: GoogleFonts.sourceSerif4(
                    color: content != null ? theme.colorScheme.onSurface : mutedColor,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month} at $h:$m';
    } catch (_) {
      return '';
    }
  }
}
