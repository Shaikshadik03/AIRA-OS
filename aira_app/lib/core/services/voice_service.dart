import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isPassiveWakeWordActive = false;
  String _lastError = '';

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  bool get isPassiveWakeWordActive => _isPassiveWakeWordActive;
  String get lastError => _lastError;

  /// Check microphone permission status
  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Initialize speech engine with microphone permission check
  Future<bool> initialize({Function(String error)? onErrorCallback}) async {
    _lastError = '';
    
    // Check microphone permission
    bool hasPermission = await checkPermission();
    if (!hasPermission) {
      hasPermission = await requestPermission();
      if (!hasPermission) {
        _lastError = 'Microphone permission denied';
        onErrorCallback?.call(_lastError);
        return false;
      }
    }

    try {
      _isInitialized = await _speech.initialize(
        onError: (errorNotification) {
          _isListening = false;
          _lastError = errorNotification.errorMsg;
          onErrorCallback?.call(_lastError);
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
        debugLogging: true,
      );

      if (!_isInitialized) {
        _lastError = 'Speech Recognition service unavailable on this device';
        onErrorCallback?.call(_lastError);
      }
    } catch (e) {
      _isInitialized = false;
      _lastError = 'Initialization failed: $e';
      onErrorCallback?.call(_lastError);
    }

    return _isInitialized;
  }

  /// Start listening for voice commands / Hey AIRA wake word
  Future<bool> startListening({
    required Function(String text, bool isFinal) onResult,
    required Function(String cleanCommand) onCommandTriggered,
    Function(String error)? onError,
  }) async {
    final available = await initialize(onErrorCallback: onError);
    if (!available) {
      onError?.call(_lastError.isNotEmpty ? _lastError : 'Speech recognition not available');
      return false;
    }

    _isListening = true;

    try {
      await _speech.listen(
        onResult: (result) {
          final recognizedWords = result.recognizedWords.trim();
          onResult(recognizedWords, result.finalResult);

          // Check if wake word or complete final result
          if (recognizedWords.isNotEmpty) {
            final cleanCommand = parseWakeWordCommand(recognizedWords);
            if (result.finalResult || isWakeWord(recognizedWords)) {
              HapticFeedback.mediumImpact();
              _speech.stop();
              _isListening = false;
              onCommandTriggered(cleanCommand);
            }
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
      );
      return true;
    } catch (e) {
      _isListening = false;
      _lastError = 'Listen error: $e';
      onError?.call(_lastError);
      return false;
    }
  }

  /// Start Continuous Passive Hands-Free "Hey AIRA" Listening Loop (Siri Style)
  Future<void> startPassiveWakeWordLoop({
    required Function(String recognizedText) onWakeWordDetected,
    required Function(String cleanCommand) onCommandTriggered,
  }) async {
    _isPassiveWakeWordActive = true;

    while (_isPassiveWakeWordActive) {
      if (!_isListening) {
        final started = await startListening(
          onResult: (text, isFinal) {
            if (isWakeWord(text)) {
              onWakeWordDetected(text);
            }
          },
          onCommandTriggered: (command) {
            if (command.isNotEmpty) {
              onCommandTriggered(command);
            }
          },
          onError: (_) {},
        );
        if (!started) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  /// Stop passive wake-word loop
  Future<void> stopPassiveWakeWordLoop() async {
    _isPassiveWakeWordActive = false;
    await stopListening();
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  /// Check if text contains Hey AIRA wake word
  bool isWakeWord(String text) {
    final lower = text.toLowerCase();
    return lower.contains('hey aira') ||
        lower.contains('hey ira') ||
        lower.contains('ok aira') ||
        lower.contains('hello aira') ||
        lower.startsWith('aira');
  }

  /// Strip wake word prefix to extract clean command
  String parseWakeWordCommand(String rawText) {
    String text = rawText.trim();
    final RegExp wakeRegExp = RegExp(
      r'^(hey|ok|hello|hi)?\s*(aira|ira|era|eyra)\b[\s,:]*',
      caseSensitive: false,
    );

    if (wakeRegExp.hasMatch(text)) {
      text = text.replaceFirst(wakeRegExp, '').trim();
    }

    return text.isEmpty ? rawText : text;
  }
}
