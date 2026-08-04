import 'package:flutter/services.dart';

/// Native Android Device & System Controller Service.
/// Provides 100% native Android capabilities via custom MethodChannel.
///
/// Capabilities:
/// - Flashlight toggle
/// - App Launcher (60+ popular apps)
/// - Deep-Link App Search (YouTube, Spotify, Maps, Google/Chrome, Amazon, Play Store)
/// - System Settings shortcuts
/// - Battery status
/// - Alarm & Timer creation
/// - Volume control (media/ring/alarm)
/// - Media playback control (play/pause/next/prev)
/// - Copy to clipboard
/// - Full Device Info
class AndroidDeviceService {
  static final AndroidDeviceService _instance = AndroidDeviceService._internal();
  factory AndroidDeviceService() => _instance;
  AndroidDeviceService._internal();

  static const MethodChannel _channel = MethodChannel('com.aira.os/device_control');

  // ── Flashlight ──────────────────────────────────────────────────────────────

  /// Toggle device flashlight / torch LED on or off.
  Future<Map<String, dynamic>> toggleFlashlight({required bool enable}) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'toggleFlashlight',
        {'enable': enable},
      );
      return result ?? {'success': true, 'enabled': enable};
    } on PlatformException catch (e) {
      throw Exception('Flashlight Error: ${e.message ?? e.code}');
    }
  }

  // ── App Launcher ────────────────────────────────────────────────────────────

  /// Launch any installed application by display label or package query.
  /// Supports 60+ popular apps natively (WhatsApp, Spotify, Netflix, etc.)
  Future<Map<String, dynamic>> launchApp({required String appName}) async {
    final cleanName = appName.trim();
    if (cleanName.isEmpty) {
      throw Exception('Please specify an app name to launch (e.g. "Open WhatsApp").');
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'launchApp',
        {'query': cleanName.toLowerCase()},
      );
      return result ?? {'success': true, 'appName': cleanName};
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Could not launch "$cleanName".');
    }
  }

  /// Launch an installed application directly with a pre-filled search query.
  /// (e.g. YouTube "trending songs", Spotify "Taylor Swift", Google Maps "nearest pizza")
  Future<Map<String, dynamic>> searchInApp({
    required String appName,
    required String searchQuery,
  }) async {
    final cleanApp = appName.trim();
    final cleanQuery = searchQuery.trim();
    if (cleanApp.isEmpty || cleanQuery.isEmpty) {
      throw Exception('App name and search query are required.');
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'searchInApp',
        {
          'appName': cleanApp.toLowerCase(),
          'searchQuery': cleanQuery,
        },
      );
      return result ?? {'success': true, 'appName': cleanApp, 'searchQuery': cleanQuery};
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Could not search "$cleanQuery" in $cleanApp.');
    }
  }

  // ── System Settings ─────────────────────────────────────────────────────────

  /// Open native Android settings screen.
  /// [settingType]: wifi | bluetooth | display | brightness | sound | volume |
  ///                battery | location | nfc | apps | accessibility | developer |
  ///                storage | network | default
  Future<Map<String, dynamic>> openSettings({String settingType = 'default'}) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'openSettings',
        {'type': settingType},
      );
      return result ?? {'success': true, 'setting': settingType};
    } on PlatformException catch (e) {
      throw Exception('Could not open $settingType settings: ${e.message ?? e.code}');
    }
  }

  // ── Battery ─────────────────────────────────────────────────────────────────

  /// Query device battery percentage and charging status.
  Future<Map<String, dynamic>> getBatteryStatus() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getBatteryStatus');
      return result ?? {'level': 100, 'isCharging': false};
    } on PlatformException catch (e) {
      throw Exception('Could not fetch battery status: ${e.message ?? e.code}');
    }
  }

  // ── Alarms & Timers ─────────────────────────────────────────────────────────

  /// Set an alarm via native Android AlarmClock intent.
  Future<Map<String, dynamic>> setAlarm({
    required int hour,
    required int minute,
    String message = 'AIRA Alarm',
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'setAlarm',
        {'hour': hour, 'minute': minute, 'message': message},
      );
      return result ?? {'success': true, 'hour': hour, 'minute': minute, 'message': message};
    } on PlatformException catch (e) {
      throw Exception('Could not set alarm: ${e.message ?? e.code}');
    }
  }

  /// Set a countdown timer via native Android AlarmClock intent.
  Future<Map<String, dynamic>> setTimer({
    required int seconds,
    String message = 'AIRA Timer',
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'setTimer',
        {'seconds': seconds, 'message': message},
      );
      return result ?? {'success': true, 'seconds': seconds, 'message': message};
    } on PlatformException catch (e) {
      throw Exception('Could not set timer: ${e.message ?? e.code}');
    }
  }

  // ── Volume Control ──────────────────────────────────────────────────────────

  /// Adjust system volume.
  /// [direction]: "up" | "down" | "mute" | "unmute" | "max" | "min"
  /// [stream]: "media" | "ring" | "alarm" | "notification"
  Future<Map<String, dynamic>> adjustVolume({
    required String direction,
    String stream = 'media',
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'adjustVolume',
        {'direction': direction, 'stream': stream},
      );
      return result ?? {'success': true, 'direction': direction};
    } on PlatformException catch (e) {
      throw Exception('Volume Error: ${e.message ?? e.code}');
    }
  }

  // ── Media Playback ──────────────────────────────────────────────────────────

  /// Control media playback via Android media key dispatch.
  /// [action]: "play_pause" | "play" | "pause" | "next" | "previous" | "stop"
  Future<Map<String, dynamic>> controlMedia({required String action}) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'controlMedia',
        {'action': action},
      );
      return result ?? {'success': true, 'action': action};
    } on PlatformException catch (e) {
      throw Exception('Media Control Error: ${e.message ?? e.code}');
    }
  }

  // ── Clipboard ───────────────────────────────────────────────────────────────

  /// Copy text to the Android clipboard.
  Future<Map<String, dynamic>> copyToClipboard({required String text}) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'copyToClipboard',
        {'text': text},
      );
      return result ?? {'success': true, 'copied': text.take(50)};
    } on PlatformException catch (e) {
      throw Exception('Clipboard Error: ${e.message ?? e.code}');
    }
  }

  // ── Device Info ─────────────────────────────────────────────────────────────

  /// Get full device information: model, Android version, battery, storage.
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getDeviceInfo');
      return result ?? {};
    } on PlatformException catch (e) {
      throw Exception('Device Info Error: ${e.message ?? e.code}');
    }
  }
}

extension _StringTake on String {
  String take(int n) => length > n ? substring(0, n) : this;
}
