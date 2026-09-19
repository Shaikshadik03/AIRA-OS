import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/config/app_config.dart';
import 'package:aira_app/core/services/llm_service.dart';
import 'package:aira_app/features/laptop/data/laptop_control_service.dart';
import 'package:aira_app/core/services/diagnostic_logger.dart';

enum DiagnosticStatus { healthy, degraded, offline, unconfigured }

class DiagnosticTargetResult {
  final String target;
  final DiagnosticStatus status;
  final int latencyMs;
  final String details;

  const DiagnosticTargetResult({
    required this.target,
    required this.status,
    required this.latencyMs,
    required this.details,
  });

  String get statusBadge => switch (status) {
    DiagnosticStatus.healthy => '🟢 Healthy',
    DiagnosticStatus.degraded => '🟡 Degraded',
    DiagnosticStatus.offline => '🔴 Offline',
    DiagnosticStatus.unconfigured => '⚪ Unconfigured',
  };
}

class DiagnosticsReport {
  final DateTime timestamp;
  final DiagnosticTargetResult internet;
  final DiagnosticTargetResult groq;
  final DiagnosticTargetResult gemini;
  final DiagnosticTargetResult openRouter;
  final DiagnosticTargetResult laptop;
  final DiagnosticTargetResult storage;

  const DiagnosticsReport({
    required this.timestamp,
    required this.internet,
    required this.groq,
    required this.gemini,
    required this.openRouter,
    required this.laptop,
    required this.storage,
  });

  DiagnosticStatus get overallStatus {
    if (internet.status == DiagnosticStatus.offline) return DiagnosticStatus.offline;
    final llmTargets = [groq, gemini, openRouter];
    final hasHealthyLlm = llmTargets.any((t) => t.status == DiagnosticStatus.healthy);
    if (!hasHealthyLlm) return DiagnosticStatus.degraded;
    return DiagnosticStatus.healthy;
  }
}

