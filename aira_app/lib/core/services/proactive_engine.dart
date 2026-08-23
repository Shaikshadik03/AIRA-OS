import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:aira_app/core/services/notification_service.dart';
import 'package:aira_app/core/services/user_profile_service.dart';
import 'package:aira_app/core/services/personality_engine.dart';

/// AIRA Proactive Intelligence Engine
///
/// Background rule engine that evaluates context and triggers proactive
/// notifications — making AIRA reach out to YOU first, like a friend.
///
/// Uses a 3-Tier Context Funnel:
/// Tier 1: Scheduled Alarms (0% battery) — fires at pre-computed times
/// Tier 2: Fast Local Rule Check (<5ms) — if threshold met
/// Tier 3: LLM generates 1-sentence natural alert — dispatched as notification
class ProactiveEngine {
  static final ProactiveEngine _instance = ProactiveEngine._internal();
  factory ProactiveEngine() => _instance;
  ProactiveEngine._internal();

  static const String _enabledKey = 'aira_proactive_enabled';
  static const String _lastCheckKey = 'aira_proactive_last_check';
  static const String _sentNotificationsKey = 'aira_proactive_sent';

  bool _isEnabled = true;
  Timer? _periodicCheck;
  final _notifications = NotificationService();
  final _profile = UserProfileService();
  final _personality = PersonalityEngine();

