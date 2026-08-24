import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Entity node in the Cognitive Memory Graph
class MemoryEntity {
  final String id;
  final String category; // 'person', 'subject', 'habit', 'preference', 'project'
  final String name;
  final Map<String, dynamic> attributes;
  final DateTime updatedAt;

  MemoryEntity({
    required this.id,
    required this.category,
    required this.name,
    required this.attributes,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'name': name,
    'attributes': attributes,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MemoryEntity.fromJson(Map<String, dynamic> json) => MemoryEntity(
    id: json['id'] as String? ?? '',
    category: json['category'] as String? ?? 'preference',
    name: json['name'] as String? ?? '',
    attributes: Map<String, dynamic>.from(json['attributes'] as Map? ?? {}),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Dynamic Cognitive User Memory Graph
/// Stores deep social, academic, personal, and habit context for total AI personalization.
class CognitiveMemoryEngine {
  static final CognitiveMemoryEngine _instance = CognitiveMemoryEngine._internal();
  factory CognitiveMemoryEngine() => _instance;
  CognitiveMemoryEngine._internal();

  static const String _storageKey = 'aira_cognitive_memory_graph_v1';
  final Map<String, MemoryEntity> _entities = {};
  bool _loaded = false;

  Future<void> init() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final List list = jsonDecode(raw);
        for (final item in list) {
          final e = MemoryEntity.fromJson(Map<String, dynamic>.from(item as Map));
          _entities[e.id] = e;
        }
      } catch (_) {}
    } else {
      // Seed initial default academic context for Arshan
      _seedDefaultKnowledge();
      await _save();
    }
    _loaded = true;
  }

  void _seedDefaultKnowledge() {
    _upsertEntity(MemoryEntity(
      id: 'person_user',
      category: 'person',
      name: 'Arshan',
      attributes: {
        'role': 'CSE Student',
        'focus': ['Operating Systems', 'DBMS', 'DSA', 'AI/Agentic Systems'],
        'interests': ['Coding', 'Automation', 'Lofi / Classical Music'],
      },
      updatedAt: DateTime.now(),
    ));

    _upsertEntity(MemoryEntity(
      id: 'person_neha',
      category: 'person',
      name: 'Neha',
      attributes: {
        'relationship': 'Friend & Study Partner',
        'context': 'Studies OS and shares notes',
      },
      updatedAt: DateTime.now(),
    ));
  }

  void _upsertEntity(MemoryEntity entity) {
    _entities[entity.id] = entity;
  }

  Future<void> saveEntity(MemoryEntity entity) async {
    await init();
    _entities[entity.id] = entity;
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _entities.values.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(list));
  }

  List<MemoryEntity> getAllEntities() {
    return _entities.values.toList();
  }

  /// Builds a rich summary prompt section for the LLM system prompt
  String buildCognitiveSummary() {
    if (_entities.isEmpty) return '';

    final buffer = StringBuffer('### USER COGNITIVE CONTEXT & RELATIONSHIP GRAPH:\n');
    for (final e in _entities.values) {
      buffer.write('- **[${e.category.toUpperCase()}] ${e.name}**: ');
      final attrs = e.attributes.entries.map((kv) => '${kv.key}: ${kv.value}').join(', ');
      buffer.writeln(attrs);
    }
    return buffer.toString().trim();
  }
}
