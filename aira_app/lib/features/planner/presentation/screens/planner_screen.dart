import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/widgets/glassmorphic_container.dart';
import 'package:aira_app/core/widgets/aira_button.dart';
import 'package:aira_app/core/widgets/aira_text_field.dart';
import 'package:aira_app/features/planner/presentation/providers/planner_provider.dart';
import 'package:intl/intl.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() => ref.read(plannerProvider.notifier).loadAll());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(plannerProvider);

    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Planner', style: AiraTypography.h4),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AiraColors.electricCyan,
          labelColor: AiraColors.electricCyan,
          unselectedLabelColor: AiraColors.textMuted,
          labelStyle: AiraTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: AiraTypography.bodyMedium,
          tabs: const [
            Tab(text: 'Tasks', icon: Icon(Icons.check_box_outlined)),
            Tab(text: 'Habits', icon: Icon(Icons.repeat_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTasksTab(state),
          _buildHabitsTab(state),
        ],
      ),
    );
  }

  // ──────────────────── Tasks ────────────────────

  Widget _buildTasksTab(PlannerState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AiraColors.electricCyan));
    }

    final pendingTasks = state.tasks.where((t) => !t.isCompleted).toList();
    final completedTasks = state.tasks.where((t) => t.isCompleted).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(plannerProvider.notifier).loadAll(),
      color: AiraColors.electricCyan,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Today's Tasks", style: AiraTypography.h5),
              AiraButton(
                label: 'Add Task',
                icon: Icons.add,
                onPressed: () => _showAddTaskDialog(),
                isPrimary: false,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (pendingTasks.isEmpty)
            _buildEmptyState('No tasks for today. Add one above!', Icons.sentiment_satisfied_alt_rounded)
          else
            ...pendingTasks.map((task) => _buildTaskTile(task)),
          if (completedTasks.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text("Completed", style: AiraTypography.h6.copyWith(color: AiraColors.textMuted)),
            const SizedBox(height: 12),
            ...completedTasks.map((task) => _buildTaskTile(task)),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskTile(TaskItem task) {
    Color priorityColor;
    switch (task.priority) {
      case 'urgent':
        priorityColor = AiraColors.error;
        break;
      case 'high':
        priorityColor = AiraColors.warning;
        break;
      case 'medium':
        priorityColor = AiraColors.neonBlue;
        break;
      default:
        priorityColor = AiraColors.success;
    }

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AiraColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AiraColors.error),
      ),
      onDismissed: (_) {
        ref.read(plannerProvider.notifier).deleteTask(task.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: GlassmorphicContainer(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: task.isCompleted,
                activeColor: AiraColors.electricCyan,
                checkColor: Colors.black,
                onChanged: (val) {
                  ref.read(plannerProvider.notifier).toggleTask(task.id, val ?? false);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: AiraTypography.bodyMedium.copyWith(
                        color: task.isCompleted ? AiraColors.textMuted : AiraColors.textPrimary,
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (task.dueDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, h:mm a').format(task.dueDate!),
                        style: AiraTypography.caption.copyWith(color: AiraColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  task.priority.toUpperCase(),
                  style: AiraTypography.overline.copyWith(color: priorityColor, fontSize: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedPriority = 'medium';
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AiraColors.cardDark,
          title: Text('Add New Task', style: AiraTypography.h5),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AiraTextField(controller: titleController, hintText: 'Task Title'),
                const SizedBox(height: 12),
                AiraTextField(controller: descController, hintText: 'Description (Optional)'),
                const SizedBox(height: 16),
                // Priority picker
                Row(
                  children: [
                    Text('Priority: ', style: AiraTypography.bodySmall),
                    const SizedBox(width: 8),
                    ...['low', 'medium', 'high', 'urgent'].map((p) => Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => selectedPriority = p),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: selectedPriority == p
                                    ? AiraColors.electricCyan.withValues(alpha: 0.15)
                                    : AiraColors.surfaceDark,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selectedPriority == p
                                      ? AiraColors.electricCyan
                                      : AiraColors.glassBorder,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  p[0].toUpperCase() + p.substring(1),
                                  style: AiraTypography.overline.copyWith(
                                    color: selectedPriority == p
                                        ? AiraColors.electricCyan
                                        : AiraColors.textMuted,
                                    fontSize: 8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )),
                  ],
                ),
                const SizedBox(height: 16),
                // Date picker
                Row(
                  children: [
                    Text('Date: ', style: AiraTypography.bodySmall),
                    const Spacer(),
                    TextButton(
                      child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: AiraColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AiraColors.electricCyan),
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                
                final combinedDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                ref.read(plannerProvider.notifier).addTask({
                  'title': titleController.text.trim(),
                  'description': descController.text.trim(),
                  'due_date': DateFormat('yyyy-MM-dd').format(combinedDateTime),
                  'due_time': DateFormat('HH:mm:ss').format(combinedDateTime),
                  'priority': selectedPriority,
                });
                Navigator.pop(ctx);
              },
              child: const Text('Create', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────── Habits ────────────────────

  Widget _buildHabitsTab(PlannerState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AiraColors.electricCyan));
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(plannerProvider.notifier).loadAll(),
      color: AiraColors.electricCyan,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemCount: state.habits.length + 1,
        itemBuilder: (context, index) {
          if (index == state.habits.length) {
            return _buildAddHabitCard();
          }
          return _buildHabitCard(state.habits[index]);
        },
      ),
    );
  }

  Widget _buildHabitCard(HabitItem habit) {
    final color = habit.color != null ? Color(int.parse(habit.color!)) : AiraColors.electricCyan;
    
    return GestureDetector(
      onLongPress: () {
        ref.read(plannerProvider.notifier).checkInHabit(habit.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged ${habit.name}! 🔥'),
            backgroundColor: AiraColors.cardDark,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.check_circle_outline, size: 20, color: color),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16, color: AiraColors.textMuted),
                  onPressed: () => ref.read(plannerProvider.notifier).deleteHabit(habit.id),
                ),
              ],
            ),
            const Spacer(),
            Text(habit.name, style: AiraTypography.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.local_fire_department_rounded, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  '${habit.currentStreak} day streak',
                  style: AiraTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Hold to log',
              style: AiraTypography.overline.copyWith(color: AiraColors.textMuted, fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddHabitCard() {
    return GestureDetector(
      onTap: () => _showAddHabitDialog(),
      child: DottedBorderContainer(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, size: 28, color: AiraColors.textMuted),
            const SizedBox(height: 8),
            Text('Add Habit', style: AiraTypography.bodySmall.copyWith(color: AiraColors.textMuted)),
          ],
        ),
      ),
    );
  }

  void _showAddHabitDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    Color selectedColor = AiraColors.electricCyan;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AiraColors.cardDark,
          title: Text('New Habit', style: AiraTypography.h5),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AiraTextField(controller: nameController, hintText: 'Habit Name (e.g. Exercise)'),
              const SizedBox(height: 12),
              AiraTextField(controller: descController, hintText: 'Short Description'),
              const SizedBox(height: 16),
              // Color selection
              Row(
                children: [
                  Text('Color: ', style: AiraTypography.bodySmall),
                  const SizedBox(width: 8),
                  ...[AiraColors.electricCyan, AiraColors.purple, AiraColors.success, AiraColors.warning].map((col) => GestureDetector(
                        onTap: () => setModalState(() => selectedColor = col),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: selectedColor == col ? Border.all(color: Colors.white, width: 2) : null,
                          ),
                        ),
                      )),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: AiraColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AiraColors.electricCyan),
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                ref.read(plannerProvider.notifier).addHabit({
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                  'color': selectedColor.toARGB32().toString(),
                  'frequency': 'daily',
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────── Common widgets ────────────────────

  Widget _buildEmptyState(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AiraColors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(text, style: AiraTypography.bodySmall.copyWith(color: AiraColors.textMuted), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class DottedBorderContainer extends StatelessWidget {
  final Widget child;

  const DottedBorderContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AiraColors.surfaceDark.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AiraColors.glassBorder,
          style: BorderStyle.solid,
        ),
      ),
      child: child,
    );
  }
}
