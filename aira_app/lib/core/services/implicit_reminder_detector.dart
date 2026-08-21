import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:aira_app/core/services/notification_service.dart';

/// AIRA Implicit Reminder Detector
///
/// Listens to every conversation for implicit time commitments the user
/// mentions naturally — and silently schedules gentle follow-up nudges.
///
/// No explicit "remind me" needed. AIRA just knows and follows up.
///
/// Examples:
///   User: "I'll study OS tonight" → AIRA nudges at 8 PM: "Ready to start OS?"
///   User: "My exam is on Friday" → Thursday night: "Exam tomorrow. How's prep?"
///   User: "I need to call Dad" → 2 hours later: "Did you call Dad?"
class ImplicitReminderDetector {
  static final ImplicitReminderDetector _instance = ImplicitReminderDetector._internal();
  factory ImplicitReminderDetector() => _instance;
  ImplicitReminderDetector._internal();

  static const _uuid = Uuid();

  /// Analyze a user message for implicit commitments and schedule reminders.
  /// Returns a list of scheduled reminder descriptions (empty if none detected).
  Future<List<String>> detectAndSchedule(String message) async {
    final commitments = _detectCommitments(message);
    final scheduled = <String>[];

    for (final commitment in commitments) {
      final reminderTime = _inferReminderTime(commitment);
      if (reminderTime == null) continue;

      // Don't schedule reminders in the past
      if (reminderTime.isBefore(DateTime.now())) continue;

      try {
        await NotificationService().scheduleNotification(
          id: _uuid.v4().hashCode.abs() % 100000,
          title: 'AIRA Reminder',
          body: commitment.nudgeMessage,
          scheduledDate: reminderTime,
        );
        scheduled.add(commitment.nudgeMessage);
        debugPrint('[IMPLICIT REMINDER] Scheduled: "${commitment.nudgeMessage}" at $reminderTime');
      } catch (e) {
        debugPrint('[IMPLICIT REMINDER] Failed to schedule: $e');
      }
    }

    return scheduled;
  }

  /// Detect implicit commitments in a message
  List<_ImplicitCommitment> _detectCommitments(String message) {
    final lower = message.toLowerCase();
    final commitments = <_ImplicitCommitment>[];

    // Pattern 1: "I'll [action] tonight/tomorrow/today"
    final willDoPatterns = RegExp(
      r"i(?:'ll| will| need to| have to| should| gotta| must| wanna| want to)\s+(.+?)\s+(tonight|tomorrow|today|this evening|this morning|this afternoon|this weekend|later)",
      caseSensitive: false,
    );
    final willMatch = willDoPatterns.firstMatch(lower);
    if (willMatch != null) {
      final action = willMatch.group(1)?.trim() ?? '';
      final timeRef = willMatch.group(2)?.trim() ?? '';
      if (action.isNotEmpty) {
        commitments.add(_ImplicitCommitment(
          action: action,
          timeReference: timeRef,
          nudgeMessage: 'You mentioned wanting to $action. Ready to start?',
          type: _CommitmentType.selfTask,
        ));
      }
    }

    // Pattern 2: "My [subject] exam/test/quiz is on [day]/tomorrow/Friday"
    final examPattern = RegExp(
      r"my\s+(\w+(?:\s+\w+)?)\s+(?:exam|test|quiz|presentation|deadline|submission|interview)\s+(?:is\s+)?(?:on\s+)?(\w+)",
      caseSensitive: false,
    );
    final examMatch = examPattern.firstMatch(lower);
    if (examMatch != null) {
      final subject = examMatch.group(1)?.trim() ?? '';
      final when = examMatch.group(2)?.trim() ?? '';
      commitments.add(_ImplicitCommitment(
        action: '$subject exam/test',
        timeReference: when,
        nudgeMessage: 'Your $subject exam is coming up. How\'s the prep going?',
        type: _CommitmentType.deadline,
      ));
    }

    // Pattern 3: "I need to call/text/message [person]"
    final contactPattern = RegExp(
      r"i\s+(?:need to|should|have to|gotta|must)\s+(?:call|text|message|email|reach out to|contact)\s+(\w+)",
      caseSensitive: false,
    );
    final contactMatch = contactPattern.firstMatch(lower);
    if (contactMatch != null) {
      final person = contactMatch.group(1)?.trim() ?? '';
      commitments.add(_ImplicitCommitment(
        action: 'contact $person',
        timeReference: 'soon',
        nudgeMessage: 'Did you get a chance to reach out to $person?',
        type: _CommitmentType.contactAction,
      ));
    }

    // Pattern 4: "Let me [action] after/before [time]"
    final letMePattern = RegExp(
      r"let me\s+(.+?)\s+(after|before|in)\s+(.+?)(?:\.|$)",
      caseSensitive: false,
    );
    final letMeMatch = letMePattern.firstMatch(lower);
    if (letMeMatch != null) {
      final action = letMeMatch.group(1)?.trim() ?? '';
      commitments.add(_ImplicitCommitment(
        action: action,
        timeReference: 'later',
        nudgeMessage: 'Just checking — did you get to $action?',
        type: _CommitmentType.selfTask,
      ));
    }

    return commitments;
  }

