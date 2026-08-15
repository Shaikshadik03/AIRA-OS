import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles fetching daily briefings (Morning 7 AM & Night 10 PM) from Supabase.
class SupabaseBriefingService {
  static final SupabaseBriefingService _instance = SupabaseBriefingService._internal();
  factory SupabaseBriefingService() => _instance;
  SupabaseBriefingService._internal();

  final _db = Supabase.instance.client;

  /// Fetches the latest morning and night briefings.
  Future<Map<String, Map<String, dynamic>?>> getLatestBriefings() async {
    final Map<String, Map<String, dynamic>?> result = {
      'morning': null,
      'night': null,
    };

    try {
      for (final mode in ['morning', 'night']) {
        final response = await _db
            .from('briefings')
            .select('mode, content, created_at')
            .eq('mode', mode)
            .order('created_at', ascending: false)
            .limit(1);

        if (response.isNotEmpty) {
          result[mode] = Map<String, dynamic>.from(response.first);
        }
      }
    } catch (e) {
      // Graceful fallback
    }

    return result;
  }
}
