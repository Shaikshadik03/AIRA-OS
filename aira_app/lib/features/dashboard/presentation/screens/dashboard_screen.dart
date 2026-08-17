import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:aira_app/features/planner/presentation/providers/planner_provider.dart';
import 'package:aira_app/core/services/dsa_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final DsaProblemService _dsaService = DsaProblemService();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(plannerProvider.notifier).loadAll();
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
    final currentUser = ref.watch(currentUserProvider);
    final plannerState = ref.watch(plannerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final String displayName = currentUser?.displayName ?? 'Arshan';
    final double progress = plannerState.completionRate;
    final todayDsa = _dsaService.getTodayProblem();

    final cardBg = isDark ? AiraColors.cardDark : AiraColors.cardLight;
    final surfaceFill = isDark ? AiraColors.surfaceDark : AiraColors.surfaceLightWarm;
    final borderColor = isDark ? AiraColors.borderDark : AiraColors.borderLight;
    final mutedColor = isDark ? AiraColors.textMuted : AiraColors.textMutedLight;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AiraColors.claudeTerracotta,
          onRefresh: () async {
            await ref.read(plannerProvider.notifier).loadAll();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Dynamic Context Island ──
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/briefing');
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AiraColors.claudeTerracotta.withValues(alpha: isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AiraColors.claudeTerracotta.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AiraColors.claudeTerracotta,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Daily Intelligence Briefing Active',
                          style: GoogleFonts.sourceSerif4(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AiraColors.claudeTerracotta,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AiraColors.claudeTerracotta),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ── Header ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getGreeting()},',
                            style: GoogleFonts.sourceSerif4(
                              color: mutedColor,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayName,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AiraColors.claudeTerracotta,
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                          style: GoogleFonts.sourceSerif4(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 4),
                Text(
                  today,
                  style: GoogleFonts.sourceSerif4(
                    color: mutedColor,
                    fontSize: 13,
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

                const SizedBox(height: 24),

                // ── Daily DSA Challenge Card (CSE Superpower) ──
                _buildDsaCard(todayDsa, isDark, cardBg, borderColor, surfaceFill, theme),

                const SizedBox(height: 24),

                // ── Exam & Hackathon Countdown Timers ──
                _buildCountdowns(isDark, cardBg, borderColor, mutedColor, theme),

                const SizedBox(height: 24),

                // ── Quick Actions Grid ──
                Text(
                  'QUICK ACTIONS',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.3,
                  children: [
                    _quickActionTile('AI Chat', Icons.chat_bubble_outline_rounded, AiraColors.claudeTerracotta, () => context.go('/chat'), cardBg, borderColor, theme),
                    _quickActionTile('Planner', Icons.calendar_month_outlined, AiraColors.claudeAmber, () => context.go('/planner'), cardBg, borderColor, theme),
                    _quickActionTile('Intelligence', Icons.newspaper_rounded, AiraColors.purpleLight, () => context.push('/briefing'), cardBg, borderColor, theme),
                    _quickActionTile('Settings', Icons.settings_outlined, AiraColors.electricCyan, () => context.push('/settings'), cardBg, borderColor, theme),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Daily Tasks Progress ──
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Daily Task Goal',
                            style: GoogleFonts.sourceSerif4(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}% Done',
                            style: GoogleFonts.sourceSerif4(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AiraColors.claudeTerracotta,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress > 0 ? progress : 0.05,
                          minHeight: 8,
                          backgroundColor: surfaceFill,
                          valueColor: const AlwaysStoppedAnimation<Color>(AiraColors.claudeTerracotta),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${plannerState.tasks.where((t) => t.isCompleted).length} of ${plannerState.tasks.length} tasks completed.',
                        style: GoogleFonts.sourceSerif4(
                          fontSize: 12.5,
                          color: mutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDsaCard(
    DsaProblem dsa,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color surfaceFill,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AiraColors.claudeTerracotta.withValues(alpha: isDark ? 0.35 : 0.45),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.code_rounded, color: AiraColors.claudeTerracotta, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'DSA Problem of the Day',
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: dsa.difficulty == 'Easy'
                      ? AiraColors.success.withValues(alpha: 0.15)
                      : AiraColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dsa.difficulty,
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: dsa.difficulty == 'Easy' ? AiraColors.success : AiraColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            dsa.title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dsa.description,
            style: GoogleFonts.sourceSerif4(
              fontSize: 13,
              color: isDark ? AiraColors.textSecondary : AiraColors.textSecondaryLight,
              height: 1.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Topic: ${dsa.topic}',
                style: GoogleFonts.sourceSerif4(
                  fontSize: 12,
                  color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              ElevatedButton(
                onPressed: () => _showDsaModal(dsa),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AiraColors.claudeTerracotta,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(80, 34),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'Solve & Solution',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDsaModal(DsaProblem dsa) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1B1A17) : const Color(0xFFFAF9F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  dsa.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${dsa.difficulty} · ${dsa.topic} · Time: ${dsa.timeComplexity} · Space: ${dsa.spaceComplexity}',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 12.5,
                    color: AiraColors.claudeTerracotta,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Problem Statement',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dsa.description,
                  style: GoogleFonts.sourceSerif4(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 14),
                Text(
                  '💡 Hint',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AiraColors.claudeAmber,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dsa.hint,
                  style: GoogleFonts.sourceSerif4(fontSize: 13.5, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 18),
                Text(
                  'Python Solution',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141311) : const Color(0xFF262523),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    dsa.pythonSolution,
                    style: GoogleFonts.firaCode(fontSize: 13, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'C++ Solution',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141311) : const Color(0xFF262523),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    dsa.cppSolution,
                    style: GoogleFonts.firaCode(fontSize: 13, color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCountdowns(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color mutedColor,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UPCOMING DEADLINES & EXAMS',
          style: GoogleFonts.sourceSerif4(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: mutedColor,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.school_outlined, color: AiraColors.claudeTerracotta, size: 18),
                        Text(
                          'CSE Semester',
                          style: GoogleFonts.sourceSerif4(fontSize: 11, color: mutedColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mid-Sem Exams',
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '18 Days Left',
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AiraColors.claudeTerracotta,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.emoji_events_outlined, color: AiraColors.claudeAmber, size: 18),
                        Text(
                          'India AI',
                          style: GoogleFonts.sourceSerif4(fontSize: 11, color: mutedColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'IIT Hackathon',
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '6 Days Left',
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AiraColors.claudeAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActionTile(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
    Color cardBg,
    Color borderColor,
    ThemeData theme,
  ) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.sourceSerif4(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
