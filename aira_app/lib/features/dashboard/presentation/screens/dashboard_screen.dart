import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/widgets/glassmorphic_container.dart';
import 'package:aira_app/features/dashboard/presentation/widgets/progress_ring.dart';
import 'package:aira_app/features/dashboard/presentation/widgets/quick_action_card.dart';
import 'package:aira_app/features/dashboard/presentation/widgets/task_preview_card.dart';
import 'package:aira_app/features/dashboard/presentation/widgets/habit_streak_item.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      body: SafeArea(
        child: SingleChildScrollView(
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
                        Text('Arshan', style: AiraTypography.h2),
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
                        'A',
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
                    const ProgressRing(progress: 0.68, size: 150),
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
                    onTap: () {},
                  ),
                  QuickActionCard(
                    icon: Icons.add_circle_outline_rounded,
                    label: 'Add Task',
                    color: AiraColors.success,
                    onTap: () {},
                  ),
                  QuickActionCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Expense',
                    color: AiraColors.purple,
                    onTap: () {},
                  ),
                  QuickActionCard(
                    icon: Icons.menu_book_outlined,
                    label: 'Study',
                    color: AiraColors.warning,
                    onTap: () {},
                  ),
                  QuickActionCard(
                    icon: Icons.notifications_outlined,
                    label: 'Reminder',
                    color: AiraColors.neonPink,
                    onTap: () {},
                  ),
                  QuickActionCard(
                    icon: Icons.mic_outlined,
                    label: 'Voice',
                    color: AiraColors.neonBlue,
                    onTap: () {},
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
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 6,
                  separatorBuilder: (_, __) => const SizedBox(width: 4),
                  itemBuilder: (context, index) {
                    const habits = [
                      HabitStreakItem(
                        name: 'Meditate',
                        icon: Icons.self_improvement,
                        streak: 12,
                        color: AiraColors.electricCyan,
                      ),
                      HabitStreakItem(
                        name: 'Exercise',
                        icon: Icons.fitness_center,
                        streak: 8,
                        color: AiraColors.success,
                      ),
                      HabitStreakItem(
                        name: 'Read',
                        icon: Icons.auto_stories,
                        streak: 15,
                        color: AiraColors.purple,
                      ),
                      HabitStreakItem(
                        name: 'Code',
                        icon: Icons.code,
                        streak: 21,
                        color: AiraColors.neonBlue,
                      ),
                      HabitStreakItem(
                        name: 'Journal',
                        icon: Icons.edit_note,
                        streak: 5,
                        color: AiraColors.warning,
                      ),
                      HabitStreakItem(
                        name: 'Sleep 8h',
                        icon: Icons.bedtime,
                        streak: 3,
                        color: AiraColors.neonPink,
                      ),
                    ];
                    return habits[index];
                  },
                ),
              ).animate().fadeIn(delay: 650.ms, duration: 400.ms),

              const SizedBox(height: 28),

              // Financial Overview
              Text('Financial Overview', style: AiraTypography.h5)
                  .animate()
                  .fadeIn(delay: 700.ms, duration: 300.ms),
              const SizedBox(height: 12),
              GlassmorphicContainer(
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
                            '₹12,450',
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
                              'Budget',
                              style: AiraTypography.caption.copyWith(
                                color: AiraColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹25,000',
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
