import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:aira_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:aira_app/core/services/notification_service.dart';
import 'package:aira_app/core/services/android_device_service.dart';
import 'package:aira_app/core/services/voice_service.dart';
import 'package:aira_app/core/theme/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _selectedPersonality = 'Executive Mentor 🧠';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = ref.watch(currentUserProvider);
    final isAuthenticated = authState == AuthStatus.authenticated;
    final currentThemeMode = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? AiraColors.cardDark : AiraColors.cardLight;
    final borderColor = isDark ? AiraColors.borderDark : AiraColors.borderLight;
    final mutedColor = isDark ? AiraColors.textMuted : AiraColors.textMutedLight;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.onSurface,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // ── User Profile Card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AiraColors.claudeTerracotta,
                  ),
                  child: Center(
                    child: Text(
                      isAuthenticated
                          ? (user?.displayName.isNotEmpty == true ? user!.displayName[0].toUpperCase() : 'U')
                          : 'G',
                      style: GoogleFonts.sourceSerif4(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
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
                        isAuthenticated ? (user?.displayName ?? 'User') : 'Guest Account',
                        style: GoogleFonts.playfairDisplay(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAuthenticated ? (user?.email ?? 'Logged in') : 'Sign in to sync memories & data',
                        style: GoogleFonts.sourceSerif4(
                          color: mutedColor,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Appearance & Theme (Claude Dark / Linen Light / System) ──
          _sectionTitle('APPEARANCE & THEME'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Color Palette',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _themeOptionCard(
                        title: 'Dark',
                        subtitle: 'Warm Obsidian',
                        icon: Icons.dark_mode_rounded,
                        isSelected: currentThemeMode == ThemeMode.dark,
                        onTap: () => ref.read(themeProvider.notifier).setThemeMode(ThemeMode.dark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _themeOptionCard(
                        title: 'Light',
                        subtitle: 'Warm Linen',
                        icon: Icons.light_mode_rounded,
                        isSelected: currentThemeMode == ThemeMode.light,
                        onTap: () => ref.read(themeProvider.notifier).setThemeMode(ThemeMode.light),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _themeOptionCard(
                        title: 'System',
                        subtitle: 'Device Default',
                        icon: Icons.brightness_auto_rounded,
                        isSelected: currentThemeMode == ThemeMode.system,
                        onTap: () => ref.read(themeProvider.notifier).setThemeMode(ThemeMode.system),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── AIRA Smart Tools ──
          _sectionTitle('SMART TOOLS'),
          _settingsTile(
            Icons.laptop_mac_rounded,
            'Laptop Remote Control',
            'Trackpad, screen capture, keyboard & terminal',
            iconColor: AiraColors.claudeTerracotta,
            onTap: () => context.push('/laptop'),
          ),
          _settingsTile(
            Icons.newspaper_rounded,
            'Daily Intelligence Briefing',
            'Morning 7 AM & Night 10 PM Recaps',
            iconColor: AiraColors.claudeTerracotta,
            onTap: () => context.push('/briefing'),
          ),
          _settingsTile(
            Icons.remove_red_eye_outlined,
            'AIRA Vision (Camera AI)',
            'Analyze photos, code, documents & objects',
            iconColor: AiraColors.claudeTerracotta,
            onTap: () => context.push('/vision'),
          ),
          _settingsTile(
            Icons.mic_none_rounded,
            'Voice Notes & Meetings',
            'Transcribe & AI summary',
            iconColor: AiraColors.purpleLight,
            onTap: () => context.push('/voice-note'),
          ),
          _settingsTile(
            Icons.psychology_outlined,
            'Memory Vault',
            'View & manage AI long-term context',
            iconColor: AiraColors.claudeAmber,
            onTap: () {
              ref.read(chatProvider.notifier).sendMessage('show my memories');
              context.go('/chat');
            },
          ),
          _settingsTile(
            Icons.picture_in_picture_alt_rounded,
            'Everywhere Floating Bubble',
            'Use AIRA on top of other Android apps',
            iconColor: AiraColors.electricCyan,
            onTap: () => context.push('/overlay'),
          ),

          const SizedBox(height: 24),

          // ── System Controls ──
          _sectionTitle('SYSTEM & VOICE'),
          _settingsTile(
            Icons.key_rounded,
            'AI Model & API Keys',
            'Configure Groq, Gemini & OpenRouter keys',
            iconColor: AiraColors.claudeTerracotta,
            onTap: _showApiKeyDialog,
          ),
          _settingsTile(
            Icons.mic_rounded,
            'Voice & Wake-Word Engine',
            'Test speech recognition & mic permissions',
            iconColor: AiraColors.claudeTerracotta,
            onTap: _showVoiceControlDialog,
          ),
          _settingsTile(
            Icons.notifications_none_rounded,
            'System Notifications & Alarms',
            'Test high-priority reminder delivery',
            iconColor: AiraColors.claudeAmber,
            onTap: _showNotificationTestDialog,
          ),
          _settingsTile(
            Icons.auto_fix_high_rounded,
            'AI Personality Tone',
            _selectedPersonality,
            onTap: _showPersonalityDialog,
          ),

          const SizedBox(height: 24),

          // ── Privacy & Diagnostics ──
          _sectionTitle('DIAGNOSTICS & ACCOUNT'),
          _settingsTile(
            Icons.memory_rounded,
            'Device & Storage Diagnostics',
            'Check RAM, battery & hardware details',
            onTap: _showStorageInfoDialog,
          ),
          _settingsTile(
            Icons.shield_outlined,
            'Privacy & Data Security',
            'End-to-end encrypted with Supabase RLS',
            onTap: _showPrivacyDialog,
          ),
          _settingsTile(
            Icons.help_outline_rounded,
            'Command Guide',
            'Browse all supported voice and text commands',
            onTap: _showHelpDialog,
          ),

          const SizedBox(height: 28),

          // ── Sign In / Sign Out ──
          InkWell(
            onTap: () {
              if (isAuthenticated) {
                ref.read(authProvider.notifier).signOut();
              }
              context.go('/login');
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isAuthenticated
                    ? AiraColors.error.withValues(alpha: isDark ? 0.12 : 0.08)
                    : AiraColors.claudeTerracotta.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAuthenticated
                      ? AiraColors.error.withValues(alpha: 0.3)
                      : AiraColors.claudeTerracotta.withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                child: Text(
                  isAuthenticated ? 'Sign Out' : 'Sign In / Create Account',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: isAuthenticated ? AiraColors.error : AiraColors.claudeTerracotta,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AiraColors.claudeTerracotta.withValues(alpha: isDark ? 0.18 : 0.12)
              : (isDark ? AiraColors.surfaceDark : AiraColors.surfaceLightWarm),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AiraColors.claudeTerracotta
                : (isDark ? AiraColors.borderDark : AiraColors.borderLight),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? AiraColors.claudeTerracotta
                  : (isDark ? AiraColors.textSecondary : AiraColors.textSecondaryLight),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.sourceSerif4(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AiraColors.claudeTerracotta : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.sourceSerif4(
                fontSize: 10,
                color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.sourceSerif4(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? AiraColors.cardDark : AiraColors.cardLight;
    final borderColor = isDark ? AiraColors.borderDark : AiraColors.borderLight;
    final mutedColor = isDark ? AiraColors.textMuted : AiraColors.textMutedLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Icon(
          icon,
          color: iconColor ?? (isDark ? AiraColors.textSecondary : AiraColors.textSecondaryLight),
          size: 22,
        ),
        title: Text(
          title,
          style: GoogleFonts.sourceSerif4(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: trailing != null
            ? Text(
                trailing,
                style: GoogleFonts.sourceSerif4(
                  fontSize: 12,
                  color: mutedColor,
                ),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: mutedColor,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }

  // ──────────────────── Dialogs ────────────────────

  void _showVoiceControlDialog() async {
    final voice = VoiceService();
    final hasPermission = await voice.checkPermission();
    String testResultText = '';
    bool isTestingVoice = false;

    if (!mounted) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? AiraColors.cardDark : AiraColors.cardLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: isDark ? AiraColors.borderDark : AiraColors.borderLight),
            ),
            title: Row(
              children: [
                const Icon(Icons.mic_rounded, color: AiraColors.claudeTerracotta),
                const SizedBox(width: 10),
                Text(
                  'Voice & Speech Engine',
                  style: GoogleFonts.playfairDisplay(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Microphone:',
                        style: GoogleFonts.sourceSerif4(
                          color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        hasPermission ? 'Granted ✓' : 'Permission Required ⚠️',
                        style: GoogleFonts.sourceSerif4(
                          color: hasPermission ? AiraColors.success : AiraColors.warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!hasPermission)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final granted = await voice.requestPermission();
                        setDialogState(() {});
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(granted ? 'Microphone permission granted ✓' : 'Permission denied in Android Settings')),
                        );
                      },
                      icon: const Icon(Icons.security_rounded, size: 16),
                      label: const Text('Grant Microphone Permission'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AiraColors.warning,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    'Speech Recognition Test:',
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AiraColors.surfaceDark : AiraColors.surfaceLightWarm,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AiraColors.borderDark : AiraColors.borderLight),
                    ),
                    child: Text(
                      isTestingVoice
                          ? 'Listening... Speak "Hey AIRA call Rahul" or any query'
                          : (testResultText.isNotEmpty ? 'Recognized: "$testResultText"' : 'Tap button below to start live test'),
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 13,
                        color: isTestingVoice ? AiraColors.claudeTerracotta : theme.colorScheme.onSurface,
                        fontStyle: isTestingVoice ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: isTestingVoice
                        ? () async {
                            await voice.stopListening();
                            setDialogState(() => isTestingVoice = false);
                          }
                        : () async {
                            setDialogState(() {
                              isTestingVoice = true;
                              testResultText = '';
                            });
                            final success = await voice.startListening(
                              onResult: (text, isFinal) {
                                setDialogState(() {
                                  testResultText = text;
                                });
                              },
                              onCommandTriggered: (command) {
                                setDialogState(() {
                                  isTestingVoice = false;
                                  testResultText = 'Parsed Trigger: "$command"';
                                });
                              },
                              onError: (err) {
                                setDialogState(() {
                                  isTestingVoice = false;
                                  testResultText = 'Error: $err';
                                });
                              },
                            );
                            if (!success) {
                              setDialogState(() => isTestingVoice = false);
                            }
                          },
                    icon: Icon(isTestingVoice ? Icons.stop_rounded : Icons.mic_rounded, size: 16),
                    label: Text(isTestingVoice ? 'Stop Testing' : 'Start Live Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isTestingVoice ? AiraColors.error : AiraColors.claudeTerracotta,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  voice.stopListening();
                  Navigator.pop(context);
                },
                child: Text(
                  'Close',
                  style: GoogleFonts.sourceSerif4(color: AiraColors.claudeTerracotta),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showNotificationTestDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AiraColors.cardDark : AiraColors.cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? AiraColors.borderDark : AiraColors.borderLight),
        ),
        title: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: AiraColors.claudeTerracotta),
            const SizedBox(width: 10),
            Text(
              'System Notifications',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AIRA OS uses Android system notification channels to deliver high-priority alarms for exact reminders and 7 AM / 10 PM briefings.',
              style: GoogleFonts.sourceSerif4(
                fontSize: 13,
                color: isDark ? AiraColors.textSecondary : AiraColors.textSecondaryLight,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final notif = NotificationService();
                await notif.requestPermissions();
                await notif.showNotification(
                  id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  title: 'AIRA OS Notification 🔔',
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
                backgroundColor: AiraColors.claudeTerracotta,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AiraColors.cardDark : AiraColors.cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? AiraColors.borderDark : AiraColors.borderLight),
        ),
        title: Text(
          'Select AI Tone',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: personalities.map((p) {
            final isSelected = _selectedPersonality == p;
            return ListTile(
              title: Text(
                p,
                style: GoogleFonts.sourceSerif4(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? AiraColors.claudeTerracotta : theme.colorScheme.onSurface,
                ),
              ),
              trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AiraColors.claudeTerracotta) : null,
              onTap: () {
                setState(() => _selectedPersonality = p);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('AIRA Tone set to $p')),
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AiraColors.cardDark : AiraColors.cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? AiraColors.borderDark : AiraColors.borderLight),
        ),
        title: Row(
          children: [
            const Icon(Icons.memory_rounded, color: AiraColors.claudeTerracotta),
            const SizedBox(width: 10),
            Text(
              'System Diagnostics',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: theme.colorScheme.onSurface,
              ),
            ),
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
            child: Text(
              'Close',
              style: GoogleFonts.sourceSerif4(color: AiraColors.claudeTerracotta),
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagRow(String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.sourceSerif4(
              fontSize: 12.5,
              color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.sourceSerif4(
              fontSize: 12.5,
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AiraColors.cardDark : AiraColors.cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? AiraColors.borderDark : AiraColors.borderLight),
        ),
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: AiraColors.success),
            const SizedBox(width: 10),
            Text(
              'Privacy Shield',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'AIRA OS executes device controls locally via native Android OS APIs. Long-term memories and conversations are encrypted in your private Supabase instance.',
          style: GoogleFonts.sourceSerif4(
            fontSize: 13.5,
            color: isDark ? AiraColors.textSecondary : AiraColors.textSecondaryLight,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.sourceSerif4(color: AiraColors.claudeTerracotta),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AiraColors.cardDark : AiraColors.cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? AiraColors.borderDark : AiraColors.borderLight),
        ),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: AiraColors.claudeTerracotta),
            const SizedBox(width: 10),
            Text(
              'Command Guide',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _helpItem('🗞️ Daily Briefing', 'View 7 AM & 10 PM curated intelligence'),
              _helpItem('📸 Vision AI', 'Tap Eye icon in chat to analyze camera feed'),
              _helpItem('🎙️ Meeting Notes', 'Record and generate meeting transcripts & summaries'),
              _helpItem('💬 Everywhere Overlay', 'Enable floating chat bubble over all apps'),
              _helpItem('📞 Phone & SMS', '"Call Rahul", "Send SMS to Mom saying hello"'),
              _helpItem('⚙️ Device Control', '"Turn on flashlight", "Volume up", "Open YouTube"'),
              _helpItem('🔔 Reminders', '"Remind me at 2 PM", "Send daily news at 7 AM"'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.sourceSerif4(color: AiraColors.claudeTerracotta),
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpItem(String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.sourceSerif4(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AiraColors.claudeTerracotta,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.sourceSerif4(
              fontSize: 12,
              color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
            ),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final groqController = TextEditingController(text: prefs.getString('aira_custom_groq_key') ?? '');
    final geminiController = TextEditingController(text: prefs.getString('aira_custom_gemini_key') ?? '');

    if (!mounted) return;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.key_rounded, color: AiraColors.claudeTerracotta, size: 22),
            const SizedBox(width: 10),
            Text(
              'AI Model & API Keys',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AiraColors.claudeTerracotta.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AiraColors.claudeTerracotta.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '💡 AIRA works with free API keys from Groq or Google Gemini. Get a free Groq key in 10 seconds at console.groq.com/keys.',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 12.5,
                    color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Groq API Key (Recommended)',
                style: GoogleFonts.sourceSerif4(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: groqController,
                decoration: InputDecoration(
                  hintText: 'gsk_...',
                  hintStyle: GoogleFonts.firaCode(fontSize: 12),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: GoogleFonts.firaCode(fontSize: 12),
                obscureText: true,
              ),
              const SizedBox(height: 14),
              Text(
                'Gemini API Key (Optional Fallback)',
                style: GoogleFonts.sourceSerif4(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: geminiController,
                decoration: InputDecoration(
                  hintText: 'AIzaSy...',
                  hintStyle: GoogleFonts.firaCode(fontSize: 12),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: GoogleFonts.firaCode(fontSize: 12),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.sourceSerif4()),
          ),
          ElevatedButton(
            onPressed: () async {
              await prefs.setString('aira_custom_groq_key', groqController.text.trim());
              await prefs.setString('aira_custom_gemini_key', geminiController.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('AI API keys saved successfully!'),
                    backgroundColor: AiraColors.claudeTerracotta,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AiraColors.claudeTerracotta),
            child: Text('Save Keys', style: GoogleFonts.sourceSerif4(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
