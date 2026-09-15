import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/features/laptop/data/laptop_control_service.dart';

/// Emergency Automation Kill-Switch & Cross-Device Pause Service (Stage M / Stage 12).
///
/// Tenet: Immediate, complete cessation of all background proactive checks,
/// scheduled habits, autonomous multi-step plans, and remote laptop operations.
class AutomationControlService {
  static final AutomationControlService _instance = AutomationControlService._internal();
  factory AutomationControlService() => _instance;
  AutomationControlService._internal();

  static const String _prefPausedKey = 'aira_automation_global_paused';
  static const String _prefReasonKey = 'aira_automation_paused_reason';
  static const String _prefTimestampKey = 'aira_automation_paused_timestamp';

  bool _isPaused = false;
  String? _pausedReason;
  DateTime? _pausedAt;

  final ValueNotifier<bool> isPausedNotifier = ValueNotifier<bool>(false);

  bool get isPaused => _isPaused;
  String? get pausedReason => _pausedReason;
  DateTime? get pausedAt => _pausedAt;

  /// Initialize state from persistent storage
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPaused = prefs.getBool(_prefPausedKey) ?? false;
      _pausedReason = prefs.getString(_prefReasonKey);
      final ts = prefs.getString(_prefTimestampKey);
      if (ts != null) {
        _pausedAt = DateTime.tryParse(ts);
      }
      isPausedNotifier.value = _isPaused;
    } catch (e) {
      debugPrint('[AUTOMATION_CTRL] Init error: $e');
    }
  }

  /// Emergency Pause: Immediately halts all background automations across phone and laptop.
  Future<void> pauseAllAutomation({String reason = 'Emergency pause triggered by user.'}) async {
    _isPaused = true;
    _pausedReason = reason;
    _pausedAt = DateTime.now();
    isPausedNotifier.value = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefPausedKey, true);
      await prefs.setString(_prefReasonKey, reason);
      await prefs.setString(_prefTimestampKey, _pausedAt!.toIso8601String());
    } catch (e) {
      debugPrint('[AUTOMATION_CTRL] Persistence error: $e');
    }

    // Signal paired laptop companion if reachable
    try {
      await LaptopControlService().pauseLaptopAutomation();
    } catch (e) {
      debugPrint('[AUTOMATION_CTRL] Failed to broadcast pause to laptop: $e');
    }

    debugPrint('[AUTOMATION_CTRL] 🛑 EMERGENCY KILL-SWITCH ACTIVATED: $reason');
  }

  /// Resume: Re-enables proactive engines, planners, and laptop automation.
  Future<void> resumeAutomation() async {
    _isPaused = false;
    _pausedReason = null;
    _pausedAt = null;
    isPausedNotifier.value = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefPausedKey, false);
      await prefs.remove(_prefReasonKey);
      await prefs.remove(_prefTimestampKey);
    } catch (e) {
      debugPrint('[AUTOMATION_CTRL] Persistence error: $e');
    }

    // Signal paired laptop companion
    try {
      await LaptopControlService().resumeLaptopAutomation();
    } catch (e) {
      debugPrint('[AUTOMATION_CTRL] Failed to broadcast resume to laptop: $e');
    }

    debugPrint('[AUTOMATION_CTRL] ▶️ Automations resumed across all connected devices.');
  }
}
