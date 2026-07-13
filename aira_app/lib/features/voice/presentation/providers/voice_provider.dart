import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/core/services/api_service.dart';

// ──────────────────── State ────────────────────

class VoiceState {
  final bool isRecording;
  final bool isSpeaking;
  final String transcript;
  final String responseText;
  final bool isLoading;
  final String? error;

  const VoiceState({
    this.isRecording = false,
    this.isSpeaking = false,
    this.transcript = '',
    this.responseText = '',
    this.isLoading = false,
    this.error,
  });

  VoiceState copyWith({
    bool? isRecording,
    bool? isSpeaking,
    String? transcript,
    String? responseText,
    bool? isLoading,
    String? error,
  }) {
    return VoiceState(
      isRecording: isRecording ?? this.isRecording,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      transcript: transcript ?? this.transcript,
      responseText: responseText ?? this.responseText,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ──────────────────── Notifier ────────────────────

class VoiceNotifier extends StateNotifier<VoiceState> {
  final ApiService _api = ApiService();

  VoiceNotifier() : super(const VoiceState());

  void startRecording() {
    state = state.copyWith(
      isRecording: true,
      isSpeaking: false,
      transcript: 'Listening...',
      responseText: '',
      error: null,
    );
  }

  Future<void> stopRecordingAndProcess() async {
    if (!state.isRecording) return;
    
    state = state.copyWith(
      isRecording: false,
      isLoading: true,
      transcript: 'Processing your voice...',
    );

    try {
      // Simulate sending recorded WAV bytes to backend for Whisper transcription
      // In practice, this would read recorded file bytes.
      final mockAudioBytes = List<int>.generate(100, (i) => i);
      
      // Call backend transcription
      final transcript = await _api.transcribeAudio(mockAudioBytes, 'recorded_voice.wav');
      
      String text = transcript.isNotEmpty ? transcript : "Hello, how can I help you today?";
      
      state = state.copyWith(
        transcript: text,
        isLoading: true,
      );

      // Now query AI for response
      // For simplicity, simulate AI voice assistant reply
      await Future.delayed(const Duration(seconds: 1));
      
      final reply = "I understand you said: '$text'. I am here to help you manage your tasks, check your budgets, and keep track of your memories!";
      
      state = state.copyWith(
        responseText: reply,
        isLoading: false,
        isSpeaking: true,
      );

      // Stop speaking simulation after 4 seconds
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          state = state.copyWith(isSpeaking: false);
        }
      });

    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        transcript: '',
        error: 'Voice processing failed. Please try again.',
      );
    }
  }

  void cancelVoice() {
    state = const VoiceState();
  }
}

// ──────────────────── Provider ────────────────────

final voiceProvider = StateNotifierProvider<VoiceNotifier, VoiceState>((ref) {
  return VoiceNotifier();
});
