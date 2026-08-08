import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Enum representing the authentication type used for TickTick connector
enum TickTickAuthType {
  openApiBearer, // Official API Token (Bearer <token>) -> https://api.ticktick.com/open/v1
  webCookieToken, // Web session cookie (t=<token>) -> https://api.ticktick.com/api/v2
}

/// Claude-Style Connector Engine for TickTick Integration in AIRA OS.
class TickTickService {
  static final TickTickService _instance = TickTickService._internal();
  factory TickTickService() => _instance;
  TickTickService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'ticktick_access_token';
  static const String _authTypeKey = 'ticktick_auth_type';

  static const String clientId = 'Bu1phZur846CAwv76E';
  static const String clientSecret = 'HV2IIr5V0PINcNy05mgd7ad9892UEeUL';
  static const String redirectUri = 'https://localhost';

  String? _token;
  TickTickAuthType _authType = TickTickAuthType.openApiBearer;
  String lastError = '';

  bool get isConnected => _token != null && _token!.isNotEmpty;
  TickTickAuthType get authType => _authType;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  ));

  Future<void> initialize() async {
    _token = await _storage.read(key: _tokenKey);
    final savedType = await _storage.read(key: _authTypeKey);
    if (savedType == 'webCookieToken') {
      _authType = TickTickAuthType.webCookieToken;
    } else {
      _authType = TickTickAuthType.openApiBearer;
    }
  }

  Future<void> _saveAuthData(String token, TickTickAuthType type) async {
    _token = token.trim();
    _authType = type;
    await _storage.write(key: _tokenKey, value: _token);
    await _storage.write(key: _authTypeKey, value: type.name);
    lastError = '';
  }

  /// Option 1: Official API Access Token (Developer Portal / Bearer Token)
  Future<bool> connectWithApiToken(String apiToken) async {
    final cleanToken = apiToken.trim();
    if (cleanToken.isEmpty) throw Exception('API Token cannot be empty');

    await _saveAuthData(cleanToken, TickTickAuthType.openApiBearer);
    final isValid = await testConnection();
    if (!isValid) {
      // Fallback: try testing as web cookie token
      await _saveAuthData(cleanToken, TickTickAuthType.webCookieToken);
      final isValidCookie = await testConnection();
      if (!isValidCookie) {
        await disconnect();
        throw Exception('Token test failed. Make sure your API Token or Session Token is valid.');
      }
    }
    return true;
  }

  /// Option 2: Account Login (Email & Password via v2 Signon)
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
          await _saveAuthData(token, TickTickAuthType.webCookieToken);
          return true;
        }

        final cookies = response.headers['set-cookie'];
        if (cookies != null && cookies.isNotEmpty) {
          for (final cookie in cookies) {
            if (cookie.contains('t=')) {
              final match = RegExp(r't=([^;]+)').firstMatch(cookie);
              if (match != null) {
                final cookieToken = match.group(1)!;
                await _saveAuthData(cookieToken, TickTickAuthType.webCookieToken);
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

  /// Option 3: Direct Session Token / Cookie
  Future<bool> connectWithSessionCookie(String cookieToken) async {
    final cleanToken = cookieToken.trim();
    if (cleanToken.isEmpty) throw Exception('Cookie token cannot be empty');

    await _saveAuthData(cleanToken, TickTickAuthType.webCookieToken);
    final isValid = await testConnection();
    if (!isValid) {
      await disconnect();
      throw Exception('Session cookie test failed. Token may be expired.');
    }
    return true;
  }

  /// Test connection against TickTick API
  Future<bool> testConnection() async {
    await initialize();
    if (!isConnected) return false;

    try {
      if (_authType == TickTickAuthType.openApiBearer) {
        final response = await _dio.get(
          'https://api.ticktick.com/open/v1/project',
          options: Options(headers: {
            'Authorization': 'Bearer $_token',
          }),
        );
        return response.statusCode == 200;
      } else {
        final response = await _dio.get(
          'https://api.ticktick.com/api/v2/projects',
          options: Options(headers: {
            'Cookie': 't=$_token',
          }),
        );
        return response.statusCode == 200;
      }
    } catch (e) {
      lastError = 'Connection test: $e';
      return false;
    }
  }

  Future<void> disconnect() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _authTypeKey);
  }

  Options get _authOptions {
    if (!isConnected) {
      throw Exception('TickTick Connector is not connected. Please connect in Settings.');
    }
    if (_authType == TickTickAuthType.openApiBearer) {
      return Options(headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      });
    } else {
      return Options(headers: {
        'Cookie': 't=$_token',
        'Content-Type': 'application/json',
      });
    }
  }

  String get _baseUrl => _authType == TickTickAuthType.openApiBearer
      ? 'https://api.ticktick.com/open/v1'
      : 'https://api.ticktick.com/api/v2';

  /// Get user project lists
  Future<List<Map<String, dynamic>>> getProjects() async {
    await initialize();
    try {
      final endpoint = _authType == TickTickAuthType.openApiBearer ? '/project' : '/projects';
      final response = await _dio.get('$_baseUrl$endpoint', options: _authOptions);
      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } on DioException catch (e) {
      throw Exception('TickTick Projects Error: ${e.message}');
    }
  }

  /// Create a Task in TickTick
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
      if (_authType == TickTickAuthType.webCookieToken) {
        data['status'] = 0;
      }
      if (content != null && content.isNotEmpty) data['content'] = content.trim();
      if (projectId != null && projectId.isNotEmpty) data['projectId'] = projectId;
      if (dueDate != null) {
        data['dueDate'] = dueDate.toUtc().toIso8601String().replaceFirst('Z', '+0000');
      }

      final response = await _dio.post(
        '$_baseUrl/task',
        data: data,
        options: _authOptions,
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('TickTick Create Task Error: ${e.message}');
    }
  }

  /// Complete a Task in TickTick
  Future<bool> completeTask({
    required String taskId,
    required String projectId,
  }) async {
    await initialize();
    try {
      final response = await _dio.post(
        '$_baseUrl/project/$projectId/task/$taskId/complete',
        options: _authOptions,
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('TickTick Complete Task Error: ${e.message}');
    }
  }
}
