import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'llm_service.dart';

class InterceptedNotification {
  final int id;
  final String packageName;
  final String appName;
  final String title;
  final String text;
  final String subText;
  final int timestamp;
  final String category;

  InterceptedNotification({
    required this.id,
    required this.packageName,
    required this.appName,
    required this.title,
    required this.text,
    required this.subText,
    required this.timestamp,
    required this.category,
  });

  factory InterceptedNotification.fromMap(Map<dynamic, dynamic> map) {
    return InterceptedNotification(
      id: map['id'] is int ? map['id'] : int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      packageName: map['packageName']?.toString() ?? '',
      appName: map['appName']?.toString() ?? 'App',
      title: map['title']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      subText: map['subText']?.toString() ?? '',
      timestamp: map['timestamp'] is int
          ? map['timestamp']
          : int.tryParse(map['timestamp']?.toString() ?? '0') ?? DateTime.now().millisecondsSinceEpoch,
      category: map['category']?.toString() ?? 'general',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'packageName': packageName,
      'appName': appName,
      'title': title,
      'text': text,
      'subText': subText,
      'timestamp': timestamp,
      'category': category,
    };
  }
}

class NotificationMonitorService {
  static final NotificationMonitorService _instance = NotificationMonitorService._internal();
  factory NotificationMonitorService() => _instance;
  NotificationMonitorService._internal();

  static const MethodChannel _channel = MethodChannel('com.aira.os/device_control');
  static const EventChannel _eventChannel = EventChannel('com.aira.os/notification_events');

  final List<InterceptedNotification> _notifications = [];
  StreamSubscription? _subscription;
  String _cachedDigest = '';
  DateTime? _lastDigestTime;
  bool _isListening = false;

  List<InterceptedNotification> get notifications => List.unmodifiable(_notifications);
  String get cachedDigest => _cachedDigest;
  DateTime? get lastDigestTime => _lastDigestTime;
  bool get isListening => _isListening;

  Future<void> init() async {
    await _loadPersistedNotifications();
    await checkAndStartListening();
  }

  Future<bool> isPermissionGranted() async {
    if (!Platform.isAndroid) return false;
    try {
      final isEnabled = await _channel.invokeMethod<bool>('isNotificationListenerEnabled');
      return isEnabled ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openPermissionSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openNotificationListenerSettings');
    } catch (_) {}
  }

