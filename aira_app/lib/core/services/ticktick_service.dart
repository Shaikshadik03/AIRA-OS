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

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.ticktick.com/open/v1',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ));

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'ticktick_access_token';
  String? _accessToken;

  bool get isConnected => _accessToken != null && _accessToken!.isNotEmpty;

  /// Get 1-Click OAuth Authorization URL
  String get authorizationUrl =>
      'https://ticktick.com/oauth/authorize?client_id=$clientId&scope=tasks:write%20tasks:read&redirect_uri=$redirectUri&response_type=code';

  /// Load persisted TickTick Access Token
  Future<void> initialize() async {
    _accessToken = await _storage.read(key: _tokenKey);
  }

  /// Save TickTick Access Token
  Future<void> setAccessToken(String token) async {
    _accessToken = token.trim();
    await _storage.write(key: _tokenKey, value: _accessToken);
  }

  /// Direct Login with TickTick Account Credentials (No OAuth Required!)
  Future<bool> loginWithCredentials({
    required String username,
    required String password,
  }) async {
    try {
      final response = await Dio().post(
        'https://api.ticktick.com/api/v2/user/signon',
        data: {
          'username': username.trim(),
          'password': password,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'x-device': '{"platform":"web","os":"android"}',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final token = (data['token'] ?? data['token_id'] ?? data['sid'] ?? '') as String;
        if (token.isNotEmpty) {
          await setAccessToken(token);
          return true;
        }
      }
      return false;
    } on DioException catch (e) {
      throw Exception('TickTick Account Login Error: ${e.message}');
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

    // Check if input looks like an auth code vs raw token
    if (cleanInput.length < 50 && !cleanInput.startsWith('http')) {
      try {
        await exchangeCodeForToken(cleanInput);
        return;
      } catch (_) {
        // Fallback to setting as token if exchange fails
      }
    }

    // Otherwise set directly as access token
    await setAccessToken(cleanInput);

    // Verify token by calling API
    final isValid = await testConnection();
    if (!isValid) {
      await disconnect();
      throw Exception('Invalid TickTick Access Token or Code. Connection test failed.');
    }
  }

  /// Test connection with TickTick API
  Future<bool> testConnection() async {
    await initialize();
    if (!isConnected) return false;
    try {
      final response = await _dio.get('/project', options: _authOptions);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Exchange OAuth authorization code for Access Token
  Future<String> exchangeCodeForToken(String code) async {
    try {
      final response = await Dio().post(
        'https://ticktick.com/oauth/token',
        data: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code.trim(),
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        },
        options: Options(headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        }),
      );

      final token = (response.data['access_token'] ?? '') as String;
      if (token.isEmpty) {
        throw Exception('No access token returned from TickTick');
      }
      await setAccessToken(token);
      return token;
    } on DioException catch (e) {
      throw Exception('OAuth Exchange Error: ${e.message}');
    }
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
