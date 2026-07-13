import 'package:flutter/material.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/widgets/glassmorphic_container.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Finance', style: AiraTypography.h4),
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
                    color: AiraColors.purple.withValues(alpha: 0.1),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 32,
                    color: AiraColors.purple,
                  ),
                ),
                const SizedBox(height: 20),
                Text('Coming in Phase 3', style: AiraTypography.h4),
                const SizedBox(height: 8),
                Text(
                  'Expense tracking, budget planning, financial reports, and investment watchlist.',
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
