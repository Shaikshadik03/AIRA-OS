/// AIRA OS Application Configuration
/// 
/// API keys are loaded from build-time environment variables (--dart-define).
/// For local development, use the build script or pass them manually.
/// NEVER hardcode keys here — they get caught by GitHub secret scanning.
class AppConfig {
  AppConfig._();

  // App Info
  static const String appName = 'AIRA OS';
  static const String appVersion = '2.0.0';

  // ============================================
  // 🔑 SUPABASE
  // ============================================
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oeaorhoftuivzvuupyqm.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    // Key is loaded via --dart-define at build time. See README for how to build.
    defaultValue: '',
  );

  // ============================================
  // 🤖 GROQ AI
  // ============================================
  static const String groqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    // Key is loaded via --dart-define at build time. See README for how to build.
    defaultValue: '',
  );
  static const String groqModel = 'llama-3.3-70b-versatile';
  static const String groqBaseUrl = 'https://api.groq.com/openai/v1';

  // ============================================
  // Backend API URL (for other services)
  // ============================================
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
}
