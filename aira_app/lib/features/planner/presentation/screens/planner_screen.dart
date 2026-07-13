import 'package:flutter/material.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/widgets/glassmorphic_container.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Planner', style: AiraTypography.h4),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: GlassmorphicContainer(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AiraColors.electricCyan.withValues(alpha: 0.1),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 32,
                    color: AiraColors.electricCyan,
                  ),
                ),
                const SizedBox(height: 20),
                Text('Coming in Phase 3', style: AiraTypography.h4),
                const SizedBox(height: 8),
                Text(
                  'Task manager, habit tracker, goal tracking, calendar integration, and smart reminders.',
                  style: AiraTypography.bodySmall.copyWith(
                    color: AiraColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
