/// AI Intent Detector for in-built TickTick-style Task, Habit & Alarm commands.
class TaskIntentDetector {
  static bool isTaskCommand(String message) {
    final lower = message.toLowerCase().trim();

    final triggers = [
      // English triggers
      'add task', 'create task', 'new task', 'add to task', 'add to my task',
      'add to ticktick', 'ticktick', 'remind me', 'set reminder', 'set alarm for task',
      'show my tasks', 'show tasks', 'list tasks', 'my tasks', 'today tasks',
      'what are my tasks', 'show my agenda', 'show ticktick',
      'complete task', 'mark task as done', 'mark as completed', 'finish task',
      'delete task', 'remove task',
      // Telugu & code-mixed triggers
      'task add cheyyi', 'task pettuko', 'task pettu', 'naku remind cheyyi',
      'gurthupettu', 'gurthu pettu', 'naa tasks chupinchu', 'tasks chupinchu',
      'tasks kanipinchu', 'ee roju tasks', 'naa tasks', 'task complete cheyyi',
      'task aipoyindi', 'task ayipoyindi', 'task finish cheyyi',
      'task delete cheyyi', 'task teeseyyi', 'task teesey',
    ];

    return triggers.any((t) => lower.contains(t));
  }

  static TaskCommand? parse(String message) {
    final lower = message.toLowerCase().trim();

    // ── Show Tasks (English + Telugu) ──
    if (lower.contains('show my tasks') ||
        lower.contains('show tasks') ||
        lower.contains('list tasks') ||
        lower.contains('my tasks') ||
        lower.contains('what are my tasks') ||
        lower.contains('show my agenda') ||
        lower.contains('show ticktick') ||
        lower.contains('today tasks') ||
        lower.contains('naa tasks chupinchu') ||
        lower.contains('tasks chupinchu') ||
        lower.contains('tasks kanipinchu') ||
        lower.contains('ee roju tasks') ||
        lower.contains('naa tasks')) {
      return const TaskCommand(type: TaskCommandType.listTasks);
    }

    // ── Complete Task (English + Telugu) ──
    if (lower.contains('complete task') ||
        lower.contains('mark task as done') ||
        lower.contains('mark as completed') ||
        lower.contains('finish task') ||
        lower.contains('task complete cheyyi') ||
        lower.contains('task aipoyindi') ||
        lower.contains('task ayipoyindi') ||
        lower.contains('task finish cheyyi')) {
      var title = lower;
      title = title.replaceAll(RegExp(r'^(complete task|mark task as done|mark task|finish task|mark as completed|task complete cheyyi|task aipoyindi|task ayipoyindi|task finish cheyyi)\s*'), '');
      return TaskCommand(type: TaskCommandType.completeTask, title: title.trim());
    }

    // ── Delete Task (English + Telugu) ──
    if (lower.contains('delete task') || lower.contains('remove task') ||
        lower.contains('task delete cheyyi') || lower.contains('task teeseyyi') ||
        lower.contains('task teesey')) {
      var title = lower;
      title = title.replaceAll(RegExp(r'^(delete task|remove task|task delete cheyyi|task teeseyyi|task teesey)\s*'), '');
      return TaskCommand(type: TaskCommandType.deleteTask, title: title.trim());
    }

    // ── Add Task / Remind Me ──
    String taskTitle = '';
    DateTime? dueDate;
    bool hasAlarm = false;
    String priority = 'medium';
    String category = 'Inbox';

    // Check Priority
    if (lower.contains('urgent') || lower.contains('p1')) {
      priority = 'urgent';
    } else if (lower.contains('high priority') || lower.contains('high') || lower.contains('p2')) {
      priority = 'high';
    } else if (lower.contains('low priority') || lower.contains('low') || lower.contains('p4')) {
      priority = 'low';
    }

    // Check Category
    if (lower.contains('study') || lower.contains('class') || lower.contains('exam') || lower.contains('homework')) {
      category = 'Study';
    } else if (lower.contains('work') || lower.contains('project') || lower.contains('meeting') || lower.contains('code')) {
      category = 'Work';
    } else if (lower.contains('fitness') || lower.contains('gym') || lower.contains('workout')) {
      category = 'Fitness';
    } else if (lower.contains('personal') || lower.contains('home') || lower.contains('buy')) {
      category = 'Personal';
    }

    // Check Time / Alarm
    final now = DateTime.now();
    final timeMatch = RegExp(r'(?:at|by)\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false).firstMatch(lower);
    if (timeMatch != null) {
      int hour = int.tryParse(timeMatch.group(1) ?? '') ?? 9;
      final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
      final period = timeMatch.group(3)?.toLowerCase();

      if (period == 'pm' && hour < 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;

      int dayOffset = 0;
      if (lower.contains('tomorrow') || lower.contains('repu')) dayOffset = 1;

      final targetTime = DateTime(now.year, now.month, now.day + dayOffset, hour, minute);
      dueDate = targetTime.isBefore(now) && dayOffset == 0
          ? targetTime.add(const Duration(days: 1))
          : targetTime;

      hasAlarm = lower.contains('alarm') || lower.contains('remind') || lower.contains('alert');
    }

    // Extract Title (strip English + Telugu add-task prefixes)
    String cleanTitle = message;
    cleanTitle = cleanTitle.replaceAll(RegExp(r'^(add task|create task|new task|add to task|add to my task|add to ticktick|ticktick add|remind me to|set reminder for|set alarm for|task add cheyyi|task pettuko|task pettu|naku remind cheyyi|gurthupettu|gurthu pettu)\s*', caseSensitive: false), '');
    cleanTitle = cleanTitle.replaceAll(RegExp(r'\s+(tomorrow|today|repu|at\s+\d{1,2}(:\d{2})?\s*(am|pm)?|by\s+\d{1,2}(:\d{2})?\s*(am|pm)?|with\s+(high|urgent|low|medium)\s+priority)', caseSensitive: false), '');
    cleanTitle = cleanTitle.trim();

    if (cleanTitle.isNotEmpty) {
      taskTitle = cleanTitle;
    } else {
      taskTitle = 'New Task';
    }

    return TaskCommand(
      type: TaskCommandType.addTask,
      title: taskTitle,
      dueDate: dueDate,
      hasAlarm: hasAlarm || dueDate != null,
      priority: priority,
      category: category,
    );
  }
}

enum TaskCommandType {
  addTask,
  listTasks,
  completeTask,
  deleteTask,
}

class TaskCommand {
  final TaskCommandType type;
  final String title;
  final DateTime? dueDate;
  final bool hasAlarm;
  final String priority;
  final String category;

  const TaskCommand({
    required this.type,
    this.title = '',
    this.dueDate,
    this.hasAlarm = false,
    this.priority = 'medium',
    this.category = 'Inbox',
  });
}
