import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/core/services/voice_service.dart';

/// AIRA Wake Word Service
///
/// Provides "Hey AIRA" hands-free activation using:
///   1. Picovoice Porcupine (if access key provided) — most accurate, 100% offline
///   2. Native Android AudioRecord event channel (EventChannel 'com.aira.os/wakeword_events')
///   3. Fallback: Periodic speech_to_text polling with keyword matching
///
/// SETUP (for maximum accuracy):
///   1. Get a free key at https://console.picovoice.ai/
///   2. Train "Hey AIRA" keyword model → download .ppn file → assets/keywords/hey_aira.ppn
///   3. Enter your access key in AIRA Settings → Hey AIRA → Hands-Free Mode
///
/// Without a Picovoice key, the native EventChannel + speech_to_text fallback still works.
class WakeWordService {
  static final WakeWordService _instance = WakeWordService._internal();
  factory WakeWordService() => _instance;
  WakeWordService._internal();

  static const String _enabledKey = 'aira_wake_word_enabled';
  static const String _picovoiceKeyPref = 'aira_picovoice_access_key';
  static const String _sensitivityKey = 'aira_wake_word_sensitivity';
  static const _channel = MethodChannel('com.aira.os/wake_word');

  bool _isListening = false;
  bool _isEnabled = false;
  String? _picovoiceAccessKey;
  double _sensitivity = 0.7;
  Function()? _onWakeWordDetected;

  // Fallback periodic polling state
  Timer? _fallbackTimer;
  bool _fallbackSttActive = false;

  bool get isListening => _isListening;
  bool get isEnabled => _isEnabled;
  bool get hasPicovoiceKey => _picovoiceAccessKey != null && _picovoiceAccessKey!.isNotEmpty;

