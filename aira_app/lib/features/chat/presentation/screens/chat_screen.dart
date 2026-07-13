import 'package:flutter/material.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Text('AIRA', style: AiraTypography.h4),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AiraColors.success,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AiraColors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AiraColors.electricCyan.withValues(alpha: 0.08),
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 36,
                      color: AiraColors.electricCyan.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Start a conversation',
                    style: AiraTypography.h5.copyWith(
                      color: AiraColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ask me anything — I\'m here to help!',
                    style: AiraTypography.bodySmall.copyWith(
                      color: AiraColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 24),
            decoration: BoxDecoration(
              color: AiraColors.cardDark,
              border: Border(
                top: BorderSide(color: AiraColors.glassBorder),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AiraColors.surfaceDark,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AiraColors.glassBorder),
                    ),
                    child: TextField(
                      style: AiraTypography.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Message AIRA...',
                        hintStyle: AiraTypography.bodyMedium.copyWith(
                          color: AiraColors.textMuted,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AiraColors.primaryGradient,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, size: 20),
                    color: Colors.white,
                    onPressed: () {},
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
