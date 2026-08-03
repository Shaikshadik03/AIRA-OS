enum NotificationIntentType {
  scheduleReminder,
  scheduleDailyAlert,
  cancelAllReminders,
  listReminders,
  unknown,
}

class NotificationCommand {
  final NotificationIntentType intent;
  final String title;
  final String body;
  final DateTime? scheduledDate;
  final int? hour;
  final int? minute;
  final bool isNotificationCommand;

  const NotificationCommand({
    required this.intent,
    this.title = 'AIRA Reminder',
    this.body = '',
    this.scheduledDate,
    this.hour,
    this.minute,
    required this.isNotificationCommand,
  });

  factory NotificationCommand.none() => const NotificationCommand(
        intent: NotificationIntentType.unknown,
        isNotificationCommand: false,
      );
}

class NotificationIntentDetector {
  static NotificationCommand detect(String input) {
    final lower = input.toLowerCase().trim();

    if (!lower.contains('remind') &&
        !lower.contains('notification') &&
        !lower.contains('alert me') &&
        !lower.contains('notify me') &&
        !lower.contains('schedule reminder')) {
      return NotificationCommand.none();
    }

    // 1. Cancel all reminders
    if (lower.contains('cancel all reminders') || lower.contains('clear all notifications')) {
      return const NotificationCommand(
        intent: NotificationIntentType.cancelAllReminders,
        isNotificationCommand: true,
      );
    }

    // 2. List pending reminders
    if (lower.contains('show reminders') || lower.contains('list reminders') || lower.contains('my notifications')) {
      return const NotificationCommand(
        intent: NotificationIntentType.listReminders,
        isNotificationCommand: true,
      );
    }

    // 3. Daily alert (e.g. "send me daily news at 7 am", "notify daily at 8 am")
    if (lower.contains('daily') || lower.contains('every day') || lower.contains('every morning')) {
      final timeMatch = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?').firstMatch(lower);
      int hour = 7;
      int minute = 0;
      if (timeMatch != null) {
        hour = int.parse(timeMatch.group(1)!);
        minute = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
        final ampm = timeMatch.group(3);
        if (ampm == 'pm' && hour < 12) hour += 12;
        if (ampm == 'am' && hour == 12) hour = 0;
      }
      return NotificationCommand(
        intent: NotificationIntentType.scheduleDailyAlert,
        title: 'AIRA Daily Update 🌅',
        body: input,
        hour: hour,
        minute: minute,
        isNotificationCommand: true,
      );
    }

    // 4. One-time scheduled reminder (e.g., "remind me in 10 minutes", "remind me at 2 am to check logs")
    DateTime scheduledTime = DateTime.now().add(const Duration(hours: 1));
    String reminderText = input;

    // Check for "in X minutes/hours"
    final relativeMatch = RegExp(r'in\s+(\d+)\s+(minute|min|hour|hr)s?').firstMatch(lower);
    if (relativeMatch != null) {
      final amount = int.parse(relativeMatch.group(1)!);
      final unit = relativeMatch.group(2)!;
      if (unit.startsWith('min')) {
        scheduledTime = DateTime.now().add(Duration(minutes: amount));
      } else if (unit.startsWith('hour') || unit.startsWith('hr')) {
        scheduledTime = DateTime.now().add(Duration(hours: amount));
      }
    } else {
      // Check for "at X am/pm"
      final timeMatch = RegExp(r'at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?').firstMatch(lower);
      if (timeMatch != null) {
        int hour = int.parse(timeMatch.group(1)!);
        int minute = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
        final ampm = timeMatch.group(3);
        if (ampm == 'pm' && hour < 12) hour += 12;
        if (ampm == 'am' && hour == 12) hour = 0;

        final now = DateTime.now();
        scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
        if (scheduledTime.isBefore(now)) {
          scheduledTime = scheduledTime.add(const Duration(days: 1));
        }
      }
    }

    // Clean reminder text
    reminderText = input
        .replaceAll(RegExp(r'remind me (to|that|about)?', caseSensitive: false), '')
        .replaceAll(RegExp(r'at \d{1,2}(:\d{2})?\s*(am|pm)?', caseSensitive: false), '')
        .replaceAll(RegExp(r'in \d+ (minute|min|hour|hr)s?', caseSensitive: false), '')
        .trim();

    if (reminderText.isEmpty) reminderText = input;

    return NotificationCommand(
      intent: NotificationIntentType.scheduleReminder,
      title: 'AIRA Reminder 🔔',
      body: reminderText,
      scheduledDate: scheduledTime,
      isNotificationCommand: true,
    );
  }
}
