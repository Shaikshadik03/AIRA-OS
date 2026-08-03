import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/widgets/glassmorphic_container.dart';
import 'package:aira_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:aira_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:aira_app/core/services/notification_service.dart';
import 'package:aira_app/core/services/android_device_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _selectedPersonality = 'Executive Mentor 🧠';
  String _selectedLanguage = 'English 🇺🇸';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = ref.watch(currentUserProvider);
    final isAuthenticated = authState == AuthStatus.authenticated;

    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('AIRA OS Control Center', style: AiraTypography.h4.copyWith(fontWeight: FontWeight.w800)),
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
                      isAuthenticated ? (user?.displayName.isNotEmpty == true ? user!.displayName[0].toUpperCase() : 'U') : 'G',
                      style: AiraTypography.h4.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isAuthenticated ? (user?.displayName ?? 'User') : 'Guest Account', style: AiraTypography.h5),
                      const SizedBox(height: 2),
                      Text(
                        isAuthenticated ? (user?.email ?? 'Logged in') : 'Sign in to sync data across devices',
                        style: AiraTypography.caption.copyWith(
                          color: AiraColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── AIRA Tools & Features ──
          _sectionTitle('AIRA Smart Tools'),
          _settingsTile(
            Icons.remove_red_eye_rounded,
            'AIRA Vision (Live Camera AI)',
            'Analyze visual code & object',
            iconColor: AiraColors.electricCyan,
            onTap: () => context.push('/vision'),
          ),
          _settingsTile(
            Icons.mic_rounded,
            'Voice Note & Meeting Summarizer',
            'Transcribe & AI Summary',
            iconColor: AiraColors.purpleLight,
            onTap: () => context.push('/voice-note'),
          ),
          _settingsTile(
            Icons.picture_in_picture_alt_rounded,
            'AIRA Everywhere Floating Overlay',
            'Cross-app chat head bubble',
            iconColor: AiraColors.cyanLight,
            onTap: () => context.push('/overlay'),
          ),
          _settingsTile(
            Icons.psychology_rounded,
            'AIRA Memory Vault',
            'View & manage AI long-term memory',
            iconColor: AiraColors.amber,
            onTap: () {
              ref.read(chatProvider.notifier).sendMessage('show my memories');
              context.go('/chat');
            },
          ),

          const SizedBox(height: 24),

          // ── Notifications & System ──
          _sectionTitle('Notifications & System'),
          _settingsTile(
            Icons.notifications_active_rounded,
            'System Notifications',
            'Test push notification now',
            iconColor: AiraColors.electricCyan,
            onTap: _showNotificationTestDialog,
          ),
          _settingsTile(
            Icons.psychology_outlined,
            'AI Personality Engine',
            _selectedPersonality,
            onTap: _showPersonalityDialog,
          ),
          _settingsTile(
            Icons.language_rounded,
            'Voice & Language',
            _selectedLanguage,
            onTap: _showLanguageDialog,
          ),

          const SizedBox(height: 24),

          // ── Privacy & System Diagnostics ──
          _sectionTitle('Privacy & Storage Diagnostics'),
          _settingsTile(
            Icons.storage_rounded,
            'Storage & System Info',
            'Check RAM, Storage & Battery',
            onTap: _showStorageInfoDialog,
          ),
          _settingsTile(
            Icons.shield_outlined,
            'Privacy & Security Shield',
            'Supabase RLS & Encryption Active',
            onTap: _showPrivacyDialog,
          ),
          _settingsTile(
            Icons.help_outline_rounded,
            'Command Guide & Support',
            'View full feature list',
            onTap: _showHelpDialog,
          ),

          const SizedBox(height: 28),

          // Sign In / Sign Out
          GestureDetector(
            onTap: () {
              if (isAuthenticated) {
                ref.read(authProvider.notifier).signOut();
              }
              context.go('/login');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isAuthenticated 
                    ? AiraColors.error.withValues(alpha: 0.08)
                    : AiraColors.electricCyan.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAuthenticated
                      ? AiraColors.error.withValues(alpha: 0.2)
                      : AiraColors.electricCyan.withValues(alpha: 0.2),
                ),
              ),
              child: Center(
                child: Text(
                  isAuthenticated ? 'Sign Out' : 'Sign In / Create Account',
                  style: AiraTypography.buttonText.copyWith(
                    color: isAuthenticated ? AiraColors.error : AiraColors.electricCyan,
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

  Widget _settingsTile(
    IconData icon,
    String title,
    String? trailing, {
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AiraColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AiraColors.glassBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Icon(icon, color: iconColor ?? AiraColors.textSecondary, size: 22),
        title: Text(title, style: AiraTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        subtitle: trailing != null
            ? Text(trailing, style: AiraTypography.caption.copyWith(color: AiraColors.textMuted))
            : null,
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AiraColors.textMuted,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }

  // ──────────────────── Dialogs for Working Features ────────────────────

  void _showNotificationTestDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AiraColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: AiraColors.electricCyan),
            const SizedBox(width: 10),
            Text('System Notifications', style: AiraTypography.h5.copyWith(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AIRA OS uses Android system notification channels to deliver high-priority alerts for exact reminders and daily briefings.',
              style: AiraTypography.bodySmall.copyWith(color: AiraColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final notif = NotificationService();
                await notif.requestPermissions();
                await notif.showNotification(
                  id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  title: 'AIRA OS Notification Test 🔔',
                  body: 'System notifications are 100% active and working on your Android device!',
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test notification sent to your phone!')),
                );
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Send Test Notification Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AiraColors.electricCyan,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPersonalityDialog() {
    final personalities = [
      'Executive Mentor 🧠',
      'Technical Genius 💻',
      'Friendly Companion 🤝',
      'Professional Assistant 💼',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AiraColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Select AI Personality', style: AiraTypography.h5.copyWith(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: personalities.map((p) {
            final isSelected = _selectedPersonality == p;
            return ListTile(
              title: Text(p, style: AiraTypography.bodyMedium.copyWith(color: Colors.white)),
              trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AiraColors.electricCyan) : null,
              onTap: () {
                setState(() => _selectedPersonality = p);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('AIRA Personality set to $p')),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    final languages = [
      'English 🇺🇸',
      'Hindi 🇮🇳',
      'Telugu 🇮🇳',
      'Spanish 🇪🇸',
      'French 🇫🇷',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AiraColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Select Assistant Language', style: AiraTypography.h5.copyWith(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((lang) {
            final isSelected = _selectedLanguage == lang;
            return ListTile(
              title: Text(lang, style: AiraTypography.bodyMedium.copyWith(color: Colors.white)),
              trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AiraColors.electricCyan) : null,
              onTap: () {
                setState(() => _selectedLanguage = lang);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Language set to $lang')),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showStorageInfoDialog() async {
    final info = await AndroidDeviceService().getDeviceInfo();
    if (!mounted) return;

    final battery = info['batteryLevel'] ?? '?';
    final isCharging = info['isCharging'] == true ? '⚡ Charging' : 'Discharging';
    final totalGB = info['totalStorageGB'] ?? '?';
    final availMB = info['availStorageMB'] ?? '?';
    final model = '${info['manufacturer'] ?? ''} ${info['model'] ?? ''}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AiraColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.memory_rounded, color: AiraColors.electricCyan),
            const SizedBox(width: 10),
            Text('System Diagnostics', style: AiraTypography.h5.copyWith(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _diagRow('Device Model', model),
            _diagRow('Battery', '$battery% ($isCharging)'),
            _diagRow('Total Internal Storage', '$totalGB GB'),
            _diagRow('Free Storage Available', '$availMB MB'),
            _diagRow('Android Version', '${info['androidVersion']} (SDK ${info['sdkVersion']})'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _diagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AiraTypography.caption.copyWith(color: AiraColors.textMuted)),
          Text(value, style: AiraTypography.caption.copyWith(color: AiraColors.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AiraColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: AiraColors.success),
            const SizedBox(width: 10),
            Text('Privacy & Security Shield', style: AiraTypography.h5.copyWith(color: Colors.white)),
          ],
        ),
        content: Text(
          'AIRA OS processes all phone actions locally via native Android OS APIs. Long-term chat memory is encrypted in your private Supabase database instance.',
          style: AiraTypography.bodySmall.copyWith(color: AiraColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AiraColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: AiraColors.electricCyan),
            const SizedBox(width: 10),
            Text('AIRA OS Command Guide', style: AiraTypography.h5.copyWith(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _helpItem('📸 Vision AI', 'Tap Eye icon in chat to analyze camera feed'),
              _helpItem('🎙️ Meeting Notes', 'Open Voice Notes screen to record & summarize'),
              _helpItem('💬 Everywhere Overlay', 'Enable floating chat bubble over all apps'),
              _helpItem('📞 Phone & SMS', '"Call Rahul", "Send SMS to Mom saying hello"'),
              _helpItem('⚙️ Device Control', '"Turn on flashlight", "Volume up", "Open Spotify"'),
              _helpItem('🔔 Reminders', '"Remind me at 2 PM", "Send daily news at 7 AM"'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _helpItem(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AiraTypography.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AiraColors.electricCyan)),
          Text(subtitle, style: AiraTypography.caption.copyWith(color: AiraColors.textMuted)),
        ],
      ),
    );
  }
}
