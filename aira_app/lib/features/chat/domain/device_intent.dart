// Native Android Device Control Intent Detector for AIRA OS (Milestone 4).

enum DeviceIntent {
  none,
  toggleFlashlight,
  launchApp,
  openSettings,
  getBatteryStatus,
  setAlarm,
  setTimer,
}

class DeviceCommand {
  final DeviceIntent intent;
  final Map<String, dynamic> params;
  final String originalMessage;

  const DeviceCommand({
    required this.intent,
    required this.params,
    required this.originalMessage,
  });

  bool get isDeviceCommand => intent != DeviceIntent.none;

  String get description {
    switch (intent) {
      case DeviceIntent.toggleFlashlight:
        final enable = params['enable'] as bool? ?? true;
        return enable ? 'Turn on flashlight' : 'Turn off flashlight';
      case DeviceIntent.launchApp:
        final appName = params['appName'] as String? ?? 'App';
        return 'Open $appName';
      case DeviceIntent.openSettings:
        final type = params['settingType'] as String? ?? 'system';
        return 'Open $type settings';
      case DeviceIntent.getBatteryStatus:
        return 'Check battery status';
      case DeviceIntent.setAlarm:
        final hour = params['hour'] as int? ?? 7;
        final min = params['minute'] as int? ?? 0;
        final timeStr = '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
        return 'Set alarm for $timeStr';
      case DeviceIntent.setTimer:
        final sec = params['seconds'] as int? ?? 60;
        return 'Set timer for ${sec ~/ 60} min';
      default:
        return 'Device action';
    }
  }
}

class DeviceIntentDetector {
  static DeviceCommand detect(String message) {
    final msg = message.trim();
    final lower = msg.toLowerCase();

    // ── 1. Flashlight / Torch Intent ──
    if (_matchesFlashlight(lower)) {
      final isOff = lower.contains('off') || lower.contains('disable') || lower.contains('stop') || lower.contains('close');
      return DeviceCommand(
        intent: DeviceIntent.toggleFlashlight,
        params: {'enable': !isOff},
        originalMessage: message,
      );
    }

    // ── 2. Battery & System Info Intent ──
    if (_matchesBattery(lower)) {
      return DeviceCommand(
        intent: DeviceIntent.getBatteryStatus,
        params: {},
        originalMessage: message,
      );
    }

    // ── 3. Alarm Intent ──
    if (_matchesAlarm(lower)) {
      int hour = 7;
      int minute = 0;
      String label = 'AIRA Alarm';

      // Parse time like 7:30 or 7:30 am or 8 pm or 6 oclock
      final timeMatch = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false).firstMatch(lower);
      if (timeMatch != null) {
        int h = int.tryParse(timeMatch.group(1) ?? '') ?? 7;
        int m = int.tryParse(timeMatch.group(2) ?? '') ?? 0;
        final ampm = timeMatch.group(3)?.toLowerCase();

        if (ampm == 'pm' && h < 12) h += 12;
        if (ampm == 'am' && h == 12) h = 0;

        hour = h;
        minute = m;
      }

      final labelMatch = RegExp(r'(?:called|for|named|title)\s+([A-Za-z0-9\s]+)', caseSensitive: false).firstMatch(msg);
      if (labelMatch != null && !labelMatch.group(1)!.toLowerCase().contains('am') && !labelMatch.group(1)!.toLowerCase().contains('pm')) {
        label = labelMatch.group(1)!.trim();
      }

      return DeviceCommand(
        intent: DeviceIntent.setAlarm,
        params: {'hour': hour, 'minute': minute, 'message': label},
        originalMessage: message,
      );
    }

    // ── 4. Timer Intent ──
    if (_matchesTimer(lower)) {
      int seconds = 60;
      String label = 'AIRA Timer';

      final minutesMatch = RegExp(r'(\d+)\s*(?:min|minute|minutes)', caseSensitive: false).firstMatch(lower);
      final secondsMatch = RegExp(r'(\d+)\s*(?:sec|second|seconds)', caseSensitive: false).firstMatch(lower);

      if (minutesMatch != null) {
        seconds = (int.tryParse(minutesMatch.group(1) ?? '1') ?? 1) * 60;
      } else if (secondsMatch != null) {
        seconds = int.tryParse(secondsMatch.group(1) ?? '60') ?? 60;
      }

      return DeviceCommand(
        intent: DeviceIntent.setTimer,
        params: {'seconds': seconds, 'message': label},
        originalMessage: message,
      );
    }

