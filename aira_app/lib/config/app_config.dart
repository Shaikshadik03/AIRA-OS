/// AIRA OS Application Configuration
///
/// Replace the placeholder values below with your actual Supabase keys.
/// Get them from: Supabase Dashboard → Project Settings → API
class AppConfig {
  AppConfig._();

  // App Info
  static const String appName = 'AIRA OS';
  static const String appVersion = '1.0.0';

  // ============================================
  // 🔑 PASTE YOUR SUPABASE KEYS BELOW
  // ============================================

  /// Your Supabase Project URL
  /// Looks like: https://abcdefghij.supabase.co
  static const String supabaseUrl = 'https://oeaorhoftuivzvuupyqm.supabase.co';

  /// Your Supabase Anon (Public) Key
  /// Looks like: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lYW9yaG9mdHVpdnp2dXVweXFtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM4Njg3NjgsImV4cCI6MjA5OTQ0NDc2OH0.BM3uNMB9um3LelTPaT_jBHsAkmsYeTezX5zoirkfTOE';

  // ============================================
  // Backend API URL (change when deployed)
  // ============================================

  /// Backend server URL (use localhost for development)
  static const String backendUrl = 'http://10.0.2.2:8000/api/v1';
  // Note: 10.0.2.2 is how Android emulator accesses host machine's localhost
  // For physical device: use your computer's IP address (e.g., 192.168.x.x:8000/api/v1)
}
