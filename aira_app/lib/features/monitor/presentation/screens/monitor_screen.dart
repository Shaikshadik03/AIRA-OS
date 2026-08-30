import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/aira_colors.dart';
import '../../../../core/theme/aira_typography.dart';
import '../../../../core/services/notification_monitor_service.dart';
import '../../../../core/services/social_world_monitor_service.dart';

class MonitorScreen extends ConsumerStatefulWidget {
  const MonitorScreen({super.key});

  @override
  ConsumerState<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends ConsumerState<MonitorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NotificationMonitorService _notifService = NotificationMonitorService();
  final SocialWorldMonitorService _worldService = SocialWorldMonitorService();

  bool _isPermissionGranted = false;
  bool _isGeneratingDigest = false;
  bool _isFetchingWorldFeed = false;
  String _selectedNotifCategory = 'all';
  String _selectedWorldCategory = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final granted = await _notifService.isPermissionGranted();
    if (mounted) {
      setState(() => _isPermissionGranted = granted);
    }
    if (granted) {
      await _notifService.checkAndStartListening();
    }
    await _worldService.fetchLiveWorldFeed();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshNotifications() async {
    setState(() => _isGeneratingDigest = true);
    await _notifService.generateSmartDigest(categoryFilter: _selectedNotifCategory);
    if (mounted) setState(() => _isGeneratingDigest = false);
  }

