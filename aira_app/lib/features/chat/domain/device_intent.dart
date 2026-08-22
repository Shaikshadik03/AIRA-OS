// Native Android Device Control Intent Detector for AIRA OS.

enum DeviceIntent {
  none,
  toggleFlashlight,
  launchApp,
  searchInApp,
  openSettings,
  getBatteryStatus,
  setAlarm,
  setTimer,
  adjustVolume,
  controlMedia,
  copyToClipboard,
  getDeviceInfo,
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
      case DeviceIntent.searchInApp:
        final appName = params['appName'] as String? ?? 'App';
        final query = params['query'] as String? ?? '';
        return 'Search "$query" on $appName';
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
        final mins = sec ~/ 60;
        final secs = sec % 60;
        if (mins > 0 && secs > 0) return 'Set timer for ${mins}m ${secs}s';
        if (mins > 0) return 'Set timer for $mins minute${mins == 1 ? '' : 's'}';
        return 'Set timer for $secs second${secs == 1 ? '' : 's'}';
      case DeviceIntent.adjustVolume:
        final dir = params['direction'] as String? ?? 'up';
        final stream = params['stream'] as String? ?? 'media';
        return 'Volume $dir ($stream)';
      case DeviceIntent.controlMedia:
        final action = params['action'] as String? ?? 'play_pause';
        return 'Media: $action';
      case DeviceIntent.copyToClipboard:
        return 'Copy to clipboard';
      case DeviceIntent.getDeviceInfo:
        return 'Get device information';
      default:
        return 'Device action';
    }
  }
}

class DeviceIntentDetector {
  static DeviceCommand detect(String message) {
    final msg = message.trim();
    final lower = msg.toLowerCase();

    // ── 0. Deep-Link Search in App ─────────────────────────────────────────────
    final searchInAppCommand = _detectSearchInApp(msg, lower);
    if (searchInAppCommand != null) {
      return searchInAppCommand;
    }

    // ── 1. Flashlight / Torch ──────────────────────────────────────────────────
    if (_matchesFlashlight(lower)) {
      final isOff = lower.contains('off') ||
          lower.contains('disable') ||
          lower.contains('stop') ||
          lower.contains('close');
      return DeviceCommand(
        intent: DeviceIntent.toggleFlashlight,
        params: {'enable': !isOff},
        originalMessage: message,
      );
    }

    // ── 2. Media Playback Controls ────────────────────────────────────────────
    if (_matchesMedia(lower)) {
      String action = 'play_pause';
      if (lower.contains('next') || lower.contains('skip')) {
        action = 'next';
      } else if (lower.contains('previous') || lower.contains('prev') || lower.contains('back')) {
        action = 'previous';
      } else if (lower.contains('pause') || lower.contains('stop music')) {
        action = 'pause';
      } else if (lower.contains('play') || lower.contains('resume')) {
        action = 'play';
      }
      return DeviceCommand(
        intent: DeviceIntent.controlMedia,
        params: {'action': action},
        originalMessage: message,
      );
    }

    // ── 3. Volume Control ─────────────────────────────────────────────────────
    if (_matchesVolume(lower)) {
      String direction = 'up';
      String stream = 'media';

      if (lower.contains('down') || lower.contains('lower') || lower.contains('decrease') || lower.contains('reduce')) {
        direction = 'down';
      } else if (lower.contains('mute') || lower.contains('silent')) {
        direction = 'mute';
      } else if (lower.contains('unmute') || lower.contains('unsilent')) {
        direction = 'unmute';
      } else if (lower.contains('max') || lower.contains('maximum') || lower.contains('full')) {
        direction = 'max';
      } else if (lower.contains('min') || lower.contains('minimum') || lower.contains('zero')) {
        direction = 'min';
      }

      if (lower.contains('ring') || lower.contains('ringtone')) {
        stream = 'ring';
      } else if (lower.contains('alarm')) {
        stream = 'alarm';
      } else if (lower.contains('notification')) {
        stream = 'notification';
      }

      return DeviceCommand(
        intent: DeviceIntent.adjustVolume,
        params: {'direction': direction, 'stream': stream},
        originalMessage: message,
      );
    }

    // ── 4. Device Info ────────────────────────────────────────────────────────
    if (_matchesDeviceInfo(lower)) {
      return DeviceCommand(
        intent: DeviceIntent.getDeviceInfo,
        params: {},
        originalMessage: message,
      );
    }

    // ── 5. Battery Status ─────────────────────────────────────────────────────
    if (_matchesBattery(lower)) {
      return DeviceCommand(
        intent: DeviceIntent.getBatteryStatus,
        params: {},
        originalMessage: message,
      );
    }

    // ── 6. Alarm ──────────────────────────────────────────────────────────────
    if (_matchesAlarm(lower)) {
      int hour = 7;
      int minute = 0;
      String label = 'AIRA Alarm';

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

      final labelMatch = RegExp(r'(?:called|for|named|titled?)\s+([A-Za-z0-9\s]+)', caseSensitive: false).firstMatch(msg);
      if (labelMatch != null &&
          !labelMatch.group(1)!.toLowerCase().contains('am') &&
          !labelMatch.group(1)!.toLowerCase().contains('pm')) {
        label = labelMatch.group(1)!.trim();
      }

      return DeviceCommand(
        intent: DeviceIntent.setAlarm,
        params: {'hour': hour, 'minute': minute, 'message': label},
        originalMessage: message,
      );
    }

    // ── 7. Timer ──────────────────────────────────────────────────────────────
    if (_matchesTimer(lower)) {
      int seconds = 60;

      final hoursMatch = RegExp(r'(\d+)\s*(?:hr|hour|hours)', caseSensitive: false).firstMatch(lower);
      final minutesMatch = RegExp(r'(\d+)\s*(?:min|minute|minutes)', caseSensitive: false).firstMatch(lower);
      final secondsMatch = RegExp(r'(\d+)\s*(?:sec|second|seconds)', caseSensitive: false).firstMatch(lower);

      if (hoursMatch != null) {
        seconds = (int.tryParse(hoursMatch.group(1) ?? '1') ?? 1) * 3600;
        final extraMins = minutesMatch != null ? (int.tryParse(minutesMatch.group(1) ?? '0') ?? 0) * 60 : 0;
        seconds += extraMins;
      } else if (minutesMatch != null) {
        seconds = (int.tryParse(minutesMatch.group(1) ?? '1') ?? 1) * 60;
      } else if (secondsMatch != null) {
        seconds = int.tryParse(secondsMatch.group(1) ?? '60') ?? 60;
      }

      return DeviceCommand(
        intent: DeviceIntent.setTimer,
        params: {'seconds': seconds, 'message': 'AIRA Timer'},
        originalMessage: message,
      );
    }

    // ── 8. Clipboard ──────────────────────────────────────────────────────────
    if (_matchesClipboard(lower)) {
      final copyMatch = RegExp(r'copy\s+(?:this\s+)?(?:text\s+)?(.+?)\s*(?:to clipboard)?$', caseSensitive: false).firstMatch(msg);
      final text = copyMatch?.group(1)?.trim() ?? '';
      return DeviceCommand(
        intent: DeviceIntent.copyToClipboard,
        params: {'text': text},
        originalMessage: message,
      );
    }

    // ── 9. System Settings ────────────────────────────────────────────────────
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
      } else if (lower.contains('storage') || lower.contains('memory')) {
        settingType = 'storage';
      } else if (lower.contains('network') || lower.contains('internet')) {
        settingType = 'network';
      } else if (lower.contains('accessibility')) {
        settingType = 'accessibility';
      } else if (lower.contains('developer') || lower.contains('dev options')) {
        settingType = 'developer';
      } else if (lower.contains('app') || lower.contains('applications')) {
        settingType = 'apps';
      }

