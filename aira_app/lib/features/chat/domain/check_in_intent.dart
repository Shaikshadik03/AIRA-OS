import 'package:aira_app/features/chat/domain/check_in_item.dart';

enum CheckInCommandType {
  createCheckIn,
  respondDone,
  respondBusy,
  respondAskTomorrow,
  respondStop,
  triggerMorningPlanning,
  triggerEveningReflection,
  listCheckIns,
}

class CheckInCommand {
  final CheckInCommandType type;
  final String title;
  final String reason;
  final DateTime? targetTime;
  final CheckInCategory category;

  const CheckInCommand({
    required this.type,
    this.title = '',
    this.reason = '',
    this.targetTime,
    this.category = CheckInCategory.agreedCheckin,
  });
}

class CheckInIntentDetector {
  static bool isCheckInCommand(String message, {bool hasActiveCheckIn = false}) {
    final lower = message.toLowerCase().trim();

    final creationTriggers = [
      'check on me', 'check in with me', 'check in on me', 'check in at',
      'follow up with me', 'follow up on', 'set check in', 'schedule check in',
      'remind me to check', 'follow up tomorrow', 'follow up tonight',
      'check in cheyyi', 'follow up cheyyi', 'gurinchi adugu', 'gurinchi check cheyyi',
      'check cheyyi', 'repu adugu', 'rathri adugu',
    ];

    if (creationTriggers.any((t) => lower.contains(t))) return true;

    if (lower.contains('morning planning') ||
        lower.contains('plan my morning') ||
        lower.contains('evening reflection') ||
        lower.contains('daily reflection') ||
        lower.contains('day wrap up') ||
        lower.contains('daily review') ||
        lower.contains('ee roju review')) {
      return true;
    }

    if (hasActiveCheckIn) {
      if (_isDoneResponse(lower) ||
          _isBusyResponse(lower) ||
          _isAskTomorrowResponse(lower) ||
          _isStopResponse(lower)) {
        return true;
      }
    } else {
      if (lower == 'done' || lower == 'completed' || lower == 'aipoyindi' ||
          lower == 'i am busy' || lower == "i'm busy" || lower == 'not now' ||
          lower == 'ask tomorrow' || lower == 'repu adugu' ||
          lower == "don't ask again" || lower == 'stop asking' || lower == 'malli adagodu') {
        return true;
      }
    }

    if (lower == 'show checkins' || lower == 'my checkins' || lower == 'list checkins') {
      return true;
    }

    return false;
  }

  static bool _isDoneResponse(String lower) {
    return lower == 'done' ||
        lower == 'completed' ||
        lower == 'finished' ||
        lower == "i'm done" ||
        lower == 'i am done' ||
        lower == 'all done' ||
        lower.contains('aipoyindi') ||
        lower.contains('ayipoyindi') ||
        lower.contains('finish aipoyindi') ||
        lower.contains('finish chesa') ||
        lower.contains('chesanu') ||
        lower == 'done with it';
  }

  static bool _isBusyResponse(String lower) {
    return lower == 'busy' ||
        lower == "i'm busy" ||
        lower == 'i am busy' ||
        lower == 'not now' ||
        lower == 'later' ||
        lower == 'in a bit' ||
        lower.contains('ippudu kudaradu') ||
        lower.contains('chala work undi') ||
        lower.contains('tharwatha');
  }

  static bool _isAskTomorrowResponse(String lower) {
    return lower == 'ask tomorrow' ||
        lower == 'check tomorrow' ||
        lower.contains('repu adugu') ||
        lower.contains('repu chuddam') ||
        lower.contains('repu matladam');
  }

  static bool _isStopResponse(String lower) {
    return lower == 'stop' ||
        lower == "don't ask again" ||
        lower == "dont ask again" ||
        lower == 'stop asking' ||
        lower.contains('cancel follow up') ||
        lower.contains('cancel check in') ||
        lower.contains('malli adagodu') ||
        lower == 'vaddu';
  }

