enum NotificationIntentType {
  scheduleReminder,
  scheduleDailyAlert,
  cancelAllReminders,
  listReminders,
  notificationDigest,
  followUpReminder,
  focusModeToggle,
  quickReply,
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
  final String? targetApp;
  final String? sender;
  final String? replyText;
  final bool? enableFocusMode;

  const NotificationCommand({
    required this.intent,
    this.title = 'AIRA Reminder',
    this.body = '',
    this.scheduledDate,
    this.hour,
    this.minute,
    required this.isNotificationCommand,
    this.targetApp,
    this.sender,
    this.replyText,
    this.enableFocusMode,
  });

  factory NotificationCommand.none() => const NotificationCommand(
        intent: NotificationIntentType.unknown,
        isNotificationCommand: false,
      );
}

class NotificationIntentDetector {
  static NotificationCommand detect(String input) {
    final lower = input.toLowerCase().trim();

    // ── 1. Focus Mode & Quiet Hours (English + Telugu) ──
    if (lower.contains('focus mode') ||
        lower.contains('quiet hours') ||
        lower.contains('do not disturb') ||
        lower.contains('dnd mode') ||
        lower.contains('silence notifications') ||
        lower.contains('silence alerts')) {
      final isTurnOff = lower.contains('off') ||
          lower.contains('disable') ||
          lower.contains('stop') ||
          lower.contains('aapu');
      final enable = !isTurnOff;

      return NotificationCommand(
        intent: NotificationIntentType.focusModeToggle,
        title: enable ? 'Focus Mode Enabled 🔕' : 'Focus Mode Disabled 🔔',
        body: enable ? 'Non-urgent alerts silenced. Direct messages preserved.' : 'Standard alert delivery restored.',
        enableFocusMode: enable,
        isNotificationCommand: true,
      );
    }

    // ── 2. Notification Digest & Intelligence (English + Telugu) ──
    // e.g. "what notifications did i get", "summarize my alerts", "check notifications",
    // Telugu: "naa notifications em vachayi", "notifications chudu", "alerts cheppu", "messages em vachayi"
    final isDigestQuery = (lower.contains('notification') || lower.contains('notif') || lower.contains('alert')) &&
            (lower.contains('what') ||
                lower.contains('summarize') ||
                lower.contains('summary') ||
                lower.contains('check') ||
                lower.contains('digest') ||
                lower.contains('read') ||
                lower.contains('show') ||
                lower.contains('list') ||
                lower.contains('did i get') ||
                lower.contains('missed') ||
                lower.contains('any')) ||
        lower.contains('what did i miss') ||
        lower.contains('recent alerts') ||
        lower.contains('unread notifications') ||
        lower.contains('naa notifications') ||
        lower.contains('notifications em vachayi') ||
        lower.contains('notifications chudu') ||
        lower.contains('alerts cheppu') ||
        lower.contains('messages em vachayi') ||
        lower.contains('notif chudu');

    if (isDigestQuery) {
      return const NotificationCommand(
        intent: NotificationIntentType.notificationDigest,
        title: 'AIRA Notification Digest 📥',
        body: 'Executive digest of your recent Android alerts',
        isNotificationCommand: true,
      );
    }

    // ── 3. Follow-Up Reminder on Notification (English + Telugu) ──
    // e.g. "remind me to reply to Rahul at 4 PM", "follow up with Sneha tomorrow 10 am"
    // Telugu: "Rahul ki 4 PM ki reply ivvalani remind cheyyi"
    final isFollowUp = (lower.contains('remind') || lower.contains('gurtu')) &&
        (lower.contains('reply') || lower.contains('follow up') || lower.contains('message back') || lower.contains('ivvalani'));

    if (isFollowUp) {
      DateTime scheduledTime = DateTime.now().add(const Duration(hours: 1));
      String senderName = 'Sender';

      // Parse sender name
      final replyToMatch = RegExp(r'(?:reply to|follow up with|reply ivvalani)\s+([A-Za-z0-9_]+)', caseSensitive: false).firstMatch(lower);
      if (replyToMatch != null) {
        senderName = replyToMatch.group(1)!;
        senderName = senderName[0].toUpperCase() + senderName.substring(1);
      }

      // Parse time
      final timeMatch = RegExp(r'(?:at|on|by)\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?').firstMatch(lower);
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
      } else {
        final relMatch = RegExp(r'in\s+(\d+)\s+(minute|min|hour|hr)s?').firstMatch(lower);
        if (relMatch != null) {
          final amt = int.parse(relMatch.group(1)!);
          final unit = relMatch.group(2)!;
          if (unit.startsWith('min')) {
            scheduledTime = DateTime.now().add(Duration(minutes: amt));
          } else {
            scheduledTime = DateTime.now().add(Duration(hours: amt));
          }
        }
      }

      return NotificationCommand(
        intent: NotificationIntentType.followUpReminder,
        title: 'Follow-Up: Reply to $senderName 💬',
        body: 'Follow up on incoming notification from $senderName',
        sender: senderName,
        scheduledDate: scheduledTime,
        isNotificationCommand: true,
      );
    }

