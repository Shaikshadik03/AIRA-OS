import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aira_app/config/app_config.dart';
import 'package:aira_app/core/services/notification_service.dart';
import 'package:aira_app/core/services/chat_cache_service.dart';
import 'package:aira_app/core/services/personality_engine.dart';
import 'package:aira_app/core/services/user_profile_service.dart';
import 'package:aira_app/core/services/memory_engine.dart';
import 'package:aira_app/core/services/cognitive_memory_engine.dart';
import 'package:aira_app/core/services/proactive_engine.dart';
import 'package:aira_app/core/services/wake_word_service.dart';
import 'package:aira_app/core/services/notification_monitor_service.dart';
import 'package:aira_app/core/services/social_world_monitor_service.dart';
import 'package:aira_app/core/services/smart_reply_service.dart';
import 'package:aira_app/core/services/automation_control_service.dart';
import 'package:aira_app/core/services/usage_metrics_service.dart';
import 'package:aira_app/app.dart';
import 'package:aira_app/routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // System UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0E1A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Supabase (with fallback if credentials not provided)
  if (AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );
      debugPrint('[SUPABASE] Initialized successfully');
    } catch (e) {
      debugPrint('[SUPABASE] Initialization failed ($e). Operating in offline/local cache mode.');
    }
  } else {
    debugPrint('[SUPABASE] Not configured. Operating in offline/local cache mode.');
  }

  // Initialize Hive for local chat storage
  await Hive.initFlutter();

  // Initialize offline chat cache
  await ChatCacheService.init();

  // Initialize Notification Service for local alerts
  await NotificationService().initialize();

  // Navigate to planner when a task/reminder notification is tapped
  NotificationService.onNotificationTapped = (payload) {
    try {
      appRouter.go('/planner');
    } catch (_) {}
  };

  // Parallel fast-load of essential AIRA Brain state
  await Future.wait([
    PersonalityEngine().load(),
    UserProfileService().load(),
    MemoryEngine().load(),
    CognitiveMemoryEngine().init(),
  ]);

  runApp(
    const ProviderScope(
      child: AiraApp(),
    ),
  );

  // Defer background monitors & secondary services (non-blocking post-launch)
  Future.microtask(() async {
    try {
      final proactive = ProactiveEngine();
      await proactive.load();
      proactive.start();
    } catch (_) {}

    try {
      await WakeWordService().load();
    } catch (_) {}

    try {
      await Future.wait([
        NotificationMonitorService().init(),
        SocialWorldMonitorService().init(),
        SmartReplyService().init(),
        AutomationControlService().init(),
        UsageMetricsService().init(),
      ]);
    } catch (_) {}
  });
}