  static CheckInCommand? parse(String message, {bool hasActiveCheckIn = false}) {
    final lower = message.toLowerCase().trim();

    if (_isDoneResponse(lower)) {
      return const CheckInCommand(type: CheckInCommandType.respondDone);
    }
    if (_isBusyResponse(lower)) {
      return const CheckInCommand(type: CheckInCommandType.respondBusy);
    }
    if (_isAskTomorrowResponse(lower)) {
      return const CheckInCommand(type: CheckInCommandType.respondAskTomorrow);
    }
    if (_isStopResponse(lower)) {
      return const CheckInCommand(type: CheckInCommandType.respondStop);
    }

    if (lower.contains('morning planning') || lower.contains('plan my morning')) {
      return const CheckInCommand(type: CheckInCommandType.triggerMorningPlanning);
    }
    if (lower.contains('evening reflection') ||
        lower.contains('daily reflection') ||
        lower.contains('day wrap up') ||
        lower.contains('daily review') ||
        lower.contains('ee roju review')) {
      return const CheckInCommand(type: CheckInCommandType.triggerEveningReflection);
    }

    if (lower == 'show checkins' || lower == 'my checkins' || lower == 'list checkins') {
      return const CheckInCommand(type: CheckInCommandType.listCheckIns);
    }

    final now = DateTime.now();
    DateTime targetTime = now.add(const Duration(hours: 2));

    int dayOffset = 0;
    if (lower.contains('tomorrow') || lower.contains('repu')) {
      dayOffset = 1;
    }

    final timeMatch = RegExp(r'(?:at|by)\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false).firstMatch(lower);
    if (timeMatch != null) {
      int hour = int.tryParse(timeMatch.group(1) ?? '') ?? 20;
      final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
      final period = timeMatch.group(3)?.toLowerCase();

      if (period == 'pm' && hour < 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;

      final dt = DateTime(now.year, now.month, now.day + dayOffset, hour, minute);
      targetTime = dt.isBefore(now) && dayOffset == 0 ? dt.add(const Duration(days: 1)) : dt;
    } else if (lower.contains('tonight') || lower.contains('rathri') || lower.contains('this evening')) {
      targetTime = DateTime(now.year, now.month, now.day, 20, 0);
      if (targetTime.isBefore(now)) targetTime = now.add(const Duration(hours: 1));
    } else if (lower.contains('tomorrow') || lower.contains('repu')) {
      targetTime = DateTime(now.year, now.month, now.day + 1, 9, 0);
    } else if (lower.contains('afternoon') || lower.contains('madhyahnam')) {
      targetTime = DateTime(now.year, now.month, now.day, 14, 0);
    }

    String reason = message;
    reason = reason.replaceAll(RegExp(
      r'^(check on me|check in with me|check in on me|check in|follow up with me|follow up on|follow up|set check in for)\s*',
      caseSensitive: false,
    ), '');
    reason = reason.replaceAll(RegExp(
      r'^(about|regarding|on|gurinchi)\s*',
      caseSensitive: false,
    ), '');
    reason = reason.replaceAll(RegExp(
      r'\s*(tonight|tomorrow|today|repu|rathri|at\s+\d{1,2}(:\d{2})?\s*(am|pm)?|by\s+\d{1,2}(:\d{2})?\s*(am|pm)?|gurinchi adugu|gurinchi check cheyyi|check in cheyyi|follow up cheyyi).*',
      caseSensitive: false,
    ), '');
    reason = reason.trim();

    if (reason.isEmpty) {
      reason = 'Focus progress check';
    }

    return CheckInCommand(
      type: CheckInCommandType.createCheckIn,
      title: 'Check on: $reason',
      reason: reason,
      targetTime: targetTime,
      category: CheckInCategory.agreedCheckin,
    );
  }
}
