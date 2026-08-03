import 'dart:io';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aira_app/core/services/llm_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

// ──────────────────── State ────────────────────

enum VisionState { idle, captured, analyzing, result, error }

class AiraVisionState {
  final VisionState state;
  final File? capturedImage;
  final String? base64Image;
  final String query;
  final String result;
  final String? errorMessage;

  const AiraVisionState({
    this.state = VisionState.idle,
    this.capturedImage,
    this.base64Image,
    this.query = '',
    this.result = '',
    this.errorMessage,
  });

  AiraVisionState copyWith({
    VisionState? state,
    File? capturedImage,
    String? base64Image,
    String? query,
    String? result,
    String? errorMessage,
  }) {
    return AiraVisionState(
      state: state ?? this.state,
      capturedImage: capturedImage ?? this.capturedImage,
      base64Image: base64Image ?? this.base64Image,
      query: query ?? this.query,
      result: result ?? this.result,
      errorMessage: errorMessage,
    );
  }
}

// ──────────────────── Notifier ────────────────────

class AiraVisionNotifier extends StateNotifier<AiraVisionState> {
  final LlmService _llm = LlmService();
  final FlutterTts _tts = FlutterTts();
  final ImagePicker _picker = ImagePicker();

  AiraVisionNotifier() : super(const AiraVisionState());

  /// Capture image from camera
  Future<void> captureFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo != null) {
        final file = File(photo.path);
        final bytes = await file.readAsBytes();
        final b64 = base64Encode(bytes);
        state = state.copyWith(
          state: VisionState.captured,
          capturedImage: file,
          base64Image: b64,
          result: '',
          errorMessage: null,
        );
      }
    } catch (e) {
      state = state.copyWith(
        state: VisionState.error,
        errorMessage: 'Camera error: $e',
      );
    }
  }

  /// Pick image from gallery
  Future<void> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        final file = File(image.path);
        final bytes = await file.readAsBytes();
        final b64 = base64Encode(bytes);
        state = state.copyWith(
          state: VisionState.captured,
          capturedImage: file,
          base64Image: b64,
          result: '',
          errorMessage: null,
        );
      }
    } catch (e) {
      state = state.copyWith(
        state: VisionState.error,
        errorMessage: 'Gallery error: $e',
      );
    }
  }

  /// Analyze captured image with given query
  Future<void> analyzeImage(String query) async {
    if (state.base64Image == null) return;

    final effectiveQuery = query.trim().isEmpty ? 'Describe this image in detail.' : query.trim();

    state = state.copyWith(
      state: VisionState.analyzing,
      query: effectiveQuery,
      errorMessage: null,
    );

    try {
      final response = await _llm.callLlm(
        userMessage: effectiveQuery,
        base64Image: state.base64Image,
      );
      state = state.copyWith(
        state: VisionState.result,
        result: response,
      );
      // Speak the result aloud
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.speak(response.replaceAll(RegExp(r'[*#`\[\]()]'), ''));
    } catch (e) {
      state = state.copyWith(
        state: VisionState.error,
        errorMessage: 'Analysis failed: $e',
      );
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  void reset() {
    _tts.stop();
    state = const AiraVisionState();
  }

  void retake() {
    _tts.stop();
    state = state.copyWith(
      state: VisionState.idle,
      capturedImage: null,
      base64Image: null,
      result: '',
      errorMessage: null,
    );
  }
}

// ──────────────────── Provider ────────────────────

final airaVisionProvider =
    StateNotifierProvider<AiraVisionNotifier, AiraVisionState>((ref) {
  return AiraVisionNotifier();
});