      return DeviceCommand(
        intent: DeviceIntent.openSettings,
        params: {'settingType': settingType},
        originalMessage: message,
      );
    }

    // ── 10. Launch App ────────────────────────────────────────────────────────
    if (_matchesLaunchApp(lower)) {
      final appMatch = RegExp(
        r'(?:open|launch|start|run|show)\s+([A-Za-z0-9\s\+\-\&\.]+?)(?:\s+app|\s+now|\s*$)',
        caseSensitive: false,
      ).firstMatch(msg);
      String appName = appMatch?.group(1)?.trim() ?? '';
      appName = appName.replaceAll(RegExp(r'[\.\!\?]$'), '').trim();
      appName = appName.replaceAll(RegExp(r'^(the|my)\s+', caseSensitive: false), '').trim();

      if (appName.isNotEmpty &&
          !appName.toLowerCase().contains('settings') &&
          !appName.toLowerCase().contains('wifi') &&
          !appName.toLowerCase().contains('bluetooth')) {
        return DeviceCommand(
          intent: DeviceIntent.launchApp,
          params: {'appName': appName},
          originalMessage: message,
        );
      }
    }

    return DeviceCommand(intent: DeviceIntent.none, params: {}, originalMessage: message);
  }

  // ── Match helpers ──────────────────────────────────────────────────────────

  static bool _matchesFlashlight(String m) =>
      m.contains('flashlight') ||
      m.contains('torch') ||
      m.contains('flash light') ||
      m.contains('turn on light') ||
      m.contains('turn off light');

  static bool _matchesMedia(String m) =>
      (m.contains('next song') || m.contains('next track') || m.contains('skip song')) ||
      (m.contains('previous song') || m.contains('prev track') || m.contains('last song')) ||
      (m.contains('pause music') || m.contains('pause song') || m.contains('stop music')) ||
      (m.contains('play music') || m.contains('resume music') || m.contains('resume song')) ||
      (m.contains('play pause') || m.contains('play/pause'));

  static bool _matchesVolume(String m) =>
      m.contains('volume up') ||
      m.contains('volume down') ||
      m.contains('increase volume') ||
      m.contains('decrease volume') ||
      m.contains('raise volume') ||
      m.contains('lower volume') ||
      m.contains('mute') ||
      m.contains('unmute') ||
      m.contains('max volume') ||
      m.contains('full volume') ||
      m.contains('minimum volume') ||
      (m.contains('turn up') && (m.contains('volume') || m.contains('sound'))) ||
      (m.contains('turn down') && (m.contains('volume') || m.contains('sound')));

  static bool _matchesBattery(String m) =>
      m.contains('battery level') ||
      m.contains('battery status') ||
      m.contains('battery percentage') ||
      m.contains('check battery') ||
      m.contains('how much battery') ||
      m.contains('battery life') ||
      m.contains('phone battery');

  static bool _matchesDeviceInfo(String m) =>
      m.contains('device info') ||
      m.contains('phone info') ||
      m.contains('about device') ||
      m.contains('phone model') ||
      m.contains('android version') ||
      m.contains('phone specs') ||
      m.contains('storage info') ||
      m.contains('storage space') ||
      m.contains('how much storage') ||
      m.contains('available storage');

  static bool _matchesAlarm(String m) =>
      m.contains('set alarm') ||
      m.contains('create alarm') ||
      m.contains('add alarm') ||
      m.contains('wake me up') ||
      m.startsWith('alarm for') ||
      m.startsWith('alarm at');

  static bool _matchesTimer(String m) =>
      m.contains('set timer') ||
      m.contains('set a timer') ||
      m.contains('start timer') ||
      m.contains('start a timer') ||
      m.contains('countdown for') ||
      m.contains('timer for');

  static bool _matchesClipboard(String m) =>
      m.contains('copy to clipboard') ||
      m.contains('copy this to clipboard') ||
      (m.startsWith('copy ') && m.contains('clipboard'));

  static bool _matchesSettings(String m) =>
      (m.contains('settings') && !m.startsWith('open app settings')) ||
      m.contains('open wifi') ||
      m.contains('turn on wifi') ||
      m.contains('open bluetooth') ||
      m.contains('turn on bluetooth') ||
      m.contains('open volume') ||
      m.contains('volume settings') ||
      m.contains('display settings') ||
      m.contains('brightness settings') ||
      m.contains('open storage') ||
      m.contains('open network') ||
      m.contains('open accessibility') ||
      m.contains('open developer');

  static bool _matchesLaunchApp(String m) {
    if (m.startsWith('open ') ||
        m.startsWith('launch ') ||
        m.startsWith('start ') ||
        m.startsWith('run ') ||
        m.contains('open app ')) {
      // Exclude Google Workspace actions
      if (m.contains('doc') ||
          m.contains('sheet') ||
          m.contains('drive') ||
          m.contains('file') ||
          m.contains('folder') ||
          m.contains('email') ||
          m.contains('mail') ||
          m.contains('calendar') ||
          m.contains('event')) {
        return false;
      }
      return true;
    }
    return false;
  }

  static DeviceCommand? _detectSearchInApp(String msg, String lower) {
    // Pattern 1: open/launch/start <app> (and|to|then) (search|play|find|look for) <query>
    final pattern1 = RegExp(
      r'^(?:open|launch|start)\s+(youtube|spotify|chrome|google|browser|[A-Za-z0-9\s]+?)\s+(?:and|to|then|\,)\s+(?:search\s+for|search|play\s+video\s+of|play\s+a\s+video\s+of|play\s+song|play|find|look\s+for)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(msg);

    if (pattern1 != null) {
      final app = pattern1.group(1)!.trim();
      final query = pattern1.group(2)!.trim();
      if (app.isNotEmpty && query.isNotEmpty) {
        return DeviceCommand(
          intent: DeviceIntent.searchInApp,
          params: {'appName': app, 'query': query},
          originalMessage: msg,
        );
      }
    }

    // Pattern 2: (play|watch|search|find|look for) (a video of |video of |song |song of )?<query> (on|in|using) <app>
    final pattern2 = RegExp(
      r'^(?:search\s+for|search|play\s+a\s+video\s+of|play\s+video\s+of|play\s+song|play|watch|find|look\s+for)\s+(?:a\s+video\s+of\s+|video\s+of\s+|a\s+song\s+of\s+|song\s+of\s+)?(.+?)\s+(?:on|in|using)\s+(youtube|spotify|google|chrome|browser|[A-Za-z0-9\s]+)$',
      caseSensitive: false,
    ).firstMatch(msg);

    if (pattern2 != null) {
      final query = pattern2.group(1)!.trim();
      final app = pattern2.group(2)!.trim();
      if (app.isNotEmpty && query.isNotEmpty) {
        return DeviceCommand(
          intent: DeviceIntent.searchInApp,
          params: {'appName': app, 'query': query},
          originalMessage: msg,
        );
      }
    }

    // Pattern 3: (play video of |play a video of |watch video of ) <query> -> default to YouTube
    final pattern3 = RegExp(
      r'^(?:play\s+a\s+video\s+of|play\s+video\s+of|watch\s+video\s+of|watch)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(msg);

    if (pattern3 != null) {
      final query = pattern3.group(1)!.trim();
      if (query.isNotEmpty) {
        return DeviceCommand(
          intent: DeviceIntent.searchInApp,
          params: {'appName': 'youtube', 'query': query},
          originalMessage: msg,
        );
      }
    }

    return null;
  }
}
