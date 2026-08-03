import 'package:flutter/services.dart';

class OverlayService {
  static const MethodChannel _channel = MethodChannel('com.aira.os/device_control');

  Future<bool> canDrawOverlays() async {
    try {
      final bool? result = await _channel.invokeMethod('canDrawOverlays');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  Future<bool> startOverlay() async {
    try {
      final bool? result = await _channel.invokeMethod('startOverlay');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopOverlay() async {
    try {
      final bool? result = await _channel.invokeMethod('stopOverlay');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
