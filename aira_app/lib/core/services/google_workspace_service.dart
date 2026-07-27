import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Workspace API service.
/// Handles Gmail, Calendar, Docs, Sheets, Drive, and Google Contacts API calls.
/// Includes persistent connection state so Google Workspace remains connected across app restarts!
class GoogleWorkspaceService {
  static final GoogleWorkspaceService _instance = GoogleWorkspaceService._internal();
  factory GoogleWorkspaceService() => _instance;
  GoogleWorkspaceService._internal();

  // Google OAuth Client ID (web type, for server auth)
  static const _webClientId = '952571077863-8ucblk4et686f7t1hqeuj90mot2othgp.apps.googleusercontent.com';

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;
  String? _accessToken;

  // Cache for recently used spreadsheets: name -> spreadsheetId
  final Map<String, String> _sheetCache = {};

  GoogleSignIn _getGoogleSignIn() {
    _googleSignIn ??= GoogleSignIn(
      serverClientId: _webClientId,
      scopes: [
        'email',
        'profile',
        'https://www.googleapis.com/auth/gmail.send',
        'https://www.googleapis.com/auth/gmail.readonly',
        'https://www.googleapis.com/auth/calendar',
        'https://www.googleapis.com/auth/calendar.events',
        'https://www.googleapis.com/auth/documents',
        'https://www.googleapis.com/auth/spreadsheets',
        'https://www.googleapis.com/auth/drive.readonly',
        'https://www.googleapis.com/auth/drive.file',
        'https://www.googleapis.com/auth/contacts.readonly',
      ],
    );
    return _googleSignIn!;
  }

  // ──────────────────── Auth & Persistence ────────────────────

  /// Sign in to Google and request Workspace scopes. Saves connection state locally.
  Future<bool> signInWithWorkspaceScopes() async {
    try {
      final googleSignIn = _getGoogleSignIn();

      // Force fresh account selection prompt
      try { await googleSignIn.signOut(); } catch (_) {}

      _currentUser = await googleSignIn.signIn();
      if (_currentUser == null) return false;

      final auth = await _currentUser!.authentication;
      _accessToken = auth.accessToken;

      if (_accessToken != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('workspace_connected', true);
        await prefs.setString('workspace_user_email', _currentUser!.email);
        return true;
      }
      return false;
    } catch (e) {
      _accessToken = null;
      return false;
    }
  }

  /// Automatically attempt silent sign-in on app startup to restore active connection.
  Future<bool> trySilentSignIn() async {
    if (_accessToken != null) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final wasConnected = prefs.getBool('workspace_connected') ?? false;
      if (!wasConnected) return false;

      final googleSignIn = _getGoogleSignIn();
      _currentUser = await googleSignIn.signInSilently();
      if (_currentUser != null) {
        final auth = await _currentUser!.authentication;
        _accessToken = auth.accessToken;
        return _accessToken != null;
      }
    } catch (_) {}