    // ── 4. Quick-Reply Command ──
    // e.g. "reply to Rahul saying I will reach in 10 mins"
    final isQuickReply = lower.startsWith('reply to ') ||
        lower.contains('send reply to ') ||
        (lower.contains('ki reply pettu') || lower.contains('ki reply ivvu'));

    if (isQuickReply) {
      String senderName = 'Contact';
      String replyText = '';

      final sayingMatch = RegExp(r'reply to\s+([a-zA-Z0-9_]+)\s+(?:saying|that)\s+(.+)', caseSensitive: false).firstMatch(input);
      if (sayingMatch != null) {
        senderName = sayingMatch.group(1)!.trim();
        replyText = sayingMatch.group(2)!.trim();
      }

      return NotificationCommand(
        intent: NotificationIntentType.quickReply,
        title: 'Quick Reply Draft 💬',
        body: replyText,
        sender: senderName,
        replyText: replyText,
        isNotificationCommand: true,
      );
    }

    // ── 5. Standard Reminder Filters ──
    if (!lower.contains('remind') &&
        !lower.contains('notification') &&
        !lower.contains('alert me') &&
        !lower.contains('notify me') &&
        !lower.contains('schedule reminder') &&
        !lower.contains('gurtu cheyyi')) {
      return NotificationCommand.none();
    }

    // Cancel all reminders
    if (lower.contains('cancel all reminders') || lower.contains('clear all notifications')) {
      return const NotificationCommand(
        intent: NotificationIntentType.cancelAllReminders,
        isNotificationCommand: true,
      );
    }

    // List pending reminders
    if (lower.contains('show reminders') || lower.contains('list reminders') || lower.contains('my reminders')) {
      return const NotificationCommand(
        intent: NotificationIntentType.listReminders,
        isNotificationCommand: true,
      );
    }

    // Daily alert (e.g. "send me daily news at 7 am", "notify daily at 8 am")
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

    // One-time scheduled reminder
    DateTime scheduledTime = DateTime.now().add(const Duration(hours: 1));
    String reminderText = input;

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
      final timeMatch = RegExp(r'(?:at|on)\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?').firstMatch(lower);
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
        .replaceAll(RegExp(r'remind me (to|that|about|on)?', caseSensitive: false), '')
        .replaceAll(RegExp(r'(at|on)\s+\d{1,2}(:\d{2})?\s*(am|pm)?', caseSensitive: false), '')
        .replaceAll(RegExp(r'in\s+\d+\s+(minute|min|hour|hr)s?', caseSensitive: false), '')
        .replaceAll(RegExp(r'^\s*(as|for)\s+', caseSensitive: false), '')
        .trim();

    if (reminderText.isEmpty) reminderText = input;
    if (reminderText.isNotEmpty) {
      reminderText = reminderText[0].toUpperCase() + reminderText.substring(1);
    }

    return NotificationCommand(
      intent: NotificationIntentType.scheduleReminder,
      title: 'AIRA Reminder 🔔',
      body: reminderText,
      scheduledDate: scheduledTime,
      isNotificationCommand: true,
    );
  }
}
