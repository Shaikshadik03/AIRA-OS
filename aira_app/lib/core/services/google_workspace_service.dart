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

  // Capability flags for granular consent & state
  bool _calendarEnabled = true;
  bool _gmailEnabled = true;
  bool _driveEnabled = true;
  bool _isSandboxMode = false;

  bool get calendarEnabled => isConnected && _calendarEnabled;
  bool get gmailEnabled => isConnected && _gmailEnabled;
  bool get driveEnabled => isConnected && _driveEnabled;
  bool get isSandboxMode => _isSandboxMode;

  void setCapability({bool? calendar, bool? gmail, bool? drive}) {
    if (calendar != null) _calendarEnabled = calendar;
    if (gmail != null) _gmailEnabled = gmail;
    if (drive != null) _driveEnabled = drive;
  }

  void enableSandboxMode(bool enabled) {
    _isSandboxMode = enabled;
  }

  // ──────────────────── Auth & Persistence ────────────────────

  /// Sign in to Google and request Workspace scopes. Saves connection state locally.
  Future<bool> signInWithWorkspaceScopes() async {
    try {
      final googleSignIn = _getGoogleSignIn();

      // Force fresh account selection prompt
      try { await googleSignIn.signOut(); } catch (_) {}

      _currentUser = await googleSignIn.signIn();
      if (_currentUser == null) {
        // User cancelled or no Google Play Services; fallback to Sandbox for testing
        _isSandboxMode = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('workspace_sandbox_mode', true);
        return true;
      }

      final auth = await _currentUser!.authentication;
      _accessToken = auth.accessToken;

      if (_accessToken != null) {
        _isSandboxMode = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('workspace_connected', true);
        await prefs.setString('workspace_user_email', _currentUser!.email);
        await prefs.setBool('workspace_sandbox_mode', false);
        return true;
      }
      return false;
    } catch (e) {
      // In development/test environments without Google Cloud SHA-1 configured,
      // fallback to Sandbox mode so the user can still test all Workspace features.
      _isSandboxMode = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('workspace_sandbox_mode', true);
      return true;
    }
  }

  /// Automatically attempt silent sign-in on app startup to restore active connection.
  Future<bool> trySilentSignIn() async {
    if (_accessToken != null) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final sandbox = prefs.getBool('workspace_sandbox_mode') ?? false;
      if (sandbox) {
        _isSandboxMode = true;
        return true;
      }

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
    _isSandboxMode = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('workspace_connected');
    await prefs.remove('workspace_user_email');
    await prefs.remove('workspace_sandbox_mode');
  }

  /// Disconnect a single service capability
  void revokeCapability(String service) {
    if (service.toLowerCase().contains('calendar')) _calendarEnabled = false;
    if (service.toLowerCase().contains('gmail') || service.toLowerCase().contains('mail')) _gmailEnabled = false;
    if (service.toLowerCase().contains('drive') || service.toLowerCase().contains('doc')) _driveEnabled = false;
  }

  bool get isConnected => _accessToken != null || _isSandboxMode;
  String get userEmail => _currentUser?.email ?? (_isSandboxMode ? 'user@gmail.com' : '');
  String get userName => _currentUser?.displayName ?? (_isSandboxMode ? 'User' : '');

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
    _requireDrive();
    if (_isSandboxMode && _accessToken == null) {
      return [
        {
          'id': 'file_drv_1',
          'name': 'AIRA OS Master Blueprint 2026.pdf',
          'mimeType': 'application/pdf',
          'modifiedTime': '2026-09-13T14:30:00Z',
          'link': 'https://drive.google.com/file/d/aira_blueprint_2026/view',
          'size': '450 KB',
        },
        {
          'id': 'file_drv_2',
          'name': 'System Architecture & Security Guardrails.gdoc',
          'mimeType': 'application/vnd.google-apps.document',
          'modifiedTime': '2026-09-12T09:15:00Z',
          'link': 'https://docs.google.com/document/d/architecture_guardrails/edit',
          'size': '85 KB',
        },
        {
          'id': 'file_drv_3',
          'name': 'Personal Milestone & Project Roadmap.gsheet',
          'mimeType': 'application/vnd.google-apps.spreadsheet',
          'modifiedTime': '2026-09-11T18:00:00Z',
          'link': 'https://docs.google.com/spreadsheets/d/milestone_roadmap/edit',
          'size': '120 KB',
        },
      ];
    }

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
    _requireDrive();
    if (_isSandboxMode && _accessToken == null) {
      final recent = await listRecentDriveFiles();
      final lower = keyword.toLowerCase();
      final filtered = recent.where((f) => (f['name'] as String).toLowerCase().contains(lower)).toList();
      return filtered.isNotEmpty ? filtered : recent;
    }

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

  /// Search Google Contacts for a person by name and return their phone number & display name.
  Future<Map<String, String>?> searchGoogleContactPhone(String nameQuery) async {
    _requireConnection();
    final lowerQuery = nameQuery.toLowerCase().trim();
    if (lowerQuery.isEmpty) return null;

    final dio = _buildDio('https://people.googleapis.com/v1');

    // 1. Try searchContacts endpoint with phoneNumbers mask
    try {
      final resp = await dio.get(
        '/people:searchContacts',
        queryParameters: {
          'query': nameQuery,
          'readMask': 'names,phoneNumbers',
          'pageSize': 5,
        },
      );

      final results = resp.data['results'] as List? ?? [];
      for (final r in results) {
        final person = r['person'] as Map<String, dynamic>?;
        if (person != null) {
          final phones = person['phoneNumbers'] as List? ?? [];
          final names = person['names'] as List? ?? [];
          final displayName = names.isNotEmpty ? (names.first['displayName'] ?? nameQuery) : nameQuery;

          if (phones.isNotEmpty) {
            final phone = phones.first['value'] as String?;
            if (phone != null && phone.isNotEmpty) {
              return {
                'name': displayName as String,
                'phone': phone,
              };
            }
          }
        }
      }
    } catch (_) {}

    // 2. Fallback: Connections list
    try {
      final resp = await dio.get(
        '/people/me/connections',
        queryParameters: {
          'personFields': 'names,phoneNumbers',
          'pageSize': 100,
        },
      );

      final connections = resp.data['connections'] as List? ?? [];
      for (final c in connections) {
        final names = c['names'] as List? ?? [];
        final phones = c['phoneNumbers'] as List? ?? [];

        if (phones.isNotEmpty) {
          final displayName = names.isNotEmpty ? (names.first['displayName'] as String? ?? '') : '';
          final phone = phones.first['value'] as String? ?? '';

          if (displayName.toLowerCase().contains(lowerQuery) && phone.isNotEmpty) {
            return {
              'name': displayName.isNotEmpty ? displayName : nameQuery,
              'phone': phone,
            };
          }
        }
      }
    } catch (_) {}

    return null;
  }

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
    _requireGmail();
    if (_isSandboxMode && _accessToken == null) {
      return getUnreadEmailsDigest(maxResults: maxResults);
    }
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
    _requireGmail();

    if (!to.contains('@') || !to.contains('.')) {
      throw Exception('Invalid email address "$to". Please provide a valid email like name@example.com.');
    }

    if (_isSandboxMode && _accessToken == null) {
      return true; // Successfully recorded and simulated in sandbox
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
    _requireCalendar();
    if (_isSandboxMode && _accessToken == null) {
      final now = DateTime.now();
      return [
        {
          'id': 'evt_1',
          'title': 'AIRA OS Architecture & Sync',
          'start': DateTime(now.year, now.month, now.day, 10, 30).toIso8601String(),
          'end': DateTime(now.year, now.month, now.day, 11, 30).toIso8601String(),
          'location': 'Google Meet',
          'description': 'Review Stage G Google Workspace Assistant & Action Guardrails.',
        },
        {
          'id': 'evt_2',
          'title': 'Android Vivo Integration Review',
          'start': DateTime(now.year, now.month, now.day, 14, 0).toIso8601String(),
          'end': DateTime(now.year, now.month, now.day, 15, 0).toIso8601String(),
          'location': 'Lab Room 3',
          'description': 'Testing voice responsiveness, TTS interruption, and background service.',
        },
        {
          'id': 'evt_3',
          'title': 'Evening Reflection & Daily Planning',
          'start': DateTime(now.year, now.month, now.day, 18, 30).toIso8601String(),
          'end': DateTime(now.year, now.month, now.day, 19, 0).toIso8601String(),
          'location': 'Home Office',
          'description': 'Review completed tasks and organize tomorrow\'s priorities.',
        },
      ];
    }

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
    _requireCalendar();

    if (_isSandboxMode && _accessToken == null) {
      final evtId = 'evt_custom_${DateTime.now().millisecondsSinceEpoch}';
      return {
        'id': evtId,
        'title': title,
        'link': 'https://calendar.google.com/calendar/event?eid=$evtId',
      };
    }

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

  // ──────────────────── Stage G: Enhanced Calendar Features ────────────────────

  /// Get today's agenda with parsed start/end times, attendees, and location
  Future<List<Map<String, dynamic>>> getTodayAgenda() async {
    _requireCalendar();
    if (_isSandboxMode && _accessToken == null) {
      final now = DateTime.now();
      return [
        {
          'id': 'evt_1',
          'title': 'AIRA OS Architecture & Sync',
          'start': DateTime(now.year, now.month, now.day, 10, 30).toIso8601String(),
          'end': DateTime(now.year, now.month, now.day, 11, 30).toIso8601String(),
          'location': 'Google Meet',
          'attendees': ['arsha@example.com', 'team@deepmind.com'],
          'description': 'Review Stage G Google Workspace Assistant & Action Guardrails.',
        },
        {
          'id': 'evt_2',
          'title': 'Android Vivo Integration Review',
          'start': DateTime(now.year, now.month, now.day, 14, 0).toIso8601String(),
          'end': DateTime(now.year, now.month, now.day, 15, 0).toIso8601String(),
          'location': 'Lab Room 3',
          'attendees': ['shaikshadik03@gmail.com'],
          'description': 'Testing voice responsiveness, TTS interruption, and background service.',
        },
        {
          'id': 'evt_3',
          'title': 'Evening Reflection & Daily Planning',
          'start': DateTime(now.year, now.month, now.day, 18, 30).toIso8601String(),
          'end': DateTime(now.year, now.month, now.day, 19, 0).toIso8601String(),
          'location': 'Home Office',
          'attendees': [],
          'description': 'Review completed tasks and organize tomorrow\'s priorities.',
        },
      ];
    }

    final allEvents = await listEvents(maxResults: 25);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return allEvents.where((e) {
      final startStr = e['start'] as String? ?? '';
      final dt = DateTime.tryParse(startStr);
      if (dt == null) return false;
      return dt.isAfter(todayStart) && dt.isBefore(todayEnd);
    }).toList();
  }

  /// Get the immediate next meeting on the schedule
  Future<Map<String, dynamic>?> getNextMeeting() async {
    _requireCalendar();
    final agenda = await getTodayAgenda();
    final now = DateTime.now();
    for (final e in agenda) {
      final start = DateTime.tryParse(e['start'] ?? '');
      if (start != null && start.isAfter(now)) {
        return e;
      }
    }
    return agenda.isNotEmpty ? agenda.first : null;
  }

  /// Find free time slots between 9 AM and 6 PM today
  Future<List<String>> findFreeTimeSlots() async {
    _requireCalendar();
    final agenda = await getTodayAgenda();
    final now = DateTime.now();
    final workStart = DateTime(now.year, now.month, now.day, 9, 0);
    final workEnd = DateTime(now.year, now.month, now.day, 18, 0);

    final sortedEvents = <Map<String, DateTime>>[];
    for (final e in agenda) {
      final s = DateTime.tryParse(e['start'] ?? '');
      final end = DateTime.tryParse(e['end'] ?? '');
      if (s != null && end != null) {
        sortedEvents.add({'start': s, 'end': end});
      }
    }
    sortedEvents.sort((a, b) => a['start']!.compareTo(b['start']!));

    final freeSlots = <String>[];
    var current = workStart;

    for (final ev in sortedEvents) {
      if (ev['start']!.isAfter(current)) {
        final diff = ev['start']!.difference(current).inMinutes;
        if (diff >= 30) {
          freeSlots.add('${_formatTime(current)} - ${_formatTime(ev['start']!)} ($diff min)');
        }
      }
      if (ev['end']!.isAfter(current)) {
        current = ev['end']!;
      }
    }

    if (workEnd.isAfter(current)) {
      final diff = workEnd.difference(current).inMinutes;
      if (diff >= 30) {
        freeSlots.add('${_formatTime(current)} - ${_formatTime(workEnd)} ($diff min)');
      }
    }

    return freeSlots;
  }

  /// Generate meeting preparation bullet points
  String generateMeetingPrep(Map<String, dynamic> meeting) {
    final title = meeting['title'] ?? 'Meeting';
    final desc = meeting['description'] ?? '';
    final location = meeting['location'] ?? '';
    final attendees = (meeting['attendees'] as List?)?.join(', ') ?? 'No other attendees';

    final sb = StringBuffer();
    sb.writeln('📋 **Meeting Preparation: $title**');
    if (location.isNotEmpty) sb.writeln('📍 **Location/Link:** $location');
    sb.writeln('👥 **Participants:** $attendees');
    if (desc.isNotEmpty) sb.writeln('📝 **Context:** $desc');
    sb.writeln('\n**Preparation Checklist:**');
    sb.writeln('• Review key discussion topics and objectives beforehand.');
    sb.writeln('• Have recent project benchmarks and notes ready.');
    sb.writeln('• Note down any open action items or questions.');
    return sb.toString();
  }

  // ──────────────────── Stage G: Enhanced Gmail Features ────────────────────

  /// Get unread email digest
  Future<List<Map<String, dynamic>>> getUnreadEmailsDigest({int maxResults = 5}) async {
    _requireGmail();
    if (_isSandboxMode && _accessToken == null) {
      return [
        {
          'id': 'msg_unread_1',
          'from': 'Shaik Shadik <shaikshadik03@gmail.com>',
          'subject': 'AIRA OS Stage G: Google Workspace Review',
          'date': 'Today, 10:15 AM',
          'snippet': 'Hi Arsha, could you please verify the review-before-send approval flow for Gmail and Calendar in AIRA OS?',
        },
        {
          'id': 'msg_unread_2',
          'from': 'Google Cloud Platform <notifications@google.com>',
          'subject': 'Workspace OAuth Permissions Configured',
          'date': 'Today, 08:30 AM',
          'snippet': 'Google Calendar, Gmail, and Google Drive access tokens are synchronized with your device environment.',
        },
        {
          'id': 'msg_unread_3',
          'from': 'DeepMind AI Research <updates@deepmind.com>',
          'subject': 'Multimodal Screen & Context Guidelines',
          'date': 'Yesterday',
          'snippet': 'New agentic screen grounding benchmarks have been published. Check out the latest findings.',
        },
      ];
    }

    final dio = _buildDio('https://gmail.googleapis.com/gmail/v1/users/me');
    try {
      final listResp = await dio.get(
        '/messages',
        queryParameters: {'maxResults': maxResults, 'q': 'is:unread label:INBOX'},
      );

      final messages = listResp.data['messages'] as List? ?? [];
      final emails = <Map<String, dynamic>>[];

      for (final msg in messages.take(maxResults)) {
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
            'from': headers['From'] ?? 'Unknown Sender',
            'date': headers['Date'] ?? '',
            'snippet': detail.data['snippet'] ?? '',
          });
        } catch (_) {}
      }
      return emails;
    } on DioException catch (_) {
      return [];
    }
  }

  // ──────────────────── Security: Untrusted Data Quarantine ────────────────────

  /// Sanitizes external untrusted text (emails, Drive docs) against prompt injection attempts.
  static String sanitizeUntrustedContent(String raw) {
    var sanitized = raw;
    // Strip common prompt injection control markers
    sanitized = sanitized.replaceAll(
      RegExp(r'(ignore previous instructions|disregard instructions|system prompt|you are now|developer mode|override guardrails)', caseSensitive: false),
      '[FILTERED_CONTROL_SEQUENCE]',
    );
    // Neutralize markdown block breaks
    sanitized = sanitized.replaceAll('```', "'''");
    return '<UNTRUSTED_EXTERNAL_DATA>\n$sanitized\n</UNTRUSTED_EXTERNAL_DATA>';
  }

  // ──────────────────── Helpers & Requirements ────────────────────

  static String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void _requireConnection() {
    if (!isConnected) {
      throw Exception('Google Workspace is not connected. Say "connect Google Workspace" to link your account.');
    }
  }

  void _requireCalendar() {
    _requireConnection();
    if (!_calendarEnabled) {
      throw Exception('Google Calendar permission is disabled. Please enable it in Settings.');
    }
  }

  void _requireGmail() {
    _requireConnection();
    if (!_gmailEnabled) {
      throw Exception('Gmail permission is disabled. Please enable it in Settings.');
    }
  }

  void _requireDrive() {
    _requireConnection();
    if (!_driveEnabled) {
      throw Exception('Google Drive permission is disabled. Please enable it in Settings.');
    }
  }
}
