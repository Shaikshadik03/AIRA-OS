import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:aira_app/core/services/llm_service.dart';
import 'package:aira_app/core/services/memory_engine.dart';

/// AIRA Fact Extractor
/// After conversation sessions, extracts durable facts about the user
/// using a lightweight LLM call and stores them in MemoryEngine.
class FactExtractor {
  static final FactExtractor _instance = FactExtractor._internal();
  factory FactExtractor() => _instance;
  FactExtractor._internal();

  final _uuid = const Uuid();
  final _memory = MemoryEngine();
  final _llm = LlmService();

  /// Extract facts from a batch of recent conversation messages.
  /// Called asynchronously after a chat session ends or every N messages.
  Future<void> extractFromConversation(List<Map<String, String>> recentMessages) async {
    if (recentMessages.isEmpty) return;

    try {
      // Build a compact transcript for extraction
      final transcript = recentMessages
          .map((m) => '${m['role'] == 'user' ? 'User' : 'AIRA'}: ${m['content']}')
          .join('\n');

      final extractionPrompt = '''Analyze this conversation and extract DURABLE FACTS about the user.

Rules:
- Only extract facts that would be useful to remember for future conversations.
- Focus on: preferences, habits, schedule, relationships, skills, goals, emotions, life events.
- Do NOT extract trivial or one-time conversational context.
- If the user corrects or updates a previous fact, note the LATEST version only.
- Output ONLY a valid JSON array. No markdown, no explanation.

Format:
[
  {"category": "preference|habit|schedule|relationship|skill|goal|event", "fact": "concise fact string", "confidence": 0.0-1.0}
]

If no durable facts found, return: []

Conversation:
$transcript''';

      final response = await _llm.chat(
        userMessage: extractionPrompt,
        conversationHistory: [],
        systemPromptOverride: 'You are a fact extraction engine. Output ONLY valid JSON arrays. No other text.',
      );

      // Parse the JSON response
      final cleaned = response.trim();
      final jsonStart = cleaned.indexOf('[');
      final jsonEnd = cleaned.lastIndexOf(']');

      if (jsonStart == -1 || jsonEnd == -1) {
        debugPrint('[FACT_EXTRACTOR] No valid JSON found in response');
        return;
      }

      final jsonStr = cleaned.substring(jsonStart, jsonEnd + 1);
      final List<dynamic> parsed = jsonDecode(jsonStr);

      if (parsed.isEmpty) {
        debugPrint('[FACT_EXTRACTOR] No facts extracted');
        return;
      }

      final facts = parsed.map((item) {
        return MemoryFact(
          id: _uuid.v4(),
          category: item['category'] ?? 'general',
          fact: item['fact'] ?? '',
          confidence: (item['confidence'] ?? 0.85).toDouble(),
          createdAt: DateTime.now(),
        );
      }).where((f) => f.fact.isNotEmpty).toList();

      if (facts.isNotEmpty) {
        await _memory.addFacts(facts);
        debugPrint('[FACT_EXTRACTOR] ✅ Extracted ${facts.length} facts');
      }
    } catch (e) {
      debugPrint('[FACT_EXTRACTOR] ❌ Extraction failed: $e');
    }
  }

  /// Extract implicit time commitments for auto-reminders.
  /// Returns list of detected commitments like "study OS tonight", "exam on Friday".
  static List<ImplicitCommitment> detectImplicitCommitments(String message) {
    final lower = message.toLowerCase();
    final commitments = <ImplicitCommitment>[];

    // Patterns: "I'll ... tonight/tomorrow/on Friday"
    final patterns = [
      RegExp(r"i(?:'ll| will| need to| have to| should| gotta| must)\s+(.+?)\s+(tonight|tomorrow|today|on \w+|this (?:evening|morning|afternoon|weekend))", caseSensitive: false),
      RegExp(r"my (\w+)\s+(?:exam|test|quiz|presentation|deadline|interview)\s+(?:is )?(on |tomorrow|today|this )", caseSensitive: false),
      RegExp(r"i need to (?:call|text|message|email|meet|visit)\s+(\w+)", caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        commitments.add(ImplicitCommitment(
          rawText: match.group(0) ?? '',
          fullMessage: message,
        ));
      }
    }

    return commitments;
  }
}

class ImplicitCommitment {
  final String rawText;
  final String fullMessage;

  const ImplicitCommitment({
    required this.rawText,
    required this.fullMessage,
  });
}
