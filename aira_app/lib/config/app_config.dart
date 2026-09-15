import 'package:supabase_flutter/supabase_flutter.dart';

/// AIRA OS Application Configuration
///
/// API keys are loaded from build-time environment variables (--dart-define)
/// with runtime fallbacks.
class AppConfig {
  AppConfig._();

  // App Info
  static const String appName = 'AIRA OS';
  static const String appVersion = '4.0.0';

  // ============================================
  // 🔑 SUPABASE
  // ============================================
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Safe accessor for the SupabaseClient instance. Returns null if not initialized.
  static SupabaseClient? get supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ============================================
  // 🤖 GROQ AI (Primary LLM)
  // ============================================
  static String get groqApiKey => const String.fromEnvironment('GROQ_API_KEY');

  static const String groqModel = 'llama-3.3-70b-versatile';
  static const String groqFallbackModel = 'llama-3.1-8b-instant';
  static const String groqBaseUrl = 'https://api.groq.com/openai/v1';

  // ============================================
  // 🤖 GEMINI AI (Fallback 1)
  // ============================================
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static const String geminiModel = 'gemini-2.0-flash';
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  // ============================================
  // 🤖 OPENROUTER AI (Fallback 2)
  // ============================================
  static const String openRouterApiKey = String.fromEnvironment(
    'OPENROUTER_API_KEY',
    defaultValue: '',
  );
  static const String openRouterModel = 'meta-llama/llama-3.3-70b-instruct';
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';

  // ============================================
  // Backend API URL
  // ============================================
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://aira-backend.onrender.com/api/v1',
  );
}
