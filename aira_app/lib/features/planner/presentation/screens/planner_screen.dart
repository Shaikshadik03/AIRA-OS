import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/features/planner/presentation/providers/planner_provider.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Study',
    'Work',
    'Personal',
    'Fitness',
    'Inbox',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: theme.colorScheme.onSurface, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'TickTick Agenda',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AiraColors.claudeTerracotta, size: 20),
            onPressed: () => ref.read(plannerProvider.notifier).loadAll(),
            tooltip: 'Refresh tasks',
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AiraColors.claudeTerracotta,
          unselectedLabelColor:
              isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
          indicatorColor: AiraColors.claudeTerracotta,
          indicatorWeight: 2.5,
          labelStyle: GoogleFonts.sourceSerif4(
              fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: GoogleFonts.sourceSerif4(fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.today_rounded, size: 18), text: 'Today'),
            Tab(icon: Icon(Icons.view_list_rounded, size: 18), text: 'Lists & Categories'),
            Tab(icon: Icon(Icons.local_fire_department_rounded, size: 18), text: 'Habits'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayTab(state, theme, isDark),
          _buildAllCategoriesTab(state, theme, isDark),
          _buildHabitsTab(state, theme, isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AiraColors.claudeTerracotta,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          'Add Task',
          style: GoogleFonts.sourceSerif4(
              fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          _showTaskEditorSheet(context);
        },
      ),
    );
  }

  // ── Tab 1: Today's Tasks ────────────────────────────────────────────────

  Widget _buildTodayTab(PlannerState state, ThemeData theme, bool isDark) {
    final cardBg = isDark ? AiraColors.cardDark : AiraColors.cardLight;
    final borderColor = isDark ? AiraColors.borderDark : AiraColors.borderLight;
    final mutedColor = isDark ? AiraColors.textMuted : AiraColors.textMutedLight;

    final pending = state.tasks.where((t) => !t.isCompleted).toList();
    final completed = state.tasks.where((t) => t.isCompleted).toList();
    final progress = state.completionRate;

    return RefreshIndicator(
      color: AiraColors.claudeTerracotta,
      onRefresh: () => ref.read(plannerProvider.notifier).loadAll(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // ── Progress Header Card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Productivity',
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}% Done',
                      style: GoogleFonts.sourceSerif4(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AiraColors.claudeTerracotta,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress > 0 ? progress : 0.04,
                    minHeight: 8,
                    backgroundColor: isDark ? const Color(0xFF262522) : const Color(0xFFEDE9DE),
                    valueColor: const AlwaysStoppedAnimation<Color>(AiraColors.claudeTerracotta),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${completed.length} of ${state.tasks.length} tasks completed today.',
                  style: GoogleFonts.sourceSerif4(fontSize: 12, color: mutedColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Category Filter Pills ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat,
                        style: GoogleFonts.sourceSerif4(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? AiraColors.textPrimary : AiraColors.textPrimaryLight),
                        )),
                    selected: isSelected,
                    selectedColor: AiraColors.claudeTerracotta,
                    backgroundColor: isDark ? AiraColors.surfaceDark : AiraColors.surfaceLightWarm,
                    side: BorderSide(
                        color: isSelected ? AiraColors.claudeTerracotta : borderColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // ── Pending Tasks ──
          _buildSectionHeader('Pending Tasks (${_filterTasks(pending).length})', theme),
          const SizedBox(height: 8),
          if (_filterTasks(pending).isEmpty)
            _buildEmptyState('No pending tasks in $_selectedCategory. Tap + to add one!', isDark)
          else
            ..._filterTasks(pending).map((t) => _buildTaskCard(t, theme, isDark)),

          // ── Completed Tasks ──
          if (_filterTasks(completed).isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSectionHeader('Completed (${_filterTasks(completed).length})', theme),
            const SizedBox(height: 8),
            ..._filterTasks(completed).map((t) => _buildTaskCard(t, theme, isDark)),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: Lists & Categories ──────────────────────────────────────────

  Widget _buildAllCategoriesTab(PlannerState state, ThemeData theme, bool isDark) {
    final groups = <String, List<TaskItem>>{};
    for (final cat in _categories.where((c) => c != 'All')) {
      groups[cat] = state.tasks.where((t) => t.category == cat).toList();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: groups.entries.map((entry) {
        final catName = entry.key;
        final list = entry.value;
        final completed = list.where((t) => t.isCompleted).length;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark ? AiraColors.cardDark : AiraColors.cardLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark ? AiraColors.borderDark : AiraColors.borderLight),
          ),
          child: ExpansionTile(
            shape: const Border(),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getCategoryColor(catName).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getCategoryIcon(catName),
                  color: _getCategoryColor(catName), size: 20),
            ),
            title: Text(
              catName,
              style: GoogleFonts.sourceSerif4(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              '${list.length} tasks · $completed completed',
              style: GoogleFonts.sourceSerif4(
                fontSize: 12,
                color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
              ),
            ),
            children: list.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No tasks in $catName list yet.',
                        style: GoogleFonts.sourceSerif4(
                          fontSize: 13,
                          color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                        ),
                      ),
                    )
                  ]
                : list.map((t) => _buildTaskCard(t, theme, isDark)).toList(),
          ),
        );
      }).toList(),
    );
  }

  // ── Tab 3: Habits ──────────────────────────────────────────────────────

  Widget _buildHabitsTab(PlannerState state, ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _buildSectionHeader('Daily Habit Streaks', theme),
        const SizedBox(height: 8),
        ...state.habits.map((habit) {
          final isDone = habit.isCompletedToday;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AiraColors.cardDark : AiraColors.cardLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDone
                    ? AiraColors.claudeTerracotta
                    : (isDark ? AiraColors.borderDark : AiraColors.borderLight),
                width: isDone ? 1.2 : 1,
              ),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    ref.read(plannerProvider.notifier).checkInHabit(habit.id);
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? AiraColors.claudeTerracotta
                          : AiraColors.claudeTerracotta.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      isDone ? Icons.check_rounded : Icons.local_fire_department_rounded,
                      color: isDone ? Colors.white : AiraColors.claudeTerracotta,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: GoogleFonts.sourceSerif4(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (habit.description != null && habit.description!.isNotEmpty)
                        Text(
                          habit.description!,
                          style: GoogleFonts.sourceSerif4(
                            fontSize: 12,
                            color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AiraColors.claudeAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: AiraColors.claudeAmber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${habit.currentStreak}d',
                        style: GoogleFonts.sourceSerif4(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AiraColors.claudeAmber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Task Card Widget ────────────────────────────────────────────────────

  Widget _buildTaskCard(TaskItem task, ThemeData theme, bool isDark) {
    final cardBg = isDark ? AiraColors.cardDark : AiraColors.cardLight;
    final borderColor = isDark ? AiraColors.borderDark : AiraColors.borderLight;
    final mutedColor = isDark ? AiraColors.textMuted : AiraColors.textMutedLight;

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        ref.read(plannerProvider.notifier).deleteTask(task.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${task.title}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          onTap: () => _showTaskEditorSheet(context, task: task),
          leading: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(plannerProvider.notifier).toggleTask(task.id, !task.isCompleted);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                color: task.isCompleted
                    ? AiraColors.claudeTerracotta
                    : Colors.transparent,
                border: Border.all(
                  color: task.isCompleted
                      ? AiraColors.claudeTerracotta
                      : _getPriorityColor(task.priority),
                  width: 1.8,
                ),
              ),
              child: task.isCompleted
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : null,
            ),
          ),
          title: Text(
            task.title,
            style: GoogleFonts.sourceSerif4(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted ? mutedColor : theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Category badge
              Text(
                task.category,
                style: GoogleFonts.sourceSerif4(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _getCategoryColor(task.category),
                ),
              ),
              // Time & Alarm badge
              if (task.dueDate != null) ...[
                Text('·', style: GoogleFonts.sourceSerif4(color: mutedColor)),
                Icon(
                  task.hasAlarm ? Icons.alarm_on_rounded : Icons.access_time_rounded,
                  size: 13,
                  color: task.hasAlarm ? AiraColors.claudeTerracotta : mutedColor,
                ),
                Text(
                  DateFormat('h:mm a').format(task.dueDate!),
                  style: GoogleFonts.sourceSerif4(
                    fontSize: 11.5,
                    color: task.hasAlarm ? AiraColors.claudeTerracotta : mutedColor,
                    fontWeight: task.hasAlarm ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ],
          ),
          trailing: _buildPriorityDot(task.priority),
        ),
      ),
    );
  }

  Widget _buildPriorityDot(String priority) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getPriorityColor(priority),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'low':
        return Colors.blueGrey;
      default:
        return Colors.amber;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Study':
        return AiraColors.claudeAmber;
      case 'Work':
        return AiraColors.claudeTerracotta;
      case 'Fitness':
        return AiraColors.success;
      case 'Personal':
        return Colors.purple.shade300;
      default:
        return AiraColors.electricCyan;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Study':
        return Icons.school_outlined;
      case 'Work':
        return Icons.work_outline_rounded;
      case 'Fitness':
        return Icons.fitness_center_rounded;
      case 'Personal':
        return Icons.favorite_outline_rounded;
      default:
        return Icons.inbox_outlined;
    }
  }

  List<TaskItem> _filterTasks(List<TaskItem> list) {
    if (_selectedCategory == 'All') return list;
    return list.where((t) => t.category == _selectedCategory).toList();
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.sourceSerif4(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AiraColors.claudeTerracotta,
      ),
    );
  }

  Widget _buildEmptyState(String msg, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: GoogleFonts.sourceSerif4(
            fontSize: 13.5,
            color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight,
          ),
        ),
      ),
    );
  }

  // ── Task Creator & Editor Bottom Sheet ───────────────────────────────────

  void _showTaskEditorSheet(BuildContext context, {TaskItem? task}) {
    final titleController = TextEditingController(text: task?.title ?? '');
    final notesController = TextEditingController(text: task?.description ?? '');
    DateTime? selectedDate = task?.dueDate ?? DateTime.now();
    TimeOfDay? selectedTime = task?.dueDate != null
        ? TimeOfDay.fromDateTime(task!.dueDate!)
        : const TimeOfDay(hour: 17, minute: 0);
    bool hasAlarm = task?.hasAlarm ?? true;
    String priority = task?.priority ?? 'medium';
    String category = task?.category ?? 'Study';

    final isEdit = task != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1B1A17) : const Color(0xFFFAF9F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black26,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEdit ? 'Edit Task' : 'New Task',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title
                    TextField(
                      controller: titleController,
                      autofocus: !isEdit,
                      style: GoogleFonts.sourceSerif4(fontSize: 15, color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'What needs to be done?',
                        hintStyle: GoogleFonts.sourceSerif4(
                            color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Description / Notes
                    TextField(
                      controller: notesController,
                      style: GoogleFonts.sourceSerif4(fontSize: 13.5, color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Add description or notes (optional)',
                        hintStyle: GoogleFonts.sourceSerif4(
                            color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),

                    // Category Selector
                    Text('Category / List',
                        style: GoogleFonts.sourceSerif4(
                            fontSize: 12, fontWeight: FontWeight.w700, color: AiraColors.claudeTerracotta)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: _categories.where((c) => c != 'All').map((cat) {
                        final isSel = category == cat;
                        return ChoiceChip(
                          label: Text(cat, style: GoogleFonts.sourceSerif4(fontSize: 12)),
                          selected: isSel,
                          selectedColor: AiraColors.claudeTerracotta,
                          onSelected: (_) => setModalState(() => category = cat),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Priority Selector
                    Text('Priority',
                        style: GoogleFonts.sourceSerif4(
                            fontSize: 12, fontWeight: FontWeight.w700, color: AiraColors.claudeTerracotta)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: ['low', 'medium', 'high', 'urgent'].map((p) {
                        final isSel = priority == p;
                        return ChoiceChip(
                          label: Text(p.toUpperCase(),
                              style: GoogleFonts.sourceSerif4(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          selected: isSel,
                          selectedColor: _getPriorityColor(p),
                          onSelected: (_) => setModalState(() => priority = p),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Time Picker & Alarm Toggle
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today_rounded, size: 16),
                            label: Text(
                              selectedDate != null
                                  ? DateFormat('MMM d').format(selectedDate!)
                                  : 'Select Date',
                              style: GoogleFonts.sourceSerif4(fontSize: 12.5),
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setModalState(() => selectedDate = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time_rounded, size: 16),
                            label: Text(
                              selectedTime != null
                                  ? selectedTime!.format(ctx)
                                  : 'Select Time',
                              style: GoogleFonts.sourceSerif4(fontSize: 12.5),
                            ),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: ctx,
                                initialTime: selectedTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setModalState(() => selectedTime = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Alarm Toggle Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '⏰ Ring Android Alarm & Notification',
                        style: GoogleFonts.sourceSerif4(fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Plays alarm sound and heads-up banner at due time',
                        style: GoogleFonts.sourceSerif4(fontSize: 11.5, color: isDark ? AiraColors.textMuted : AiraColors.textMutedLight),
                      ),
                      activeTrackColor: AiraColors.claudeTerracotta,
                      value: hasAlarm,
                      onChanged: (val) => setModalState(() => hasAlarm = val),
                    ),
                    const SizedBox(height: 16),

                    // Actions
                    Row(
                      children: [
                        if (isEdit)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            onPressed: () {
                              ref.read(plannerProvider.notifier).deleteTask(task.id);
                              Navigator.pop(ctx);
                            },
                            tooltip: 'Delete task',
                          ),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (titleController.text.trim().isEmpty) return;

                              DateTime? finalDueDate;
                              if (selectedDate != null && selectedTime != null) {
                                finalDueDate = DateTime(
                                  selectedDate!.year,
                                  selectedDate!.month,
                                  selectedDate!.day,
                                  selectedTime!.hour,
                                  selectedTime!.minute,
                                );
                              }

                              if (isEdit) {
                                await ref.read(plannerProvider.notifier).updateTask(
                                      task.copyWith(
                                        title: titleController.text.trim(),
                                        description: notesController.text.trim(),
                                        dueDate: finalDueDate,
                                        hasAlarm: hasAlarm,
                                        priority: priority,
                                        category: category,
                                      ),
                                    );
                              } else {
                                await ref.read(plannerProvider.notifier).addTask(
                                      title: titleController.text.trim(),
                                      description: notesController.text.trim(),
                                      dueDate: finalDueDate,
                                      hasAlarm: hasAlarm,
                                      priority: priority,
                                      category: category,
                                    );
                              }

                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AiraColors.claudeTerracotta,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              isEdit ? 'Save Changes' : 'Create Task',
                              style: GoogleFonts.sourceSerif4(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
