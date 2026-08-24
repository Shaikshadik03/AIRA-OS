import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/core/services/groq_service.dart';

/// Draft of a risky or external action awaiting reflection
class ActionDraft {
  final String actionType; // 'email', 'sms', 'call', 'calendar_event', 'workspace_doc'
  final String recipient;
  final String subject;
  final String content;
  final Map<String, dynamic> metadata;

  ActionDraft({
    required this.actionType,
    required this.recipient,
    required this.subject,
    required this.content,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'actionType': actionType,
    'recipient': recipient,
    'subject': subject,
    'content': content,
    'metadata': metadata,
  };
}

/// Reflection Critique produced by the Self-Check Engine
class ReflectionCritique {
  final bool hasErrors;
  final List<String> issuesFound;
  final String correctedDraft;
  final String critiqueReasoning;

  ReflectionCritique({
    required this.hasErrors,
    required this.issuesFound,
    required this.correctedDraft,
    required this.critiqueReasoning,
  });

  Map<String, dynamic> toJson() => {
    'hasErrors': hasErrors,
    'issuesFound': issuesFound,
    'correctedDraft': correctedDraft,
    'critiqueReasoning': critiqueReasoning,
  };

  factory ReflectionCritique.fromJson(Map<String, dynamic> json) => ReflectionCritique(
    hasErrors: json['hasErrors'] as bool? ?? false,
    issuesFound: (json['issuesFound'] as List?)?.map((e) => e.toString()).toList() ?? [],
    correctedDraft: json['correctedDraft'] as String? ?? '',
    critiqueReasoning: json['critiqueReasoning'] as String? ?? 'Verified accurate.',
  );
}

/// Audit log record for user inspection
class SelfCheckAuditRecord {
  final String id;
  final ActionDraft originalDraft;
  final ReflectionCritique critique;
  final String finalDraft;
  final DateTime timestamp;

  SelfCheckAuditRecord({
    required this.id,
    required this.originalDraft,
    required this.critique,
    required this.finalDraft,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'originalDraft': originalDraft.toJson(),
    'critique': critique.toJson(),
    'finalDraft': finalDraft,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Self-Check & Reflection Engine for AIRA-OS
/// Reviews drafted messages/actions for tone, factual accuracy, ambiguities, and errors before action.
class SelfCheckReflector {
  static final SelfCheckReflector _instance = SelfCheckReflector._internal();
  factory SelfCheckReflector() => _instance;
  SelfCheckReflector._internal();

  final GroqService _groq = GroqService();
  static const String _auditStorageKey = 'aira_self_check_audit_log_v1';

  static const String _criticSystemPrompt = '''
You are AIRA Autonomous Self-Check & Reflection Critic.
Your job is to thoroughly critique and review a drafted communication (email, SMS, message, note) before it is shown or sent.

EVALUATE:
1. Tone & Politeness: Is it respectful, natural, and appropriately professional/friendly?
2. Factual Accuracy & Clarity: Are dates, names, or promises clear? Are there placeholders like "[Insert Date]" or ambiguous pronouns?
3. Grammar & Conciseness: Remove corporate filler, robotic phrases ("I hope this email finds you well"), or typos.

OUTPUT FORMAT:
Return ONLY valid JSON matching this exact structure:
{
  "hasErrors": true/false,
  "issuesFound": ["List of specific issues or [] if perfect"],
  "correctedDraft": "The polished, corrected, final draft ready to send",
  "critiqueReasoning": "1-sentence explanation of what was fixed or why it was approved"
}

RULES:
- If the draft contains placeholders, syntax errors, aggressive tone, or vague dates, set hasErrors: true and provide the corrected version.
- If the draft is already great, return hasErrors: false, issuesFound: [], and set correctedDraft to the original.
- Do NOT output markdown codeblocks (```json), output raw JSON only.
''';

  /// Critique and refine a draft
  Future<SelfCheckAuditRecord> reviewAndRefineDraft(ActionDraft draft) async {
    try {
      final prompt = '''
DRAFT TYPE: ${draft.actionType.toUpperCase()}
RECIPIENT: ${draft.recipient}
SUBJECT: ${draft.subject}
DRAFT BODY:
"""
${draft.content}
"""

Critique this draft, identify any errors or tone flaws, and provide the refined draft.
''';

      final raw = await _groq.chat(prompt, [], memoryContext: _criticSystemPrompt);
      String cleanJson = raw.trim();
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.replaceAll(RegExp(r'^```(?:json)?\n?'), '').replaceAll(RegExp(r'\n?```$'), '').trim();
      }

      final parsed = jsonDecode(cleanJson) as Map<String, dynamic>;
      final critique = ReflectionCritique.fromJson(parsed);
      final finalDraft = critique.correctedDraft.isNotEmpty ? critique.correctedDraft : draft.content;

      final record = SelfCheckAuditRecord(
        id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
        originalDraft: draft,
        critique: critique,
        finalDraft: finalDraft,
      );

      await _logAuditRecord(record);
      return record;
    } catch (e) {
      debugPrint('[SELF-CHECK] Reflection LLM failed, using heuristic rule check: $e');
      return await _heuristicFallbackReview(draft);
    }
  }

  Future<SelfCheckAuditRecord> _heuristicFallbackReview(ActionDraft draft) async {
    final issues = <String>[];
    var refined = draft.content;

    // Rule 1: Check for leftover placeholders
    if (refined.contains('[') && refined.contains(']')) {
      issues.add('Contains unfilled placeholder brackets.');
      refined = refined.replaceAll(RegExp(r'\[.*?\]'), 'as discussed');
    }

    // Rule 2: Remove robotic corporate filler
    if (refined.contains('I hope this email finds you well')) {
      issues.add('Contains robotic filler phrase.');
      refined = refined.replaceAll('I hope this email finds you well,', '').replaceAll('I hope this email finds you well.', '').trim();
    }

    final critique = ReflectionCritique(
      hasErrors: issues.isNotEmpty,
      issuesFound: issues,
      correctedDraft: refined,
      critiqueReasoning: issues.isNotEmpty ? 'Removed placeholders and corporate filler.' : 'Draft verified clear.',
    );

    final record = SelfCheckAuditRecord(
      id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
      originalDraft: draft,
      critique: critique,
      finalDraft: refined,
    );

    await _logAuditRecord(record);
    return record;
  }

  Future<void> _logAuditRecord(SelfCheckAuditRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingRaw = prefs.getString(_auditStorageKey);
      final list = existingRaw != null ? (jsonDecode(existingRaw) as List) : [];
      list.insert(0, record.toJson());
      if (list.length > 50) list.removeLast(); // Keep latest 50 audit logs
      await prefs.setString(_auditStorageKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[SELF-CHECK] Failed to log audit record: $e');
    }
  }

  /// Retrieve all persistent audit logs
  Future<List<SelfCheckAuditRecord>> getAuditLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_auditStorageKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list.map((item) {
        final m = Map<String, dynamic>.from(item as Map);
        return SelfCheckAuditRecord(
          id: m['id'] as String? ?? '',
          originalDraft: ActionDraft(
            actionType: m['originalDraft']?['actionType'] ?? 'email',
            recipient: m['originalDraft']?['recipient'] ?? '',
            subject: m['originalDraft']?['subject'] ?? '',
            content: m['originalDraft']?['content'] ?? '',
          ),
          critique: ReflectionCritique.fromJson(Map<String, dynamic>.from(m['critique'] ?? {})),
          finalDraft: m['finalDraft'] as String? ?? '',
          timestamp: DateTime.tryParse(m['timestamp'] ?? '') ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