    // ── 5. System Settings Intent ──
    if (_matchesSettings(lower)) {
      String settingType = 'default';
      if (lower.contains('wifi') || lower.contains('wi-fi')) {
        settingType = 'wifi';
      } else if (lower.contains('bluetooth')) {
        settingType = 'bluetooth';
      } else if (lower.contains('display') || lower.contains('brightness')) {
        settingType = 'display';
      } else if (lower.contains('sound') || lower.contains('volume') || lower.contains('audio')) {
        settingType = 'sound';
      } else if (lower.contains('battery') || lower.contains('power')) {
        settingType = 'battery';
      } else if (lower.contains('location') || lower.contains('gps')) {
        settingType = 'location';
      } else if (lower.contains('nfc')) {
        settingType = 'nfc';
      } else if (lower.contains('app') || lower.contains('applications')) {
        settingType = 'apps';
      }

      return DeviceCommand(
        intent: DeviceIntent.openSettings,
        params: {'settingType': settingType},
        originalMessage: message,
      );
    }

    // ── 6. Launch App Intent ──
    if (_matchesLaunchApp(lower)) {
      final appMatch = RegExp(r'(?:open|launch|start|run|show)\s+([A-Za-z0-9\s\+\-\&]+?)(?:\s+app|\s+now|\s*$)', caseSensitive: false).firstMatch(msg);
      String appName = appMatch?.group(1)?.trim() ?? '';
      appName = appName.replaceAll(RegExp(r'[\.\!\?]$'), '').trim();
      appName = appName.replaceAll(RegExp(r'^(the|my)\s+', caseSensitive: false), '').trim();

      if (appName.isNotEmpty && !appName.toLowerCase().contains('settings') && !appName.toLowerCase().contains('wifi') && !appName.toLowerCase().contains('bluetooth')) {
        return DeviceCommand(
          intent: DeviceIntent.launchApp,
          params: {'appName': appName},
          originalMessage: message,
        );
      }
    }

    return DeviceCommand(intent: DeviceIntent.none, params: {}, originalMessage: message);
  }

  static bool _matchesFlashlight(String lowerMsg) {
    return lowerMsg.contains('flashlight') ||
        lowerMsg.contains('torch') ||
        lowerMsg.contains('flash light') ||
        lowerMsg.contains('turn on light') ||
        lowerMsg.contains('turn off light');
  }

  static bool _matchesBattery(String lowerMsg) {
    return lowerMsg.contains('battery level') ||
        lowerMsg.contains('battery status') ||
        lowerMsg.contains('battery percentage') ||
        lowerMsg.contains('check battery') ||
        lowerMsg.contains('how much battery');
  }

  static bool _matchesAlarm(String lowerMsg) {
    return lowerMsg.contains('set alarm') ||
        lowerMsg.contains('create alarm') ||
        lowerMsg.contains('wake me up') ||
        lowerMsg.startsWith('alarm for');
  }

  static bool _matchesTimer(String lowerMsg) {
    return lowerMsg.contains('set timer') ||
        lowerMsg.contains('set a timer') ||
        lowerMsg.contains('start timer') ||
        lowerMsg.contains('countdown for');
  }

  static bool _matchesSettings(String lowerMsg) {
    return (lowerMsg.contains('settings') && !lowerMsg.startsWith('open app settings')) ||
        lowerMsg.contains('open wifi') ||
        lowerMsg.contains('turn on wifi') ||
        lowerMsg.contains('open bluetooth') ||
        lowerMsg.contains('turn on bluetooth') ||
        lowerMsg.contains('open volume') ||
        lowerMsg.contains('volume settings') ||
        lowerMsg.contains('display settings') ||
        lowerMsg.contains('brightness settings');
  }

  static bool _matchesLaunchApp(String lowerMsg) {
    if (lowerMsg.startsWith('open ') ||
        lowerMsg.startsWith('launch ') ||
        lowerMsg.startsWith('start ') ||
        lowerMsg.startsWith('run ') ||
        lowerMsg.contains('open app ')) {
      // Exclude files, documents, drive, email, calendar
      if (lowerMsg.contains('doc') ||
          lowerMsg.contains('sheet') ||
          lowerMsg.contains('drive') ||
          lowerMsg.contains('file') ||
          lowerMsg.contains('folder') ||
          lowerMsg.contains('email') ||
          lowerMsg.contains('mail') ||
          lowerMsg.contains('calendar') ||
          lowerMsg.contains('event')) {
        return false;
      }
      return true;
    }
    return false;
  }
}
