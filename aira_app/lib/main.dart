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
import 'package:aira_app/app.dart';

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

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  // Initialize Hive for local chat storage
  await Hive.initFlutter();

  // Initialize offline chat cache (was missing — caused silent cache failures)
  await ChatCacheService.init();

  // Initialize AIRA Brain: Personality, Profile, Memory, and Cognitive Graph
  await PersonalityEngine().load();
  await UserProfileService().load();
  await MemoryEngine().load();
  await CognitiveMemoryEngine().init();

  // Initialize Notification Service for local alerts
  await NotificationService().initialize();

  // Initialize Proactive Intelligence Engine (auto-reminders, nudges)
  final proactive = ProactiveEngine();
  await proactive.load();
  proactive.start();

  // Initialize Wake Word Service (Hey AIRA hands-free)
  await WakeWordService().load();

  runApp(
    const ProviderScope(
      child: AiraApp(),
    ),
  );
}

