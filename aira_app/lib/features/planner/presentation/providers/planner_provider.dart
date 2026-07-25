import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ──────────────────── Models ────────────────────

class TaskItem {
  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String priority; // low, medium, high, urgent
  final String status; // pending, completed
  final String? category;

  const TaskItem({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    required this.priority,
    required this.status,
    this.category,
  });

  bool get isCompleted => status == 'completed';

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'pending',
      category: json['category'],
    );
  }

  TaskItem copyWith({
    String? status,
  }) {
    return TaskItem(
      id: id,
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      status: status ?? this.status,
      category: category,
    );
  }
}

class HabitItem {
  final String id;
  final String name;
  final String? description;
  final String frequency;
  final int targetCount;
  final String? icon;
  final String? color;
  final int currentStreak;
  final int longestStreak;

  const HabitItem({
    required this.id,
    required this.name,
    this.description,
    required this.frequency,
    required this.targetCount,
    this.icon,
    this.color,
    required this.currentStreak,
    required this.longestStreak,
  });

  factory HabitItem.fromJson(Map<String, dynamic> json) {
    return HabitItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      frequency: json['frequency'] ?? 'daily',
      targetCount: json['target_count'] ?? 1,
      icon: json['icon'],
      color: json['color'],
      currentStreak: json['current_streak'] ?? 0,
      longestStreak: json['longest_streak'] ?? 0,
    );
  }
}

// ──────────────────── State ────────────────────

class PlannerState {
  final List<TaskItem> tasks;
  final List<HabitItem> habits;
  final bool isLoading;
  final String? error;

  const PlannerState({
    this.tasks = const [],
    this.habits = const [],
    this.isLoading = false,
    this.error,
  });

  PlannerState copyWith({
    List<TaskItem>? tasks,
    List<HabitItem>? habits,
    bool? isLoading,
    String? error,
  }) {
    return PlannerState(
      tasks: tasks ?? this.tasks,
      habits: habits ?? this.habits,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  double get completionRate {
    final total = tasks.length + habits.length;
    if (total == 0) return 0.0;
    
    final completedTasks = tasks.where((t) => t.isCompleted).length;
    // For habits, let's count a habit checked if its currentStreak > 0 for now (simulated log representation)
    final activeHabits = habits.where((h) => h.currentStreak > 0).length;
    
    return (completedTasks + activeHabits) / total;
  }
}

// ──────────────────── Notifier ────────────────────

class PlannerNotifier extends StateNotifier<PlannerState> {
  PlannerNotifier() : super(const PlannerState());

  final _supabase = Supabase.instance.client;

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not logged in');

      final tasksRes = await _supabase.from('tasks').select().eq('user_id', userId);
      final habitsRes = await _supabase.from('habits').select().eq('user_id', userId);

      final tasks = (tasksRes as List).map((e) => TaskItem.fromJson(e)).toList();
      final habits = (habitsRes as List).map((e) => HabitItem.fromJson(e)).toList();

      state = state.copyWith(
        tasks: tasks,
        habits: habits,
        isLoading: false,
      );
    } catch (e) {
      // If table doesn't exist, we just show empty list (to avoid crashing if user hasn't run SQL yet)
      state = state.copyWith(isLoading: false, tasks: [], habits: []);
    }
  }

  // Tasks actions
  Future<void> addTask(Map<String, dynamic> taskData) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      final data = await _supabase.from('tasks').insert({
        ...taskData,
        'user_id': userId,
      }).select().single();
      
      final newTask = TaskItem.fromJson(data);
      state = state.copyWith(tasks: [...state.tasks, newTask]);
    } catch (e) {
      state = state.copyWith(error: 'Failed to create task. Did you run the SQL script?');
    }
  }

  Future<void> toggleTask(String taskId, bool isCompleted) async {
    final statusStr = isCompleted ? 'completed' : 'pending';
    
    // Optimistic UI update
    final previousTasks = state.tasks;
    state = state.copyWith(
      tasks: state.tasks.map((t) => t.id == taskId ? t.copyWith(status: statusStr) : t).toList(),
    );

    try {
      await _supabase.from('tasks').update({'status': statusStr}).eq('id', taskId);
    } catch (e) {
      // Revert on error
      state = state.copyWith(tasks: previousTasks, error: 'Failed to update task');
    }
  }

  Future<void> deleteTask(String taskId) async {
    final previousTasks = state.tasks;
    state = state.copyWith(tasks: state.tasks.where((t) => t.id != taskId).toList());
    try {
      await _supabase.from('tasks').delete().eq('id', taskId);
    } catch (e) {
      state = state.copyWith(tasks: previousTasks, error: 'Failed to delete task');
    }
  }

  // Habits actions
  Future<void> addHabit(Map<String, dynamic> habitData) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase.from('habits').insert({
        ...habitData,
        'user_id': userId,
      }).select().single();
      
      final newHabit = HabitItem.fromJson(data);
      state = state.copyWith(habits: [...state.habits, newHabit]);
    } catch (e) {
      state = state.copyWith(error: 'Failed to create habit');
    }
  }

  Future<void> checkInHabit(String habitId) async {
    // Basic optimistic streak bump for now
    try {
      // Just reload for now
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: 'Failed to check in');
    }
  }

  Future<void> deleteHabit(String habitId) async {
    final previousHabits = state.habits;
    state = state.copyWith(habits: state.habits.where((h) => h.id != habitId).toList());
    try {
      await _supabase.from('habits').delete().eq('id', habitId);
    } catch (e) {
      state = state.copyWith(habits: previousHabits, error: 'Failed to delete habit');
    }
  }
}

// ──────────────────── Provider ────────────────────

final plannerProvider = StateNotifierProvider<PlannerNotifier, PlannerState>((ref) {
  return PlannerNotifier();
});
