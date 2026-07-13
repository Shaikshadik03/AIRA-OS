import 'package:dio/dio.dart';
import 'package:aira_app/config/app_config.dart';

/// Centralized Dio HTTP client for communicating with the AIRA backend.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  String? _authToken;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.backendUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
  }

  /// Set the auth token for authenticated requests.
  void setAuthToken(String token) {
    _authToken = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear the auth token on logout.
  void clearAuthToken() {
    _authToken = null;
    _dio.options.headers.remove('Authorization');
  }

  bool get isAuthenticated => _authToken != null;

  // ──────────────────── Chat API ────────────────────

  /// Create a new conversation.
  Future<Map<String, dynamic>> createConversation({String? title}) async {
    final response = await _dio.post('/chat/conversations', data: {
      'title': title,
    });
    return response.data;
  }

  /// List user's conversations.
  Future<List<Map<String, dynamic>>> listConversations({int limit = 20}) async {
    final response = await _dio.get('/chat/conversations', queryParameters: {
      'limit': limit,
    });
    return List<Map<String, dynamic>>.from(response.data);
  }

  /// Get a conversation with all messages.
  Future<Map<String, dynamic>> getConversation(String conversationId) async {
    final response = await _dio.get('/chat/conversations/$conversationId');
    return response.data;
  }

  /// Send a message and get AI response.
  Future<Map<String, dynamic>> sendMessage(
    String conversationId,
    String content,
  ) async {
    final response = await _dio.post(
      '/chat/conversations/$conversationId/messages',
      data: {'content': content},
    );
    return response.data;
  }

  /// Delete a conversation.
  Future<void> deleteConversation(String conversationId) async {
    await _dio.delete('/chat/conversations/$conversationId');
  }

  // ──────────────────── Memory API ────────────────────

  /// List stored memories.
  Future<List<Map<String, dynamic>>> listMemories({
    String? category,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (category != null) params['category'] = category;

    final response = await _dio.get('/memory/', queryParameters: params);
    return List<Map<String, dynamic>>.from(response.data);
  }

  /// Search memories.
  Future<List<Map<String, dynamic>>> searchMemories(String query) async {
    final response = await _dio.get('/memory/search', queryParameters: {
      'q': query,
    });
    return List<Map<String, dynamic>>.from(response.data);
  }

  /// Delete a memory.
  Future<void> deleteMemory(String memoryId) async {
    await _dio.delete('/memory/$memoryId');
  }

  // ──────────────────── Health ────────────────────

  /// Check backend health.
  Future<Map<String, dynamic>> healthCheck() async {
    final response = await _dio.get('/health');
    return response.data;
  }
}
