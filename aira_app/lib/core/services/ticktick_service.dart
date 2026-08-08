import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Direct TickTick Integration Service using TickTick Web/Mobile API (v2).
/// Bypasses OAuth registration constraints by using direct session signon / cookie auth.
class TickTickService {
  static final TickTickService _instance = TickTickService._internal();
  factory TickTickService() => _instance;
  TickTickService._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.ticktick.com/api/v2',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'x-device': '{"platform":"web","os":"android","deviceId":"aira-os"}',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  ));

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'ticktick_session_token';
  String? _sessionToken;
  String lastError = '';

  bool get isConnected => _sessionToken != null && _sessionToken!.isNotEmpty;

  Future<void> initialize() async {
    _sessionToken = await _storage.read(key: _tokenKey);
  }

  Future<void> setAccessToken(String token) async {
    _sessionToken = token.trim();
    await _storage.write(key: _tokenKey, value: _sessionToken);
    lastError = '';
  }

  /// Direct Signon using Username & Password via TickTick v2 API
  Future<bool> loginWithCredentials({
    required String username,
    required String password,
  }) async {
    lastError = '';
    try {
      final response = await Dio().post(
        'https://ticktick.com/api/v2/user/signon?wc=true&remember=true',
        data: {
          'username': username.trim(),
          'password': password,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'x-device': '{"platform":"web","os":"android","deviceId":"aira-os"}',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final token = (data['token'] ?? data['token_id'] ?? data['access_token'] ?? data['id'] ?? '').toString();
        if (token.isNotEmpty) {
          await setAccessToken(token);
          return true;
        }

        // Try extracting set-cookie header if token not in body
        final cookies = response.headers['set-cookie'];
        if (cookies != null && cookies.isNotEmpty) {
          for (final cookie in cookies) {
            if (cookie.contains('t=')) {
              final match = RegExp(r't=([^;]+)').firstMatch(cookie);
              if (match != null) {
                final cookieToken = match.group(1)!;
                await setAccessToken(cookieToken);
                return true;
              }
            }
          }
        }
      }
      lastError = 'Invalid credentials or no token returned from TickTick.';
      return false;
    } on DioException catch (e) {
      final body = e.response?.data?.toString() ?? '';
      lastError = 'TickTick Login Error (${e.response?.statusCode ?? 'N/A'}): $body';
      throw Exception(lastError);
    }
  }

  /// Direct token saver / manual session token input
  Future<void> saveToken(String input) async {
    final cleanToken = input.trim();
    if (cleanToken.isEmpty) throw Exception('Token cannot be empty');
    await setAccessToken(cleanToken);
    final isValid = await testConnection();
    if (!isValid) {
      await disconnect();
      throw Exception('Session token test failed. Check if token is valid.');
    }
  }

  Future<bool> testConnection() async {
    await initialize();
    if (!isConnected) return false;
    try {
      final response = await _dio.get('/projects', options: _authOptions);
      return response.statusCode == 200;
    } catch (e) {
      lastError = 'Connection test failed: $e';
      return false;
    }
  }

  Future<void> disconnect() async {
    _sessionToken = null;
    await _storage.delete(key: _tokenKey);
  }

  Options get _authOptions {
    if (!isConnected) {
      throw Exception('TickTick is not connected.');
    }
    return Options(headers: {
      'Cookie': 't=$_sessionToken',
    });
  }

  /// Get projects / lists
  Future<List<Map<String, dynamic>>> getProjects() async {
    await initialize();
    try {
      final response = await _dio.get('/projects', options: _authOptions);
      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } on DioException catch (e) {
      throw Exception('TickTick Projects Error: ${e.message}');
    }
  }

  /// Create a task using v2 API
  Future<Map<String, dynamic>> createTask({
    required String title,
    String? content,
    DateTime? dueDate,
    int priority = 0,
    String? projectId,
  }) async {
    await initialize();
    try {
      final data = <String, dynamic>{
        'title': title.trim(),
        'priority': priority,
        'status': 0,
      };
      if (content != null && content.isNotEmpty) data['content'] = content.trim();
      if (projectId != null && projectId.isNotEmpty) data['projectId'] = projectId;
      if (dueDate != null) {
        data['dueDate'] = dueDate.toUtc().toIso8601String().replaceFirst('Z', '+0000');
      }
      final response = await _dio.post('/task', data: data, options: _authOptions);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('TickTick Task Error: ${e.message}');
    }
  }

  /// Complete a task using v2 API
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