  Future<void> _refreshWorldFeed() async {
    setState(() => _isFetchingWorldFeed = true);
    await _worldService.fetchLiveWorldFeed(forceRefresh: true);
    await _worldService.generateExecutiveWorldDigest();
    if (mounted) setState(() => _isFetchingWorldFeed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AiraColors.canvasDark : AiraColors.canvasLight,
      appBar: AppBar(
        backgroundColor: isDark ? AiraColors.canvasDark : AiraColors.canvasLight,
        elevation: 0,
        title: Text(
          'Intelligence & Monitor',
          style: GoogleFonts.playfairDisplay(
            color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AiraColors.claudeTerracotta),
            tooltip: 'Refresh Feeds',
            onPressed: () {
              if (_tabController.index == 0) {
                _refreshNotifications();
              } else {
                _refreshWorldFeed();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AiraColors.claudeTerracotta,
          indicatorWeight: 3,
          labelColor: AiraColors.claudeTerracotta,
          unselectedLabelColor: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
          labelStyle: GoogleFonts.sourceSerif4(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(
              icon: Icon(Icons.notifications_active_outlined, size: 20),
              text: 'Notifications Digest',
            ),
            Tab(
              icon: Icon(Icons.public_outlined, size: 20),
              text: 'World & Social Radar',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationsTab(isDark),
          _buildWorldFeedTab(isDark),
        ],
      ),
    );
  }

  // ── Tab 1: Notifications Digest ──
  Widget _buildNotificationsTab(bool isDark) {
    if (!_isPermissionGranted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AiraColors.claudeTerracotta.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_off_outlined, color: AiraColors.claudeTerracotta, size: 48),
              ),
              const SizedBox(height: 20),
              Text(
                'Notification Access Required',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Allow AIRA to read incoming notifications so it can summarize your WhatsApp messages, emails, OTPs, and social alerts into a single smart daily digest.',
                style: AiraTypography.bodyMedium.copyWith(
                  color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await _notifService.openPermissionSettings();
                  Future.delayed(const Duration(seconds: 2), _loadInitialData);
                },
                icon: const Icon(Icons.security, color: Colors.white),
                label: const Text('Grant Notification Access'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AiraColors.claudeTerracotta,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final notifs = _selectedNotifCategory == 'all'
        ? _notifService.notifications
        : _notifService.notifications.where((n) => n.category == _selectedNotifCategory).toList();

    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      color: AiraColors.claudeTerracotta,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAiDigestCard(isDark),
          const SizedBox(height: 16),
          _buildCategoryFilterChips(isDark),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Captured Alerts (${notifs.length})',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
                ),
              ),
              if (notifs.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: isDark ? AiraColors.cardDark : AiraColors.cardLight,
                        title: const Text('Clear All Captured Notifications?'),
                        content: const Text('This will clear the local notification history buffer.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Clear', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _notifService.clearAll();
                      setState(() {});
                    }
                  },
                  child: const Text('Clear All', style: TextStyle(color: AiraColors.claudeTerracotta, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (notifs.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 40,
                    color: (isDark ? AiraColors.textMuted : AiraColors.textMutedLight).withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No notifications captured yet.',
                    style: TextStyle(color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Incoming alerts will appear here in real-time.',
                    style: TextStyle(
                      color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ...notifs.map((n) => _buildNotificationItem(n, isDark)),
        ],
      ),
    );
  }

  Widget _buildAiDigestCard(bool isDark) {
    final hasDigest = _notifService.cachedDigest.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AiraColors.cardDark : AiraColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AiraColors.claudeTerracotta.withValues(alpha: 0.3), width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AiraColors.claudeTerracotta.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: AiraColors.claudeTerracotta, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'AI Smart Digest',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_isGeneratingDigest)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AiraColors.claudeTerracotta),
                )
              else
                IconButton(
                  icon: const Icon(Icons.replay, size: 18, color: AiraColors.claudeTerracotta),
                  tooltip: 'Regenerate Digest',
                  onPressed: _refreshNotifications,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasDigest)
            MarkdownBody(
              data: _notifService.cachedDigest,
              styleSheet: MarkdownStyleSheet(
                p: AiraTypography.bodyMedium.copyWith(
                  color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
                  height: 1.4,
                ),
                listBullet: const TextStyle(color: AiraColors.claudeTerracotta),
              ),
            )
          else
            Text(
              'Tap below to synthesize your notifications into an AI executive summary.',
              style: AiraTypography.bodyMedium.copyWith(
                color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isGeneratingDigest ? null : _refreshNotifications,
              icon: const Icon(Icons.bolt, size: 16, color: AiraColors.claudeTerracotta),
              label: Text(
                hasDigest ? 'Refresh AI Summary' : 'Generate AI Summary',
                style: const TextStyle(color: AiraColors.claudeTerracotta, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AiraColors.claudeTerracotta),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChips(bool isDark) {
    final categories = [
      {'key': 'all', 'label': 'All Alerts'},
      {'key': 'messaging', 'label': '💬 Chats'},
      {'key': 'email_work', 'label': '📧 Email & Work'},
      {'key': 'finance', 'label': '💳 Finance & OTPs'},
      {'key': 'delivery_transport', 'label': '🍔 Delivery'},
      {'key': 'social', 'label': '📢 Social'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedNotifCategory == cat['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat['label']!),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedNotifCategory = cat['key']!);
                }
              },
              selectedColor: AiraColors.claudeTerracotta,
              backgroundColor: isDark ? AiraColors.cardDark : AiraColors.cardLight,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : (isDark ? AiraColors.textMuted : AiraColors.textMutedLight),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AiraColors.claudeTerracotta : Colors.transparent,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationItem(InterceptedNotification n, bool isDark) {
    final time = DateTime.fromMillisecondsSinceEpoch(n.timestamp);
    final timeStr = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

    IconData icon;
    Color iconColor;
    switch (n.category) {
      case 'messaging':
        icon = Icons.chat_bubble_outline;
        iconColor = Colors.green;
        break;
      case 'email_work':
        icon = Icons.mail_outline;
        iconColor = Colors.blue;
        break;
      case 'finance':
        icon = Icons.account_balance_wallet_outlined;
        iconColor = Colors.amber;
        break;
      case 'delivery_transport':
        icon = Icons.delivery_dining_outlined;
        iconColor = Colors.orange;
        break;
      case 'social':
        icon = Icons.share_outlined;
        iconColor = Colors.purple;
        break;
      default:
        icon = Icons.notifications_none;
        iconColor = AiraColors.claudeTerracotta;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AiraColors.cardDark : AiraColors.cardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      n.appName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                if (n.title.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (n.text.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    n.text,
                    style: TextStyle(
                      color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Outside World & Social Radar ──
  Widget _buildWorldFeedTab(bool isDark) {
    final items = _selectedWorldCategory == 'all'
        ? _worldService.cachedItems
        : _worldService.cachedItems.where((i) => i.category == _selectedWorldCategory).toList();

    return RefreshIndicator(
      onRefresh: _refreshWorldFeed,
      color: AiraColors.claudeTerracotta,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWorldExecutiveCard(isDark),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildWorldCategoryChip('all', 'All Radar', isDark),
                _buildWorldCategoryChip('ai', '🤖 AI & Models', isDark),
                _buildWorldCategoryChip('tech', '⚡ Tech & Dev', isDark),
                _buildWorldCategoryChip('india', '🇮🇳 India Ecosystem', isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Social & Web Signals (${items.length})',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
                ),
              ),
              if (_worldService.lastSyncTime != null)
                Text(
                  'Synced ${_worldService.lastSyncTime!.hour.toString().padLeft(2, '0')}:${_worldService.lastSyncTime!.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const CircularProgressIndicator(color: AiraColors.claudeTerracotta),
                  const SizedBox(height: 12),
                  Text(
                    'Scanning outside world & tech feeds...',
                    style: TextStyle(color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight),
                  ),
                ],
              ),
            )
          else
            ...items.map((item) => _buildWorldFeedItem(item, isDark)),
        ],
      ),
    );
  }

  Widget _buildWorldExecutiveCard(bool isDark) {
    final hasDigest = _worldService.cachedExecutiveDigest.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AiraColors.cardDark : AiraColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3), width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.public, color: Colors.blueAccent, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Outside World Executive Briefing',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_isFetchingWorldFeed)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: Colors.blueAccent),
                  tooltip: 'Sync Radar',
                  onPressed: _refreshWorldFeed,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasDigest)
            MarkdownBody(
              data: _worldService.cachedExecutiveDigest,
              styleSheet: MarkdownStyleSheet(
                p: AiraTypography.bodyMedium.copyWith(
                  color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
                  height: 1.4,
                ),
                listBullet: const TextStyle(color: Colors.blueAccent),
              ),
            )
          else
            Text(
              'Scanning live trends across Hacker News, Reddit, GitHub, and India tech headlines...',
              style: AiraTypography.bodyMedium.copyWith(
                color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorldCategoryChip(String key, String label, bool isDark) {
    final isSelected = _selectedWorldCategory == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _selectedWorldCategory = key);
        },
        selectedColor: Colors.blueAccent,
        backgroundColor: isDark ? AiraColors.cardDark : AiraColors.cardLight,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : (isDark ? AiraColors.textMuted : AiraColors.textMutedLight),
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Colors.blueAccent : Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _buildWorldFeedItem(WorldNewsItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AiraColors.cardDark : AiraColors.cardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: item.category == 'ai'
                      ? Colors.purple.withValues(alpha: 0.2)
                      : Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.source,
                  style: TextStyle(
                    color: item.category == 'ai' ? Colors.purpleAccent : Colors.blueAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (item.score > 0) ...[
                const Icon(Icons.arrow_upward, size: 12, color: Colors.orangeAccent),
                Text(' ${item.score}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              Text(
                item.timeAgo,
                style: TextStyle(
                  color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