  Future<void> checkAndStartListening() async {
    if (!Platform.isAndroid) return;
    final granted = await isPermissionGranted();
    if (!granted) return;

    if (_isListening) return;
    _isListening = true;

    // Fetch any notifications already captured on native side
    try {
      final List<dynamic>? nativeList = await _channel.invokeMethod<List<dynamic>>('getRecentNotifications');
      if (nativeList != null) {
        for (final item in nativeList) {
          if (item is Map) {
            _addNotification(InterceptedNotification.fromMap(item), save: false);
          }
        }
      }
    } catch (_) {}

    // Stream real-time notifications
    try {
      _subscription?.cancel();
      _subscription = _eventChannel.receiveBroadcastStream().listen((dynamic event) {
        if (event is Map) {
          _addNotification(InterceptedNotification.fromMap(event), save: true);
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  void _addNotification(InterceptedNotification notif, {bool save = true}) {
    // Deduplicate
    final exists = _notifications.any((n) =>
        n.packageName == notif.packageName &&
        n.title == notif.title &&
        n.text == notif.text &&
        (notif.timestamp - n.timestamp).abs() < 3000);
    if (!exists) {
      _notifications.insert(0, notif);
      if (_notifications.length > 100) {
        _notifications.removeLast();
      }
      if (save) {
        _persistNotifications();
      }
    }
  }

  Future<void> _persistNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = jsonEncode(_notifications.map((n) => n.toMap()).toList());
      await prefs.setString('aira_saved_notifications_v1', listJson);
    } catch (_) {}
  }

  Future<void> _loadPersistedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getString('aira_saved_notifications_v1');
      if (listJson != null && listJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(listJson);
        _notifications.clear();
        for (final item in decoded) {
          if (item is Map) {
            _notifications.add(InterceptedNotification.fromMap(item));
          }
        }
      }
      _cachedDigest = prefs.getString('aira_cached_notification_digest_v1') ?? '';
      final timeStr = prefs.getString('aira_cached_notification_digest_time_v1');
      if (timeStr != null) {
        _lastDigestTime = DateTime.tryParse(timeStr);
      }
    } catch (_) {}
  }

  Future<void> clearAll() async {
    _notifications.clear();
    _cachedDigest = '';
    _lastDigestTime = null;
    try {
      await _channel.invokeMethod('clearRecentNotifications');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('aira_saved_notifications_v1');
      await prefs.remove('aira_cached_notification_digest_v1');
      await prefs.remove('aira_cached_notification_digest_time_v1');
    } catch (_) {}
  }

  /// Generate AI-powered executive digest of captured notifications
  Future<String> generateSmartDigest({String? categoryFilter}) async {
    var notifsToAnalyze = _notifications;
    if (categoryFilter != null && categoryFilter.isNotEmpty && categoryFilter != 'all') {
      notifsToAnalyze = _notifications.where((n) => n.category == categoryFilter).toList();
    }

    if (notifsToAnalyze.isEmpty) {
      final defaultMsg = "No new notifications intercepted yet. Make sure Notification Access is granted in settings!";
      _cachedDigest = defaultMsg;
      return defaultMsg;
    }

    // Format top 25 recent notifications for LLM
    final buffer = StringBuffer();
    for (final n in notifsToAnalyze.take(25)) {
      final time = DateTime.fromMillisecondsSinceEpoch(n.timestamp);
      final timeStr = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
      buffer.writeln("• [${n.appName}] ($timeStr) ${n.title}: ${n.text}");
    }

    final prompt = """
You are AIRA Notification Intelligence.
Analyze these recent incoming phone notifications from the user's Android device:

$buffer

TASK:
1. Provide a crisp, high-value executive summary of what happened.
2. Group key points into:
   - 🔴 Urgent / Direct Messages (WhatsApp, Telegram, SMS, DMs)
   - 💼 Work / Emails / Updates (Gmail, LinkedIn, Slack)
   - 💳 Financial / Security / Orders (Bank, Swiggy, Zomato, Amazon, OTPs)
3. If an item is trivial or marketing spam, concisely group or ignore it.
4. Keep the summary punchy, clean, and directly actionable (max 4-6 bullet points).
""";

    try {
      final summary = await LlmService().chat(
        userMessage: prompt,
        systemPromptOverride: "You are AIRA OS Notification Intelligence. Synthesize phone notifications into a smart, structured executive briefing.",
      );

      _cachedDigest = summary.trim();
      _lastDigestTime = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('aira_cached_notification_digest_v1', _cachedDigest);
      await prefs.setString('aira_cached_notification_digest_time_v1', _lastDigestTime!.toIso8601String());

      return _cachedDigest;
    } catch (e) {
      // Fallback rule-based summary
      final apps = notifsToAnalyze.map((n) => n.appName).toSet().join(', ');
      final fallback = "You have ${notifsToAnalyze.length} recent notifications across $apps. Most recent from ${notifsToAnalyze.first.appName}: \"${notifsToAnalyze.first.title} - ${notifsToAnalyze.first.text}\"";
      _cachedDigest = fallback;
      return fallback;
    }
  }

  /// Get quick summary stats
  Map<String, int> getCategoryCounts() {
    final counts = <String, int>{
      'all': _notifications.length,
      'messaging': 0,
      'social': 0,
      'email_work': 0,
      'finance': 0,
      'delivery_transport': 0,
      'general': 0,
    };
    for (final n in _notifications) {
      counts[n.category] = (counts[n.category] ?? 0) + 1;
    }
    return counts;
  }
}
