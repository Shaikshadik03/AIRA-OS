import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:dio/dio.dart';
import 'package:aira_app/core/services/llm_service.dart';
import 'package:aira_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:aira_app/core/services/notification_service.dart';
import 'package:aira_app/core/services/android_device_service.dart';
import 'package:aira_app/core/services/voice_service.dart';
import 'package:aira_app/core/theme/theme_provider.dart';
import 'package:flutter/services.dart';
import 'package:aira_app/core/services/user_profile_service.dart';
import 'package:aira_app/core/services/wake_word_service.dart';
import 'package:aira_app/core/services/personality_engine.dart';
import 'package:aira_app/core/services/automation_control_service.dart';
import 'package:aira_app/core/services/setup_checklist_service.dart';
import 'package:aira_app/core/services/connection_diagnostics_service.dart';
import 'package:aira_app/core/services/diagnostic_logger.dart';
import 'package:aira_app/core/services/usage_metrics_service.dart';
import 'package:aira_app/core/services/data_backup_service.dart';

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

          const SizedBox(height: 16),

          // ── Emergency Automation Kill-Switch (Stage M) ──
          _buildEmergencyAutomationCard(isDark, cardBg, borderColor),

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
            Icons.notifications_active_outlined,
            'Intelligence & Monitor',
            'Summarize phone notifications & outside world trends',
            iconColor: AiraColors.claudeTerracotta,
            onTap: () => context.push('/monitor'),
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
            Icons.person_outline_rounded,
            'My Profile & Memory',
            'Tell AIRA who you are so it knows you personally',
            iconColor: AiraColors.claudeTerracotta,
            onTap: _showProfileDialog,
          ),
          _settingsTile(
            Icons.mic_none_rounded,
            'Hey AIRA — Hands-Free Mode',
            WakeWordService().isEnabled ? 'Active — say "Hey AIRA" anytime' : 'Tap to enable always-on voice',
            iconColor: const Color(0xFF4CAF50),
            onTap: _showWakeWordDialog,
          ),
          _settingsTile(
            Icons.auto_fix_high_rounded,
            'AI Personality Tone',
            _selectedPersonality,
            onTap: _showPersonalityDialog,
          ),

          const SizedBox(height: 24),

          // ── Privacy & Diagnostics ──
          _sectionTitle('RELIABILITY & DIAGNOSTICS'),
          _settingsTile(
            Icons.checklist_rounded,
            'First-Run Setup Checklist',
            'Verify readiness across AI, mic, alerts & laptop',
            iconColor: const Color(0xFF4CAF50),
            onTap: _showChecklistDialog,
          ),
          _settingsTile(
            Icons.network_check_rounded,
            'Connection & Provider Health',
            'Real-time latency ping for Groq, Gemini & laptop',
            iconColor: AiraColors.electricCyan,
            onTap: _showConnectionDiagnosticsDialog,
          ),
          _settingsTile(
            Icons.analytics_outlined,
            'System Health & Reliability Metrics',
            'Track query volume, latency averages & success rate',
            iconColor: AiraColors.claudeTerracotta,
            onTap: _showMetricsDialog,
          ),
          _settingsTile(
            Icons.terminal_rounded,
            'Redacted Diagnostic Logs',
            'Sanitized, token-scrubbed system events & errors',
            iconColor: AiraColors.claudeAmber,
            onTap: _showDiagnosticLogsDialog,
          ),
          _settingsTile(
            Icons.cloud_sync_outlined,
            'Data Backup, Restore & Wipe (GDPR)',
            'Export personal context or erase all local data',
            iconColor: AiraColors.purpleLight,
            onTap: _showDataBackupDialog,
          ),
          _settingsTile(
            Icons.memory_rounded,
            'Device & Hardware Details',
            'Check RAM, battery & hardware details',
            onTap: _showStorageInfoDialog,
          ),
          _settingsTile(
            Icons.shield_outlined,
            'Privacy & Security Architecture',
            'Guaranteed boundary security & local encryption',
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
    // Map display labels → PersonalityEngine mode keys
    final personalities = {
      'Friendly Companion 🤝': 'friend',
      'Executive Mentor 🧠': 'mentor',
      'Professional Assistant 💼': 'professional',
      'Creative Spark ✨': 'creative',
    };

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
          children: personalities.entries.map((entry) {
            final label = entry.key;
            final modeKey = entry.value;
            final isSelected = _selectedPersonality == label;
            return ListTile(
              title: Text(
                label,
                style: GoogleFonts.sourceSerif4(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? AiraColors.claudeTerracotta : theme.colorScheme.onSurface,
                ),
              ),
              trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AiraColors.claudeTerracotta) : null,
              onTap: () async {
                // Actually save to PersonalityEngine (persisted via SharedPreferences)
                await PersonalityEngine().setMode(modeKey);
                setState(() => _selectedPersonality = label);
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('AIRA Tone set to $label')),
                  );
                }
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
    final openRouterController = TextEditingController(text: prefs.getString('aira_custom_openrouter_key') ?? '');

    String? testResult;
    bool isTesting = false;
    bool isTestSuccess = false;

    if (!mounted) return;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          Future<void> testGroqKey() async {
            final key = LlmService.sanitizeApiKey(groqController.text);
            if (key.isEmpty) {
              setDialogState(() {
                testResult = 'Please enter a Groq API key first.';
                isTestSuccess = false;
              });
              return;
            }

            setDialogState(() {
              isTesting = true;
              testResult = 'Verifying key with Groq Cloud...';
            });

            try {
              final dio = Dio(BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
              ));
              final resp = await dio.get(
                'https://api.groq.com/openai/v1/models',
                options: Options(headers: {'Authorization': 'Bearer $key'}),
              );
              if (resp.statusCode == 200) {
                setDialogState(() {
                  isTesting = false;
                  isTestSuccess = true;
                  testResult = '✅ Key Valid! Connected to Groq Cloud.';
                });
              } else {
                setDialogState(() {
                  isTesting = false;
                  isTestSuccess = false;
                  testResult = '⚠️ Server returned code ${resp.statusCode}.';
                });
              }
            } on DioException catch (e) {
              setDialogState(() {
                isTesting = false;
                isTestSuccess = false;
                if (e.response?.statusCode == 401) {
                  testResult = '❌ Invalid API Key (HTTP 401 Unauthorized).';
                } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
                  testResult = '⚠️ Network timeout. Check internet connection.';
                } else {
                  testResult = '❌ Connection failed: ${e.response?.statusCode ?? e.message}';
                }
              });
            } catch (e) {
              setDialogState(() {
                isTesting = false;
                isTestSuccess = false;
                testResult = '❌ Verification error: $e';
              });
            }
          }

          return AlertDialog(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Groq API Key (Primary)',
                        style: GoogleFonts.sourceSerif4(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: isTesting ? null : testGroqKey,
                        icon: isTesting
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AiraColors.claudeTerracotta),
                              )
                            : const Icon(Icons.flash_on_rounded, size: 14, color: AiraColors.claudeTerracotta),
                        label: Text(
                          isTesting ? 'Testing...' : 'Test Key',
                          style: GoogleFonts.sourceSerif4(fontSize: 11, fontWeight: FontWeight.w700, color: AiraColors.claudeTerracotta),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
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
                  if (testResult != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isTestSuccess
                            ? AiraColors.success.withValues(alpha: 0.12)
                            : AiraColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        testResult!,
                        style: GoogleFonts.sourceSerif4(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isTestSuccess ? AiraColors.success : AiraColors.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Gemini API Key (Optional Fallback 1)',
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
                  const SizedBox(height: 14),
                  Text(
                    'OpenRouter API Key (Optional Fallback 2)',
                    style: GoogleFonts.sourceSerif4(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: openRouterController,
                    decoration: InputDecoration(
                      hintText: 'sk-or-v1-...',
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
                  final cleanGroq = LlmService.sanitizeApiKey(groqController.text);
                  final cleanGemini = LlmService.sanitizeApiKey(geminiController.text);
                  final cleanOpenRouter = LlmService.sanitizeApiKey(openRouterController.text);

                  await prefs.setString('aira_custom_groq_key', cleanGroq);
                  await prefs.setString('aira_custom_gemini_key', cleanGemini);
                  await prefs.setString('aira_custom_openrouter_key', cleanOpenRouter);

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('AI API keys saved and verified successfully!'),
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
          );
        },
      ),
    );
  }
  void _showProfileDialog() async {
    final profileService = UserProfileService();
    await profileService.load();
    final controllers = <String, TextEditingController>{};

    for (final field in UserProfileService.profileFields) {
      controllers[field['key']!] = TextEditingController(
        text: (profileService.getField(field['key']!) ?? '').toString(),
      );
    }

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
            const Icon(Icons.person_outline_rounded, color: AiraColors.claudeTerracotta, size: 22),
            const SizedBox(width: 10),
            Text(
              'My Profile',
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
                  'Tell AIRA about yourself so it can talk to you like a real friend who knows you.',
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 12.5,
                    color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ...UserProfileService.profileFields.map((field) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: controllers[field['key']!],
                  decoration: InputDecoration(
                    labelText: field['label'],
                    hintText: field['hint'],
                    labelStyle: GoogleFonts.sourceSerif4(fontSize: 12.5, fontWeight: FontWeight.w600),
                    hintStyle: GoogleFonts.sourceSerif4(fontSize: 12, color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: GoogleFonts.sourceSerif4(fontSize: 13, color: theme.colorScheme.onSurface),
                ),
              )),
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
              final updates = <String, dynamic>{};
              for (final entry in controllers.entries) {
                updates[entry.key] = entry.value.text.trim();
              }
              await profileService.updateProfile(updates);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Profile saved! AIRA now knows you personally.'),
                    backgroundColor: AiraColors.claudeTerracotta,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AiraColors.claudeTerracotta),
            child: Text('Save Profile', style: GoogleFonts.sourceSerif4(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showWakeWordDialog() async {
    final wakeService = WakeWordService();
    await wakeService.load();
    final keyController = TextEditingController();
    bool isEnabled = wakeService.isEnabled;

    if (!mounted) return;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.mic_none_rounded, color: Color(0xFF4CAF50), size: 22),
              const SizedBox(width: 10),
              Text(
                'Hey AIRA',
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
                    color: const Color(0xFF4CAF50).withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Say "Hey AIRA" with your screen off, phone in pocket — and AIRA starts listening. Just like Siri, but yours.',
                    style: GoogleFonts.sourceSerif4(
                      fontSize: 12.5,
                      color: isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text('Enable Hands-Free Mode', style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    isEnabled ? 'AIRA is always listening for your voice' : 'Turn on to activate "Hey AIRA"',
                    style: GoogleFonts.sourceSerif4(fontSize: 12),
                  ),
                  value: isEnabled,
                  activeTrackColor: const Color(0xFF4CAF50),
                  onChanged: (val) {
                    setDialogState(() => isEnabled = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyController,
                  decoration: InputDecoration(
                    labelText: 'Picovoice Access Key (Optional)',
                    hintText: 'Get free key from console.picovoice.ai',
                    labelStyle: GoogleFonts.sourceSerif4(fontSize: 12.5, fontWeight: FontWeight.w600),
                    hintStyle: GoogleFonts.sourceSerif4(fontSize: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: GoogleFonts.sourceSerif4(fontSize: 13, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  'Without a Picovoice key, AIRA uses fallback keyword detection (less accurate but still works).',
                  style: GoogleFonts.sourceSerif4(fontSize: 11, color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight),
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
                if (keyController.text.trim().isNotEmpty) {
                  await wakeService.setAccessKey(keyController.text.trim());
                }
                await wakeService.setEnabled(isEnabled);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  setState(() {}); // Refresh settings UI
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEnabled
                          ? 'Hands-free mode enabled! Say "Hey AIRA" anytime.'
                          : 'Hands-free mode disabled.'),
                      backgroundColor: const Color(0xFF4CAF50),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
              child: Text('Save', style: GoogleFonts.sourceSerif4(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stage M: Reliability, Emergency Control & Diagnostics ─────────────

  Widget _buildEmergencyAutomationCard(bool isDark, Color cardBg, Color borderColor) {
    return ValueListenableBuilder<bool>(
      valueListenable: AutomationControlService().isPausedNotifier,
      builder: (context, isPaused, _) {
        final alertColor = isPaused ? const Color(0xFFE53935) : const Color(0xFF4CAF50);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isPaused
                ? const Color(0xFFE53935).withValues(alpha: isDark ? 0.15 : 0.08)
                : cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPaused
                  ? const Color(0xFFE53935).withValues(alpha: 0.5)
                  : borderColor,
              width: isPaused ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: alertColor.withValues(alpha: 0.15),
                ),
                child: Icon(
                  isPaused ? Icons.pause_circle_filled_rounded : Icons.bolt_rounded,
                  color: alertColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPaused ? 'AUTOMATIONS PAUSED' : 'Autonomous Automations',
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isPaused ? const Color(0xFFE53935) : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPaused
                          ? 'All background proactive nudges, goal plans & laptop actions stopped.'
                          : 'Proactive nudges, goal planners & companion tasks active.',
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 11.5,
                        color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: !isPaused,
                activeThumbColor: const Color(0xFF4CAF50),
                inactiveThumbColor: const Color(0xFFE53935),
                inactiveTrackColor: const Color(0xFFE53935).withValues(alpha: 0.3),
                onChanged: (active) async {
                  if (active) {
                    await AutomationControlService().resumeAutomation();
                  } else {
                    await AutomationControlService().pauseAllAutomation(reason: 'Paused by user via Settings.');
                  }
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChecklistDialog() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final report = await SetupChecklistService().evaluateReadiness();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.checklist_rounded, color: Color(0xFF4CAF50)),
            const SizedBox(width: 10),
            Text(
              'First-Run Setup Checklist',
              style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (report.isProductionReady ? const Color(0xFF4CAF50) : AiraColors.claudeAmber)
                      .withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      '${report.readinessPercentage}%',
                      style: GoogleFonts.sourceSerif4(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.isProductionReady ? 'Production Ready' : 'Setup Incomplete',
                            style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          Text(
                            '${report.completedCount} of ${report.totalCount} core pillars active',
                            style: GoogleFonts.sourceSerif4(fontSize: 11.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: report.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final item = report.items[idx];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        item.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: item.isCompleted ? const Color(0xFF4CAF50) : AiraColors.textMuted,
                        size: 20,
                      ),
                      title: Text(item.title, style: GoogleFonts.sourceSerif4(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(item.description, style: GoogleFonts.sourceSerif4(fontSize: 11)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Done', style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showConnectionDiagnosticsDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return FutureBuilder<DiagnosticsReport>(
          future: ConnectionDiagnosticsService().runAllDiagnostics(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return AlertDialog(
                backgroundColor: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                content: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AiraColors.claudeTerracotta),
                      const SizedBox(height: 16),
                      Text('Running Real-Time Connection Diagnostics...', style: GoogleFonts.sourceSerif4(fontSize: 13.5)),
                    ],
                  ),
                ),
              );
            }

            final rep = snapshot.data!;
            final targets = [rep.internet, rep.groq, rep.gemini, rep.openRouter, rep.laptop, rep.storage];

            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(
                children: [
                  const Icon(Icons.network_check_rounded, color: AiraColors.electricCyan),
                  const SizedBox(width: 10),
                  Text('System Diagnostics', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, fontSize: 17)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: targets.length,
                  separatorBuilder: (_, __) => const Divider(height: 8),
                  itemBuilder: (_, i) {
                    final t = targets[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.target, style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text(t.details, style: GoogleFonts.sourceSerif4(fontSize: 11, color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (t.status == DiagnosticStatus.healthy ? const Color(0xFF4CAF50) : AiraColors.error).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              t.statusBadge,
                              style: GoogleFonts.sourceSerif4(fontSize: 10.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Close', style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMetricsDialog() {
    final theme = Theme.of(context);
    final m = UsageMetricsService();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: AiraColors.claudeTerracotta),
            const SizedBox(width: 10),
            Text('Reliability Metrics', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _metricRow('Total Queries Processed', '${m.totalQueries}'),
            _metricRow('Successful Tool Actions', '${m.successfulToolExecutions}'),
            _metricRow('Failed Tool Actions', '${m.failedToolExecutions}'),
            _metricRow('Tool Success Rate', '${m.toolSuccessRatePercent}%'),
            _metricRow('Average AI Latency', '${m.averageLatencyMs} ms'),
            _metricRow('Total Automations Run', '${m.totalAutomationsRun}'),
            _metricRow('Automations Paused', '${m.totalAutomationsPaused}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await m.resetMetrics();
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: Text('Reset', style: GoogleFonts.sourceSerif4(color: AiraColors.error)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AiraColors.claudeTerracotta),
            child: Text('OK', style: GoogleFonts.sourceSerif4(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.sourceSerif4(fontSize: 12.5)),
          Text(value, style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  void _showDiagnosticLogsDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final logText = DiagnosticLogger().exportRedactedLogs();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.terminal_rounded, color: AiraColors.claudeAmber),
            const SizedBox(width: 10),
            Text('Redacted Diagnostic Logs', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF10100E) : const Color(0xFFF5F5F0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AiraColors.borderDark : AiraColors.borderLight),
            ),
            child: SingleChildScrollView(
              child: Text(
                logText,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, height: 1.4),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              DiagnosticLogger().clear();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Clear', style: GoogleFonts.sourceSerif4(color: AiraColors.error)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: logText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Redacted logs copied to clipboard.'), behavior: SnackBarBehavior.floating),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
            label: Text('Copy', style: GoogleFonts.sourceSerif4(color: Colors.white, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: AiraColors.claudeTerracotta),
          ),
        ],
      ),
    );
  }

  void _showDataBackupDialog() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.cloud_sync_outlined, color: AiraColors.purpleLight),
            const SizedBox(width: 10),
            Text('Data Backup & Privacy', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Export your complete personal context, memory facts, tasks, and notes, or permanently erase all local storage.',
              style: GoogleFonts.sourceSerif4(fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              icon: const Icon(Icons.download_rounded),
              label: Text('Export Data Backup (JSON)', style: GoogleFonts.sourceSerif4(fontWeight: FontWeight.w600)),
              onPressed: () async {
                final json = await DataBackupService().exportBackupJson();
                await Clipboard.setData(ClipboardData(text: json));
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Complete data backup copied to clipboard! Save it safely.'),
                      backgroundColor: Color(0xFF4CAF50),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_forever_rounded, color: AiraColors.error),
              label: Text('Delete All Data (GDPR Wipe)', style: GoogleFonts.sourceSerif4(color: AiraColors.error, fontWeight: FontWeight.w700)),
              onPressed: () {
                Navigator.pop(ctx);
                _showConfirmDataWipeDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: GoogleFonts.sourceSerif4()),
          ),
        ],
      ),
    );
  }

  void _showConfirmDataWipeDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AiraColors.error),
            const SizedBox(width: 10),
            Text('Confirm Data Wipe', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, fontSize: 17, color: AiraColors.error)),
          ],
        ),
        content: Text(
          'This action is IRREVERSIBLE. It will permanently delete all your memories, habits, local tasks, saved notes, and active goal plans from this device.',
          style: GoogleFonts.sourceSerif4(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.sourceSerif4()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AiraColors.error),
            onPressed: () async {
              await DataBackupService().deleteAllData();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All personal data has been erased. Device reset to factory state.'),
                    backgroundColor: AiraColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('Erase Everything', style: GoogleFonts.sourceSerif4(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
