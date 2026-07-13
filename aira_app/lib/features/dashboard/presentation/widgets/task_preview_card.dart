import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/widgets/glassmorphic_container.dart';
import 'package:aira_app/features/planner/presentation/providers/planner_provider.dart';
import 'package:intl/intl.dart';

class TaskPreviewCard extends ConsumerWidget {
  const TaskPreviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plannerState = ref.watch(plannerProvider);
    
    // Grab only the top 3 pending tasks for dashboard preview
    final pendingTasks = plannerState.tasks.where((t) => !t.isCompleted).take(3).toList();

    if (plannerState.isLoading) {
      return const GlassmorphicContainer(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: AiraColors.electricCyan)),
      );
    }

    if (pendingTasks.isEmpty) {
      return GlassmorphicContainer(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: AiraColors.success.withValues(alpha: 0.6), size: 32),
              const SizedBox(height: 8),
              Text(
                'All tasks completed!',
                style: AiraTypography.bodyMedium.copyWith(color: AiraColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return GlassmorphicContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          pendingTasks.length,
          (index) {
            final task = pendingTasks[index];
            Color priorityColor;
            switch (task.priority) {
              case 'urgent':
                priorityColor = AiraColors.error;
                break;
              case 'high':
                priorityColor = AiraColors.warning;
                break;
              case 'medium':
                priorityColor = AiraColors.neonBlue;
                break;
              default:
                priorityColor = AiraColors.success;
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: index < pendingTasks.length - 1 ? 12 : 0,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      ref.read(plannerProvider.notifier).toggleTask(task.id, true);
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AiraColors.textMuted,
                          width: 1.5,
                        ),
                        color: Colors.transparent,
                      ),
                      child: null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: AiraTypography.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.dueDate != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MMM d, h:mm a').format(task.dueDate!),
                            style: AiraTypography.caption.copyWith(
                              color: AiraColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: priorityColor,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
