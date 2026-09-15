import 'dart:collection';
import 'package:flutter/foundation.dart';

enum LogSeverity { info, warn, error, automation }

class DiagnosticLogEntry {
  final DateTime timestamp;
  final LogSeverity severity;
  final String tag;
  final String message;

  DiagnosticLogEntry({
    required this.timestamp,
    required this.severity,
    required this.tag,
    required this.message,
  });

  String get severityLabel => switch (severity) {
    LogSeverity.info => 'INFO',
    LogSeverity.warn => 'WARN',
    LogSeverity.error => 'ERROR',
    LogSeverity.automation => 'AUTO',
  };

  @override
  String toString() {
    final timeStr = timestamp.toIso8601String().substring(11, 19);
    return '[$timeStr] [$severityLabel] [$tag] $message';
  }
}

/// Redacted Diagnostic Logger (Stage M / Stage 12).
///
/// Automatically scrubs API keys, authorization bearer tokens, emails, and phone numbers
/// to ensure diagnostics can be shared safely without secret leakage.
class DiagnosticLogger {
  static final DiagnosticLogger _instance = DiagnosticLogger._internal();
  factory DiagnosticLogger() => _instance;
  DiagnosticLogger._internal();

  static const int maxLogEntries = 200;
  final Queue<DiagnosticLogEntry> _logBuffer = Queue<DiagnosticLogEntry>();

  List<DiagnosticLogEntry> get logs => _logBuffer.toList();

  /// Regex sanitization patterns for sensitive credentials & PII
  static final RegExp _groqKeyRegex = RegExp(r'gsk_[a-zA-Z0-9_-]{16,}');
  static final RegExp _geminiKeyRegex = RegExp(r'AIzaSy[a-zA-Z0-9_-]{20,}');
  static final RegExp _openRouterKeyRegex = RegExp(r'sk-or-[a-zA-Z0-9_-]{16,}');
  static final RegExp _bearerRegex = RegExp(r'Bearer\s+[a-zA-Z0-9._-]{12,}', caseSensitive: false);
  static final RegExp _emailRegex = RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b');
  static final RegExp _phoneRegex = RegExp(r'(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}');

  /// Sanitize any string input to remove tokens and sensitive PII
  static String sanitize(String input) {
    var clean = input;
    clean = clean.replaceAll(_groqKeyRegex, '[REDACTED_GROQ_KEY]');
    clean = clean.replaceAll(_geminiKeyRegex, '[REDACTED_GEMINI_KEY]');
    clean = clean.replaceAll(_openRouterKeyRegex, '[REDACTED_OPENROUTER_KEY]');
    clean = clean.replaceAll(_bearerRegex, 'Bearer [REDACTED_TOKEN]');
    clean = clean.replaceAll(_emailRegex, '[REDACTED_EMAIL]');
    clean = clean.replaceAll(_phoneRegex, '[REDACTED_PHONE]');
    return clean;
  }

  void log(LogSeverity severity, String tag, String rawMessage) {
    final sanitizedMessage = sanitize(rawMessage);
    final entry = DiagnosticLogEntry(
      timestamp: DateTime.now(),
      severity: severity,
      tag: tag,
      message: sanitizedMessage,
    );

    if (_logBuffer.length >= maxLogEntries) {
      _logBuffer.removeFirst();
    }
    _logBuffer.addLast(entry);

    if (kDebugMode) {
      debugPrint(entry.toString());
    }
  }

  void info(String tag, String message) => log(LogSeverity.info, tag, message);
  void warn(String tag, String message) => log(LogSeverity.warn, tag, message);
  void warning(String tag, String message) => warn(tag, message);
  void error(String tag, String message, [dynamic error]) {
    final fullMessage = error != null ? '$message | Details: $error' : message;
    log(LogSeverity.error, tag, fullMessage);
  }
  void automation(String tag, String message) => log(LogSeverity.automation, tag, message);

  /// Returns full redacted log stream as exportable text
  String exportRedactedLogs() {
    if (_logBuffer.isEmpty) return 'No diagnostic logs recorded yet.';
    final buffer = StringBuffer('=== AIRA OS REDACTED DIAGNOSTIC LOGS ===\n');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}\n');
    for (final entry in _logBuffer) {
      buffer.writeln(entry.toString());
    }
    return buffer.toString();
  }

  void clear() {
    _logBuffer.clear();
  }
}
