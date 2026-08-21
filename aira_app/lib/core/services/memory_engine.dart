import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AIRA Memory Engine — 4-Tier Memory Hierarchy
/// Stores durable facts about the user extracted from conversations.
/// This is the "brain" that makes AIRA feel like it truly knows you.
class MemoryEngine {
  static final MemoryEngine _instance = MemoryEngine._internal();
  factory MemoryEngine() => _instance;
  MemoryEngine._internal();

  static const String _factsKey = 'aira_memory_facts_v2';
  static const String _episodesKey = 'aira_memory_episodes_v2';
  static const int _maxFacts = 200;
  static const int _maxEpisodes = 100;

  List<MemoryFact> _facts = [];
  List<EpisodeEntry> _episodes = [];

  List<MemoryFact> get facts => List.unmodifiable(_facts);
  List<EpisodeEntry> get episodes => List.unmodifiable(_episodes);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Load semantic facts
    final factsJson = prefs.getString(_factsKey);
    if (factsJson != null && factsJson.isNotEmpty) {
      final List list = jsonDecode(factsJson);
      _facts = list.map((e) => MemoryFact.fromJson(Map<String, dynamic>.from(e))).toList();
    }

    // Load episodic summaries
    final episodesJson = prefs.getString(_episodesKey);
    if (episodesJson != null && episodesJson.isNotEmpty) {
      final List list = jsonDecode(episodesJson);
      _episodes = list.map((e) => EpisodeEntry.fromJson(Map<String, dynamic>.from(e))).toList();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_factsKey, jsonEncode(_facts.map((f) => f.toJson()).toList()));
    await prefs.setString(_episodesKey, jsonEncode(_episodes.map((e) => e.toJson()).toList()));
  }

  // ── Semantic Facts (Tier 3) ────────────────────────────────────────────

  /// Add a new fact, replacing any conflicting older fact in the same category.
  Future<void> addFact(MemoryFact fact) async {
    // Check for conflicting fact (same category + similar subject)
    _facts.removeWhere((existing) =>
        existing.category == fact.category &&
        _isSimilarSubject(existing.fact, fact.fact));

    _facts.insert(0, fact);

    // Trim to max
    if (_facts.length > _maxFacts) {
      _facts = _facts.sublist(0, _maxFacts);
    }

    await _save();
    debugPrint('[MEMORY] Added fact: ${fact.fact} (${fact.category})');
  }

  /// Add multiple facts at once (from fact extraction)
  Future<void> addFacts(List<MemoryFact> newFacts) async {
    for (final fact in newFacts) {
      _facts.removeWhere((existing) =>
          existing.category == fact.category &&
          _isSimilarSubject(existing.fact, fact.fact));
      _facts.insert(0, fact);
    }

    if (_facts.length > _maxFacts) {
      _facts = _facts.sublist(0, _maxFacts);
    }

    await _save();
    debugPrint('[MEMORY] Added ${newFacts.length} facts');
  }

  /// Delete a specific fact
  Future<void> deleteFact(String factId) async {
    _facts.removeWhere((f) => f.id == factId);
    await _save();
  }

  /// Get top-N most relevant facts for a query (simple keyword matching)
  List<String> getRelevantFacts(String query, {int limit = 5}) {
    if (_facts.isEmpty) return [];

    final queryWords = query.toLowerCase().split(RegExp(r'\s+'));

    // Score each fact by keyword overlap
    final scored = _facts.map((fact) {
      final factWords = fact.fact.toLowerCase().split(RegExp(r'\s+'));
      int score = 0;
      for (final qw in queryWords) {
        if (qw.length < 3) continue;
        for (final fw in factWords) {
          if (fw.contains(qw) || qw.contains(fw)) score++;
        }
      }
      // Boost recent facts
      final ageDays = DateTime.now().difference(fact.createdAt).inDays;
      if (ageDays < 7) score += 2;
      if (ageDays < 1) score += 3;
      return MapEntry(fact, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));

    return scored
        .take(limit)
        .where((e) => e.value > 0)
        .map((e) => e.key.fact)
        .toList();
  }

  /// Get all facts as strings for display or injection
  List<String> getAllFactStrings() {
    return _facts.map((f) => f.fact).toList();
  }

  // ── Episodic History (Tier 4) ──────────────────────────────────────────

  /// Store a conversation summary
  Future<void> addEpisode(EpisodeEntry episode) async {
    _episodes.insert(0, episode);

    if (_episodes.length > _maxEpisodes) {
      _episodes = _episodes.sublist(0, _maxEpisodes);
    }

    await _save();
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  bool _isSimilarSubject(String existing, String newFact) {
    final existWords = existing.toLowerCase().split(RegExp(r'\s+')).toSet();
    final newWords = newFact.toLowerCase().split(RegExp(r'\s+')).toSet();
    final overlap = existWords.intersection(newWords);
    final threshold = (existWords.length * 0.5).ceil();
    return overlap.length >= threshold;
  }
}

// ── Data Classes ────────────────────────────────────────────────────────

class MemoryFact {
  final String id;
  final String category; // preference, habit, schedule, relationship, skill, goal
  final String fact;
  final double confidence;
  final DateTime createdAt;

  const MemoryFact({
    required this.id,
    required this.category,
    required this.fact,
    this.confidence = 0.9,
    required this.createdAt,
  });

  factory MemoryFact.fromJson(Map<String, dynamic> json) {
    return MemoryFact(
      id: json['id'] ?? '',
      category: json['category'] ?? 'general',
      fact: json['fact'] ?? '',
      confidence: (json['confidence'] ?? 0.9).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'fact': fact,
        'confidence': confidence,
        'created_at': createdAt.toIso8601String(),
      };
}

class EpisodeEntry {
  final String id;
  final String summary;
  final DateTime timestamp;
  final List<String> topics;

  const EpisodeEntry({
    required this.id,
    required this.summary,
    required this.timestamp,
    this.topics = const [],
  });

  factory EpisodeEntry.fromJson(Map<String, dynamic> json) {
    return EpisodeEntry(
      id: json['id'] ?? '',
      summary: json['summary'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      topics: json['topics'] != null
          ? List<String>.from(json['topics'])
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'summary': summary,
        'timestamp': timestamp.toIso8601String(),
        'topics': topics,
      };
}
