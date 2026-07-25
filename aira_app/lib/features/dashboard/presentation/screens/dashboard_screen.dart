import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/widgets/glassmorphic_container.dart';
import 'package:aira_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:aira_app/features/planner/presentation/providers/planner_provider.dart';
import 'package:aira_app/features/dashboard/presentation/widgets/progress_ring.dart';
import 'package:aira_app/features/dashboard/presentation/widgets/quick_action_card.dart';
import 'package:aira_app/features/dashboard/presentation/widgets/task_preview_card.dart';
import 'package:aira_app/features/dashboard/presentation/widgets/habit_streak_item.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
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

    final String displayName = currentUser?.displayName ?? 'Arshan';
    final double progress = plannerState.completionRate;

    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      body: SafeArea(
        child: RefreshIndicator(
          color: AiraColors.electricCyan,
          onRefresh: () async {
            await ref.read(plannerProvider.notifier).loadAll();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getGreeting()},',
                            style: AiraTypography.bodyMedium.copyWith(
                              color: AiraColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(displayName, style: AiraTypography.h2),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AiraColors.cyanPurpleGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                          style: AiraTypography.h5.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05, end: 0),
                const SizedBox(height: 6),
                Text(
                  today,
                  style: AiraTypography.caption.copyWith(
                    color: AiraColors.textMuted,
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

                const SizedBox(height: 28),

                // Progress Ring
                Center(
                  child: Column(
                    children: [
                      ProgressRing(progress: progress, size: 150),
                      const SizedBox(height: 8),
                      Text(
                        'Daily Productivity Progress',
                        style: AiraTypography.caption.copyWith(
                          color: AiraColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms).scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1.0, 1.0),
                      duration: 500.ms,
                    ),

                const SizedBox(height: 28),

                // Quick Actions
                Text('Quick Actions', style: AiraTypography.h5)
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 300.ms),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.2,
                  children: [
                    QuickActionCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'AI Chat',
                      color: AiraColors.electricCyan,
                      onTap: () => context.go('/chat'),
                    ),
                    QuickActionCard(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Planner & Tasks',
                      color: AiraColors.success,
                      onTap: () => context.go('/planner'),
                    ),
                    QuickActionCard(
                      icon: Icons.mic_outlined,
                      label: 'Voice Assistant',
                      color: AiraColors.purple,
                      onTap: () => context.go('/voice-panel'),
                    ),
                    QuickActionCard(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      color: AiraColors.warning,
                      onTap: () => context.go('/settings'),
                    ),
                  ],
                ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

                const SizedBox(height: 28),

                // Today's Tasks
                Text("Today's Tasks", style: AiraTypography.h5)
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 300.ms),
                const SizedBox(height: 12),
                const TaskPreviewCard()
                    .animate()
                    .fadeIn(delay: 550.ms, duration: 400.ms)
                    .slideY(begin: 0.05, end: 0),

                const SizedBox(height: 28),

                // Habit Streaks
                Text('Habit Streaks', style: AiraTypography.h5)
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 300.ms),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: plannerState.habits.isEmpty
                      ? Center(
                          child: Text(
                            'No habits tracked yet. Tap Planner to start!',
                            style: AiraTypography.caption.copyWith(color: AiraColors.textMuted),
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: plannerState.habits.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final habit = plannerState.habits[index];
                            final color = habit.color != null
                                ? Color(int.parse(habit.color!))
                                : AiraColors.electricCyan;

                            return HabitStreakItem(
                              name: habit.name,
                              icon: Icons.check_circle_outline,
                              streak: habit.currentStreak,
                              color: color,
                            );
                          },
                        ),
                ).animate().fadeIn(delay: 650.ms, duration: 400.ms),

                const SizedBox(height: 28),

                // Recent AI Activity
                Text('Recent AI Activity', style: AiraTypography.h5)
                    .animate()
                    .fadeIn(delay: 700.ms, duration: 300.ms),
                const SizedBox(height: 12),
                GlassmorphicContainer(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Column(
                    children: [
                      _activityRow(
                        Icons.chat_bubble_outline_rounded,
                        'Started new AI chat session',
                        'Just now',
                        AiraColors.electricCyan,
                      ),
                      Divider(color: AiraColors.glassBorder, height: 16),
                      _activityRow(
                        Icons.check_circle_outline,
                        'Planner daily task update',
                        '2 hours ago',
                        AiraColors.success,
                      ),
                      Divider(color: AiraColors.glassBorder, height: 16),
                      _activityRow(
                        Icons.mic_none_rounded,
                        'Voice assistant query processed',
                        'Today',
                        AiraColors.purple,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 750.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _activityRow(
    IconData icon,
    String title,
    String time,
    Color iconColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: AiraTypography.bodyMedium.copyWith(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            time,
            style: AiraTypography.caption.copyWith(
              color: AiraColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
