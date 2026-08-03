import 'package:flutter/services.dart';

/// Native Android Device & System Controller Service (Milestone 4).
/// Provides 100% native Android device capabilities via custom MethodChannel.
class AndroidDeviceService {
  static final AndroidDeviceService _instance = AndroidDeviceService._internal();
  factory AndroidDeviceService() => _instance;
  AndroidDeviceService._internal();

  static const MethodChannel _channel = MethodChannel('com.aira.os/device_control');

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

  /// Launch any installed application by display label or package query.
  Future<Map<String, dynamic>> launchApp({required String appName}) async {
    final cleanName = appName.trim();
    if (cleanName.isEmpty) {
      throw Exception('Please specify an app name to launch (e.g. "Open WhatsApp").');
    }

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'launchApp',
        {'query': cleanName},
      );
      return result ?? {'success': true, 'appName': cleanName};
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Could not launch "$cleanName".');
    }
  }

  /// Open native Android settings screen (wifi, bluetooth, display, sound, battery, location, apps, default).
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

  /// Query device battery percentage and charging status.
  Future<Map<String, dynamic>> getBatteryStatus() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getBatteryStatus');
      return result ?? {'level': 100, 'isCharging': false};
    } on PlatformException catch (e) {
      throw Exception('Could not fetch battery status: ${e.message ?? e.code}');
    }
  }

  /// Set an alarm via native Android AlarmClock intent.
  Future<Map<String, dynamic>> setAlarm({
    required int hour,
    required int minute,
    String message = 'AIRA Alarm',
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'setAlarm',
        {
          'hour': hour,
          'minute': minute,
          'message': message,
        },
      );
      return result ?? {'success': true, 'hour': hour, 'minute': minute, 'message': message};
    } on PlatformException catch (e) {
      throw Exception('Could not set alarm: ${e.message ?? e.code}');
    }
  }

  /// Set a timer via native Android AlarmClock intent.
  Future<Map<String, dynamic>> setTimer({
    required int seconds,
    String message = 'AIRA Timer',
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'setTimer',
        {
          'seconds': seconds,
          'message': message,
        },
      );
      return result ?? {'success': true, 'seconds': seconds, 'message': message};
    } on PlatformException catch (e) {
      throw Exception('Could not set timer: ${e.message ?? e.code}');
    }
  }
}
