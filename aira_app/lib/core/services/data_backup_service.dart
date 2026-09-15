import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/core/services/user_profile_service.dart';
import 'package:aira_app/core/services/memory_engine.dart';
import 'package:aira_app/core/services/diagnostic_logger.dart';

/// Data Export, Backup Restoration & Privacy Data Wipe Service (Stage M / Stage 12).
///
/// Implements full portability and complete GDPR-compliant "Right to be Forgotten"
/// data deletion across local flash storage.
class DataBackupService {
  static final DataBackupService _instance = DataBackupService._internal();
  factory DataBackupService() => _instance;
  DataBackupService._internal();

  static const int schemaVersion = 1;
  static const String _tasksPrefKey = 'aira_local_tasks_v2';
  static const String _activePlanPrefKey = 'aira_active_goal_plan_v1';

  /// Export all personal data, memory vault, tasks, and notes into an envelope JSON string.
  Future<String> exportBackupJson() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Profile
    final profile = Map<String, dynamic>.from(UserProfileService().profile);

    // 2. Memory Facts & Episodes
    final memoryFacts = MemoryEngine().facts.map((f) => f.toJson()).toList();
    final memoryEpisodes = MemoryEngine().episodes.map((e) => e.toJson()).toList();

    // 3. Agenda Tasks
    List<dynamic> tasks = [];
    final tasksRaw = prefs.getString(_tasksPrefKey);
    if (tasksRaw != null && tasksRaw.isNotEmpty) {
      try {
        tasks = jsonDecode(tasksRaw) as List;
      } catch (_) {}
    }

    // 4. Saved Notes & Vault Briefings
    final Map<String, String> notes = {};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('aira_note_') || key.startsWith('aira_briefing_')) {
        notes[key] = prefs.getString(key) ?? '';
      }
    }

    final envelope = {
      'aira_backup_version': schemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'platform': 'android_windows_cross_platform',
      'data': {
        'profile': profile,
        'memory_facts': memoryFacts,
        'memory_episodes': memoryEpisodes,
        'tasks': tasks,
        'notes': notes,
      }
    };

    DiagnosticLogger().info('BACKUP', 'Exported data backup: ${memoryFacts.length} facts, ${tasks.length} tasks, ${notes.length} notes.');
    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  /// Restore user state, memories, profile, and tasks from a valid backup JSON.
  Future<Map<String, dynamic>> restoreBackupJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final version = decoded['aira_backup_version'] as int?;
      if (version == null || version > schemaVersion) {
        return {'success': false, 'error': 'Unsupported backup schema version ($version).'};
      }

      final data = decoded['data'] as Map<String, dynamic>?;
      if (data == null) {
        return {'success': false, 'error': 'Invalid backup structure: missing data block.'};
      }

      final prefs = await SharedPreferences.getInstance();

      // 1. Restore Profile
      if (data['profile'] is Map) {
        final profileMap = Map<String, dynamic>.from(data['profile'] as Map);
        await UserProfileService().updateProfile(profileMap);
      }

      // 2. Restore Memory Facts
      int factsCount = 0;
      if (data['memory_facts'] is List) {
        final factsList = (data['memory_facts'] as List)
            .map((f) => MemoryFact.fromJson(Map<String, dynamic>.from(f as Map)))
            .toList();
        await MemoryEngine().restoreFacts(factsList);
        factsCount = factsList.length;
      }

      // 3. Restore Tasks
      int tasksCount = 0;
      if (data['tasks'] is List) {
        await prefs.setString(_tasksPrefKey, jsonEncode(data['tasks']));
        tasksCount = (data['tasks'] as List).length;
      }

      // 4. Restore Notes
      int notesCount = 0;
      if (data['notes'] is Map) {
        final notesMap = Map<String, dynamic>.from(data['notes'] as Map);
        for (final entry in notesMap.entries) {
          await prefs.setString(entry.key, entry.value.toString());
          notesCount++;
        }
      }

      DiagnosticLogger().info('BACKUP', 'Restored backup successfully ($factsCount facts, $tasksCount tasks, $notesCount notes).');

      return {
        'success': true,
        'message': 'Restored $factsCount memories, $tasksCount tasks, and $notesCount notes.',
        'factsCount': factsCount,
        'tasksCount': tasksCount,
        'notesCount': notesCount,
      };
    } catch (e) {
      DiagnosticLogger().error('BACKUP', 'Backup restore failed', e);
      return {'success': false, 'error': 'Failed to parse or restore backup: $e'};
    }
  }

  /// Irreversibly delete all personal memories, tasks, profiles, active plans, and cached credentials.
  Future<bool> deleteAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Clear Memory Vault
      await MemoryEngine().clearAll();

      // 2. Reset Profile to default
      await UserProfileService().clearProfile();

      // 3. Wipe Tasks & Active Plans
      await prefs.remove(_tasksPrefKey);
      await prefs.remove(_activePlanPrefKey);

      // 4. Wipe Notes & Briefings
      final keysToRemove = prefs.getKeys().where((k) =>
          k.startsWith('aira_note_') ||
          k.startsWith('aira_briefing_') ||
          k.startsWith('aira_custom_') ||
          k.startsWith('aira_device_') ||
          k.startsWith('aira_laptop_') ||
          k.startsWith('aira_action_receipts') ||
          k.startsWith('aira_proactive_')
      ).toList();

      for (final k in keysToRemove) {
        await prefs.remove(k);
      }

      DiagnosticLogger().warn('DATA_WIPE', 'Full data wipe completed. Restored factory state.');
      return true;
    } catch (e) {
      DiagnosticLogger().error('DATA_WIPE', 'Failed during data wipe', e);
      return false;
    }
  }
}
