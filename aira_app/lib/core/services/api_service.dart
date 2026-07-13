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

  // ──────────────────── Planner API ────────────────────

  /// List tasks, optional status filter.
  Future<List<Map<String, dynamic>>> listTasks({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    final response = await _dio.get('/planner/tasks', queryParameters: params);
    return List<Map<String, dynamic>>.from(response.data);
  }

  /// Create a new task.
  Future<Map<String, dynamic>> createTask(Map<String, dynamic> taskData) async {
    final response = await _dio.post('/planner/tasks', data: taskData);
    return response.data;
  }

  /// Update a task.
  Future<Map<String, dynamic>> updateTask(
    String taskId,
    Map<String, dynamic> updateData,
  ) async {
    final response = await _dio.patch('/planner/tasks/$taskId', data: updateData);
    return response.data;
  }

  /// Delete a task.
  Future<void> deleteTask(String taskId) async {
    await _dio.delete('/planner/tasks/$taskId');
  }

  /// List habits.
  Future<List<Map<String, dynamic>>> listHabits() async {
    final response = await _dio.get('/planner/habits');
    return List<Map<String, dynamic>>.from(response.data);
  }

  /// Create a new habit.
  Future<Map<String, dynamic>> createHabit(Map<String, dynamic> habitData) async {
    final response = await _dio.post('/planner/habits', data: habitData);
    return response.data;
  }

  /// Log checking in for a habit.
  Future<Map<String, dynamic>> logHabit(
    String habitId, {
    String? dateStr,
  }) async {
    final params = <String, dynamic>{};
    if (dateStr != null) params['logged_date'] = dateStr;
    final response = await _dio.post('/planner/habits/$habitId/log', queryParameters: params);
    return response.data;
  }

  /// Delete/Deactivate a habit.
  Future<void> deleteHabit(String habitId) async {
    await _dio.delete('/planner/habits/$habitId');
  }

  // ──────────────────── Finance API ────────────────────

  /// List transactions.
  Future<List<Map<String, dynamic>>> listTransactions({int limit = 50}) async {
    final response = await _dio.get('/finance/transactions', queryParameters: {'limit': limit});
    return List<Map<String, dynamic>>.from(response.data);
  }

  /// Create a new transaction.
  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> txData) async {
    final response = await _dio.post('/finance/transactions', data: txData);
    return response.data;
  }

  /// Delete a transaction.
  Future<void> deleteTransaction(String txId) async {
    await _dio.delete('/finance/transactions/$txId');
  }

  /// List category budgets with spent balances.
  Future<List<Map<String, dynamic>>> listBudgets() async {
    final response = await _dio.get('/finance/budgets');
    return List<Map<String, dynamic>>.from(response.data);
  }

  /// Create a budget.
  Future<Map<String, dynamic>> createBudget(Map<String, dynamic> budgetData) async {
    final response = await _dio.post('/finance/budgets', data: budgetData);
    return response.data;
  }

  /// List expense/income category tags.
  Future<List<Map<String, dynamic>>> listCategories() async {
    final response = await _dio.get('/finance/categories');
    return List<Map<String, dynamic>>.from(response.data);
  }

  // ──────────────────── Intelligence (Phase 4) ────────────────────

  /// Perform a web search query.
  Future<Map<String, dynamic>> searchWeb(String query) async {
    final response = await _dio.post('/agents/web-search', data: {'query': query});
    return response.data;
  }

  /// Draft an email.
  Future<Map<String, dynamic>> draftEmail(String prompt) async {
    final response = await _dio.post('/agents/email-draft', data: {'prompt': prompt});
    return response.data;
  }

  /// Generate notes.
  Future<Map<String, dynamic>> generateStudyNotes(String topic) async {
    final response = await _dio.post('/study/generate-notes', data: {'topic': topic});
    return response.data;
  }

  /// Generate MCQs quiz.
  Future<List<Map<String, dynamic>>> generateQuiz(String topic) async {
    final response = await _dio.post('/study/generate-quiz', data: {'topic': topic});
    return List<Map<String, dynamic>>.from(response.data);
  }

  /// Debug code snippet.
  Future<Map<String, dynamic>> debugCode(String code, String language) async {
    final response = await _dio.post('/coding/debug', data: {
      'code': code,
      'language': language,
    });
    return response.data;
  }

  /// Explain code.
  Future<Map<String, dynamic>> explainCode(String code, String language) async {
    final response = await _dio.post('/coding/explain', data: {
      'code': code,
      'language': language,
    });
    return response.data;
  }

  // ──────────────────── Phase 5 Voice, Creative & Business CRM ────────────────────

  /// Transcribe speech audio file.
  Future<String> transcribeAudio(List<int> fileBytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: filename),
    });
    final response = await _dio.post('/voice/stt', data: formData);
    return response.data['transcript'] ?? '';
  }

  /// Synthesize text into voice bytes.
  Future<List<int>> textToSpeech(String text) async {
    final response = await _dio.post(
      '/voice/tts',
      data: {'text': text},
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data as List<int>;
  }

  /// Generate AI image prompt.
  Future<Map<String, dynamic>> generateImage(String prompt) async {
    final response = await _dio.post('/creative/generate-image', data: {'prompt': prompt});
    return response.data;
  }

  /// List CRM business clients.
  Future<List<Map<String, dynamic>>> listClients() async {
    final response = await _dio.get('/business/clients');
    return List<Map<String, dynamic>>.from(response.data);
  }

  /// Add a business client contact.
  Future<Map<String, dynamic>> createClient(Map<String, dynamic> clientData) async {
    final response = await _dio.post('/business/clients', data: clientData);
    return response.data;
  }

  /// Delete a business client contact.
  Future<void> deleteClient(String clientId) async {
    await _dio.delete('/business/clients/$clientId');
  }

  /// Compile print invoices.
  Future<Map<String, dynamic>> generateInvoice(Map<String, dynamic> invoiceData) async {
    final response = await _dio.post('/business/invoices', data: invoiceData);
    return response.data;
  }

  // ──────────────────── Health ────────────────────

  /// Check backend health.
  Future<Map<String, dynamic>> healthCheck() async {
    final response = await _dio.get('/health');
    return response.data;
  }
}
