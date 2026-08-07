import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Direct TickTick Open API Integration Service for AIRA OS.
/// Endpoints: https://api.ticktick.com/open/v1
class TickTickService {
  static final TickTickService _instance = TickTickService._internal();
  factory TickTickService() => _instance;
  TickTickService._internal();

  static const String clientId = 'Bu1phZur846CAvv76E';
  static const String clientSecret = 'HV2IIr5V0PINcNy05mgd7ad9892UEeUL';
  static const String redirectUri = 'https://localhost';
  static const String scope = 'tasks:write tasks:read';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.ticktick.com/open/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'ticktick_access_token';
  String? _accessToken;
  String lastError = '';

  bool get isConnected => _accessToken != null && _accessToken!.isNotEmpty;

  /// OAuth Authorization URL
  String get authorizationUrl =>
      'https://ticktick.com/oauth/authorize'
      '?client_id=${Uri.encodeComponent(clientId)}'
      '&scope=${Uri.encodeComponent(scope)}'
      '&redirect_uri=${Uri.encodeComponent(redirectUri)}'
      '&response_type=code'
      '&state=aira_os_auth';

  Future<void> initialize() async {
    _accessToken = await _storage.read(key: _tokenKey);
  }

  Future<void> setAccessToken(String token) async {
    _accessToken = token.trim();
    await _storage.write(key: _tokenKey, value: _accessToken);
    lastError = '';
  }

  /// Direct Login with TickTick Account Credentials
  Future<bool> loginWithCredentials({
    required String username,
    required String password,
  }) async {
    lastError = '';
    try {
      final response = await Dio().post(
        'https://api.ticktick.com/api/v2/user/signon?wc=true&remember=true',
        data: {
          'username': username.trim(),
          'password': password,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'x-device': '{"platform":"web","os":"android","deviceId":"aira-os"}',
            'User-Agent': 'Mozilla/5.0',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final token = (data['token'] ?? data['token_id'] ?? data['access_token'] ?? '').toString();
        if (token.isNotEmpty) {
          await setAccessToken(token);
          return true;
        }
      }
      lastError = 'No token returned from TickTick login';
      return false;
    } on DioException catch (e) {
      final body = e.response?.data?.toString() ?? '';
      lastError = 'Login Error: ${e.message}. $body';
      throw Exception(lastError);
    }
  }

  /// Exchange OAuth authorization code for Access Token.
  /// Uses RAW string body to guarantee correct form encoding.
  Future<String> exchangeCodeForToken(String code) async {
    lastError = '';
    final trimmedCode = code.trim();

    // Build URL-encoded body as raw string — no Dio encoding ambiguity
    final body = 'client_id=${Uri.encodeComponent(clientId)}'
        '&client_secret=${Uri.encodeComponent(clientSecret)}'
        '&code=${Uri.encodeComponent(trimmedCode)}'
        '&grant_type=authorization_code'
        '&redirect_uri=${Uri.encodeComponent(redirectUri)}'
        '&scope=${Uri.encodeComponent(scope)}';

    try {
      final response = await Dio().post(
        'https://ticktick.com/oauth/token',
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.data == null) {
        lastError = 'Empty response from TickTick';
        throw Exception(lastError);
      }

      final data = response.data;
      String token = '';
      if (data is Map) {
        token = (data['access_token'] ?? '').toString();
      }

      if (token.isEmpty) {
        lastError = 'No access_token in response: $data';
        throw Exception(lastError);
      }

      await setAccessToken(token);
      return token;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode ?? 'N/A';
      final responseBody = e.response?.data?.toString() ?? 'no body';
      lastError = 'Token exchange failed (HTTP $statusCode): $responseBody';
      throw Exception(lastError);
    }
  }

  /// Smart Parser: Accepts raw token, auth code, or redirect URL
  Future<void> parseAndAuthenticate(String input) async {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) throw Exception('Input cannot be empty');

    // Full URL with code=XXXXX
    if (cleanInput.contains('code=')) {
      final uri = Uri.parse(cleanInput);
      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        await exchangeCodeForToken(code);
        return;
      }
    }

    // Short string → try as auth code first
    if (cleanInput.length < 50 && !cleanInput.startsWith('http')) {
      try {
        await exchangeCodeForToken(cleanInput);
        return;
      } catch (_) {
        // Fall through to try as raw token
      }
    }

    // Treat as direct API token / access token
    await setAccessToken(cleanInput);
    final isValid = await testConnection();
    if (!isValid) {
      await disconnect();
      throw Exception('Token verification failed — does not work with TickTick API.');
    }
  }

  Future<bool> testConnection() async {
    await initialize();
    if (!isConnected) return false;
    try {
      final response = await _dio.get('/project', options: _authOptions);
      return response.statusCode == 200;
    } catch (e) {
      lastError = 'Connection test: $e';
      return false;
    }
  }

  Future<void> disconnect() async {
    _accessToken = null;
    await _storage.delete(key: _tokenKey);
  }

  Options get _authOptions {
    if (!isConnected) {
      throw Exception('TickTick not connected. Go to Settings to connect.');
    }
    return Options(headers: {
      'Authorization': 'Bearer $_accessToken',
      'Content-Type': 'application/json',
    });
  }

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
      };
      if (content != null && content.isNotEmpty) data['content'] = content.trim();
      if (projectId != null && projectId.isNotEmpty) data['projectId'] = projectId;
      if (dueDate != null) {
        data['dueDate'] = dueDate.toUtc().toIso8601String().replaceFirst('Z', '+0000');
      }
      final response = await _dio.post('/task', data: data, options: _authOptions);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('TickTick Create Task Error: ${e.message}');
    }
  }

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