  /// Infer the actual DateTime for a reminder based on time reference
  DateTime? _inferReminderTime(_ImplicitCommitment commitment) {
    final now = DateTime.now();
    final ref = commitment.timeReference.toLowerCase();

    switch (commitment.type) {
      case _CommitmentType.contactAction:
        // Nudge 2 hours later
        return now.add(const Duration(hours: 2));

      case _CommitmentType.deadline:
        // Nudge the evening before the deadline
        if (ref == 'tomorrow') {
          return DateTime(now.year, now.month, now.day, 20, 0); // Tonight 8 PM
        }
        if (ref == 'friday') return _nextWeekday(DateTime.thursday, 20);
        if (ref == 'monday') return _nextWeekday(DateTime.sunday, 20);
        if (ref == 'wednesday') return _nextWeekday(DateTime.tuesday, 20);
        return now.add(const Duration(hours: 6)); // Default: 6 hours

      case _CommitmentType.selfTask:
        if (ref.contains('tonight') || ref.contains('evening')) {
          return DateTime(now.year, now.month, now.day, 20, 0); // 8 PM
        }
        if (ref.contains('tomorrow')) {
          return DateTime(now.year, now.month, now.day + 1, 9, 0); // 9 AM next day
        }
        if (ref.contains('morning')) {
          if (now.hour < 9) {
            return DateTime(now.year, now.month, now.day, 9, 0);
          }
          return now.add(const Duration(hours: 1));
        }
        if (ref.contains('afternoon')) {
          return DateTime(now.year, now.month, now.day, 14, 0); // 2 PM
        }
        if (ref.contains('later')) {
          return now.add(const Duration(hours: 3));
        }
        if (ref.contains('weekend')) {
          return _nextWeekday(DateTime.saturday, 10);
        }
        return now.add(const Duration(hours: 2)); // Default: 2 hours
    }
  }

  /// Get the next occurrence of a specific weekday at a specific hour
  DateTime _nextWeekday(int weekday, int hour) {
    final now = DateTime.now();
    var daysUntil = weekday - now.weekday;
    if (daysUntil <= 0) daysUntil += 7;
    return DateTime(now.year, now.month, now.day + daysUntil, hour, 0);
  }
}

enum _CommitmentType { selfTask, deadline, contactAction }

class _ImplicitCommitment {
  final String action;
  final String timeReference;
  final String nudgeMessage;
  final _CommitmentType type;

  const _ImplicitCommitment({
    required this.action,
    required this.timeReference,
    required this.nudgeMessage,
    required this.type,
  });
}
