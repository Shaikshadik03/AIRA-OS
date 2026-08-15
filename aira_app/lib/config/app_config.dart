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
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lYW9yaG9mdHVpdnp2dXVweXFtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM4Njg3NjgsImV4cCI6MjA5OTQ0NDc2OH0.BM3uNMB9um3LelTPaT_jBHsAkmsYeTezX5zoirkfTOE',
  );

  // ============================================
  // 🤖 GROQ AI (Primary LLM)
  // ============================================
  static const String groqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );
  static const String groqModel = 'llama-3.3-70b-versatile';
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
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
}
