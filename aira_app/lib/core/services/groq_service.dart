import 'package:aira_app/core/services/llm_service.dart';

/// Legacy alias for GroqService — routes all calls directly to LlmService.
/// No broken code across the app.
class GroqService {
  static final GroqService _instance = GroqService._internal();
  factory GroqService() => _instance;
  GroqService._internal();

  final LlmService _llm = LlmService();

  /// Legacy chat method signature — forwards call to unified LlmService fallback chain.
  Future<String> chat(
    String userMessage,
    List<Map<String, dynamic>> history, {
    String? base64Image,
    String? memoryContext,
  }) async {
    return _llm.callLlm(
      userMessage: userMessage,
      history: history,
      base64Image: base64Image,
      memoryContext: memoryContext,
    );
  }

  /// Provider stats helper
  String get lastProviderName => _llm.lastProviderName;
}
