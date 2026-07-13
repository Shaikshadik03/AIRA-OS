import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/widgets/glassmorphic_container.dart';
import 'package:aira_app/features/auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Settings', style: AiraTypography.h4),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // Profile section
          GlassmorphicContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AiraColors.cyanPurpleGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'A',
                      style: AiraTypography.h4.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Arshan', style: AiraTypography.h5),
                    const SizedBox(height: 2),
                    Text(
                      'arshan@aira.os',
                      style: AiraTypography.caption.copyWith(
                        color: AiraColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AiraColors.textMuted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _sectionTitle('General'),
          _settingsTile(Icons.person_outline_rounded, 'Account', null),
          _settingsTile(Icons.notifications_outlined, 'Notifications', null),
          _settingsTile(Icons.psychology_outlined, 'AI Personality', 'Mentor'),
          _settingsTile(Icons.palette_outlined, 'Appearance', 'Dark'),
          _settingsTile(Icons.language_rounded, 'Language', 'English'),

          const SizedBox(height: 20),
          _sectionTitle('Privacy'),
          _settingsTile(Icons.shield_outlined, 'Privacy & Security', null),
          _settingsTile(Icons.storage_outlined, 'Data & Storage', null),

          const SizedBox(height: 20),
          _sectionTitle('About'),
          _settingsTile(Icons.info_outline_rounded, 'About AIRA', 'v1.0.0'),
          _settingsTile(Icons.help_outline_rounded, 'Help & Support', null),

          const SizedBox(height: 24),
          // Sign Out
          GestureDetector(
            onTap: () {
              ref.read(authProvider.notifier).signOut();
              context.go('/login');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AiraColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AiraColors.error.withValues(alpha: 0.2),
                ),
              ),
              child: Center(
                child: Text(
                  'Sign Out',
                  style: AiraTypography.buttonText.copyWith(
                    color: AiraColors.error,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: AiraTypography.overline.copyWith(
          color: AiraColors.textMuted,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _settingsTile(IconData icon, String title, String? trailing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: Icon(icon, color: AiraColors.textSecondary, size: 22),
        title: Text(title, style: AiraTypography.bodyMedium),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null)
              Text(
                trailing,
                style: AiraTypography.caption.copyWith(
                  color: AiraColors.textMuted,
                ),
              ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AiraColors.textMuted,
              size: 20,
            ),
          ],
        ),
        onTap: () {},
      ),
    );
  }
}
