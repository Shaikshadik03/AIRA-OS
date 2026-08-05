import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Direct TickTick Open API Integration Service for AIRA OS.
/// Endpoints: https://api.ticktick.com/open/v1
class TickTickService {
  static final TickTickService _instance = TickTickService._internal();
  factory TickTickService() => _instance;
  TickTickService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.ticktick.com/open/v1',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'ticktick_access_token';
  String? _accessToken;

  bool get isConnected => _accessToken != null && _accessToken!.isNotEmpty;

  /// Load persisted TickTick Access Token
  Future<void> initialize() async {
    _accessToken = await _storage.read(key: _tokenKey);
  }

  /// Save TickTick Access Token
  Future<void> setAccessToken(String token) async {
    _accessToken = token.trim();
    await _storage.write(key: _tokenKey, value: _accessToken);
  }

  /// Disconnect TickTick
  Future<void> disconnect() async {
    _accessToken = null;
    await _storage.delete(key: _tokenKey);
  }

  Options get _authOptions {
    if (!isConnected) {
      throw Exception('TickTick is not connected. Please enter your TickTick API Access Token in Settings.');
    }
    return Options(headers: {
      'Authorization': 'Bearer $_accessToken',
      'Content-Type': 'application/json',
    });
  }

  /// Fetch user project / task lists
  Future<List<Map<String, dynamic>>> getProjects() async {
    await initialize();
    try {
      final response = await _dio.get('/project', options: _authOptions);
      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } on DioException catch (e) {
      throw Exception('TickTick Projects Error: ${e.message}');
    }
  }

  /// Create a task in TickTick
  Future<Map<String, dynamic>> createTask({
    required String title,
    String? content,
    DateTime? dueDate,
    int priority = 0, // 0: None, 1: Low, 3: Medium, 5: High
    String? projectId,
  }) async {
    await initialize();
    try {
      final data = <String, dynamic>{
        'title': title.trim(),
        'priority': priority,
      };
      if (content != null && content.isNotEmpty) data['content'] = content.trim();
      if (projectId != null && projectId.isNotEmpty) data['projectId'] = projectId;
      if (dueDate != null) {
        data['dueDate'] = dueDate.toUtc().toIso8601String().replaceFirst('Z', '+0000');
      }

      final response = await _dio.post(
        '/task',
        data: data,
        options: _authOptions,
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('TickTick Create Task Error: ${e.message}');
    }
  }

  /// Complete a task in TickTick
  Future<bool> completeTask({
    required String taskId,
    required String projectId,
  }) async {
    await initialize();
    try {
      final response = await _dio.post(
        '/project/$projectId/task/$taskId/complete',
        options: _authOptions,
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('TickTick Complete Task Error: ${e.message}');
    }
  }
}
