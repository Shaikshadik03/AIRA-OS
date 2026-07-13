import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/features/auth/presentation/providers/auth_provider.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Drawer(
      backgroundColor: AiraColors.cardDark,
      child: SafeArea(
        child: Column(
          children: [
            // ─── User Profile Header ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AiraColors.glassBorder),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AiraColors.cyanPurpleGradient,
                    ),
                    child: Center(
                      child: Text(
                        (user?.displayName ?? 'U')[0].toUpperCase(),
                        style: AiraTypography.h4.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.displayName ?? 'User',
                    style: AiraTypography.h5.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? '',
                    style: AiraTypography.caption.copyWith(color: AiraColors.textMuted),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ─── Navigation Items ───
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerItem(
                    icon: Icons.chat_rounded,
                    label: 'Chat',
                    color: AiraColors.electricCyan,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/chat');
                    },
                  ),
                  const _DrawerDivider(),
                  _DrawerSectionTitle(title: 'TOOLS'),
                  _DrawerItem(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Tasks & Planner',
                    color: AiraColors.success,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/planner');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Finance Tracker',
                    color: AiraColors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/finance');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.menu_book_outlined,
                    label: 'Study Tools',
                    color: AiraColors.warning,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/study');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.code_rounded,
                    label: 'Code Assistant',
                    color: AiraColors.neonBlue,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/coding');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.palette_outlined,
                    label: 'Creative Studio',
                    color: AiraColors.neonPink,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/creative');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.business_center_outlined,
                    label: 'Business CRM',
                    color: AiraColors.amber,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/business');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.psychology_outlined,
                    label: 'Memory Bank',
                    color: AiraColors.cyanLight,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/memory');
                    },
                  ),
                ],
              ),
            ),

            // ─── Bottom Section ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AiraColors.glassBorder),
                ),
              ),
              child: Column(
                children: [
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    color: AiraColors.textSecondary,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/settings');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    color: AiraColors.error,
                    onTap: () async {
                      Navigator.pop(context);
                      await ref.read(authProvider.notifier).signOut();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: AiraTypography.bodyMedium),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      onTap: onTap,
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Divider(color: AiraColors.glassBorder, height: 1),
    );
  }
}

class _DrawerSectionTitle extends StatelessWidget {
  final String title;
  const _DrawerSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        title,
        style: AiraTypography.overline.copyWith(
          color: AiraColors.textMuted,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}
