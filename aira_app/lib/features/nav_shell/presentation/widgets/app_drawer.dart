import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final drawerBg = isDark ? AiraColors.canvasDark : AiraColors.canvasLight;
    final cardBg = isDark ? AiraColors.cardDark : AiraColors.cardLight;
    final borderColor = isDark ? AiraColors.borderDark : AiraColors.borderLight;
    final mutedColor = isDark ? AiraColors.textMuted : AiraColors.textMutedLight;

    return Drawer(
      backgroundColor: drawerBg,
      child: SafeArea(
        child: Column(
          children: [
            // ─── Header: Profile ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AiraColors.claudeTerracotta,
                    ),
                    child: Center(
                      child: Text(
                        (user?.displayName.isNotEmpty == true ? user!.displayName[0] : 'U').toUpperCase(),
                        style: GoogleFonts.sourceSerif4(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'User',
                          style: GoogleFonts.playfairDisplay(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? 'Not signed in',
                          style: GoogleFonts.sourceSerif4(
                            color: mutedColor,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: mutedColor, size: 20),
                    tooltip: 'Refresh chats',
                    onPressed: _loadHistory,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

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
                    backgroundColor: cardBg,
                    foregroundColor: theme.colorScheme.onSurface,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: borderColor),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20, color: AiraColors.claudeTerracotta),
                  label: Text(
                    'New Chat',
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ─── Chat History Section ───
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                    child: Text(
                      'RECENT CONVERSATIONS',
                      style: GoogleFonts.sourceSerif4(
                        color: mutedColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: AiraColors.claudeTerracotta,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : _history.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: mutedColor,
                                      size: 28,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'No previous chats',
                                      style: GoogleFonts.sourceSerif4(
                                        color: mutedColor,
                                        fontSize: 13,
                                      ),
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

                                  return _ChatHistoryTile(
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
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Column(
                children: [
                  _DrawerItem(
                    icon: Icons.newspaper_rounded,
                    label: 'Daily Intelligence',
                    iconColor: AiraColors.claudeTerracotta,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/briefing');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.laptop_mac_rounded,
                    label: 'Laptop Remote',
                    iconColor: AiraColors.claudeTerracotta,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/laptop');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings & Theme',
                    iconColor: isDark ? AiraColors.textSecondary : AiraColors.textSecondaryLight,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/settings');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    iconColor: AiraColors.error,
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

// ──────────────────── Chat History Tile ────────────────────

class _ChatHistoryTile extends StatelessWidget {
  final String title;
  final String timeAgo;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ChatHistoryTile({
    required this.title,
    required this.timeAgo,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor = isDark ? AiraColors.textMuted : AiraColors.textMutedLight;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: mutedColor,
              size: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.sourceSerif4(
                      color: theme.colorScheme.onSurface,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (timeAgo.isNotEmpty)
                    Text(
                      timeAgo,
                      style: GoogleFonts.sourceSerif4(
                        color: mutedColor,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, size: 16, color: mutedColor),
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

// ──────────────────── Drawer Action Item ────────────────────

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.sourceSerif4(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
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
