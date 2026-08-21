import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AIRA Laptop Control Service
/// Communicates with the AIRA Desktop Agent (Python FastAPI) running on the laptop.
/// Handles HTTP REST calls and WebSocket trackpad events.
class LaptopControlService {
  static final LaptopControlService _instance = LaptopControlService._internal();
  factory LaptopControlService() => _instance;
  LaptopControlService._internal();

  static const String _ipKey = 'aira_laptop_ip';
  static const String _pinKey = 'aira_laptop_pin';
  static const String _portKey = 'aira_laptop_port';
  static const int _defaultPort = 8765;

  String? _laptopIp;
  String? _laptopPin;
  int _port = _defaultPort;

  bool get isConfigured => _laptopIp != null && _laptopIp!.isNotEmpty;

  Dio get _dio {
    final baseUrl = 'http://${_sanitizeHost(_laptopIp)}:$_port';
    return Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'X-AIRA-PIN': _laptopPin ?? '123456',
        'Content-Type': 'application/json',
      },
    ));
  }

  static String _sanitizeHost(String? rawIp) {
    if (rawIp == null || rawIp.trim().isEmpty) return '127.0.0.1';
    var clean = rawIp.trim();
    clean = clean.replaceAll(RegExp(r'^https?:\/\/'), '');
    clean = clean.replaceAll(RegExp(r'\/.*$'), '');
    if (clean.contains(':')) {
      clean = clean.split(':')[0];
    }
    return clean.trim();
  }

  // ── Config ────────────────────────────────────────────────────────────

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _laptopIp = prefs.getString(_ipKey);
    _laptopPin = prefs.getString(_pinKey) ?? '123456';
    _port = prefs.getInt(_portKey) ?? _defaultPort;
  }

  Future<void> saveConfig(String ip, String pin, {int port = _defaultPort}) async {
    var rawIp = ip.trim();
    int targetPort = port;

    // Sanitize user input (e.g. "http://192.168.1.15:8765" -> host="192.168.1.15", port=8765)
    var clean = rawIp.replaceAll(RegExp(r'^https?:\/\/'), '').replaceAll(RegExp(r'\/.*$'), '');
    if (clean.contains(':')) {
      final parts = clean.split(':');
      clean = parts[0];
      targetPort = int.tryParse(parts[1]) ?? port;
    }

    _laptopIp = clean.trim();
    _laptopPin = pin.trim().isNotEmpty ? pin.trim() : '123456';
    _port = targetPort;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipKey, _laptopIp!);
    await prefs.setString(_pinKey, _laptopPin!);
    await prefs.setInt(_portKey, _port);
  }

  Future<void> clearConfig() async {
    _laptopIp = null;
    _laptopPin = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ipKey);
    await prefs.remove(_pinKey);
  }

  String get laptopIp => _laptopIp ?? '';
  String get laptopPin => _laptopPin ?? '';

  // ── Connection Test ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> testConnection() async {
    if (!isConfigured) {
      return {
        'success': false,
        'error': 'Please enter your laptop IP address first.',
      };
    }

    try {
      final res = await _dio.get('/');
      return {'success': true, 'data': res.data};
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  Future<Map<String, dynamic>> getInfo() async {
    try {
      final res = await _dio.get('/info');
      return {'success': true, 'data': res.data};
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  // ── Screenshot ────────────────────────────────────────────────────────

  Future<Uint8List?> captureScreenshot() async {
    try {
      final res = await _dio.get('/screen/capture',
          queryParameters: {'quality': 55, 'scale': 0.45});
      final imageB64 = res.data['image'] as String?;
      if (imageB64 != null) {
        return base64Decode(imageB64);
      }
    } catch (_) {}
    return null;
  }

  // ── Mouse & Keyboard ──────────────────────────────────────────────────

  Future<void> moveMouse(int dx, int dy) async {
    try {
      await _dio.post('/mouse/move', data: {'dx': dx, 'dy': dy});
    } catch (_) {}
  }

  Future<void> leftClick({int? x, int? y}) async {
    try {
      await _dio.post('/mouse/click', data: {'button': 'left', 'x': x, 'y': y});
    } catch (_) {}
  }

  Future<void> rightClick({int? x, int? y}) async {
    try {
      await _dio.post('/mouse/click', data: {'button': 'right', 'x': x, 'y': y});
    } catch (_) {}
  }

  Future<void> doubleClick() async {
    try {
      await _dio.post('/mouse/click', data: {'button': 'double'});
    } catch (_) {}
  }

  Future<void> scroll(int amount) async {
    try {
      await _dio.post('/mouse/scroll', data: {'amount': amount});
    } catch (_) {}
  }

  Future<void> typeText(String text) async {
    try {
      await _dio.post('/keyboard/type', data: {'text': text});
    } catch (_) {}
  }

  Future<void> pressKey(String key) async {
    try {
      await _dio.post('/keyboard/press', data: {'text': key});
    } catch (_) {}
  }

  Future<void> sendHotkey(List<String> keys) async {
    try {
      await _dio.post('/keyboard/hotkey', data: {'keys': keys});
    } catch (_) {}
  }

  // ── System Control ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSystemStats() async {
    try {
      final res = await _dio.get('/system/stats');
      return res.data;
    } catch (e) {
      return {'error': _friendlyError(e)};
    }
  }

  Future<void> setVolume(int level) async {
    try {
      await _dio.post('/system/volume', data: {'level': level});
    } catch (_) {}
  }

  Future<int> getVolume() async {
    try {
      final res = await _dio.get('/system/volume');
      return res.data['volume'] as int? ?? 50;
    } catch (_) {
      return 50;
    }
  }

  Future<void> muteVolume() async {
    try {
      await _dio.post('/system/volume/mute');
    } catch (_) {}
  }

  Future<void> volumeUp() async {
    try {
      await _dio.post('/system/volume/up');
    } catch (_) {}
  }

  Future<void> volumeDown() async {
    try {
      await _dio.post('/system/volume/down');
    } catch (_) {}
  }

  Future<void> setBrightness(int level) async {
    try {
      await _dio.post('/system/brightness', data: {'level': level});
    } catch (_) {}
  }

  Future<void> lockScreen() async {
    try {
      await _dio.post('/system/lock');
    } catch (_) {}
  }

  Future<void> sleepLaptop() async {
    try {
      await _dio.post('/system/sleep');
    } catch (_) {}
  }

  Future<void> shutdownLaptop({int delaySeconds = 10}) async {
    try {
      await _dio.post('/system/shutdown', data: {'delay_seconds': delaySeconds});
    } catch (_) {}
  }

  Future<void> restartLaptop({int delaySeconds = 10}) async {
    try {
      await _dio.post('/system/restart', data: {'delay_seconds': delaySeconds});
    } catch (_) {}
  }

  Future<void> cancelShutdown() async {
    try {
      await _dio.post('/system/cancel_shutdown');
    } catch (_) {}
  }

  // ── App Launcher ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> openApp(String appName) async {
    try {
      final res = await _dio.post('/apps/open', data: {'app_name': appName});
      return res.data;
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  Future<Map<String, dynamic>> closeApp(String appName) async {
    try {
      final res = await _dio.post('/apps/close', data: {'app_name': appName});
      return res.data;
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  Future<List<dynamic>> listRunningApps() async {
    try {
      final res = await _dio.get('/apps/list');
      return res.data['apps'] ?? [];
    } catch (_) {
      return [];
    }
  }

  // ── File Manager ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> listDirectory({String? path}) async {
    try {
      final res = await _dio.post('/files/list', data: {'path': path});
      return res.data;
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  Future<Map<String, dynamic>> getQuickAccess() async {
    try {
      final res = await _dio.get('/files/quick_access');
      return res.data;
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> openFile(String path) async {
    try {
      final res = await _dio.post('/files/open', data: {'path': path});
      return res.data;
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  Future<Map<String, dynamic>> readFile(String path) async {
    try {
      final res = await _dio.post('/files/read', data: {'path': path});
      return res.data;
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  // ── Terminal ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> runCommand(String command, {String? workingDir}) async {
    try {
      final res = await _dio.post('/terminal/run', data: {
        'command': command,
        'working_dir': workingDir,
      });
      return res.data;
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e), 'stdout': '', 'stderr': ''};
    }
  }

  // ── Clipboard ─────────────────────────────────────────────────────────

  Future<String> getClipboard() async {
    try {
      final res = await _dio.get('/clipboard');
      return res.data['content'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> setClipboard(String text) async {
    try {
      await _dio.post('/clipboard', data: {'text': text});
    } catch (_) {}
  }

  // ── Autonomous Actions ────────────────────────────────────────────────

  Future<Map<String, dynamic>> organizeDownloads() async {
    try {
      final res = await _dio.post('/auto/organize_downloads');
      return res.data;
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  Future<Map<String, dynamic>> saveQuickNote(String title, String content) async {
    try {
      final res = await _dio.post('/auto/quick_note', data: {
        'title': title,
        'content': content,
      });
      return res.data;
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  Future<Map<String, dynamic>> autoWebSearch(String query) async {
    try {
      final res = await _dio.post('/auto/web_search', data: {
        'query': query,
      });
      return res.data;
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  String _friendlyError(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Cannot connect to laptop.\n\nQuick checklist:\n1. Is start_aira_desktop.bat running on your laptop?\n2. Are both phone and laptop on the SAME Wi-Fi network?\n3. Check your IP: ${_laptopIp ?? "none"}';
      }
      if (e.response?.statusCode == 401) {
        return 'Invalid PIN. Please enter the PIN shown in your desktop terminal (default: 123456).';
      }
      return 'Connection error (${e.message}). Ensure desktop agent is running.';
    }
    return e.toString();
  }
}
