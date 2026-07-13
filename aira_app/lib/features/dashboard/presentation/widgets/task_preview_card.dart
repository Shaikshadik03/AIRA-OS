import 'package:flutter/material.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/widgets/glassmorphic_container.dart';

class TaskPreviewCard extends StatefulWidget {
  const TaskPreviewCard({super.key});

  @override
  State<TaskPreviewCard> createState() => _TaskPreviewCardState();
}

class _TaskPreviewCardState extends State<TaskPreviewCard> {
  final List<_TaskItem> _tasks = [
    _TaskItem(
      title: 'Review Flutter architecture docs',
      time: '9:00 AM',
      priority: AiraColors.warning,
      isCompleted: true,
    ),
    _TaskItem(
      title: 'Build AIRA dashboard UI',
      time: '11:00 AM',
      priority: AiraColors.error,
      isCompleted: false,
    ),
    _TaskItem(
      title: 'Set up Supabase database',
      time: '2:00 PM',
      priority: AiraColors.electricCyan,
      isCompleted: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          _tasks.length,
          (index) {
            final task = _tasks[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _tasks.length - 1 ? 12 : 0,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _tasks[index] = _TaskItem(
                          title: task.title,
                          time: task.time,
                          priority: task.priority,
                          isCompleted: !task.isCompleted,
                        );
                      });
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: task.isCompleted
                              ? AiraColors.electricCyan
                              : AiraColors.textMuted,
                          width: 1.5,
                        ),
                        color: task.isCompleted
                            ? AiraColors.electricCyan.withValues(alpha: 0.15)
                            : Colors.transparent,
                      ),
                      child: task.isCompleted
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: AiraColors.electricCyan,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: AiraTypography.bodyMedium.copyWith(
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.isCompleted
                                ? AiraColors.textMuted
                                : AiraColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          task.time,
                          style: AiraTypography.caption.copyWith(
                            color: AiraColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: task.priority,
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

class _TaskItem {
  final String title;
  final String time;
  final Color priority;
  final bool isCompleted;

  const _TaskItem({
    required this.title,
    required this.time,
    required this.priority,
    required this.isCompleted,
  });
}
