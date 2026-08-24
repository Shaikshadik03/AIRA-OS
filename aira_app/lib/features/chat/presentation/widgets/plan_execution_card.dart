import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/agent/plan_models.dart';

/// Interactive UI Card displaying the live decomposition and progress of an Autonomous Agent Goal Plan
class PlanExecutionCard extends StatefulWidget {
  final AgentGoalPlan plan;

  const PlanExecutionCard({
    super.key,
    required this.plan,
  });

  @override
  State<PlanExecutionCard> createState() => _PlanExecutionCardState();
}

class _PlanExecutionCardState extends State<PlanExecutionCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF161513) : const Color(0xFFFAF9F5);
    final borderColor = isDark ? AiraColors.borderDark : AiraColors.borderLight;

    final completed = widget.plan.completedSteps;
    final total = widget.plan.totalSteps;
    final progress = total > 0 ? (completed / total) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AiraColors.claudeTerracotta.withValues(alpha: isDark ? 0.2 : 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AiraColors.claudeTerracotta,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'GOAL EXECUTION PLAN',
                              style: GoogleFonts.firaCode(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: AiraColors.claudeTerracotta,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget.plan.isCompleted
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : AiraColors.claudeTerracotta.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                widget.plan.isCompleted
                                    ? 'COMPLETED ($completed/$total)'
                                    : 'EXECUTING ($completed/$total)',
                                style: GoogleFonts.sourceSerif4(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: widget.plan.isCompleted ? Colors.green : AiraColors.claudeTerracotta,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.plan.goal,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Linear Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.plan.isCompleted ? Colors.green : AiraColors.claudeTerracotta,
                ),
              ),
            ),
          ),

          if (_expanded) ...[
            const SizedBox(height: 10),
            // Rationale
            if (widget.plan.rationale.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  widget.plan.rationale,
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                  ),
                ),
              ),

            // Step List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              itemCount: widget.plan.steps.length,
              itemBuilder: (context, index) {
                final step = widget.plan.steps[index];
                return _buildStepTile(step, isDark, theme);
              },
            ),
          ] else
            const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStepTile(AgentPlanStep step, bool isDark, ThemeData theme) {
    Widget leadingIcon;
    Color textColor = theme.colorScheme.onSurface;

    switch (step.status) {
      case PlanStepStatus.completed:
        leadingIcon = const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18);
        break;
      case PlanStepStatus.running:
        leadingIcon = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AiraColors.claudeTerracotta),
        );
        textColor = AiraColors.claudeTerracotta;
        break;
      case PlanStepStatus.failed:
        leadingIcon = const Icon(Icons.cancel_rounded, color: Colors.red, size: 18);
        break;
      case PlanStepStatus.waitingApproval:
        leadingIcon = const Icon(Icons.shield_outlined, color: Colors.amber, size: 18);
        textColor = Colors.amber;
        break;
      case PlanStepStatus.pending:
      case PlanStepStatus.skipped:
        leadingIcon = Icon(
          Icons.circle_outlined,
          color: isDark ? Colors.white24 : Colors.black26,
          size: 18,
        );
        textColor = isDark ? AiraColors.textMuted : AiraColors.textMutedLight;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: leadingIcon,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Step ${step.stepId}: ${step.title}',
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 13,
                        fontWeight: step.status == PlanStepStatus.running ? FontWeight.w700 : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      step.tool.replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.firaCode(
                        fontSize: 9,
                        color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                      ),
                    ),
                  ],
                ),
                if (step.output != null && step.output!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      step.output!,
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 11.5,
                        color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