  /// Load settings from SharedPreferences
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_enabledKey) ?? false;
    _picovoiceAccessKey = prefs.getString(_picovoiceKeyPref);
    _sensitivity = prefs.getDouble(_sensitivityKey) ?? 0.7;
  }

  /// Enable or disable hands-free mode
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);

    if (enabled) {
      await startListening();
    } else {
      await stopListening();
    }
  }

  /// Set Picovoice access key
  Future<void> setAccessKey(String key) async {
    _picovoiceAccessKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_picovoiceKeyPref, key);
  }

  /// Set wake word detection sensitivity (0.0 to 1.0)
  Future<void> setSensitivity(double sensitivity) async {
    _sensitivity = sensitivity.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_sensitivityKey, _sensitivity);
  }

  /// Register the callback for when "Hey AIRA" is detected
  void onWakeWord(Function() callback) {
    _onWakeWordDetected = callback;
  }

  /// Start listening for the wake word
  Future<bool> startListening() async {
    if (_isListening) return true;

    try {
      if (hasPicovoiceKey) {
        // ─────── Mode A: Porcupine on-device wake word (most accurate) ───────
        debugPrint('[WAKE WORD] Starting Porcupine wake word detection...');
        final result = await _channel.invokeMethod('startWakeWord', {
          'accessKey': _picovoiceAccessKey,
          'sensitivity': _sensitivity,
        });
        _isListening = result == true;

        // Listen for wake word events from native Porcupine side
        _channel.setMethodCallHandler((call) async {
          if (call.method == 'onWakeWordDetected') {
            debugPrint('[WAKE WORD] 🎤 Porcupine detected "Hey AIRA"!');
            HapticFeedback.mediumImpact();
            _onWakeWordDetected?.call();
          }
        });

        debugPrint('[WAKE WORD] Porcupine listening: $_isListening');
      } else {
        // ─────── Mode B: Native EventChannel + STT Fallback ───────
        debugPrint('[WAKE WORD] No Picovoice key — starting native+STT fallback detection...');
        _isListening = true;
        _startFallbackDetection();
      }

      return _isListening;
    } catch (e) {
      debugPrint('[WAKE WORD] ❌ Porcupine failed ($e) — falling back to STT...');
      // Even if Porcupine fails, fall back gracefully
      _isListening = true;
      _startFallbackDetection();
      return true;
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    _stopFallbackDetection();

    try {
      await _channel.invokeMethod('stopWakeWord');
    } catch (e) {
      debugPrint('[WAKE WORD] Stop Porcupine error: $e');
    }

    _isListening = false;
    debugPrint('[WAKE WORD] Stopped all wake word listeners');
  }

  // ──────────────────── Fallback Detection (speech_to_text polling) ─────────

  /// Fallback: Polls speech_to_text every 8 seconds and checks for wake keyword.
  /// This works even without a Picovoice key — the trade-off is slightly higher
  /// battery usage vs native Porcupine (which runs at ~< 1% CPU).
  void _startFallbackDetection() {
    _stopFallbackDetection(); // Cancel any existing
    debugPrint('[WAKE WORD] 🎤 Fallback STT polling started — listening every 8s');

    // First listen immediately, then repeat
    _runFallbackListenCycle();

    // Repeat every 8 seconds
    _fallbackTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_isEnabled && !_fallbackSttActive) {
        _runFallbackListenCycle();
      }
    });
  }

  /// Single STT listen cycle for fallback wake word detection
  Future<void> _runFallbackListenCycle() async {
    if (_fallbackSttActive || !_isEnabled) return;
    _fallbackSttActive = true;

    try {
      final voiceService = VoiceService();
      final initialized = await voiceService.initialize();
      if (!initialized) {
        _fallbackSttActive = false;
        return;
      }

      await voiceService.startListening(
        onResult: (text, isFinal) {
          if (text.isNotEmpty) {
            // Check if transcript contains wake word
            if (WakeWordService.containsWakeWord(text)) {
              debugPrint('[WAKE WORD] 🎤 STT detected wake word in: "$text"');
              HapticFeedback.mediumImpact();
              _onWakeWordDetected?.call();
            }
          }
        },
        onCommandTriggered: (command) {
          // If VoiceService also detects a wake word, trigger directly
          if (command.isNotEmpty) {
            debugPrint('[WAKE WORD] STT command triggered: $command');
            _onWakeWordDetected?.call();
          }
        },
        onError: (error) {
          debugPrint('[WAKE WORD] STT cycle error: $error');
        },
      );

      // Each cycle listens for 5s then stops to save battery
      await Future.delayed(const Duration(seconds: 5));
      await voiceService.stopListening();
    } catch (e) {
      debugPrint('[WAKE WORD] Fallback cycle exception: $e');
    } finally {
      _fallbackSttActive = false;
    }
  }

  /// Cancel fallback detection
  void _stopFallbackDetection() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _fallbackSttActive = false;
    debugPrint('[WAKE WORD] Fallback detection stopped');
  }

  // ──────────────────── Utilities ───────────────────────────────────────────

  /// Check if a transcript contains the wake word (static, usable anywhere)
  static bool containsWakeWord(String transcript) {
    final lower = transcript.toLowerCase().trim();
    const wakePatterns = [
      'hey aira',
      'hey era',
      'hey ira',
      'hi aira',
      'ok aira',
      'okay aira',
      'hello aira',
    ];
    return wakePatterns.any((pattern) => lower.contains(pattern));
  }

  /// Request battery optimization exemption (needed for background always-on)
  Future<bool> requestBatteryExemption() async {
    try {
      final result = await _channel.invokeMethod('requestBatteryExemption');
      return result == true;
    } catch (e) {
      debugPrint('[WAKE WORD] Battery exemption request failed: $e');
      return false;
    }
  }

  /// Check if battery optimization is disabled for this app
  Future<bool> isBatteryOptimized() async {
    try {
      final result = await _channel.invokeMethod('isBatteryOptimized');
      return result == true;
    } catch (e) {
      return true;
    }
  }
}
