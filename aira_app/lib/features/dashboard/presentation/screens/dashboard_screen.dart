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
import 'package:aira_app/features/finance/presentation/providers/finance_provider.dart';
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
    // Load planner and finance items dynamically on load
    Future.microtask(() {
      ref.read(plannerProvider.notifier).loadAll();
      ref.read(financeProvider.notifier).loadAll();
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
    
    // Auth and planner states
    final currentUser = ref.watch(currentUserProvider);
    final plannerState = ref.watch(plannerProvider);
    final financeState = ref.watch(financeProvider);

    final String displayName = currentUser?.displayName ?? 'Arshan';
    final double progress = plannerState.completionRate;

    final format = NumberFormat.simpleCurrency(locale: 'en_IN', name: 'INR');

    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      body: SafeArea(
        child: RefreshIndicator(
          color: AiraColors.electricCyan,
          onRefresh: () async {
            await ref.read(plannerProvider.notifier).loadAll();
            await ref.read(financeProvider.notifier).loadAll();
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
                        'Daily Progress',
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
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.0,
                  children: [
                    QuickActionCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Chat',
                      color: AiraColors.electricCyan,
                      onTap: () => context.go('/chat'),
                    ),
                    QuickActionCard(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Planner',
                      color: AiraColors.success,
                      onTap: () => context.go('/planner'),
                    ),
                    QuickActionCard(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Expense',
                      color: AiraColors.purple,
                      onTap: () => context.go('/finance'),
                    ),
                    QuickActionCard(
                      icon: Icons.menu_book_outlined,
                      label: 'Study',
                      color: AiraColors.warning,
                      onTap: () => context.go('/study'),
                    ),
                    QuickActionCard(
                      icon: Icons.code_rounded,
                      label: 'Coding',
                      color: AiraColors.neonBlue,
                      onTap: () => context.go('/coding'),
                    ),
                    QuickActionCard(
                      icon: Icons.mic_outlined,
                      label: 'Voice',
                      color: AiraColors.electricCyan,
                      onTap: () => context.go('/voice'),
                    ),
                    QuickActionCard(
                      icon: Icons.palette_outlined,
                      label: 'Creative',
                      color: AiraColors.neonPink,
                      onTap: () => context.go('/creative'),
                    ),
                    QuickActionCard(
                      icon: Icons.business_center_rounded,
                      label: 'CRM',
                      color: AiraColors.amber,
                      onTap: () => context.go('/business'),
                    ),
                    QuickActionCard(
                      icon: Icons.psychology_outlined,
                      label: 'Memory',
                      color: AiraColors.success,
                      onTap: () => context.go('/settings/memory'),
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
                            'No habits tracked. Tap Planner to start!',
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

                // Financial Overview
                Text('Financial Overview', style: AiraTypography.h5)
                    .animate()
                    .fadeIn(delay: 700.ms, duration: 300.ms),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => context.go('/finance'),
                  child: GlassmorphicContainer(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Spent this month',
                                style: AiraTypography.caption.copyWith(
                                  color: AiraColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                format.format(financeState.totalExpense),
                                style: AiraTypography.h3.copyWith(
                                  color: AiraColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: AiraColors.glassBorder,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Income total',
                                  style: AiraTypography.caption.copyWith(
                                    color: AiraColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  format.format(financeState.totalIncome),
                                  style: AiraTypography.h3.copyWith(
                                    color: AiraColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 750.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),

                const SizedBox(height: 28),

                // Recent Activity
                Text('Recent Activity', style: AiraTypography.h5)
                    .animate()
                    .fadeIn(delay: 800.ms, duration: 300.ms),
                const SizedBox(height: 12),
                GlassmorphicContainer(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Column(
                    children: [
                      _activityRow(
                        Icons.description_outlined,
                        'Summarized your research PDF',
                        '2 hours ago',
                        AiraColors.electricCyan,
                      ),
                      Divider(color: AiraColors.glassBorder, height: 16),
                      _activityRow(
                        Icons.notifications_active_outlined,
                        'Reminder: Team meeting at 3 PM',
                        '4 hours ago',
                        AiraColors.warning,
                      ),
                      Divider(color: AiraColors.glassBorder, height: 16),
                      _activityRow(
                        Icons.code_rounded,
                        'Debugged your Python script',
                        'Yesterday',
                        AiraColors.purple,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 850.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _activityRow(IconData icon, String title, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AiraTypography.bodySmall.copyWith(
                    color: AiraColors.textPrimary,
                  ),
                ),
                Text(
                  time,
                  style: AiraTypography.overline.copyWith(
                    color: AiraColors.textMuted,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