/// Real-Time Connection & Provider Health Diagnostics Service (Stage M / Stage 12).
class ConnectionDiagnosticsService {
  static final ConnectionDiagnosticsService _instance = ConnectionDiagnosticsService._internal();
  factory ConnectionDiagnosticsService() => _instance;
  ConnectionDiagnosticsService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
  ));

  /// Run comprehensive diagnostics test across all core subsystems
  Future<DiagnosticsReport> runAllDiagnostics() async {
    final sw = Stopwatch()..start();
    DiagnosticLogger().info('DIAGNOSTICS', 'Starting real-time connection diagnostics...');

    final results = await Future.wait([
      _testInternet(),
      _testGroq(),
      _testGemini(),
      _testOpenRouter(),
      _testLaptop(),
      _testStorageIo(),
    ]);

    sw.stop();
    DiagnosticLogger().info('DIAGNOSTICS', 'Completed connection diagnostics in ${sw.elapsedMilliseconds}ms.');

    return DiagnosticsReport(
      timestamp: DateTime.now(),
      internet: results[0],
      groq: results[1],
      gemini: results[2],
      openRouter: results[3],
      laptop: results[4],
      storage: results[5],
    );
  }

  Future<DiagnosticTargetResult> _testInternet() async {
    final sw = Stopwatch()..start();
    try {
      final res = await _dio.get('https://1.1.1.1').timeout(const Duration(seconds: 3));
      sw.stop();
      if (res.statusCode != null && res.statusCode! < 400) {
        return DiagnosticTargetResult(
          target: 'Internet',
          status: DiagnosticStatus.healthy,
          latencyMs: sw.elapsedMilliseconds,
          details: 'Global DNS reachable (${sw.elapsedMilliseconds}ms)',
        );
      }
      return DiagnosticTargetResult(
        target: 'Internet',
        status: DiagnosticStatus.degraded,
        latencyMs: sw.elapsedMilliseconds,
        details: 'Status code ${res.statusCode}',
      );
    } catch (e) {
      sw.stop();
      return DiagnosticTargetResult(
        target: 'Internet',
        status: DiagnosticStatus.offline,
        latencyMs: sw.elapsedMilliseconds,
        details: 'Unreachable: ${e.toString().split("\n").first}',
      );
    }
  }

  Future<DiagnosticTargetResult> _testGroq() async {
    final prefs = await SharedPreferences.getInstance();
    final customKey = LlmService.sanitizeApiKey(prefs.getString('aira_custom_groq_key'));
    final key = customKey.isNotEmpty ? customKey : LlmService.sanitizeApiKey(AppConfig.groqApiKey);

    if (key.isEmpty) {
      return const DiagnosticTargetResult(
        target: 'Groq Cloud (Primary)',
        status: DiagnosticStatus.unconfigured,
        latencyMs: 0,
        details: 'No API key configured in Settings',
      );
    }

    final sw = Stopwatch()..start();
    try {
      final res = await _dio.get(
        'https://api.groq.com/openai/v1/models',
        options: Options(headers: {'Authorization': 'Bearer $key'}),
      ).timeout(const Duration(seconds: 4));
      sw.stop();

      if (res.statusCode == 200) {
        return DiagnosticTargetResult(
          target: 'Groq Cloud (Primary)',
          status: DiagnosticStatus.healthy,
          latencyMs: sw.elapsedMilliseconds,
          details: 'Verified with model list (${sw.elapsedMilliseconds}ms)',
        );
      }
      return DiagnosticTargetResult(
        target: 'Groq Cloud (Primary)',
        status: DiagnosticStatus.degraded,
        latencyMs: sw.elapsedMilliseconds,
        details: 'HTTP ${res.statusCode}',
      );
    } catch (e) {
      sw.stop();
      return DiagnosticTargetResult(
        target: 'Groq Cloud (Primary)',
        status: DiagnosticStatus.offline,
        latencyMs: sw.elapsedMilliseconds,
        details: 'Failed: ${e.toString().split("\n").first}',
      );
    }
  }

  Future<DiagnosticTargetResult> _testGemini() async {
    final prefs = await SharedPreferences.getInstance();
    final customKey = LlmService.sanitizeApiKey(prefs.getString('aira_custom_gemini_key'));
    final key = customKey.isNotEmpty ? customKey : LlmService.sanitizeApiKey(AppConfig.geminiApiKey);

    if (key.isEmpty) {
      return const DiagnosticTargetResult(
        target: 'Google Gemini (Fallback 1)',
        status: DiagnosticStatus.unconfigured,
        latencyMs: 0,
        details: 'No Gemini key configured',
      );
    }

    final sw = Stopwatch()..start();
    try {
      final res = await _dio.get(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$key',
      ).timeout(const Duration(seconds: 4));
      sw.stop();

      if (res.statusCode == 200) {
        return DiagnosticTargetResult(
          target: 'Google Gemini (Fallback 1)',
          status: DiagnosticStatus.healthy,
          latencyMs: sw.elapsedMilliseconds,
          details: 'Verified endpoint (${sw.elapsedMilliseconds}ms)',
        );
      }
      return DiagnosticTargetResult(
        target: 'Google Gemini (Fallback 1)',
        status: DiagnosticStatus.degraded,
        latencyMs: sw.elapsedMilliseconds,
        details: 'HTTP ${res.statusCode}',
      );
    } catch (e) {
      sw.stop();
      return DiagnosticTargetResult(
        target: 'Google Gemini (Fallback 1)',
        status: DiagnosticStatus.offline,
        latencyMs: sw.elapsedMilliseconds,
        details: 'Failed: ${e.toString().split("\n").first}',
      );
    }
  }

  Future<DiagnosticTargetResult> _testOpenRouter() async {
    final prefs = await SharedPreferences.getInstance();
    final customKey = LlmService.sanitizeApiKey(prefs.getString('aira_custom_openrouter_key'));
    final key = customKey.isNotEmpty ? customKey : LlmService.sanitizeApiKey(AppConfig.openRouterApiKey);

    if (key.isEmpty) {
      return const DiagnosticTargetResult(
        target: 'OpenRouter (Fallback 2)',
        status: DiagnosticStatus.unconfigured,
        latencyMs: 0,
        details: 'No OpenRouter key configured',
      );
    }

    final sw = Stopwatch()..start();
    try {
      final res = await _dio.get(
        'https://openrouter.ai/api/v1/auth/key',
        options: Options(headers: {'Authorization': 'Bearer $key'}),
      ).timeout(const Duration(seconds: 4));
      sw.stop();

      if (res.statusCode == 200) {
        return DiagnosticTargetResult(
          target: 'OpenRouter (Fallback 2)',
          status: DiagnosticStatus.healthy,
          latencyMs: sw.elapsedMilliseconds,
          details: 'Key verified (${sw.elapsedMilliseconds}ms)',
        );
      }
      return DiagnosticTargetResult(
        target: 'OpenRouter (Fallback 2)',
        status: DiagnosticStatus.degraded,
        latencyMs: sw.elapsedMilliseconds,
        details: 'HTTP ${res.statusCode}',
      );
    } catch (e) {
      sw.stop();
      return DiagnosticTargetResult(
        target: 'OpenRouter (Fallback 2)',
        status: DiagnosticStatus.offline,
        latencyMs: sw.elapsedMilliseconds,
        details: 'Failed: ${e.toString().split("\n").first}',
      );
    }
  }

  Future<DiagnosticTargetResult> _testLaptop() async {
    final laptop = LaptopControlService();
    if (!laptop.isConfigured) {
      return const DiagnosticTargetResult(
        target: 'Paired Laptop Companion',
        status: DiagnosticStatus.unconfigured,
        latencyMs: 0,
        details: 'Not paired or IP unconfigured',
      );
    }

    final sw = Stopwatch()..start();
    try {
      final status = await laptop.getSystemStatus();
      sw.stop();
      if (status['success'] != false) {
        final hostname = status['hostname'] ?? laptop.laptopIp;
        return DiagnosticTargetResult(
          target: 'Paired Laptop Companion',
          status: DiagnosticStatus.healthy,
          latencyMs: sw.elapsedMilliseconds,
          details: 'Connected to $hostname (${sw.elapsedMilliseconds}ms)',
        );
      }
      return DiagnosticTargetResult(
        target: 'Paired Laptop Companion',
        status: DiagnosticStatus.degraded,
        latencyMs: sw.elapsedMilliseconds,
        details: status['error'] ?? 'Unresponsive',
      );
    } catch (e) {
      sw.stop();
      return DiagnosticTargetResult(
        target: 'Paired Laptop Companion',
        status: DiagnosticStatus.offline,
        latencyMs: sw.elapsedMilliseconds,
        details: 'Unreachable at ${laptop.laptopIp}',
      );
    }
  }

  Future<DiagnosticTargetResult> _testStorageIo() async {
    final sw = Stopwatch()..start();
    try {
      final prefs = await SharedPreferences.getInstance();
      const testKey = 'aira_diagnostic_storage_test';
      final testData = 'aira_io_bench_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(testKey, testData);
      final readBack = prefs.getString(testKey);
      await prefs.remove(testKey);
      sw.stop();

      if (readBack == testData) {
        return DiagnosticTargetResult(
          target: 'Local Flash Storage & Memory Vault',
          status: DiagnosticStatus.healthy,
          latencyMs: sw.elapsedMilliseconds,
          details: 'Read/Write benchmark OK (${sw.elapsedMilliseconds}ms)',
        );
      }
      return DiagnosticTargetResult(
        target: 'Local Flash Storage & Memory Vault',
        status: DiagnosticStatus.degraded,
        latencyMs: sw.elapsedMilliseconds,
        details: 'Data mismatch on readback',
      );
    } catch (e) {
      sw.stop();
      return DiagnosticTargetResult(
        target: 'Local Flash Storage & Memory Vault',
        status: DiagnosticStatus.offline,
        latencyMs: sw.elapsedMilliseconds,
        details: 'Storage I/O Error: $e',
      );
    }
  }
}
