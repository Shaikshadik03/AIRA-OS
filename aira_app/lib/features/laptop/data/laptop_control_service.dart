import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  static const String _deviceTokenKey = 'aira_device_token';
  static const String _deviceIdKey = 'aira_device_id';
  static const String _hostnameKey = 'aira_laptop_hostname';
  static const String _isRemotePausedKey = 'aira_remote_paused';
  static const String _actionReceiptsKey = 'aira_action_receipts';
  static const int _defaultPort = 8765;

  String? _laptopIp;
  String? _laptopPin;
  int _port = _defaultPort;
  String? _deviceToken;
  String? _deviceId;
  String? _hostname;
  bool _isRemotePaused = false;
  List<Map<String, dynamic>> _actionReceipts = [];

  // Real-time low-latency WebSocket connection for trackpad
  WebSocket? _ws;
  bool get isWsConnected => _ws != null;

  // Throttle HTTP fallback movements to 50fps (20ms) to avoid queue exhaustion
  int _pendingDx = 0;
  int _pendingDy = 0;
  Timer? _httpMoveThrottleTimer;

  bool get isConfigured => _laptopIp != null && _laptopIp!.isNotEmpty;
  bool get isPaired => _deviceToken != null && _deviceToken!.isNotEmpty && isConfigured;

  String get laptopIp => _laptopIp ?? '';
  String get laptopPin => _laptopPin ?? '';
  String? get deviceToken => _deviceToken;
  String? get deviceId => _deviceId;
  String? get hostname => _hostname;
  bool get isRemotePaused => _isRemotePaused;
  List<Map<String, dynamic>> get actionReceipts => List.unmodifiable(_actionReceipts);

  Dio get _dio {
    final baseUrl = 'http://${_sanitizeHost(_laptopIp)}:$_port';
    final headers = <String, dynamic>{
      'Content-Type': 'application/json',
      'X-AIRA-PIN': _laptopPin ?? '123456',
    };
    if (_deviceToken != null && _deviceToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_deviceToken';
    }
    return Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 8),
      headers: headers,
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
    _deviceToken = prefs.getString(_deviceTokenKey);
    _hostname = prefs.getString(_hostnameKey);
    _isRemotePaused = prefs.getBool(_isRemotePausedKey) ?? false;

    // Persistent Device Identifier
    _deviceId = prefs.getString(_deviceIdKey);
    if (_deviceId == null || _deviceId!.isEmpty) {
      _deviceId = 'phone_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
      await prefs.setString(_deviceIdKey, _deviceId!);
    }

    // Load action receipts cache
    final receiptsJson = prefs.getString(_actionReceiptsKey);
    if (receiptsJson != null && receiptsJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(receiptsJson) as List;
        _actionReceipts = decoded
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      } catch (_) {
        _actionReceipts = [];
      }
    }
  }

  Future<void> saveConfig(String ip, String pin, {int port = _defaultPort}) async {
    var rawIp = ip.trim();
    int targetPort = port;

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
    _deviceToken = null;
    _hostname = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ipKey);
    await prefs.remove(_pinKey);
    await prefs.remove(_deviceTokenKey);
    await prefs.remove(_hostnameKey);
  }

  // ── WebSocket Connection for 0ms Real-Time Trackpad ──────────────────

  Future<bool> connectWebSocket() async {
    if (_ws != null) return true;
    if (!isConfigured) return false;

    try {
      final host = _sanitizeHost(_laptopIp);
      final wsUrl = 'ws://$host:$_port/ws/trackpad';
      _ws = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 3));

      // Send auth PIN and paired token as first message
      _ws!.add(jsonEncode({
        'pin': _laptopPin ?? '123456',
        'token': _deviceToken,
      }));

      _ws!.listen(
        (data) {},
        onError: (_) => disconnectWebSocket(),
        onDone: () => disconnectWebSocket(),
        cancelOnError: true,
      );
      return true;
    } catch (_) {
      disconnectWebSocket();
      return false;
    }
  }

  void disconnectWebSocket() {
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
  }

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
      // Also establish WebSocket in background for instantaneous trackpad
      connectWebSocket();
      return {'success': true, 'data': res.data};
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  // ── Stage I: Device Pairing & Security Bridge ─────────────────────────

  /// Request a one-time 6-digit pairing PIN from the laptop host
  Future<Map<String, dynamic>> requestPairingPin(String ip, {int port = _defaultPort}) async {
    final host = _sanitizeHost(ip);
    final dio = Dio(BaseOptions(
      baseUrl: 'http://$host:$port',
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 8),
    ));

    try {
      final res = await dio.post('/pair/request', data: {
        'device_id': _deviceId ?? 'phone_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}',
        'device_name': 'AIRA Android Phone',
      });
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  /// Pair device using 6-digit PIN and obtain cryptographic Bearer token
  Future<Map<String, dynamic>> pairDevice(
    String ip,
    String pin, {
    int port = _defaultPort,
    String? deviceName,
  }) async {
    final host = _sanitizeHost(ip);
    final dio = Dio(BaseOptions(
      baseUrl: 'http://$host:$port',
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 8),
    ));

    try {
      final devId = _deviceId ?? 'phone_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
      final res = await dio.post('/pair/confirm', data: {
        'pin': pin.trim(),
        'device_id': devId,
        'device_name': deviceName ?? 'AIRA Android Phone',
        'platform': 'android',
      });

      final data = Map<String, dynamic>.from(res.data);
      if (data['success'] == true) {
        final token = data['device_token'] as String?;
        final hostName = data['hostname'] as String?;

        await saveConfig(host, pin, port: port);
        _deviceToken = token;
        _hostname = hostName;

        final prefs = await SharedPreferences.getInstance();
        if (token != null) {
          await prefs.setString(_deviceTokenKey, token);
        }
        if (hostName != null) {
          await prefs.setString(_hostnameKey, hostName);
        }

        // Establish WS connection with new pairing credentials
        connectWebSocket();
      }
      return data;
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  /// Check pairing heartbeat, pause state, and latency
  Future<Map<String, dynamic>> getPairingStatus() async {
    try {
      final res = await _dio.get('/pair/status');
      final data = Map<String, dynamic>.from(res.data);
      if (data.containsKey('is_paused')) {
        _isRemotePaused = data['is_paused'] == true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_isRemotePausedKey, _isRemotePaused);
      }
      if (data.containsKey('hostname')) {
        _hostname = data['hostname'] as String?;
      }
      return {'success': true, 'data': data};
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  /// Revoke pairing immediately; drops connection and revokes access on laptop
  Future<Map<String, dynamic>> unpairDevice() async {
    try {
      if (isConfigured && _deviceToken != null) {
        await _dio.post('/pair/revoke', data: {
          'device_token': _deviceToken,
          'device_id': _deviceId,
        });
      }
    } catch (_) {}

    disconnectWebSocket();
    await clearConfig();
    return {'success': true, 'message': 'Device unpaired successfully.'};
  }

  /// Toggle remote control pause on laptop host
  Future<Map<String, dynamic>> toggleRemotePause(bool pause) async {
    try {
      final res = await _dio.post('/pair/pause', data: {'pause': pause});
      _isRemotePaused = pause;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isRemotePausedKey, _isRemotePaused);
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  /// Clear stored action receipts
  Future<void> clearActionReceipts() async {
    _actionReceipts.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_actionReceiptsKey);
  }

  // ── Stage I: Durable Idempotent Remote Command Pipeline ────────────────

  /// Execute an idempotent, durable command on the laptop with replay prevention & 30s TTL
  Future<Map<String, dynamic>> executeDurableCommand({
    required String tool,
    required Map<String, dynamic> arguments,
    int ttlSeconds = 30,
    String? explicitCommandId,
  }) async {
    if (!isConfigured) {
      return {
        'success': false,
        'status': 'unconfigured',
        'output': 'Laptop is not configured. Please pair first.',
      };
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = now + (ttlSeconds * 1000);
    final cmdId = explicitCommandId ?? 'cmd_${DateTime.now().microsecondsSinceEpoch}_$tool';
    final devId = _deviceId ?? 'phone_default';

    final payload = {
      'command_id': cmdId,
      'device_id': devId,
      'tool': tool,
      'arguments': arguments,
      'created_at': now,
      'expires_at': expiresAt,
    };

    try {
      final res = await _dio.post('/command/execute', data: payload);
      final receipt = Map<String, dynamic>.from(res.data);

      // Record receipt in cache (keep last 50 receipts)
      _recordReceipt(receipt);

      return {
        'success': receipt['status'] == 'executed' || receipt['status'] == 'cached',
        'status': receipt['status'],
        'receipt': receipt,
        'output': receipt['output'],
        'replayed': receipt['replayed'] ?? false,
      };
    } catch (e) {
      final failureReceipt = {
        'command_id': cmdId,
        'device_id': devId,
        'tool': tool,
        'status': 'failed',
        'output': _friendlyError(e),
        'executed_at': now,
        'duration_ms': 0,
        'replayed': false,
      };
      _recordReceipt(failureReceipt);
      return {
        'success': false,
        'status': 'failed',
        'receipt': failureReceipt,
        'error': _friendlyError(e),
        'output': _friendlyError(e),
      };
    }
  }

  void _recordReceipt(Map<String, dynamic> receipt) {
    _actionReceipts.insert(0, receipt);
    if (_actionReceipts.length > 50) {
      _actionReceipts = _actionReceipts.sublist(0, 50);
    }
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_actionReceiptsKey, jsonEncode(_actionReceipts));
    });
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
    if (dx == 0 && dy == 0) return;
    if (_ws != null) {
      try {
        _ws!.add(jsonEncode({'type': 'move', 'dx': dx, 'dy': dy}));
        return;
      } catch (_) {
        disconnectWebSocket();
      }
    }
    _scheduleHttpMove(dx, dy);
  }

  void _scheduleHttpMove(int dx, int dy) {
    _pendingDx += dx;
    _pendingDy += dy;
    if (_httpMoveThrottleTimer?.isActive ?? false) return;
    _httpMoveThrottleTimer = Timer(const Duration(milliseconds: 20), () async {
      final toSendDx = _pendingDx;
      final toSendDy = _pendingDy;
      _pendingDx = 0;
      _pendingDy = 0;
      if (toSendDx != 0 || toSendDy != 0) {
        try {
          await _dio.post('/mouse/move', data: {'dx': toSendDx, 'dy': toSendDy});
        } catch (_) {}
      }
    });
  }

  Future<void> leftClick({int? x, int? y}) async {
    if (_ws != null) {
      try {
        _ws!.add(jsonEncode({'type': 'click', 'button': 'left', 'x': x, 'y': y}));
        return;
      } catch (_) {
        disconnectWebSocket();
      }
    }
    try {
      await _dio.post('/mouse/click', data: {'button': 'left', 'x': x, 'y': y});
    } catch (_) {}
  }

  Future<void> rightClick({int? x, int? y}) async {
    if (_ws != null) {
      try {
        _ws!.add(jsonEncode({'type': 'click', 'button': 'right', 'x': x, 'y': y}));
        return;
      } catch (_) {
        disconnectWebSocket();
      }
    }
    try {
      await _dio.post('/mouse/click', data: {'button': 'right', 'x': x, 'y': y});
    } catch (_) {}
  }

  Future<void> doubleClick() async {
    if (_ws != null) {
      try {
        _ws!.add(jsonEncode({'type': 'click', 'button': 'double'}));
        return;
      } catch (_) {
        disconnectWebSocket();
      }
    }
    try {
      await _dio.post('/mouse/click', data: {'button': 'double'});
    } catch (_) {}
  }

  Future<void> scroll(int amount) async {
    if (_ws != null) {
      try {
        _ws!.add(jsonEncode({'type': 'scroll', 'amount': amount}));
        return;
      } catch (_) {
        disconnectWebSocket();
      }
    }
    try {
      await _dio.post('/mouse/scroll', data: {'amount': amount});
    } catch (_) {}
  }

  Future<void> typeText(String text) async {
    if (_ws != null) {
      try {
        _ws!.add(jsonEncode({'type': 'type', 'text': text}));
        return;
      } catch (_) {
        disconnectWebSocket();
      }
    }
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
    if (_ws != null) {
      try {
        _ws!.add(jsonEncode({'type': 'hotkey', 'keys': keys}));
        return;
      } catch (_) {
        disconnectWebSocket();
      }
    }
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

  Future<void> scrollMouse(int amount) async {
    try {
      await _dio.post('/mouse/scroll', data: {'amount': amount});
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

  bool get isConnected => isConfigured;

  /// Execute an autonomous multi-step agent workflow on the connected laptop
  Future<Map<String, dynamic>> executeAgentTask(String prompt, {String? customGroqKey}) async {
    try {
      final res = await _dio.post('/agent/execute', data: {
        'prompt': prompt,
        'custom_groq_key': customGroqKey,
      });
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      return {
        'success': false,
        'error': _friendlyError(e),
        'message': _friendlyError(e),
      };
    }
  }

  /// Stream autonomous multi-step agent workflow progress over WebSocket
  Stream<Map<String, dynamic>> streamAgentTask(String prompt, {String? customGroqKey}) async* {
    if (!isConfigured) {
      yield {'type': 'error', 'message': 'Laptop not configured.'};
      return;
    }

    WebSocket? ws;
    try {
      final host = _sanitizeHost(_laptopIp);
      final wsUrl = 'ws://$host:$_port/ws/agent';
      ws = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 4));

      // Send auth + prompt
      ws.add(jsonEncode({
        'pin': _laptopPin ?? '123456',
        'token': _deviceToken,
        'prompt': prompt,
        'custom_groq_key': customGroqKey,
      }));

      await for (final raw in ws) {
        if (raw is String) {
          try {
            final data = jsonDecode(raw) as Map<String, dynamic>;
            yield data;
            if (data['type'] == 'done' || data['type'] == 'error') {
              break;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      // Graceful fallback to HTTP executeAgentTask if WebSocket is unavailable
      try {
        yield {'type': 'status', 'message': 'Executing task via HTTP fallback...'};
        final result = await executeAgentTask(prompt, customGroqKey: customGroqKey);
        yield {
          'type': 'done',
          'success': result['success'] == true,
          'message': result['message'] ?? 'Task completed',
          'results': result['results'] ?? [],
        };
      } catch (fallbackErr) {
        yield {'type': 'error', 'message': _friendlyError(e)};
      }
    } finally {
      try {
        await ws?.close();
      } catch (_) {}
    }
  }

  /// Execute a live screen-grounded voice or text command on the connected laptop
  Future<Map<String, dynamic>> executeLiveDesktopCommand(String command, {String? customGroqKey}) async {
    try {
      final res = await _dio.post('/agent/live_desktop_command', data: {
        'command': command,
        'custom_groq_key': customGroqKey,
      });
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      return {
        'success': false,
        'action': 'error',
        'message': _friendlyError(e),
      };
    }
  }

  /// Get atomic step breakdown of a goal from the laptop agent
  Future<Map<String, dynamic>> planAgentTask(String prompt, {String? customGroqKey}) async {
    try {
      final res = await _dio.post('/agent/plan', data: {
        'prompt': prompt,
        'custom_groq_key': customGroqKey,
      });
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  // ── Stage J: Windows Digital Task Execution ───────────────────────────

  /// Scoped file search across user folders (Downloads, Documents, Desktop, etc.)
  Future<Map<String, dynamic>> searchFiles({
    String? directory = 'downloads',
    String? query = '',
    List<String>? extensions,
    int maxResults = 25,
  }) async {
    if (isPaired) {
      return executeDurableCommand(
        tool: 'search_files',
        arguments: {
          'directory': directory,
          'query': query,
          'extensions': extensions,
          'max_results': maxResults,
        },
      );
    }
    try {
      final res = await _dio.post('/task/search_files', data: {
        'directory': directory,
        'query': query,
        'extensions': extensions,
        'max_results': maxResults,
      });
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e), 'files': []};
    }
  }

  /// Reversible folder organization with undo manifest generation
  Future<Map<String, dynamic>> organizeFolderReversible({
    required String directory,
    bool preview = false,
  }) async {
    if (isPaired) {
      return executeDurableCommand(
        tool: 'organize_folder',
        arguments: {
          'directory': directory,
          'preview': preview,
        },
      );
    }
    try {
      final res = await _dio.post('/task/organize_folder', data: {
        'directory': directory,
        'preview': preview,
      });
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  /// Reverses a previous folder organization using the _aira_undo_manifest.json
  Future<Map<String, dynamic>> undoFolderOrganization({required String directory}) async {
    if (isPaired) {
      return executeDurableCommand(
        tool: 'undo_organization',
        arguments: {
          'directory': directory,
        },
      );
    }
    try {
      final res = await _dio.post('/task/undo_organization', data: {
        'directory': directory,
      });
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  /// Prepare document in Documents/AIRA_Documents and open in Notepad
  Future<Map<String, dynamic>> prepareDocument({
    required String title,
    required String content,
    String docFormat = 'txt',
    bool openAfter = true,
  }) async {
    if (isPaired) {
      return executeDurableCommand(
        tool: 'prepare_document',
        arguments: {
          'title': title,
          'content': content,
          'doc_format': docFormat,
          'open_after': openAfter,
        },
      );
    }
    try {
      final res = await _dio.post('/task/prepare_document', data: {
        'title': title,
        'content': content,
        'doc_format': docFormat,
        'open_after': openAfter,
      });
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  /// Supervised screen execution loop: Observe -> Target -> Validate -> Act -> Verify
  Future<Map<String, dynamic>> executeSupervisedScreenAction({
    required String targetDescription,
    String action = 'click',
    String? text,
    String? expectedOutcome,
  }) async {
    if (isPaired) {
      return executeDurableCommand(
        tool: 'supervised_screen_action',
        arguments: {
          'target_description': targetDescription,
          'action': action,
          'text': text,
          'expected_outcome': expectedOutcome,
        },
      );
    }
    try {
      final res = await _dio.post('/task/supervised_screen_action', data: {
        'target_description': targetDescription,
        'action': action,
        'text': text,
        'expected_outcome': expectedOutcome,
      });
      return Map<String, dynamic>.from(res.data);
    } catch (e) {
      return {'success': false, 'error': _friendlyError(e)};
    }
  }

  /// Pause all autonomous operations on connected laptop
  Future<bool> pauseLaptopAutomation() async {
    _isRemotePaused = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isRemotePausedKey, true);
    } catch (_) {}
    if (!isConfigured) return false;
    try {
      await _dio.post('/automation/pause').timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Resume autonomous operations on connected laptop
  Future<bool> resumeLaptopAutomation() async {
    _isRemotePaused = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isRemotePausedKey, false);
    } catch (_) {}
    if (!isConfigured) return false;
    try {
      await _dio.post('/automation/resume').timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get companion system status and health info
  Future<Map<String, dynamic>> getSystemStatus() async {
    if (!isConfigured) return {'success': false, 'error': 'Laptop not configured'};
    try {
      final res = await _dio.get('/health').timeout(const Duration(seconds: 3));
      if (res.statusCode == 200 && res.data is Map) {
        final data = Map<String, dynamic>.from(res.data as Map);
        if (data.containsKey('hostname')) {
          _hostname = data['hostname']?.toString();
        }
        return {'success': true, ...data};
      }
      return {'success': false, 'error': 'Companion returned ${res.statusCode}'};
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
