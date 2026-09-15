import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Usage Controls & Reliability Metrics Tracking (Stage M / Stage 12).
///
/// Tracks error rate, latency averages, tool outcomes, and automation throughput
/// for real-time observability and reliability reporting.
class UsageMetricsService {
  static final UsageMetricsService _instance = UsageMetricsService._internal();
  factory UsageMetricsService() => _instance;
  UsageMetricsService._internal();

  static const String _metricsPrefKey = 'aira_reliability_metrics_v1';

  int _totalQueries = 0;
  int _successfulToolExecutions = 0;
  int _failedToolExecutions = 0;
  int _totalLlmCalls = 0;
  int _accumulatedLatencyMs = 0;
  int _totalAutomationsRun = 0;
  int _totalAutomationsPaused = 0;
  DateTime _startedAt = DateTime.now();

  int get totalQueries => _totalQueries;
  int get successfulToolExecutions => _successfulToolExecutions;
  int get failedToolExecutions => _failedToolExecutions;
  int get totalLlmCalls => _totalLlmCalls;
  int get totalAutomationsRun => _totalAutomationsRun;
  int get totalAutomationsPaused => _totalAutomationsPaused;
  DateTime get startedAt => _startedAt;

  int get averageLatencyMs => _totalLlmCalls > 0 ? (_accumulatedLatencyMs / _totalLlmCalls).round() : 0;

  double get errorRatePercent {
    final totalTools = _successfulToolExecutions + _failedToolExecutions;
    if (totalTools == 0) return 0.0;
    return ((_failedToolExecutions / totalTools) * 100.0 * 10).round() / 10.0;
  }

  double get toolSuccessRatePercent {
    final totalTools = _successfulToolExecutions + _failedToolExecutions;
    if (totalTools == 0) return 100.0;
    return ((_successfulToolExecutions / totalTools) * 100.0 * 10).round() / 10.0;
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_metricsPrefKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _totalQueries = data['totalQueries'] as int? ?? 0;
        _successfulToolExecutions = data['successfulToolExecutions'] as int? ?? 0;
        _failedToolExecutions = data['failedToolExecutions'] as int? ?? 0;
        _totalLlmCalls = data['totalLlmCalls'] as int? ?? 0;
        _accumulatedLatencyMs = data['accumulatedLatencyMs'] as int? ?? 0;
        _totalAutomationsRun = data['totalAutomationsRun'] as int? ?? 0;
        _totalAutomationsPaused = data['totalAutomationsPaused'] as int? ?? 0;
        final sAt = data['startedAt'] as String?;
        if (sAt != null) _startedAt = DateTime.tryParse(sAt) ?? DateTime.now();
      }
    } catch (e) {
      debugPrint('[METRICS] Failed to load metrics: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'totalQueries': _totalQueries,
        'successfulToolExecutions': _successfulToolExecutions,
        'failedToolExecutions': _failedToolExecutions,
        'totalLlmCalls': _totalLlmCalls,
        'accumulatedLatencyMs': _accumulatedLatencyMs,
        'totalAutomationsRun': _totalAutomationsRun,
        'totalAutomationsPaused': _totalAutomationsPaused,
        'startedAt': _startedAt.toIso8601String(),
      };
      await prefs.setString(_metricsPrefKey, jsonEncode(data));
    } catch (_) {}
  }

  void recordQuery() {
    _totalQueries++;
    _persist();
  }

  void recordToolOutcome({required bool success}) {
    if (success) {
      _successfulToolExecutions++;
    } else {
      _failedToolExecutions++;
    }
    _persist();
  }

  void recordLlmCall({required int latencyMs, bool success = true}) {
    _totalLlmCalls++;
    _accumulatedLatencyMs += latencyMs;
    if (!success) {
      _failedToolExecutions++;
    }
    _persist();
  }

  void recordAutomationRun() {
    _totalAutomationsRun++;
    _persist();
  }

  void recordAutomationPaused() {
    _totalAutomationsPaused++;
    _persist();
  }

  Future<void> resetMetrics() async {
    _totalQueries = 0;
    _successfulToolExecutions = 0;
    _failedToolExecutions = 0;
    _totalLlmCalls = 0;
    _accumulatedLatencyMs = 0;
    _totalAutomationsRun = 0;
    _totalAutomationsPaused = 0;
    _startedAt = DateTime.now();
    await _persist();
  }
}
