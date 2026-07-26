import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';

/// Google Workspace API service.
/// Handles Gmail, Calendar, and Docs API calls using the user's Google OAuth token.
class GoogleWorkspaceService {
  static final GoogleWorkspaceService _instance = GoogleWorkspaceService._internal();
  factory GoogleWorkspaceService() => _instance;
  GoogleWorkspaceService._internal();

  // Google OAuth Client ID (web type, for server auth)
  static const _webClientId = '952571077863-8ucblk4et686f7t1hqeuj90mot2othgp.apps.googleusercontent.com';

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  String? _accessToken;

  // ──────────────────── Auth ────────────────────

  /// Sign in to Google and request Workspace scopes.
  Future<bool> signInWithWorkspaceScopes() async {
    try {
      _googleSignIn = GoogleSignIn(
        serverClientId: _webClientId,
        scopes: [
          'email',
          'profile',
          'https://www.googleapis.com/auth/gmail.send',
          'https://www.googleapis.com/auth/gmail.readonly',
          'https://www.googleapis.com/auth/calendar',
          'https://www.googleapis.com/auth/calendar.events',
          'https://www.googleapis.com/auth/documents',
        ],
      );

      // Force fresh account selection
      try { await _googleSignIn!.signOut(); } catch (_) {}

      _currentUser = await _googleSignIn!.signIn();
      if (_currentUser == null) return false;

      final auth = await _currentUser!.authentication;
      _accessToken = auth.accessToken;
      return _accessToken != null;
    } catch (e) {
      _accessToken = null;
      return false;
    }
  }

  /// Disconnect from Google Workspace.
  Future<void> signOut() async {
    try { await _googleSignIn?.signOut(); } catch (_) {}
    _accessToken = null;
    _currentUser = null;
  }

  bool get isConnected => _accessToken != null;
  String get userEmail => _currentUser?.email ?? '';
  String get userName => _currentUser?.displayName ?? '';

  Dio _buildDio(String baseUrl) => Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      ));

  // ──────────────────── Gmail ────────────────────

  /// List recent inbox emails.
  Future<List<Map<String, dynamic>>> listEmails({int maxResults = 5}) async {
    _requireConnection();
    final dio = _buildDio('https://gmail.googleapis.com/gmail/v1/users/me');

    try {
      final listResp = await dio.get(
        '/messages',
        queryParameters: {'maxResults': maxResults, 'labelIds': 'INBOX'},
      );

      final messages = listResp.data['messages'] as List? ?? [];
      final emails = <Map<String, dynamic>>[];

      for (final msg in messages.take(5)) {
        try {
          final detail = await dio.get(
            '/messages/${msg['id']}',
            queryParameters: {
              'format': 'metadata',
              'metadataHeaders': ['Subject', 'From', 'Date'],
            },
          );
          final headers = (detail.data['payload']['headers'] as List).fold<Map<String, String>>(
            {},
            (map, h) { map[h['name'] as String] = h['value'] as String? ?? ''; return map; },
          );
          emails.add({
            'id': msg['id'],
            'subject': headers['Subject'] ?? '(no subject)',
            'from': headers['From'] ?? '',
            'date': headers['Date'] ?? '',
            'snippet': detail.data['snippet'] ?? '',
          });
        } catch (_) {}
      }

      return emails;
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message;
      throw Exception('Gmail API error: $msg');
    }
  }

  /// Send an email via Gmail API.
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    _requireConnection();

    if (!to.contains('@') || !to.contains('.')) {
      throw Exception('Invalid email address "$to". Please provide a valid email like name@example.com.');
    }

    final dio = _buildDio('https://gmail.googleapis.com/gmail/v1/users/me');

    // Build RFC 2822 formatted email
    final rawEmail = [
      'To: $to',
      'Subject: $subject',
      'Content-Type: text/plain; charset=utf-8',
      'MIME-Version: 1.0',
      '',
      body,
    ].join('\r\n');

    // RFC 4648 URL-safe Base64 WITHOUT padding '=' (required by Gmail API)
    final encoded = base64Url.encode(utf8.encode(rawEmail)).replaceAll('=', '');

    try {
      await dio.post('/messages/send', data: {'raw': encoded});
      return true;
    } on DioException catch (e) {
      final errorData = e.response?.data;
      final msg = errorData is Map ? (errorData['error']?['message'] ?? e.message) : e.message;
      throw Exception('Gmail send failed: $msg');
    }
  }

  // ──────────────────── Calendar ────────────────────

  /// List upcoming events from primary calendar.
  Future<List<Map<String, dynamic>>> listEvents({int maxResults = 10}) async {
    _requireConnection();
    final dio = _buildDio('https://www.googleapis.com/calendar/v3');

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final resp = await dio.get(
        '/calendars/primary/events',
        queryParameters: {
          'maxResults': maxResults,
          'timeMin': now,
          'orderBy': 'startTime',
          'singleEvents': true,
        },
      );

      final items = resp.data['items'] as List? ?? [];
      return items.map<Map<String, dynamic>>((e) => {
        'id': e['id'] ?? '',
        'title': e['summary'] ?? '(no title)',
        'start': e['start']?['dateTime'] ?? e['start']?['date'] ?? '',
        'end': e['end']?['dateTime'] ?? e['end']?['date'] ?? '',
        'location': e['location'] ?? '',
        'description': e['description'] ?? '',
      }).toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message;
      throw Exception('Calendar API error: $msg');
    }
  }

  /// Create a calendar event.
  Future<Map<String, dynamic>> createEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
    String? location,
  }) async {
    _requireConnection();
    final dio = _buildDio('https://www.googleapis.com/calendar/v3');

    try {
      final resp = await dio.post('/calendars/primary/events', data: {
        'summary': title,
        'description': description ?? '',
        'location': location ?? '',
        'start': {'dateTime': start.toIso8601String(), 'timeZone': 'Asia/Kolkata'},
        'end': {'dateTime': end.toIso8601String(), 'timeZone': 'Asia/Kolkata'},
      });

      return {
        'id': resp.data['id'] ?? '',
        'title': resp.data['summary'] ?? title,
        'link': resp.data['htmlLink'] ?? '',
      };
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message;
      throw Exception('Calendar create event failed: $msg');
    }
  }

  // ──────────────────── Google Docs ────────────────────

  /// Create a new Google Doc and return its link.
  Future<Map<String, dynamic>> createDoc({required String title}) async {
    _requireConnection();
    final dio = _buildDio('https://docs.googleapis.com/v1');

    try {
      final resp = await dio.post('/documents', data: {'title': title});

      final docId = resp.data['documentId'] as String;
      return {
        'id': docId,
        'title': resp.data['title'] ?? title,
        'link': 'https://docs.google.com/document/d/$docId/edit',
      };
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message;
      throw Exception('Google Docs create failed: $msg');
    }
  }

  // ──────────────────── Helpers ────────────────────

  void _requireConnection() {
    if (_accessToken == null) {
      throw Exception('Google Workspace not connected. Say "connect Google Workspace" to link your account.');
    }
  }
}
