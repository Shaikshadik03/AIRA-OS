import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/core/services/api_service.dart';

// ──────────────────── State ────────────────────

class CodingState {
  final String? result;
  final bool isLoading;
  final String? error;

  const CodingState({
    this.result,
    this.isLoading = false,
    this.error,
  });

  CodingState copyWith({
    String? result,
    bool? isLoading,
    String? error,
  }) {
    return CodingState(
      result: result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ──────────────────── Notifier ────────────────────

class CodingNotifier extends StateNotifier<CodingState> {
  final ApiService _api = ApiService();

  CodingNotifier() : super(const CodingState());

  Future<void> debugCode(String code, String language) async {
    state = state.copyWith(isLoading: true, error: null, result: null);
    try {
      final res = await _api.debugCode(code, language);
      state = state.copyWith(
        result: res['result'],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> explainCode(String code, String language) async {
    state = state.copyWith(isLoading: true, error: null, result: null);
    try {
      final res = await _api.explainCode(code, language);
      state = state.copyWith(
        result: res['result'],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clear() {
    state = const CodingState();
  }
}

// ──────────────────── Provider ────────────────────

final codingProvider = StateNotifierProvider<CodingNotifier, CodingState>((ref) {
  return CodingNotifier();
});
