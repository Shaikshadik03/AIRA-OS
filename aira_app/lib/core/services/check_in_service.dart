import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:aira_app/features/chat/domain/check_in_item.dart';
import 'package:aira_app/core/services/notification_service.dart';
import 'package:aira_app/features/planner/presentation/providers/planner_provider.dart';

/// Service managing persistent proactive check-ins and follow-ups.
class CheckInService {
  static final CheckInService _instance = CheckInService._internal();
  factory CheckInService() => _instance;
  CheckInService._internal();

  static const String _storageKey = 'aira_checkins_v1';
  final _uuid = const Uuid();
  final _notifications = NotificationService();

  Future<List<CheckInItem>> getAllCheckIns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return [];
      final List list = jsonDecode(raw);
      return list
          .map((e) => CheckInItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('[CHECKIN] Failed to load check-ins: $e');
      return [];
    }
  }

  Future<void> _saveAll(List<CheckInItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(items.map((e) => e.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (e) {
      debugPrint('[CHECKIN] Failed to save check-ins: $e');
    }
  }

  /// Create a new check-in or follow-up
  Future<CheckInItem> createCheckIn({
    required String title,
    required String reason,
    required DateTime targetTime,
    CheckInCategory category = CheckInCategory.agreedCheckin,
    String? relatedTaskId,
    String? relatedProject,
    String? customPrompt,
  }) async {
    final item = CheckInItem(
      id: _uuid.v4(),
      title: title.trim(),
      reason: reason.trim(),
      category: category,
      targetTime: targetTime,
      status: CheckInStatus.pending,
      relatedTaskId: relatedTaskId,
      relatedProject: relatedProject,
      createdAt: DateTime.now(),
      customPrompt: customPrompt,
    );

    final all = await getAllCheckIns();
    all.add(item);
    await _saveAll(all);

    // Schedule notification if in the future
    if (targetTime.isAfter(DateTime.now())) {
      final notifId = item.id.hashCode.abs() % 100000;
      await _notifications.scheduleNotification(
        id: notifId,
        title: 'AIRA Check-In: ${item.title}',
        body: customPrompt ?? reason,
        scheduledDate: targetTime,
      );
    }

    debugPrint('[CHECKIN] Created: ${item.title} for ${item.targetTime}');
    return item;
  }

  /// Get active check-ins (pending or snoozed)
  Future<List<CheckInItem>> getActiveCheckIns() async {
    final all = await getAllCheckIns();
    return all
        .where((c) =>
            c.status == CheckInStatus.pending ||
            c.status == CheckInStatus.snoozed)
        .toList();
  }

  /// Get check-ins that are due now
  Future<List<CheckInItem>> getDueCheckIns() async {
    final all = await getAllCheckIns();
    return all.where((c) => c.isDue).toList();
  }

  /// Mark check-in as delivered
  Future<void> markDelivered(String id) async {
    final all = await getAllCheckIns();
    final updated = all.map((c) {
      if (c.id == id) {
        return c.copyWith(
          status: CheckInStatus.delivered,
          deliveredAt: DateTime.now(),
        );
      }
      return c;
    }).toList();
    await _saveAll(updated);
  }

  /// Mark check-in as completed (and complete any related task)
  Future<CheckInItem?> markCompleted(String id) async {
    final all = await getAllCheckIns();
    CheckInItem? completedItem;

    final updated = all.map((c) {
      if (c.id == id) {
        completedItem = c.copyWith(status: CheckInStatus.completed);
        return completedItem!;
      }
      return c;
    }).toList();

    await _saveAll(updated);

    if (completedItem?.relatedTaskId != null) {
      try {
        await PlannerNotifier.active.toggleTask(completedItem!.relatedTaskId!, true);
      } catch (_) {}
    }

    // Cancel scheduled notification if any
    final notifId = id.hashCode.abs() % 100000;
    await _notifications.cancelNotification(notifId);

    return completedItem;
  }

  /// Snooze check-in by duration
  Future<CheckInItem?> snooze(String id, Duration duration) async {
    final all = await getAllCheckIns();
    final snoozeTime = DateTime.now().add(duration);
    CheckInItem? snoozedItem;

    final updated = all.map((c) {
      if (c.id == id) {
        snoozedItem = c.copyWith(
          status: CheckInStatus.snoozed,
          snoozeUntil: snoozeTime,
        );
        return snoozedItem!;
      }
      return c;
    }).toList();

    await _saveAll(updated);

    // Reschedule notification
    final notifId = id.hashCode.abs() % 100000;
    await _notifications.scheduleNotification(
      id: notifId,
      title: 'AIRA Check-In: ${snoozedItem?.title ?? "Follow-up"}',
      body: snoozedItem?.reason ?? 'Checking in as requested.',
      scheduledDate: snoozeTime,
    );

    return snoozedItem;
  }

  /// Cancel check-in permanently
  Future<CheckInItem?> cancel(String id) async {
    final all = await getAllCheckIns();
    CheckInItem? cancelledItem;

    final updated = all.map((c) {
      if (c.id == id) {
        cancelledItem = c.copyWith(status: CheckInStatus.cancelled);
        return cancelledItem!;
      }
      return c;
    }).toList();

    await _saveAll(updated);

    final notifId = id.hashCode.abs() % 100000;
    await _notifications.cancelNotification(notifId);

    return cancelledItem;
  }

  /// Get the most recently delivered check-in (delivered within last 3 hours and not yet completed/cancelled)
  Future<CheckInItem?> getLastDeliveredCheckIn() async {
    final all = await getAllCheckIns();
    final now = DateTime.now();

    final delivered = all.where((c) {
      if (c.status == CheckInStatus.completed ||
          c.status == CheckInStatus.cancelled) {
        return false;
      }
      if (c.deliveredAt == null) return false;
      return now.difference(c.deliveredAt!).inHours < 3;
    }).toList();

    if (delivered.isEmpty) return null;

    delivered.sort((a, b) => b.deliveredAt!.compareTo(a.deliveredAt!));
    return delivered.first;
  }
}
