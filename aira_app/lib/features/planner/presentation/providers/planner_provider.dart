import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/core/services/api_service.dart';

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
  final ApiService _api = ApiService();

  PlannerNotifier() : super(const PlannerState());

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tasksData = await _api.listTasks();
      final habitsData = await _api.listHabits();

      final tasks = tasksData.map((json) => TaskItem.fromJson(json)).toList();
      final habits = habitsData.map((json) => HabitItem.fromJson(json)).toList();

      state = state.copyWith(
        tasks: tasks,
        habits: habits,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Tasks actions
  Future<void> addTask(Map<String, dynamic> taskData) async {
    try {
      final data = await _api.createTask(taskData);
      final newTask = TaskItem.fromJson(data);
      state = state.copyWith(tasks: [...state.tasks, newTask]);
    } catch (e) {
      state = state.copyWith(error: 'Failed to create task: $e');
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
      await _api.updateTask(taskId, {'status': statusStr});
    } catch (e) {
      // Revert on error
      state = state.copyWith(tasks: previousTasks, error: 'Failed to update task: $e');
    }
  }

  Future<void> deleteTask(String taskId) async {
    final previousTasks = state.tasks;
    state = state.copyWith(tasks: state.tasks.where((t) => t.id != taskId).toList());
    try {
      await _api.deleteTask(taskId);
    } catch (e) {
      state = state.copyWith(tasks: previousTasks, error: 'Failed to delete task: $e');
    }
  }

  // Habits actions
  Future<void> addHabit(Map<String, dynamic> habitData) async {
    try {
      final data = await _api.createHabit(habitData);
      final newHabit = HabitItem.fromJson(data);
      state = state.copyWith(habits: [...state.habits, newHabit]);
    } catch (e) {
      state = state.copyWith(error: 'Failed to create habit: $e');
    }
  }

  Future<void> checkInHabit(String habitId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _api.logHabit(habitId);
      // Reload habits to update streak numbers
      final habitsData = await _api.listHabits();
      state = state.copyWith(
        habits: habitsData.map((json) => HabitItem.fromJson(json)).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to log check-in: $e');
    }
  }

  Future<void> deleteHabit(String habitId) async {
    final previousHabits = state.habits;
    state = state.copyWith(habits: state.habits.where((h) => h.id != habitId).toList());
    try {
      await _api.deleteHabit(habitId);
    } catch (e) {
      state = state.copyWith(habits: previousHabits, error: 'Failed to delete habit: $e');
    }
  }
}

// ──────────────────── Provider ────────────────────

final plannerProvider = StateNotifierProvider<PlannerNotifier, PlannerState>((ref) {
  return PlannerNotifier();
});
