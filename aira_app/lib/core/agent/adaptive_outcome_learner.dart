import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserDecision {
  accepted,
  edited,
  rejected,
}

/// A logged outcome of an AI recommendation, draft, or action
class ActionOutcomeRecord {
  final String id;
  final String category; // 'email_draft', 'schedule_time', 'tone_preference', 'summary_length'
  final String initialProposal;
  final UserDecision decision;
  final String? userEditedText;
  final int lengthDelta; // Difference in character count between proposal and edit
  final DateTime timestamp;

  ActionOutcomeRecord({
    required this.id,
    required this.category,
    required this.initialProposal,
    required this.decision,
    this.userEditedText,
    this.lengthDelta = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'initialProposal': initialProposal,
    'decision': decision.name,
    'userEditedText': userEditedText,
    'lengthDelta': lengthDelta,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ActionOutcomeRecord.fromJson(Map<String, dynamic> json) => ActionOutcomeRecord(
    id: json['id'] as String? ?? '',
    category: json['category'] as String? ?? 'general',
    initialProposal: json['initialProposal'] as String? ?? '',
    decision: UserDecision.values.firstWhere(
      (e) => e.name == (json['decision'] as String? ?? 'accepted'),
      orElse: () => UserDecision.accepted,
    ),
    userEditedText: json['userEditedText'] as String?,
    lengthDelta: json['lengthDelta'] as int? ?? 0,
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Adaptive Memory & Outcome Learning Engine for AIRA-OS
/// Calibrates future behavior, draft brevity, and styles based on user decisions over time.
class AdaptiveOutcomeLearner {
  static final AdaptiveOutcomeLearner _instance = AdaptiveOutcomeLearner._internal();
  factory AdaptiveOutcomeLearner() => _instance;
  AdaptiveOutcomeLearner._internal();

  static const String _storageKey = 'aira_adaptive_outcomes_v1';
  final List<ActionOutcomeRecord> _history = [];

  List<ActionOutcomeRecord> get history => List.unmodifiable(_history);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _history.clear();
        _history.addAll(list.map((e) => ActionOutcomeRecord.fromJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (e) {
      debugPrint('[ADAPTIVE LEARNER] Init error: $e');
    }
  }

  /// Log a user reaction / outcome
  Future<void> logOutcome({
    required String category,
    required String initialProposal,
    required UserDecision decision,
    String? userEditedText,
  }) async {
    int delta = 0;
    if (userEditedText != null && userEditedText.isNotEmpty) {
      delta = userEditedText.length - initialProposal.length;
    }

    final record = ActionOutcomeRecord(
      id: 'outc_${DateTime.now().millisecondsSinceEpoch}',
      category: category,
      initialProposal: initialProposal,
      decision: decision,
      userEditedText: userEditedText,
      lengthDelta: delta,
    );

    _history.insert(0, record);
    if (_history.length > 200) _history.removeLast();
    await _persist();
  }

  /// Analyzes historical outcomes to generate calibrated prompt constraints
  String getCalibratedDirectives() {
    if (_history.isEmpty) return '';

    final directives = <String>[];

    // 1. Check email draft length calibrations
    final emailOutcomes = _history.where((h) => h.category == 'email_draft' || h.category == 'email').toList();
    if (emailOutcomes.length >= 3) {
      final editedShorter = emailOutcomes.where((h) => h.decision == UserDecision.edited && h.lengthDelta < -20).length;
      if (editedShorter >= 2 || (editedShorter / emailOutcomes.length) > 0.4) {
        directives.add('• USER PREFERENCE (LEARNED): User prefers ultra-concise, punchy emails (max 2-3 short sentences). Avoid long preambles.');
      }
    }

    // 2. Check tone / greeting calibrations
    final toneOutcomes = _history.where((h) => h.category == 'tone_preference').toList();
    if (toneOutcomes.any((h) => h.decision == UserDecision.edited && (h.userEditedText?.contains('Hey') ?? false))) {
      directives.add('• USER PREFERENCE (LEARNED): User prefers casual and direct greetings ("Hey", "Quick update") over formal salutations.');
    }

    if (directives.isEmpty) return '';

    return '\n<adaptive_learned_preferences>\n${directives.join('\n')}\n</adaptive_learned_preferences>';
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_history.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('[ADAPTIVE LEARNER] Persist error: $e');
    }
  }
}
