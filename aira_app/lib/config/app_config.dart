/// AIRA OS Application Configuration
class AppConfig {
  AppConfig._();

  // App Info
  static const String appName = 'AIRA OS';
  static const String appVersion = '2.0.0';

  // ============================================
  // 🔑 SUPABASE
  // ============================================
  static const String supabaseUrl = 'https://oeaorhoftuivzvuupyqm.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lYW9yaG9mdHVpdnp2dXVweXFtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM4Njg3NjgsImV4cCI6MjA5OTQ0NDc2OH0.BM3uNMB9um3LelTPaT_jBHsAkmsYeTezX5zoirkfTOE';

  // ============================================
  // 🤖 GROQ AI (Direct from app — no backend needed)
  // ============================================
  static const String groqApiKey =
      'GROQ_API_KEY_USE_DART_DEFINE';
  static const String groqModel = 'llama-3.3-70b-versatile';
  static const String groqBaseUrl = 'https://api.groq.com/openai/v1';

  // ============================================
  // Backend API URL (for other services)
  // ============================================
  static const String backendUrl = 'http://10.0.2.2:8000/api/v1';
}
