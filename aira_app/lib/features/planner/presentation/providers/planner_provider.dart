import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:aira_app/core/services/notification_service.dart';

// ──────────────────── Models ────────────────────

class TaskItem {
  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool hasAlarm;
  final String priority; // low, medium, high, urgent
  final String status; // pending, completed
  final String category; // Inbox, Study, Work, Personal, Fitness
  final DateTime createdAt;

  const TaskItem({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.hasAlarm = false,
    this.priority = 'medium',
    this.status = 'pending',
    this.category = 'Inbox',
    required this.createdAt,
  });

  bool get isCompleted => status == 'completed';

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null,
      hasAlarm: json['has_alarm'] == true || json['has_alarm'] == 1,
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'pending',
      category: json['category'] ?? 'Inbox',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'due_date': dueDate?.toIso8601String(),
      'has_alarm': hasAlarm,
      'priority': priority,
      'status': status,
      'category': category,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TaskItem copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    bool? hasAlarm,
    String? priority,
    String? status,
    String? category,
  }) {
    return TaskItem(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      hasAlarm: hasAlarm ?? this.hasAlarm,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      category: category ?? this.category,
      createdAt: createdAt,
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
  final DateTime? lastChecked;

  const HabitItem({
    required this.id,
    required this.name,
    this.description,
    this.frequency = 'daily',
    this.targetCount = 1,
    this.icon,
    this.color,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastChecked,
  });

  bool get isCompletedToday {
    if (lastChecked == null) return false;
    final now = DateTime.now();
    return lastChecked!.year == now.year &&
        lastChecked!.month == now.month &&
        lastChecked!.day == now.day;
  }

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
      lastChecked: json['last_checked'] != null ? DateTime.tryParse(json['last_checked']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'frequency': frequency,
      'target_count': targetCount,
      'icon': icon,
      'color': color,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_checked': lastChecked?.toIso8601String(),
    };
  }

  HabitItem copyWith({
    String? name,
    String? description,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastChecked,
  }) {
    return HabitItem(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      frequency: frequency,
      targetCount: targetCount,
      icon: icon,
      color: color,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastChecked: lastChecked ?? this.lastChecked,
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
    if (tasks.isEmpty) return 0.0;
    final completed = tasks.where((t) => t.isCompleted).length;
    return completed / tasks.length;
  }
}

// ──────────────────── Notifier ────────────────────

class PlannerNotifier extends StateNotifier<PlannerState> {
  PlannerNotifier() : super(const PlannerState()) {
    loadAll();
  }

  static const String _localTasksKey = 'aira_local_tasks_v2';
  static const String _localHabitsKey = 'aira_local_habits_v2';
  final _uuid = const Uuid();
  final _notifications = NotificationService();

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final prefs = await SharedPreferences.getInstance();
      List<TaskItem> loadedTasks = [];
      List<HabitItem> loadedHabits = [];

      // 1. Load from local persistent storage (offline-first)
      final tasksJson = prefs.getString(_localTasksKey);
      if (tasksJson != null && tasksJson.isNotEmpty) {
        final List list = jsonDecode(tasksJson);
        loadedTasks = list.map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e))).toList();
      }

      final habitsJson = prefs.getString(_localHabitsKey);
      if (habitsJson != null && habitsJson.isNotEmpty) {
        final List list = jsonDecode(habitsJson);
        loadedHabits = list.map((e) => HabitItem.fromJson(Map<String, dynamic>.from(e))).toList();
      }

      // Initial defaults if empty
      if (loadedTasks.isEmpty && loadedHabits.isEmpty) {
        loadedTasks = _getDefaultTasks();
        loadedHabits = _getDefaultHabits();
        await _saveLocal(loadedTasks, loadedHabits);
      }

      state = state.copyWith(
        tasks: loadedTasks,
        habits: loadedHabits,
        isLoading: false,
      );

      // 2. Optional Supabase cloud sync if logged in
      try {
        final supabase = Supabase.instance.client;
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          final tasksRes = await supabase.from('tasks').select().eq('user_id', userId);
          if (tasksRes.isNotEmpty) {
            final cloudTasks = tasksRes.map((e) => TaskItem.fromJson(e)).toList();
            state = state.copyWith(tasks: cloudTasks);
            await _saveLocal(cloudTasks, state.habits);
          }
        }
      } catch (_) {}
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _saveLocal(List<TaskItem> tasks, List<HabitItem> habits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localTasksKey, jsonEncode(tasks.map((t) => t.toJson()).toList()));
    await prefs.setString(_localHabitsKey, jsonEncode(habits.map((h) => h.toJson()).toList()));
  }

  // ── Task Actions ────────────────────────────────────────────────────────

  Future<TaskItem> addTask({
    required String title,
    String? description,
    DateTime? dueDate,
    bool hasAlarm = false,
    String priority = 'medium',
    String category = 'Inbox',
  }) async {
    final newTask = TaskItem(
      id: _uuid.v4(),
      title: title.trim(),
      description: description?.trim(),
      dueDate: dueDate,
      hasAlarm: hasAlarm,
      priority: priority,
      category: category,
      createdAt: DateTime.now(),
    );

    final updatedTasks = [newTask, ...state.tasks];
    state = state.copyWith(tasks: updatedTasks);
    await _saveLocal(updatedTasks, state.habits);

    // Schedule Android local notification / alarm if requested
    if (hasAlarm && dueDate != null && dueDate.isAfter(DateTime.now())) {
      final notifId = newTask.id.hashCode.abs() % 100000;
      await _notifications.scheduleNotification(
        id: notifId,
        title: '⏰ Task Reminder: ${newTask.title}',
        body: newTask.description?.isNotEmpty == true
            ? newTask.description!
            : 'Scheduled for ${dueDate.hour.toString().padLeft(2, '0')}:${dueDate.minute.toString().padLeft(2, '0')}',
        scheduledDate: dueDate,
      );
    }

    // Background sync to Supabase
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase.from('tasks').insert({
          ...newTask.toJson(),
          'user_id': userId,
        });
      }
    } catch (_) {}

    return newTask;
  }

  Future<void> updateTask(TaskItem task) async {
    final updatedTasks = state.tasks.map((t) => t.id == task.id ? task : t).toList();
    state = state.copyWith(tasks: updatedTasks);
    await _saveLocal(updatedTasks, state.habits);

    // Reschedule alarm if needed
    if (task.hasAlarm && task.dueDate != null && task.dueDate!.isAfter(DateTime.now())) {
      final notifId = task.id.hashCode.abs() % 100000;
      await _notifications.scheduleNotification(
        id: notifId,
        title: '⏰ Task Reminder: ${task.title}',
        body: task.description?.isNotEmpty == true
            ? task.description!
            : 'Scheduled for ${task.dueDate!.hour.toString().padLeft(2, '0')}:${task.dueDate!.minute.toString().padLeft(2, '0')}',
        scheduledDate: task.dueDate!,
      );
    }

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('tasks').update(task.toJson()).eq('id', task.id);
    } catch (_) {}
  }

  Future<void> toggleTask(String taskId, bool isCompleted) async {
    final statusStr = isCompleted ? 'completed' : 'pending';
    final updatedTasks = state.tasks.map((t) => t.id == taskId ? t.copyWith(status: statusStr) : t).toList();
    state = state.copyWith(tasks: updatedTasks);
    await _saveLocal(updatedTasks, state.habits);

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('tasks').update({'status': statusStr}).eq('id', taskId);
    } catch (_) {}
  }

  Future<void> deleteTask(String taskId) async {
    final updatedTasks = state.tasks.where((t) => t.id != taskId).toList();
    state = state.copyWith(tasks: updatedTasks);
    await _saveLocal(updatedTasks, state.habits);

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('tasks').delete().eq('id', taskId);
    } catch (_) {}
  }

  // ── Habit Actions ───────────────────────────────────────────────────────

  Future<void> addHabit({
    required String name,
    String? description,
    String frequency = 'daily',
    String? color,
  }) async {
    final newHabit = HabitItem(
      id: _uuid.v4(),
      name: name.trim(),
      description: description?.trim(),
      frequency: frequency,
      color: color,
    );

    final updatedHabits = [...state.habits, newHabit];
    state = state.copyWith(habits: updatedHabits);
    await _saveLocal(state.tasks, updatedHabits);
  }

  Future<void> checkInHabit(String habitId) async {
    final now = DateTime.now();
    final updatedHabits = state.habits.map((h) {
      if (h.id == habitId) {
        final alreadyDoneToday = h.isCompletedToday;
        final newStreak = alreadyDoneToday ? (h.currentStreak > 0 ? h.currentStreak - 1 : 0) : h.currentStreak + 1;
        final longest = newStreak > h.longestStreak ? newStreak : h.longestStreak;
        return h.copyWith(
          currentStreak: newStreak,
          longestStreak: longest,
          lastChecked: alreadyDoneToday ? null : now,
        );
      }
      return h;
    }).toList();

    state = state.copyWith(habits: updatedHabits);
    await _saveLocal(state.tasks, updatedHabits);
  }

  Future<void> deleteHabit(String habitId) async {
    final updatedHabits = state.habits.where((h) => h.id != habitId).toList();
    state = state.copyWith(habits: updatedHabits);
    await _saveLocal(state.tasks, updatedHabits);
  }

  // ── Default Data ────────────────────────────────────────────────────────

  List<TaskItem> _getDefaultTasks() {
    final now = DateTime.now();
    return [
      TaskItem(
        id: '1',
        title: 'Solve Daily DSA Challenge',
        description: 'Complete Kadane\'s Algorithm problem on AIRA Dashboard',
        dueDate: DateTime(now.year, now.month, now.day, 17, 0),
        hasAlarm: true,
        priority: 'high',
        category: 'Study',
        createdAt: now,
      ),
      TaskItem(
        id: '2',
        title: 'Review Operating Systems Lecture Notes',
        description: 'Process Synchronization and Semaphores',
        dueDate: DateTime(now.year, now.month, now.day, 20, 0),
        hasAlarm: false,
        priority: 'medium',
        category: 'Study',
        createdAt: now,
      ),
      TaskItem(
        id: '3',
        title: 'Prepare Hackathon Pitch Deck',
        description: 'Finalize presentation slides for IIT AI Hackathon',
        dueDate: DateTime(now.year, now.month, now.day + 1, 14, 0),
        hasAlarm: true,
        priority: 'urgent',
        category: 'Work',
        createdAt: now,
      ),
    ];
  }

  List<HabitItem> _getDefaultHabits() {
    return [
      const HabitItem(
        id: 'h1',
        name: 'Daily LeetCode Coding',
        description: '1 problem minimum every day',
        currentStreak: 5,
        longestStreak: 12,
        color: '0xFFD97757',
      ),
      const HabitItem(
        id: 'h2',
        name: 'Morning Intelligence Podcast',
        description: 'Listen to AIRA Morning Brief at 7 AM',
        currentStreak: 3,
        longestStreak: 7,
        color: '0xFFD4973B',
      ),
      const HabitItem(
        id: 'h3',
        name: 'Gym & Fitness',
        description: 'Workout / evening walk',
        currentStreak: 4,
        longestStreak: 14,
        color: '0xFF4E9F70',
      ),
    ];
  }
}

// ──────────────────── Provider ────────────────────

final plannerProvider = StateNotifierProvider<PlannerNotifier, PlannerState>((ref) {
  return PlannerNotifier();
});
