import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/core/services/api_service.dart';

// ──────────────────── State ────────────────────

class CreativeState {
  final List<String> galleryUrls;
  final bool isLoading;
  final String? error;

  const CreativeState({
    this.galleryUrls = const [],
    this.isLoading = false,
    this.error,
  });

  CreativeState copyWith({
    List<String>? galleryUrls,
    bool? isLoading,
    String? error,
  }) {
    return CreativeState(
      galleryUrls: galleryUrls ?? this.galleryUrls,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ──────────────────── Notifier ────────────────────

class CreativeNotifier extends StateNotifier<CreativeState> {
  final ApiService _api = ApiService();

  CreativeNotifier() : super(const CreativeState());

  Future<void> generateImage(String prompt) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.generateImage(prompt);
      final newUrl = res['image_url'] as String;

      state = state.copyWith(
        galleryUrls: [newUrl, ...state.galleryUrls],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearGallery() {
    state = const CreativeState();
  }
}

// ──────────────────── Provider ────────────────────

final creativeProvider = StateNotifierProvider<CreativeNotifier, CreativeState>((ref) {
  return CreativeNotifier();
});
