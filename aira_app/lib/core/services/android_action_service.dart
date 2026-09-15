import 'package:flutter/services.dart';
import 'package:aira_app/core/services/android_action_registry.dart';

/// Native Android Action Service for AIRA OS (Stage K).
/// Executes supported Android intents, enforces human authorization for message sending,
/// prepares calendar events, launches navigation, and coordinates guided task handoffs.
class AndroidActionService {
  static final AndroidActionService _instance = AndroidActionService._internal();
  factory AndroidActionService() => _instance;
  AndroidActionService._internal();

  static const MethodChannel _channel = MethodChannel('com.aira.os/device_control');

  // ── Message Drafting (Preparation vs. Sending Separation) ──────────────────

  /// Prepare a message draft without transmitting it.
  /// Enforces human authorization before sending.
  Map<String, dynamic> prepareMessageDraft({
    required String app,
    required String recipient,
    required String message,
    String? phone,
    String? subject,
  }) {
    return {
      'actionType': AndroidActionType.composeMessage.name,
      'app': app,
      'recipient': recipient,
      'phone': phone ?? '',
      'subject': subject ?? '',
      'body': message,
      'status': 'prepared',
      'requiresAuthorization': true,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Launch the prepared draft in the target messaging app for user review & dispatch.
  Future<Map<String, dynamic>> launchMessageDraft(Map<String, dynamic> actionData) async {
    final app = (actionData['app'] as String? ?? 'whatsapp').toLowerCase();
    final recipient = actionData['recipient'] as String? ?? '';
    final phone = actionData['phone'] as String? ?? recipient;
    final body = actionData['body'] as String? ?? '';
    final subject = actionData['subject'] as String? ?? '';

    try {
      if (app.contains('whatsapp')) {
        final res = await _channel.invokeMapMethod<String, dynamic>(
          'composeWhatsApp',
          {'phone': phone, 'text': body},
        );
        return res ?? {'success': true, 'app': 'WhatsApp'};
      } else if (app.contains('sms') || app.contains('message')) {
        final res = await _channel.invokeMapMethod<String, dynamic>(
          'composeSms',
          {'recipient': phone, 'body': body},
        );
        return res ?? {'success': true, 'app': 'SMS'};
      } else if (app.contains('email') || app.contains('gmail') || app.contains('mail')) {
        final res = await _channel.invokeMapMethod<String, dynamic>(
          'composeEmail',
          {'recipient': recipient, 'subject': subject, 'body': body},
        );
        return res ?? {'success': true, 'app': 'Email'};
      } else {
        final res = await _channel.invokeMapMethod<String, dynamic>(
          'composeWhatsApp',
          {'phone': phone, 'text': body},
        );
        return res ?? {'success': true, 'app': 'WhatsApp'};
      }
    } on PlatformException catch (e) {
      throw Exception('Could not launch message draft: ${e.message ?? e.code}');
    }
  }

  // ── Calendar Event Preparation ─────────────────────────────────────────────

  /// Prepare a calendar event draft
  Map<String, dynamic> prepareCalendarAction({
    required String title,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? description,
    bool allDay = false,
  }) {
    final start = startTime ?? DateTime.now().add(const Duration(hours: 1));
    final end = endTime ?? start.add(const Duration(hours: 1));

    return {
      'actionType': AndroidActionType.calendarEvent.name,
      'title': title,
      'startTime': start.millisecondsSinceEpoch,
      'endTime': end.millisecondsSinceEpoch,
      'beginTimeMs': start.millisecondsSinceEpoch,
      'endTimeMs': end.millisecondsSinceEpoch,
      'startTimeFormatted': _formatDateTime(start),
      'endTimeFormatted': _formatDateTime(end),
      'location': location ?? '',
      'description': description ?? 'Created via AIRA Assistant',
      'allDay': allDay,
      'status': 'prepared',
    };
  }

  /// Launch pre-populated event in the native Android Calendar app for user confirmation
  Future<Map<String, dynamic>> launchCalendarAction(Map<String, dynamic> actionData) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'createCalendarEvent',
        {
          'title': actionData['title'] ?? 'AIRA Event',
          'description': actionData['description'] ?? '',
          'location': actionData['location'] ?? '',
          'beginTimeMs': actionData['beginTimeMs'] ?? DateTime.now().millisecondsSinceEpoch,
          'endTimeMs': actionData['endTimeMs'] ?? DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
          'allDay': actionData['allDay'] ?? false,
        },
      );
      return res ?? {'success': true, 'title': actionData['title']};
    } on PlatformException catch (e) {
      throw Exception('Could not open calendar event: ${e.message ?? e.code}');
    }
  }

  // ── Navigation & Maps ──────────────────────────────────────────────────────

  /// Launch turn-by-turn navigation on Google Maps
  Future<Map<String, dynamic>> launchNavigation({
    required String destination,
    String mode = 'd',
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'navigateMaps',
        {'destination': destination, 'mode': mode},
      );
      return res ?? {'success': true, 'destination': destination};
    } on PlatformException catch (e) {
      throw Exception('Could not start navigation: ${e.message ?? e.code}');
    }
  }

  // ── Guided Task Handoffs ───────────────────────────────────────────────────

  /// Prepare a guided task handoff when internal app automation is not supported
  Map<String, dynamic> prepareAppTaskHandoff({
    required String targetApp,
    required String goal,
    String? searchQuery,
  }) {
    final steps = AndroidActionRegistry.getFinishSteps(targetApp, goal);
    return {
      'actionType': AndroidActionType.taskHandoff.name,
      'targetApp': targetApp,
      'goal': goal,
      'searchQuery': searchQuery ?? goal,
      'steps': steps,
      'status': 'ready_to_launch',
    };
  }

  /// Launch the target app with pre-filled query for task handoff
  Future<Map<String, dynamic>> executeTaskHandoffLaunch({
    required String targetApp,
    required String searchQuery,
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'searchInApp',
        {'appName': targetApp, 'searchQuery': searchQuery},
      );
      return res ?? {'success': true, 'appName': targetApp, 'searchQuery': searchQuery};
    } on PlatformException {
      // Fallback to simple launch
      final fallbackRes = await _channel.invokeMapMethod<String, dynamic>(
        'launchApp',
        {'query': targetApp},
      );
      return fallbackRes ?? {'success': true, 'appName': targetApp};
    }
  }

  // ── Security Boundary Interceptor ──────────────────────────────────────────

  /// Prepare protected security boundary halt notice
  Map<String, dynamic> prepareSecurityBoundaryNotice({
    required String requestedAction,
    String targetApp = 'banking',
  }) {
    final explanation = AndroidActionRegistry.getSafetyBoundaryExplanation(requestedAction);
    return {
      'actionType': AndroidActionType.safetyBoundaryHalted.name,
      'targetApp': targetApp,
      'requestedAction': requestedAction,
      'explanation': explanation,
      'status': 'halted_by_guardrail',
    };
  }

  /// Safely open the app without attempting automated actions
  Future<Map<String, dynamic>> launchAppSafely(String appName) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'launchApp',
        {'query': appName},
      );
      return res ?? {'success': true, 'appName': appName};
    } on PlatformException catch (e) {
      throw Exception('Could not launch $appName: ${e.message ?? e.code}');
    }
  }

  // ── Media Controls ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> controlMedia({required String action}) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'controlMedia',
        {'action': action},
      );
      return res ?? {'success': true, 'action': action};
    } on PlatformException catch (e) {
      throw Exception('Media control failed: ${e.message ?? e.code}');
    }
  }

  // ── Package Installation Check ─────────────────────────────────────────────

  Future<bool> isAppInstalled(String appNameOrPackage) async {
    try {
      final res = await _channel.invokeMethod<bool>(
        'isAppInstalled',
        {'query': appNameOrPackage},
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} at $hour:$min $period';
  }
}