    return false;
  }

  /// Disconnect from Google Workspace and clear local saved state.
  Future<void> signOut() async {
    try { await _googleSignIn?.signOut(); } catch (_) {}
    _accessToken = null;
    _currentUser = null;
    _sheetCache.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('workspace_connected');
    await prefs.remove('workspace_user_email');
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

  // ──────────────────── Google Drive API ────────────────────

  /// List recent files in Google Drive.
  Future<List<Map<String, dynamic>>> listRecentDriveFiles({int pageSize = 10}) async {
    _requireConnection();
    final dio = _buildDio('https://www.googleapis.com/drive/v3');

    try {
      final resp = await dio.get(
        '/files',
        queryParameters: {
          'pageSize': pageSize,
          'orderBy': 'modifiedTime desc',
          'fields': 'files(id, name, mimeType, modifiedTime, webViewLink, size)',
          'q': 'trashed = false',
        },
      );

      final files = resp.data['files'] as List? ?? [];
      return files.map<Map<String, dynamic>>((f) => {
        'id': f['id'] ?? '',
        'name': f['name'] ?? 'Untitled',
        'mimeType': f['mimeType'] ?? '',
        'modifiedTime': f['modifiedTime'] ?? '',
        'link': f['webViewLink'] ?? 'https://drive.google.com',
        'size': f['size'] != null ? '${((int.tryParse(f['size'].toString()) ?? 0) / 1024).round()} KB' : 'N/A',
      }).toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message;
      throw Exception('Google Drive list failed: $msg');
    }
  }

  /// Search Drive for files or folders by keyword/name.
  Future<List<Map<String, dynamic>>> searchDriveFiles(String keyword) async {
    _requireConnection();
    final dio = _buildDio('https://www.googleapis.com/drive/v3');

    try {
      final cleanKeyword = keyword.replaceAll("'", "\\'");
      final q = "name contains '$cleanKeyword' and trashed = false";
      final resp = await dio.get(
        '/files',
        queryParameters: {
          'q': q,
          'pageSize': 10,
          'fields': 'files(id, name, mimeType, modifiedTime, webViewLink)',
        },
      );

      final files = resp.data['files'] as List? ?? [];
      return files.map<Map<String, dynamic>>((f) => {
        'id': f['id'] ?? '',
        'name': f['name'] ?? 'Untitled',
        'mimeType': f['mimeType'] ?? '',
        'link': f['webViewLink'] ?? 'https://drive.google.com',
        'isFolder': (f['mimeType'] as String? ?? '').contains('folder'),
      }).toList();
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message;
      throw Exception('Google Drive search failed: $msg');
    }
  }

  /// Upload a text file/note to Google Drive.
  Future<Map<String, dynamic>> uploadTextFileToDrive({
    required String filename,
    required String content,
  }) async {
    _requireConnection();

    final dio = Dio(BaseOptions(
      baseUrl: 'https://www.googleapis.com/upload/drive/v3',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    ));

    final boundary = '----AiraDriveBoundary${DateTime.now().millisecondsSinceEpoch}';

    final metadataJson = jsonEncode({
      'name': filename.endsWith('.txt') ? filename : '$filename.txt',
      'mimeType': 'text/plain',
    });

    final bodyBytes = <int>[];
    bodyBytes.addAll(utf8.encode('--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadataJson\r\n'));
    bodyBytes.addAll(utf8.encode('--$boundary\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n$content\r\n'));
    bodyBytes.addAll(utf8.encode('--$boundary--\r\n'));

    try {
      final resp = await dio.post(
        '/files?uploadType=multipart',
        data: Stream.fromIterable([bodyBytes]),
        options: Options(
          headers: {
            'Content-Type': 'multipart/related; boundary=$boundary',
            'Content-Length': bodyBytes.length.toString(),
          },
        ),
      );

      final fileId = resp.data['id'] as String;
      return {
        'id': fileId,
        'name': resp.data['name'] ?? filename,
        'link': 'https://drive.google.com/file/d/$fileId/view',
      };
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message;
      throw Exception('Drive upload failed: $msg');
    }
  }

  // ──────────────────── Google Contacts API ────────────────────

  /// Search Google Contacts for a person by name and return their email address & display name.
  /// Uses Google People API (v1).
  Future<Map<String, String>?> searchGoogleContactEmail(String nameQuery) async {
    _requireConnection();
    final lowerQuery = nameQuery.toLowerCase().trim();
    if (lowerQuery.isEmpty) return null;

    final dio = _buildDio('https://people.googleapis.com/v1');

    // 1. Try searchContacts endpoint
    try {
      final resp = await dio.get(
        '/people:searchContacts',
        queryParameters: {
          'query': nameQuery,
          'readMask': 'names,emailAddresses',
          'pageSize': 5,
        },
      );

      final results = resp.data['results'] as List? ?? [];
      for (final r in results) {
        final person = r['person'] as Map<String, dynamic>?;
        if (person != null) {
          final emails = person['emailAddresses'] as List? ?? [];
          final names = person['names'] as List? ?? [];
          final displayName = names.isNotEmpty ? (names.first['displayName'] ?? nameQuery) : nameQuery;

          if (emails.isNotEmpty) {
            final email = emails.first['value'] as String?;
            if (email != null && email.contains('@')) {
              return {
                'name': displayName as String,
                'email': email,
              };
            }
          }
        }
      }
    } catch (_) {}

    // 2. Fallback: Connections list (list contacts directly)
    try {
      final resp = await dio.get(
        '/people/me/connections',
        queryParameters: {
          'personFields': 'names,emailAddresses',
          'pageSize': 100,
        },
      );

      final connections = resp.data['connections'] as List? ?? [];
      for (final c in connections) {
        final names = c['names'] as List? ?? [];
        final emails = c['emailAddresses'] as List? ?? [];

        if (emails.isNotEmpty) {
          final displayName = names.isNotEmpty ? (names.first['displayName'] as String? ?? '') : '';
          final email = emails.first['value'] as String? ?? '';

          if (displayName.toLowerCase().contains(lowerQuery) && email.contains('@')) {
            return {
              'name': displayName.isNotEmpty ? displayName : nameQuery,
              'email': email,
            };
          }
        }
      }
    } catch (_) {}

    return null;
  }

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

  /// Send an email via Gmail API. Returns true on success or throws clear Exception on failure.
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
      final resp = await dio.post('/messages/send', data: {'raw': encoded});
      if (resp.statusCode == 200 || resp.statusCode == 201 || resp.data?['id'] != null) {
        return true;
      }
      throw Exception('Gmail server returned unexpected response: ${resp.data}');
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

  // ──────────────────── Google Sheets ────────────────────

  /// Create a new Google Sheet (Spreadsheet).
  Future<Map<String, dynamic>> createSheet({required String title}) async {
    _requireConnection();
    final dio = _buildDio('https://sheets.googleapis.com/v1');

    try {
      final resp = await dio.post(
        '/spreadsheets',
        data: {
          'properties': {'title': title},
        },
      );

      final spreadsheetId = resp.data['spreadsheetId'] as String;
      final link = 'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit';

      // Cache title to ID mapping
      _sheetCache[title.toLowerCase()] = spreadsheetId;

      return {
        'id': spreadsheetId,
        'title': resp.data['properties']?['title'] ?? title,
        'link': link,
      };
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message;
      throw Exception('Google Sheets create failed: $msg');
    }
  }

  /// Search Drive for a spreadsheet by name or ID.
  Future<String?> findSpreadsheetId(String nameOrId) async {
    _requireConnection();

    // If it looks like a spreadsheet ID (length ~44, alphanumeric with -_)
    if (nameOrId.length > 25 && !nameOrId.contains(' ')) {
      return nameOrId;
    }

    final lowerName = nameOrId.toLowerCase().trim();
    if (_sheetCache.containsKey(lowerName)) {
      return _sheetCache[lowerName];
    }

    final dio = _buildDio('https://www.googleapis.com/drive/v3');

    try {
      final q = "mimeType='application/vnd.google-apps.spreadsheet' and name contains '${nameOrId.replaceAll("'", "\\'")}' and trashed = false";
      final resp = await dio.get('/files', queryParameters: {'q': q, 'pageSize': 5});

      final files = resp.data['files'] as List? ?? [];
      if (files.isNotEmpty) {
        final id = files.first['id'] as String;
        _sheetCache[lowerName] = id;
        return id;
      }
      return null;
    } on DioException catch (_) {
      return null;
    }
  }

  /// Append a row of data values to a Google Sheet.
  Future<Map<String, dynamic>> appendSheetRow({
    required String sheetTarget,
    required List<String> values,
  }) async {
    _requireConnection();

    final spreadsheetId = await findSpreadsheetId(sheetTarget);
    if (spreadsheetId == null) {
      throw Exception('Could not find Google Sheet matching "$sheetTarget". Create it first by saying "create a sheet called $sheetTarget".');
    }

    final dio = _buildDio('https://sheets.googleapis.com/v1');

    try {
      final resp = await dio.post(
        '/spreadsheets/$spreadsheetId/values/Sheet1!A1:append',
        queryParameters: {'valueInputOption': 'USER_ENTERED'},
        data: {
          'values': [values],
        },
      );

      final updatedRange = resp.data['updates']?['updatedRange'] ?? 'Sheet1';
      final updatedRows = resp.data['updates']?['updatedRows'] ?? 1;

      return {
        'spreadsheetId': spreadsheetId,
        'updatedRange': updatedRange,
        'updatedRows': updatedRows,
        'link': 'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit',
      };
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message;
      throw Exception('Failed to append row to Google Sheet: $msg');
    }
  }

  /// Read rows/data from a Google Sheet.
  Future<Map<String, dynamic>> readSheetData({
    required String sheetTarget,
    String range = 'Sheet1!A1:Z50',
  }) async {
    _requireConnection();

    final spreadsheetId = await findSpreadsheetId(sheetTarget);
    if (spreadsheetId == null) {
      throw Exception('Could not find Google Sheet matching "$sheetTarget".');
    }

    final dio = _buildDio('https://sheets.googleapis.com/v1');

    try {
      final resp = await dio.get('/spreadsheets/$spreadsheetId/values/$range');

      final rawValues = resp.data['values'] as List? ?? [];
      final rows = rawValues.map((r) => (r as List).map((c) => c.toString()).toList()).toList();

      return {
        'spreadsheetId': spreadsheetId,
        'rows': rows,
        'link': 'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit',
      };
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ?? e.message;
      throw Exception('Failed to read Google Sheet: $msg');
    }
  }

  // ──────────────────── Helpers ────────────────────

  void _requireConnection() {
    if (_accessToken == null) {
      throw Exception('Google Workspace not connected. Say "connect Google Workspace" to link your account.');
    }
  }
}
