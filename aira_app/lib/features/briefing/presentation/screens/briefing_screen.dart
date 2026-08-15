import 'package:flutter/material.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/services/supabase_briefing_service.dart';

class BriefingScreen extends StatefulWidget {
  const BriefingScreen({super.key});

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen> {
  final _service = SupabaseBriefingService();
  bool _loading = true;
  Map<String, Map<String, dynamic>?> _briefings = {
    'morning': null,
    'night': null,
  };

  @override
  void initState() {
    super.initState();
    _fetch();
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

  @override
  Widget build(BuildContext context) {
    final morning = _briefings['morning'];
    final night = _briefings['night'];

    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: AiraColors.scaffoldDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AiraColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Daily Intelligence',
          style: AiraTypography.h3.copyWith(
            color: AiraColors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AiraColors.electricCyan),
            onPressed: _fetch,
            tooltip: 'Refresh briefings',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AiraColors.electricCyan,
                strokeWidth: 2.5,
              ),
            )
          : RefreshIndicator(
              color: AiraColors.electricCyan,
              backgroundColor: AiraColors.cardDark,
              onRefresh: _fetch,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(
                    'AIRA Briefing Feed',
                    style: AiraTypography.h2.copyWith(color: AiraColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Curated AI intelligence, India hackathons, & CSE career updates.',
                    style: AiraTypography.bodySmall.copyWith(color: AiraColors.textMuted),
                  ),
                  const SizedBox(height: 20),

                  // Morning Brief Card
                  _BriefingCard(
                    title: '🌅 Morning Briefing',
                    scheduledTime: '7:00 AM IST',
                    accentColor: AiraColors.amber,
                    data: morning,
                    emptyFallback: 'No morning briefing generated yet.\nAIRA prepares your brief daily at 7:00 AM.',
                  ),

                  const SizedBox(height: 16),

                  // Night Brief Card
                  _BriefingCard(
                    title: '🌙 Night Recap & Tech Q&A',
                    scheduledTime: '10:00 PM IST',
                    accentColor: AiraColors.purpleLight,
                    data: night,
                    emptyFallback: 'No night briefing generated yet.\nAIRA prepares your day recap daily at 10:00 PM.',
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

    return Container(
      decoration: BoxDecoration(
        color: AiraColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withValues(alpha: 0.05),
            blurRadius: 16,
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
                          style: AiraTypography.bodyLarge.copyWith(
                            color: AiraColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          createdAt != null
                              ? 'Updated ${_formatTime(createdAt)}'
                              : widget.scheduledTime,
                          style: AiraTypography.caption.copyWith(
                            color: AiraColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AiraColors.textMuted,
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
                  color: AiraColors.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AiraColors.glassBorder),
                ),
                child: SelectableText(
                  content ?? widget.emptyFallback,
                  style: AiraTypography.bodyMedium.copyWith(
                    color: content != null ? AiraColors.textPrimary : AiraColors.textMuted,
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
