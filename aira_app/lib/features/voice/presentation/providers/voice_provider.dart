import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:aira_app/features/chat/presentation/providers/chat_provider.dart';

// ──────────────────── State ────────────────────

class VoiceState {
  final bool isRecording;
  final bool isSpeaking;
  final String transcript;
  final String responseText;
  final bool isLoading;
  final bool isWakeWordDetected;
  final String? error;

  const VoiceState({
    this.isRecording = false,
    this.isSpeaking = false,
    this.transcript = '',
    this.responseText = '',
    this.isLoading = false,
    this.isWakeWordDetected = false,
    this.error,
  });

  VoiceState copyWith({
    bool? isRecording,
    bool? isSpeaking,
    String? transcript,
    String? responseText,
    bool? isLoading,
    bool? isWakeWordDetected,
    String? error,
  }) {
    return VoiceState(
      isRecording: isRecording ?? this.isRecording,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      transcript: transcript ?? this.transcript,
      responseText: responseText ?? this.responseText,
      isLoading: isLoading ?? this.isLoading,
      isWakeWordDetected: isWakeWordDetected ?? this.isWakeWordDetected,
      error: error,
    );
  }
}

// ──────────────────── Notifier ────────────────────

class VoiceNotifier extends StateNotifier<VoiceState> {
  final Ref _ref;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeechInitialized = false;

  VoiceNotifier(this._ref) : super(const VoiceState());

  /// Initialize SpeechToText engine
  Future<bool> _initSpeech() async {
    if (_isSpeechInitialized) return true;
    try {
      _isSpeechInitialized = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (state.isRecording) {
              stopRecordingAndProcess();
            }
          }
        },
        onError: (errorNotification) {
          state = state.copyWith(
            isRecording: false,
            isLoading: false,
            error: 'Speech recognition error: ${errorNotification.errorMsg}',
          );
        },
      );
      return _isSpeechInitialized;
    } catch (e) {
      state = state.copyWith(
        isRecording: false,
        isLoading: false,
        error: 'Microphone permission or engine unavailable.',
      );
      return false;
    }
  }

  /// Start real-time voice recording & listening
  Future<void> startRecording() async {
    final available = await _initSpeech();
    if (!available) {
      state = state.copyWith(
        error: 'Speech recognition is not available on this device.',
      );
      return;
    }

    state = state.copyWith(
      isRecording: true,
      isSpeaking: false,
      transcript: '',
      responseText: '',
      isWakeWordDetected: false,
      error: null,
    );

    await _speech.listen(
      onResult: (result) {
        final recognizedText = result.recognizedWords;
        final lower = recognizedText.toLowerCase();

        bool wakeWord = lower.contains('hey aira') ||
            lower.contains('hey ira') ||
            lower.contains('aira') ||
            lower.contains('ira');

        state = state.copyWith(
          transcript: recognizedText,
          isWakeWordDetected: wakeWord,
        );
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  /// Stop listening and dispatch spoken command to AIRA AI & Device Controller
  Future<void> stopRecordingAndProcess() async {
    if (!state.isRecording) return;

    await _speech.stop();

    final spokenText = state.transcript.trim();

    if (spokenText.isEmpty) {
      state = state.copyWith(
        isRecording: false,
        isLoading: false,
        transcript: 'No speech heard. Try holding the button and speaking.',
      );
      return;
    }

    // Clean off "hey aira" / "aira" wake prefix if present
    String cleanCommand = spokenText;
    final lower = cleanCommand.toLowerCase();
    if (lower.startsWith('hey aira')) {
      cleanCommand = cleanCommand.substring(8).trim();
    } else if (lower.startsWith('hey ira')) {
      cleanCommand = cleanCommand.substring(7).trim();
    } else if (lower.startsWith('aira')) {
      cleanCommand = cleanCommand.substring(4).trim();
    }

    if (cleanCommand.isEmpty) {
      cleanCommand = spokenText;
    }

    state = state.copyWith(
      isRecording: false,
      isLoading: true,
      transcript: spokenText,
    );

    try {
      // Send spoken command directly to AIRA ChatNotifier (handles AI, Workspace, Phone, & Device intents)
      final chatNotifier = _ref.read(chatProvider.notifier);
      await chatNotifier.sendMessage(cleanCommand);

      // Get latest system response from ChatNotifier
      final messages = _ref.read(chatProvider).messages;
      final lastAssistantMsg = messages.lastWhere(
        (m) => m.role == 'assistant' && !m.isStreaming,
        orElse: () => messages.last,
      );

      state = state.copyWith(
        responseText: lastAssistantMsg.content,
        isLoading: false,
        isSpeaking: true,
      );

      // Reset speaking indicator after short delay
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          state = state.copyWith(isSpeaking: false);
        }
      });
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to process command: $e',
      );
    }
  }

  void cancelVoice() {
    _speech.stop();
    state = const VoiceState();
  }
}

// ──────────────────── Provider ────────────────────

final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceState>((ref) {
  return VoiceNotifier(ref);
});
