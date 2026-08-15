import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:aira_app/core/services/supabase_chat_service.dart';
import 'package:aira_app/features/chat/presentation/providers/chat_provider.dart';

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
      final conversations = await SupabaseChatService()
          .listConversations()
          .timeout(const Duration(seconds: 5));
      if (mounted) setState(() => _history = conversations);
    } catch (_) {
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
                  Row(
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
                      const Spacer(),
                      // Refresh history button
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: AiraColors.textMuted, size: 20),
                        tooltip: 'Refresh history',
                        onPressed: _loadHistory,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.displayName ?? 'User',
                    style: AiraTypography.h5.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? 'Not signed in',
                    style: AiraTypography.caption.copyWith(color: AiraColors.textMuted),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ─── New Chat Button ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(chatProvider.notifier).clearChat();
                    context.go('/chat');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AiraColors.electricCyan.withValues(alpha: 0.15),
                    foregroundColor: AiraColors.electricCyan,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AiraColors.electricCyan.withValues(alpha: 0.3)),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text('New Chat', style: AiraTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ─── Chat History ───
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DrawerSectionTitle(title: 'RECENT CHATS'),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: AiraColors.electricCyan,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : _history.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: AiraColors.textMuted,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No previous chats',
                                      style: AiraTypography.bodySmall.copyWith(color: AiraColors.textMuted),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Start a new chat above',
                                      style: AiraTypography.caption.copyWith(color: AiraColors.textMuted),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: _history.length,
                                itemBuilder: (context, index) {
                                  final chat = _history[index];
                                  final title = (chat['title'] as String?) ?? 'New Chat';
                                  final updatedAt = chat['updated_at'] != null
                                      ? DateTime.tryParse(chat['updated_at'] as String)
                                      : null;
                                  final timeAgo = _formatTimeAgo(updatedAt);

                                  return _ChatHistoryItem(
                                    title: title,
                                    timeAgo: timeAgo,
                                    onTap: () {
                                      Navigator.pop(context);
                                      ref.read(chatProvider.notifier).loadConversation(
                                            chat['id'] as String,
                                            title,
                                          );
                                      context.go('/chat');
                                    },
                                    onDelete: () async {
                                      try {
                                        await SupabaseChatService().deleteConversation(chat['id'] as String);
                                        await _loadHistory();
                                      } catch (_) {}
                                    },
                                  );
                                },
                              ),
                  ),
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
                    icon: Icons.newspaper_rounded,
                    label: 'Daily Intelligence',
                    color: AiraColors.amber,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/briefing');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    color: AiraColors.electricCyan,
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

  String _formatTimeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ──────────────────── Chat History Item ────────────────────

class _ChatHistoryItem extends StatelessWidget {
  final String title;
  final String timeAgo;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ChatHistoryItem({
    required this.title,
    required this.timeAgo,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: AiraColors.electricCyan.withValues(alpha: 0.1),
      highlightColor: AiraColors.electricCyan.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AiraColors.textMuted,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AiraTypography.bodySmall.copyWith(
                      color: AiraColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (timeAgo.isNotEmpty)
                    Text(
                      timeAgo,
                      style: AiraTypography.caption.copyWith(color: AiraColors.textMuted),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AiraColors.textMuted),
              onPressed: onDelete,
              tooltip: 'Delete chat',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────── Drawer Helpers ────────────────────

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
