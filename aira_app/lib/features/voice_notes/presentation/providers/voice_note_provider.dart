import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:aira_app/core/services/llm_service.dart';
import 'package:aira_app/core/services/google_workspace_service.dart';
import 'package:aira_app/core/services/supabase_memory_service.dart';

enum VoiceNoteState { idle, recording, processing, completed, error }

class VoiceNoteStatus {
  final VoiceNoteState state;
  final int durationSeconds;
  final String transcript;
  final String summary;
  final String? errorMessage;
  final bool isExportedToDoc;
  final bool isExportedToMemory;

  const VoiceNoteStatus({
    this.state = VoiceNoteState.idle,
    this.durationSeconds = 0,
    this.transcript = '',
    this.summary = '',
    this.errorMessage,
    this.isExportedToDoc = false,
    this.isExportedToMemory = false,
  });

  VoiceNoteStatus copyWith({
    VoiceNoteState? state,
    int? durationSeconds,
    String? transcript,
    String? summary,
    String? errorMessage,
    bool? isExportedToDoc,
    bool? isExportedToMemory,
  }) {
    return VoiceNoteStatus(
      state: state ?? this.state,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      transcript: transcript ?? this.transcript,
      summary: summary ?? this.summary,
      errorMessage: errorMessage,
      isExportedToDoc: isExportedToDoc ?? this.isExportedToDoc,
      isExportedToMemory: isExportedToMemory ?? this.isExportedToMemory,
    );
  }
}

class VoiceNoteNotifier extends StateNotifier<VoiceNoteStatus> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final LlmService _llm = LlmService();
  final GoogleWorkspaceService _workspace = GoogleWorkspaceService();
  final SupabaseMemoryService _memory = SupabaseMemoryService();

  Timer? _timer;

  VoiceNoteNotifier() : super(const VoiceNoteStatus());

  /// Start recording meeting audio & transcribing live
  Future<void> startRecording() async {
    final available = await _speech.initialize();
    if (!available) {
      state = state.copyWith(
        state: VoiceNoteState.error,
        errorMessage: 'Microphone permission or speech recognition unavailable.',
      );
      return;
    }

    state = const VoiceNoteStatus(state: VoiceNoteState.recording);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      state = state.copyWith(durationSeconds: state.durationSeconds + 1);
    });

    await _speech.listen(
      onResult: (result) {
        state = state.copyWith(transcript: result.recognizedWords);
      },
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(hours: 1),
        pauseFor: const Duration(seconds: 10),
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  /// Stop recording & generate AI summary
  Future<void> stopRecordingAndSummarize() async {
    _timer?.cancel();
    await _speech.stop();

    final text = state.transcript.trim();
    if (text.isEmpty) {
      state = state.copyWith(
        state: VoiceNoteState.completed,
        summary: 'No speech was detected during the recording session.',
      );
      return;
    }

    state = state.copyWith(state: VoiceNoteState.processing);

    try {
      final prompt = 'You are AIRA, an executive AI assistant. Analyze and summarize this meeting / voice note transcript clearly:\n\n"$text"\n\nFormat your response in GitHub markdown with these sections:\n1. 📋 **Executive Summary**\n2. 💡 **Key Discussion Points**\n3. 🎯 **Action Items & Owners**\n4. 📝 **Key Decisions**';

      final summaryResult = await _llm.callLlm(userMessage: prompt);

      state = state.copyWith(
        state: VoiceNoteState.completed,
        summary: summaryResult,
      );
    } catch (e) {
      state = state.copyWith(
        state: VoiceNoteState.error,
        errorMessage: 'Summarization failed: $e',
      );
    }
  }

  /// Export meeting summary to Google Docs
  Future<void> exportToGoogleDoc(String title) async {
    if (state.summary.isEmpty) return;

    try {
      final docTitle = title.isEmpty ? 'AIRA Meeting Summary — ${DateTime.now().day}/${DateTime.now().month}' : title;
      final doc = await _workspace.createDoc(title: docTitle);
      if (doc.isNotEmpty) {
        state = state.copyWith(isExportedToDoc: true);
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Docs export failed: $e');
    }
  }

  /// Save summary to AIRA AI Long-Term Memory
  Future<void> saveToMemory() async {
    if (state.summary.isEmpty) return;

    try {
      await _memory.saveMemory(
        content: 'Meeting Summary: ${state.summary.substring(0, state.summary.length > 200 ? 200 : state.summary.length)}',
        category: 'meeting',
      );
      state = state.copyWith(isExportedToMemory: true);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Memory save failed: $e');
    }
  }

  void reset() {
    _timer?.cancel();
    _speech.stop();
    state = const VoiceNoteStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _speech.stop();
    super.dispose();
  }
}

final voiceNoteProvider =
    StateNotifierProvider<VoiceNoteNotifier, VoiceNoteStatus>((ref) {
  return VoiceNoteNotifier();
});
