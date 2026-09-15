import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:aira_app/config/app_config.dart';
import 'package:aira_app/core/services/user_profile_service.dart';
import 'package:aira_app/core/services/memory_engine.dart';
import 'package:aira_app/features/laptop/data/laptop_control_service.dart';

class SetupChecklistItem {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final String category;
  final String actionLabel;
  final String? route;

  const SetupChecklistItem({
    required this.id,
    required this.title,
    required this.description,
    required this.isCompleted,
    required this.category,
    required this.actionLabel,
    this.route,
  });
}

class ChecklistReport {
  final List<SetupChecklistItem> items;
  final int completedCount;
  final int totalCount;
  final int readinessPercentage;

  const ChecklistReport({
    required this.items,
    required this.completedCount,
    required this.totalCount,
    required this.readinessPercentage,
  });

  bool get isProductionReady => readinessPercentage >= 80;
}

/// First-Run Setup & Readiness Checklist Service (Stage M / Stage 12).
class SetupChecklistService {
  static final SetupChecklistService _instance = SetupChecklistService._internal();
  factory SetupChecklistService() => _instance;
  SetupChecklistService._internal();

  /// Evaluate the 6 foundational readiness pillars for daily production usage
  Future<ChecklistReport> evaluateReadiness() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. AI API Key configured
    final groqKey = prefs.getString('aira_custom_groq_key')?.trim() ?? AppConfig.groqApiKey;
    final geminiKey = prefs.getString('aira_custom_gemini_key')?.trim() ?? AppConfig.geminiApiKey;
    final openRouterKey = prefs.getString('aira_custom_openrouter_key')?.trim() ?? AppConfig.openRouterApiKey;
    final hasAiKey = groqKey.isNotEmpty || geminiKey.isNotEmpty || openRouterKey.isNotEmpty;

    // 2. Microphone / Voice Permissions
    bool hasMic = false;
    try {
      hasMic = await Permission.microphone.isGranted;
    } catch (_) {
      hasMic = true; // Fallback for test/desktop environments
    }

    // 3. System Notification Permission
    bool hasNotifications = false;
    try {
      hasNotifications = await Permission.notification.isGranted;
    } catch (_) {
      hasNotifications = true;
    }

    // 4. Personal Profile Configured
    final profileName = UserProfileService().displayName;
    final hasProfile = UserProfileService().isProfileSetUp;

    // 5. Memory Vault Active
    final facts = MemoryEngine().getAllFactStrings();
    final hasMemory = facts.isNotEmpty;

    // 6. Connected Laptop Companion
    final isLaptopPaired = LaptopControlService().isPaired;

    final items = [
      SetupChecklistItem(
        id: 'ai_brain_key',
        title: 'AI Intelligence Key',
        description: hasAiKey
            ? 'Active (Groq / Gemini / OpenRouter)'
            : 'Configure your free Groq or Gemini key in Settings',
        isCompleted: hasAiKey,
        category: 'Intelligence',
        actionLabel: 'Configure Keys',
        route: '/settings',
      ),
      SetupChecklistItem(
        id: 'mic_permission',
        title: 'Voice & Microphone',
        description: hasMic
            ? 'Microphone permission granted for voice interaction'
            : 'Grant microphone permission for conversational mode',
        isCompleted: hasMic,
        category: 'Hardware',
        actionLabel: 'Enable Mic',
        route: '/settings',
      ),
      SetupChecklistItem(
        id: 'notification_alerts',
        title: 'Notifications & Reminders',
        description: hasNotifications
            ? 'Background alarms and proactive notifications active'
            : 'Allow notification alerts for briefings and agendas',
        isCompleted: hasNotifications,
        category: 'System',
        actionLabel: 'Allow Alerts',
        route: '/settings',
      ),
      SetupChecklistItem(
        id: 'user_profile',
        title: 'Personal Context & Habits',
        description: hasProfile
            ? 'Profile configured for $profileName'
            : 'Tell AIRA your name and daily wake/sleep routine',
        isCompleted: hasProfile,
        category: 'Personalization',
        actionLabel: 'Set Profile',
        route: '/settings',
      ),
      SetupChecklistItem(
        id: 'memory_vault',
        title: 'Memory Vault Initialized',
        description: hasMemory
            ? '${facts.length} semantic facts and preferences stored'
            : 'Share your work style, projects, or food preferences',
        isCompleted: hasMemory,
        category: 'Context',
        actionLabel: 'View Vault',
        route: '/chat',
      ),
      SetupChecklistItem(
        id: 'laptop_companion',
        title: 'Laptop Companion Remote',
        description: isLaptopPaired
            ? 'Paired with laptop (${LaptopControlService().laptopIp})'
            : 'Pair with your PC or run standalone in mobile mode',
        isCompleted: isLaptopPaired,
        category: 'Ecosystem',
        actionLabel: 'Pair Laptop',
        route: '/laptop',
      ),
    ];

    final completed = items.where((i) => i.isCompleted).length;
    final percent = ((completed / items.length) * 100).round();

    return ChecklistReport(
      items: items,
      completedCount: completed,
      totalCount: items.length,
      readinessPercentage: percent,
    );
  }
}
