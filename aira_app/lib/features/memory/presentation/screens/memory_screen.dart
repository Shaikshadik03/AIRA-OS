import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/widgets/glassmorphic_container.dart';
import 'package:aira_app/core/services/api_service.dart';

/// Memory data model.
class MemoryItem {
  final String id;
  final String content;
  final String category;
  final double importanceScore;
  final DateTime createdAt;

  const MemoryItem({
    required this.id,
    required this.content,
    required this.category,
    required this.importanceScore,
    required this.createdAt,
  });

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? 'general',
      importanceScore: (json['importance_score'] ?? 0.5).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  IconData get categoryIcon {
    switch (category) {
      case 'fact':
        return Icons.info_outline_rounded;
      case 'preference':
        return Icons.favorite_outline_rounded;
      case 'habit':
        return Icons.repeat_rounded;
      case 'goal':
        return Icons.flag_outlined;
      case 'note':
        return Icons.sticky_note_2_outlined;
      default:
        return Icons.memory_rounded;
    }
  }

  Color get categoryColor {
    switch (category) {
      case 'fact':
        return AiraColors.neonBlue;
      case 'preference':
        return AiraColors.neonPink;
      case 'habit':
        return AiraColors.success;
      case 'goal':
        return AiraColors.warning;
      case 'note':
        return AiraColors.purple;
      default:
        return AiraColors.electricCyan;
    }
  }
}

/// Memory Viewer state provider.
final memoryListProvider =
    StateNotifierProvider<MemoryListNotifier, MemoryListState>((ref) {
  return MemoryListNotifier();
});

class MemoryListState {
  final List<MemoryItem> memories;
  final bool isLoading;
  final String? selectedCategory;

  const MemoryListState({
    this.memories = const [],
    this.isLoading = false,
    this.selectedCategory,
  });

  MemoryListState copyWith({
    List<MemoryItem>? memories,
    bool? isLoading,
    String? selectedCategory,
  }) {
    return MemoryListState(
      memories: memories ?? this.memories,
      isLoading: isLoading ?? this.isLoading,
      selectedCategory: selectedCategory,
    );
  }
}

class MemoryListNotifier extends StateNotifier<MemoryListState> {
  final ApiService _api = ApiService();

  MemoryListNotifier() : super(const MemoryListState());

  Future<void> loadMemories({String? category}) async {
    state = state.copyWith(isLoading: true, selectedCategory: category);
    try {
      final data = await _api.listMemories(category: category);
      final memories = data.map((json) => MemoryItem.fromJson(json)).toList();
      state = state.copyWith(memories: memories, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> deleteMemory(String id) async {
    try {
      await _api.deleteMemory(id);
      state = state.copyWith(
        memories: state.memories.where((m) => m.id != id).toList(),
      );
    } catch (_) {}
  }
}

/// Memory Viewer Screen.
class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(memoryListProvider.notifier).loadMemories());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memoryListProvider);
    final categories = ['all', 'fact', 'preference', 'habit', 'goal', 'note'];

    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            const Icon(Icons.psychology_rounded,
                color: AiraColors.electricCyan, size: 24),
            const SizedBox(width: 8),
            Text("AIRA's Memory", style: AiraTypography.h4),
          ],
        ),
      ),
      body: Column(
        children: [
          // Category filter chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = (state.selectedCategory ?? 'all') ==
                    (cat == 'all' ? null : cat).toString();
                final isAll = cat == 'all' && state.selectedCategory == null;

                return GestureDetector(
                  onTap: () {
                    ref.read(memoryListProvider.notifier).loadMemories(
                          category: cat == 'all' ? null : cat,
                        );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isAll || isSelected
                          ? AiraColors.electricCyan.withValues(alpha: 0.15)
                          : AiraColors.surfaceDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isAll || isSelected
                            ? AiraColors.electricCyan.withValues(alpha: 0.4)
                            : AiraColors.glassBorder,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        cat[0].toUpperCase() + cat.substring(1),
                        style: AiraTypography.caption.copyWith(
                          color: isAll || isSelected
                              ? AiraColors.electricCyan
                              : AiraColors.textMuted,
                          fontWeight: isAll || isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Memory count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  '${state.memories.length} memories stored',
                  style: AiraTypography.caption.copyWith(
                    color: AiraColors.textMuted,
                  ),
                ),
                const Spacer(),
                Icon(Icons.auto_awesome,
                    size: 14, color: AiraColors.electricCyan.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(
                  'Auto-extracted',
                  style: AiraTypography.overline.copyWith(
                    color: AiraColors.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Memory list
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AiraColors.electricCyan,
                    ),
                  )
                : state.memories.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: state.memories.length,
                        itemBuilder: (context, index) {
                          final memory = state.memories[index];
                          return Dismissible(
                            key: Key(memory.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AiraColors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.delete_rounded,
                                  color: AiraColors.error),
                            ),
                            onDismissed: (_) {
                              ref
                                  .read(memoryListProvider.notifier)
                                  .deleteMemory(memory.id);
                            },
                            child: _buildMemoryCard(memory, index),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(MemoryItem memory, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: memory.categoryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                memory.categoryIcon,
                size: 18,
                color: memory.categoryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory.content,
                    style: AiraTypography.bodyMedium.copyWith(
                      color: AiraColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              memory.categoryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          memory.category,
                          style: AiraTypography.overline.copyWith(
                            color: memory.categoryColor,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _timeAgo(memory.createdAt),
                        style: AiraTypography.overline.copyWith(
                          color: AiraColors.textMuted,
                          fontSize: 9,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
          delay: Duration(milliseconds: 50 * index),
          duration: 300.ms,
        );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 56,
            color: AiraColors.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No memories yet',
            style: AiraTypography.h5.copyWith(color: AiraColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Chat with AIRA and memories will\nbe automatically extracted!',
            style: AiraTypography.bodySmall.copyWith(
              color: AiraColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
