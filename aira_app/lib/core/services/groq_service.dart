import 'package:dio/dio.dart';
import 'package:aira_app/config/app_config.dart';

/// Direct Groq API service — calls Llama 3.3 from the app itself.
/// No backend server needed.
class GroqService {
  static final GroqService _instance = GroqService._internal();
  factory GroqService() => _instance;

  late final Dio _dio;

  GroqService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.groqBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Authorization': 'Bearer ${AppConfig.groqApiKey}',
        'Content-Type': 'application/json',
      },
    ));
  }

  /// System prompt that defines AIRA's personality.
  static const String _systemPrompt = '''You are AIRA, a personal AI assistant created for your user. You are warm, helpful, and intelligent.

Key traits:
- You remember context from the conversation and refer back to it naturally
- You give concise, well-structured answers using markdown formatting
- You use code blocks with language tags when showing code
- You're friendly but not overly casual — like a knowledgeable friend
- When asked about yourself, you say you're AIRA (AI Real Assistant)
- You help with coding, studying, planning, writing, and general knowledge
- You format lists, tables, and headers clearly for readability''';

  /// Send a message and get AI response.
  /// [history] is the list of previous messages in OpenAI format:
  /// `[{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]`
  /// [memoryContext] includes long-term saved memories to inject into system prompt.
  Future<String> chat(
    String userMessage,
    List<Map<String, dynamic>> history, {
    String? base64Image,
    String? memoryContext,
  }) async {
    final systemContent = (memoryContext != null && memoryContext.isNotEmpty)
        ? '$_systemPrompt\n$memoryContext'
        : _systemPrompt;

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemContent},
    ];

    if (base64Image != null) {
      // Vision model doesn't support multi-turn conversations yet, so we don't include history
      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': userMessage},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
          }
        ]
      });
    } else {
      messages.addAll(history);
      messages.add({'role': 'user', 'content': userMessage});
    }

    try {
      final response = await _dio.post('/chat/completions', data: {
        'model': base64Image != null ? 'llama-3.2-90b-vision-preview' : AppConfig.groqModel,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 4096,
        'stream': false,
      });

      final data = response.data;
      final content = data['choices'][0]['message']['content'] as String;
      return content.trim();
    } on DioException catch (e) {
      if (e.response != null) {
        final body = e.response?.data;
        final msg = body is Map ? (body['error']?['message'] ?? 'API error') : 'API error';
        throw Exception('Groq API error: $msg');
      }
      throw Exception('Connection failed. Check your internet.');
    } catch (e) {
      throw Exception('Failed to get AI response: $e');
    }
  }
}
