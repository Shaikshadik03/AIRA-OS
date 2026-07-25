import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:aira_app/core/services/api_service.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final conversations = await ApiService()
          .listConversations()
          .timeout(const Duration(seconds: 3));
      if (mounted) setState(() => _history = conversations);
    } catch (e) {
      // Backend unavailable or timed out, display empty state
      if (mounted) setState(() => _history = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    label: 'New Chat',
                    color: AiraColors.electricCyan,
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/chat');
                    },
                  ),
                  const _DrawerDivider(),
                  _DrawerSectionTitle(title: 'CHAT HISTORY'),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator(color: AiraColors.electricCyan)),
                    )
                  else if (_history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('No previous chats found.', style: AiraTypography.bodySmall.copyWith(color: AiraColors.textMuted)),
                    )
                  else
                    ..._history.map((chat) => _DrawerItem(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: chat['title'] ?? 'New Conversation',
                          color: AiraColors.textSecondary,
                          onTap: () {
                            Navigator.pop(context);
                            // TODO: load specific chat via provider
                            context.go('/chat');
                          },
                        )),
                ],
              ),
            ),

            // ─── Bottom Actions ───
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AiraColors.glassBorder),
                ),
              ),
              child: Column(
                children: [
                  _DrawerItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    color: AiraColors.textSecondary,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/settings');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    color: AiraColors.error,
                    onTap: () async {
                      Navigator.pop(context);
                      final notifier = ref.read(authProvider.notifier);
                      await notifier.signOut();
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
    return InkWell(
      onTap: onTap,
      splashColor: color.withValues(alpha: 0.1),
      highlightColor: color.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: AiraTypography.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSectionTitle extends StatelessWidget {
  final String title;

  const _DrawerSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: AiraTypography.overline.copyWith(
          color: AiraColors.textMuted,
        ),
      ),
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Divider(
        color: AiraColors.glassBorder,
        height: 1,
      ),
    );
  }
}
