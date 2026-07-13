import 'package:flutter/material.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';

class AiraButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isPrimary;
  final bool isFullWidth;

  const AiraButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isPrimary = true,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPrimary) {
      return SizedBox(
        width: isFullWidth ? double.infinity : null,
        height: 50,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: _buildChild(isOnPrimary: false),
        ),
      );
    }

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed != null && !isLoading
              ? AiraColors.primaryGradient
              : LinearGradient(
                  colors: [
                    AiraColors.electricCyan.withValues(alpha: 0.3),
                    AiraColors.neonBlue.withValues(alpha: 0.3),
                  ],
                ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: onPressed != null && !isLoading
              ? [
                  BoxShadow(
                    color: AiraColors.electricCyan.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _buildChild(isOnPrimary: true),
        ),
      ),
    );
  }

  Widget _buildChild({required bool isOnPrimary}) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(
            isOnPrimary ? Colors.white : AiraColors.electricCyan,
          ),
        ),
      );
    }

    final textColor = isOnPrimary ? Colors.white : AiraColors.electricCyan;

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: textColor),
          const SizedBox(width: 8),
          Text(label, style: AiraTypography.buttonText.copyWith(color: textColor)),
        ],
      );
    }

    return Text(label, style: AiraTypography.buttonText.copyWith(color: textColor));
  }
}
