import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;

  /// Initialize speech engine with microphone permission check
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // Check microphone permission
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      return false;
    }

    _isInitialized = await _speech.initialize(
      onError: (error) {
        _isListening = false;
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
        }
      },
    );

    return _isInitialized;
  }

  /// Start listening for voice commands / Hey AIRA wake word
  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    required Function(String cleanCommand) onCommandTriggered,
  }) async {
    final available = await initialize();
    if (!available) return;

    _isListening = true;

    await _speech.listen(
      onResult: (result) {
        final recognizedWords = result.recognizedWords.trim();
        onResult(recognizedWords, result.finalResult);

        // Check if wake word or complete final result
        if (recognizedWords.isNotEmpty) {
          final cleanCommand = parseWakeWordCommand(recognizedWords);
          if (result.finalResult || isWakeWord(recognizedWords)) {
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