  bool get isEnabled => _isEnabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);

    if (enabled) {
      start();
    } else {
      stop();
    }
  }

  /// Start the proactive engine (periodic checks every 15 minutes)
  void start() {
    if (!_isEnabled) return;
    stop(); // Cancel any existing timer

    // Run immediate check
    _runProactiveCheck();

    // Schedule periodic checks every 15 minutes
    _periodicCheck = Timer.periodic(const Duration(minutes: 15), (_) {
      _runProactiveCheck();
    });

    debugPrint('[PROACTIVE] Engine started — checking every 15 minutes');
  }

  /// Stop the proactive engine
  void stop() {
    _periodicCheck?.cancel();
    _periodicCheck = null;
    debugPrint('[PROACTIVE] Engine stopped');
  }

  /// Main check loop — evaluates all proactive rules
  Future<void> _runProactiveCheck() async {
    if (!_isEnabled) return;

    final now = DateTime.now();
    final hour = now.hour;
    final name = _profile.displayName;

    // Don't send proactive notifications during sleep hours (midnight to 6 AM)
    if (hour < 6) return;

    // Check cooldown — don't spam notifications
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString(_lastCheckKey);
    if (lastCheck != null) {
      final lastTime = DateTime.tryParse(lastCheck);
      if (lastTime != null && now.difference(lastTime).inMinutes < 14) return;
    }
    await prefs.setString(_lastCheckKey, now.toIso8601String());

    // Track which notifications have been sent today
    final sentToday = await _getSentToday();

    // ── Rule 1: Morning Wake-Up Nudge ──
    if (hour >= 6 && hour <= 9 && !sentToday.contains('morning_nudge')) {
      final greeting = _personality.getTimeGreeting(name);
      final pendingCount = await _getPendingTaskCount();
      final taskText = pendingCount > 0
          ? 'You have $pendingCount tasks scheduled for today. Ready to get started?'
          : 'Your agenda is clean today. What are we working on?';

      await _sendProactiveNotification(
        id: 'morning_nudge',
        title: 'Morning Briefing',
        body: '$greeting $taskText',
      );
    }

    // ── Rule 2: Task Deadline Approaching ──
    try {
      await _checkTaskDeadlines(sentToday, name);
    } catch (e) {
      debugPrint('[PROACTIVE] Task deadline check failed: $e');
    }

    // ── Rule 3: Evening Wind-Down ──
    final sleepTime = _profile.getField('sleep_time') ?? '11:00 PM';
    if (_isNearSleepTime(hour, sleepTime) && !sentToday.contains('evening_winddown')) {
      final pendingCount = await _getPendingTaskCount();
      final summary = pendingCount > 0
          ? 'You still have $pendingCount pending tasks. Want me to move them to tomorrow so you can recharge?'
          : 'You crushed all your goals today! Time to relax and recharge.';

      await _sendProactiveNotification(
        id: 'evening_winddown',
        title: 'Daily Wrap-Up',
        body: 'Almost bedtime, $name. $summary',
      );
    }

    // ── Rule 4: Habit Streak Reminder ──
    if (hour >= 18 && hour <= 21 && !sentToday.contains('habit_reminder')) {
      final hasUncheckedHabits = await _checkUncheckedHabits();
      if (hasUncheckedHabits) {
        await _sendProactiveNotification(
          id: 'habit_reminder',
          title: 'Habit Tracker',
          body: 'Hey $name, you haven\'t checked off all your daily habits yet. Keep your streak alive!',
        );
      }
    }

    // ── Rule 5: Idle Check-In (4+ hours no interaction during day) ──
    if (hour >= 10 && hour <= 20 && !sentToday.contains('idle_checkin')) {
      final lastInteraction = prefs.getString('aira_last_interaction_time');
      if (lastInteraction != null) {
        final lastTime = DateTime.tryParse(lastInteraction);
        if (lastTime != null && now.difference(lastTime).inHours >= 4) {
          final pendingCount = await _getPendingTaskCount();
          final msg = pendingCount > 0
              ? 'Checking in on you! Still working on your $pendingCount tasks, or taking a well-deserved break?'
              : 'Everything good, $name? Haven\'t heard from you in a while. I\'m right here if you need anything.';
          await _sendProactiveNotification(
            id: 'idle_checkin',
            title: 'Hey $name',
            body: msg,
          );
        }
      }
    }
  }

  /// Get count of pending tasks
  Future<int> _getPendingTaskCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getString('aira_local_tasks_v2');
      if (tasksJson == null) return 0;
      final List list = jsonDecode(tasksJson);
      return list.where((t) => t['isCompleted'] != true && t['status'] != 'completed').length;
    } catch (_) {
      return 0;
    }
  }

  /// Check task deadlines
  Future<void> _checkTaskDeadlines(Set<String> sentToday, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getString('aira_local_tasks_v2');
    if (tasksJson == null) return;

    final List tasks = jsonDecode(tasksJson);
    final now = DateTime.now();

    for (final task in tasks) {
      if (task['isCompleted'] == true) continue;

      final dueDate = task['dueDate'];
      if (dueDate == null) continue;

      final due = DateTime.tryParse(dueDate);
      if (due == null) continue;

      final diff = due.difference(now);
      final taskId = 'task_deadline_${task['id']}';

      // 30 minutes before deadline
      if (diff.inMinutes > 0 && diff.inMinutes <= 30 && !sentToday.contains(taskId)) {
        await _sendProactiveNotification(
          id: taskId,
          title: 'Deadline Approaching',
          body: '"${task['title']}" is due in ${diff.inMinutes} minutes. Almost done?',
        );
      }
    }
  }

  /// Check if user's sleep time is near
  bool _isNearSleepTime(int currentHour, String sleepTimeStr) {
    try {
      final clean = sleepTimeStr.toLowerCase().replaceAll(' ', '');
      final isPM = clean.contains('pm');
      final hourMatch = RegExp(r'(\d+)').firstMatch(clean);
      if (hourMatch == null) return currentHour == 22;

      var hour = int.parse(hourMatch.group(1)!);
      if (isPM && hour < 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;

      return (currentHour == hour - 1 && currentHour >= 18) ||
             (currentHour == hour && currentHour >= 18);
    } catch (_) {
      return currentHour == 22;
    }
  }

  /// Check if any habits are unchecked today
  Future<bool> _checkUncheckedHabits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final habitsJson = prefs.getString('aira_local_habits_v2');
      if (habitsJson == null) return false;
      final List list = jsonDecode(habitsJson);
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      for (final h in list) {
        final completedDays = h['completedDays'] as List? ?? [];
        if (!completedDays.contains(todayStr)) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Real-time in-chat message callback (wired to active ChatNotifier)
  static Function(String title, String body)? onProactiveChatMessage;
  static const String _pendingChatMessagesKey = 'aira_pending_proactive_chat_messages';

  /// Send a proactive notification, record it, and inject as real in-chat message
  Future<void> _sendProactiveNotification({
    required String id,
    required String title,
    required String body,
  }) async {
    // 1. Send Android system push notification
    await _notifications.showNotification(
      id: id.hashCode.abs() % 100000,
      title: 'AIRA · $title',
      body: body,
    );

    // 2. Dispatch to live chat if open
    onProactiveChatMessage?.call(title, body);

    // 3. Queue in SharedPreferences for chat screen to display when opened
    final prefs = await SharedPreferences.getInstance();
    final pendingRaw = prefs.getStringList(_pendingChatMessagesKey) ?? [];
    pendingRaw.add(jsonEncode({
      'title': title,
      'body': body,
      'time': DateTime.now().toIso8601String(),
    }));
    await prefs.setStringList(_pendingChatMessagesKey, pendingRaw);

    // 4. Record that this notification was sent today
    final sentKey = '${_sentNotificationsKey}_${DateTime.now().toIso8601String().substring(0, 10)}';
    final existing = prefs.getStringList(sentKey) ?? [];
    existing.add(id);
    await prefs.setStringList(sentKey, existing);

    debugPrint('[PROACTIVE] ✅ Sent & Queued in Chat: $title — $body');
  }

  /// Pop all pending proactive messages to insert into chat
  static Future<List<Map<String, String>>> popPendingChatMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_pendingChatMessagesKey) ?? [];
    if (rawList.isEmpty) return [];

    await prefs.remove(_pendingChatMessagesKey);
    final results = <Map<String, String>>[];
    for (final str in rawList) {
      try {
        final map = jsonDecode(str) as Map<String, dynamic>;
        results.add({
          'title': map['title']?.toString() ?? '',
          'body': map['body']?.toString() ?? '',
        });
      } catch (_) {}
    }
    return results;
  }

  /// Get set of notification IDs sent today
  Future<Set<String>> _getSentToday() async {
    final prefs = await SharedPreferences.getInstance();
    final sentKey = '${_sentNotificationsKey}_${DateTime.now().toIso8601String().substring(0, 10)}';
    return (prefs.getStringList(sentKey) ?? []).toSet();
  }

  /// Record user interaction time (called from chat provider)
  static Future<void> recordInteraction() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aira_last_interaction_time', DateTime.now().toIso8601String());
  }
}

