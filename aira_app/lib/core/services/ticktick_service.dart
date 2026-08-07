import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Direct TickTick Open API Integration Service for AIRA OS.
/// Endpoints: https://api.ticktick.com/open/v1
///
/// TickTick OAuth docs: credentials go in POST body as form fields.
/// Token endpoint: POST https://ticktick.com/oauth/token
///   Content-Type: application/x-www-form-urlencoded
///   Body: client_id, client_secret, code, grant_type, redirect_uri, scope
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

  /// Last error message for debugging
  String lastError = '';

  bool get isConnected => _accessToken != null && _accessToken!.isNotEmpty;

  /// OAuth Authorization URL
  String get authorizationUrl {
    final params = {
      'client_id': clientId,
      'scope': scope,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'state': 'aira_os_auth',
    };
    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'https://ticktick.com/oauth/authorize?$query';
  }

  /// Load persisted TickTick Access Token
  Future<void> initialize() async {
    _accessToken = await _storage.read(key: _tokenKey);
  }

  /// Save TickTick Access Token
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

  /// Exchange OAuth authorization code for Access Token
  ///
  /// TickTick docs: send client_id, client_secret in POST body
  /// Content-Type: application/x-www-form-urlencoded
  Future<String> exchangeCodeForToken(String code) async {
    lastError = '';
    try {
      // Build form data exactly as TickTick expects
      final formData = {
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': code.trim(),
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
        'scope': scope,
      };

      final response = await Dio().post(
        'https://ticktick.com/oauth/token',
        data: formData,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      if (response.data == null) {
        lastError = 'Empty response from TickTick token endpoint';
        throw Exception(lastError);
      }

      final data = response.data;
      String token = '';
      if (data is Map) {
        token = (data['access_token'] ?? '').toString();
      }

      if (token.isEmpty) {
        lastError = 'No access_token in response. Response: $data';
        throw Exception(lastError);
      }

      await setAccessToken(token);
      return token;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode ?? 'unknown';
      final responseBody = e.response?.data?.toString() ?? 'no body';
      lastError = 'OAuth token exchange failed.\n'
          'Status: $statusCode\n'
          'Response: $responseBody\n'
          'Error: ${e.message}';
      throw Exception(lastError);
    } catch (e) {
      if (lastError.isEmpty) lastError = e.toString();
      rethrow;
    }
  }

  /// Smart Parser: Accepts raw token, authorization code, or full redirect URL
  Future<void> parseAndAuthenticate(String input) async {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) {
      throw Exception('Input cannot be empty');
    }

    // Check if full URL containing code=XXXXX
    if (cleanInput.contains('code=')) {
      final uri = Uri.parse(cleanInput);
      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        await exchangeCodeForToken(code);
        return;
      }
    }

    // Check if input looks like a short auth code (not a long token)
    if (cleanInput.length < 50 && !cleanInput.startsWith('http')) {
      try {
        await exchangeCodeForToken(cleanInput);
        return;
      } catch (_) {
        // If code exchange fails, try setting as raw token below
      }
    }

    // Otherwise treat as direct access token / API token
    await setAccessToken(cleanInput);

    // Verify token works
    final isValid = await testConnection();
    if (!isValid) {
      await disconnect();
      throw Exception('Token verification failed. The token does not work with TickTick API.');
    }
  }

  /// Test connection with TickTick API
  Future<bool> testConnection() async {
    await initialize();
    if (!isConnected) return false;
    try {
      final response = await _dio.get('/project', options: _authOptions);
      return response.statusCode == 200;
    } catch (e) {
      lastError = 'Connection test failed: $e';
      return false;
    }
  }

  /// Disconnect TickTick
  Future<void> disconnect() async {
    _accessToken = null;
    await _storage.delete(key: _tokenKey);
  }

  Options get _authOptions {
    if (!isConnected) {
      throw Exception('TickTick is not connected. Please connect in Settings.');
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
