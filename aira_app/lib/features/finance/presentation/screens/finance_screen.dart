import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/widgets/glassmorphic_container.dart';
import 'package:aira_app/core/widgets/aira_button.dart';
import 'package:aira_app/core/widgets/aira_text_field.dart';
import 'package:aira_app/features/finance/presentation/providers/finance_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() => ref.read(financeProvider.notifier).loadAll());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeProvider);

    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Finance', style: AiraTypography.h4),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AiraColors.electricCyan,
          labelColor: AiraColors.electricCyan,
          unselectedLabelColor: AiraColors.textMuted,
          labelStyle: AiraTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: AiraTypography.bodyMedium,
          tabs: const [
            Tab(text: 'Transactions', icon: Icon(Icons.receipt_long_rounded)),
            Tab(text: 'Budgets', icon: Icon(Icons.donut_large_rounded)),
            Tab(text: 'Reports', icon: Icon(Icons.analytics_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTransactionsTab(state),
          _buildBudgetsTab(state),
          _buildReportsTab(state),
        ],
      ),
    );
  }

  // ──────────────────── Transactions Tab ────────────────────

  Widget _buildTransactionsTab(FinanceState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AiraColors.electricCyan));
    }

    final format = NumberFormat.simpleCurrency(locale: 'en_IN', name: 'INR');

    return RefreshIndicator(
      onRefresh: () => ref.read(financeProvider.notifier).loadAll(),
      color: AiraColors.electricCyan,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Balance Summary Header Card
          GlassmorphicContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('CURRENT BALANCE', style: AiraTypography.overline.copyWith(color: AiraColors.textMuted)),
                const SizedBox(height: 8),
                Text(
                  format.format(state.totalIncome - state.totalExpense),
                  style: AiraTypography.h2.copyWith(
                    color: (state.totalIncome - state.totalExpense) >= 0
                        ? AiraColors.success
                        : AiraColors.error,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.arrow_downward_rounded, color: AiraColors.success, size: 16),
                              const SizedBox(width: 4),
                              Text('Income', style: AiraTypography.caption.copyWith(color: AiraColors.textMuted)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(format.format(state.totalIncome), style: AiraTypography.h5.copyWith(color: AiraColors.success)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: AiraColors.glassBorder),
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.arrow_upward_rounded, color: AiraColors.error, size: 16),
                              const SizedBox(width: 4),
                              Text('Expenses', style: AiraTypography.caption.copyWith(color: AiraColors.textMuted)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(format.format(state.totalExpense), style: AiraTypography.h5.copyWith(color: AiraColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Logs', style: AiraTypography.h5),
              AiraButton(
                label: 'Add Transaction',
                icon: Icons.add,
                onPressed: () => _showAddTransactionDialog(state),
                isPrimary: false,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.transactions.isEmpty)
            _buildEmptyState('No transactions found. Add logs to track budget!')
          else
            ...state.transactions.map((tx) => _buildTransactionTile(tx, format)),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(TransactionItem tx, NumberFormat format) {
    return Dismissible(
      key: Key(tx.id),
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
        ref.read(financeProvider.notifier).deleteTransaction(tx.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: GlassmorphicContainer(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tx.isExpense
                      ? AiraColors.error.withValues(alpha: 0.1)
                      : AiraColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  tx.isExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: tx.isExpense ? AiraColors.error : AiraColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx.title, style: AiraTypography.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      tx.categoryName ?? 'Other',
                      style: AiraTypography.caption.copyWith(color: AiraColors.textMuted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    (tx.isExpense ? '-' : '+') + format.format(tx.amount),
                    style: AiraTypography.bodyMedium.copyWith(
                      color: tx.isExpense ? AiraColors.error : AiraColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d').format(tx.transactionDate),
                    style: AiraTypography.caption.copyWith(color: AiraColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTransactionDialog(FinanceState state) {
    final amountController = TextEditingController();
    final titleController = TextEditingController();
    String txType = 'expense';
    String? selectedCategoryId;

    // Prefill category selection
    final list = state.categories.where((c) => c.type == txType).toList();
    if (list.isNotEmpty) selectedCategoryId = list.first.id;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentCategories = state.categories.where((c) => c.type == txType).toList();

          return AlertDialog(
            backgroundColor: AiraColors.cardDark,
            title: Text('Add Transaction', style: AiraTypography.h5),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Type Selector
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              txType = 'expense';
                              selectedCategoryId = state.categories.firstWhere((c) => c.type == 'expense').id;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: txType == 'expense' ? AiraColors.error.withValues(alpha: 0.15) : AiraColors.surfaceDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: txType == 'expense' ? AiraColors.error : AiraColors.glassBorder,
                              ),
                            ),
                            child: Center(child: Text('Expense', style: AiraTypography.bodyMedium.copyWith(color: txType == 'expense' ? AiraColors.error : AiraColors.textMuted))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              txType = 'income';
                              selectedCategoryId = state.categories.firstWhere((c) => c.type == 'income').id;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: txType == 'income' ? AiraColors.success.withValues(alpha: 0.15) : AiraColors.surfaceDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: txType == 'income' ? AiraColors.success : AiraColors.glassBorder,
                              ),
                            ),
                            child: Center(child: Text('Income', style: AiraTypography.bodyMedium.copyWith(color: txType == 'income' ? AiraColors.success : AiraColors.textMuted))),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AiraTextField(
                    controller: amountController,
                    hintText: 'Amount (₹)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  AiraTextField(controller: titleController, hintText: 'Title (e.g. Groceries)'),
                  const SizedBox(height: 16),
                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    dropdownColor: AiraColors.cardDark,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AiraColors.surfaceDark,
                      labelText: 'Category',
                      labelStyle: TextStyle(color: AiraColors.textMuted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    initialValue: selectedCategoryId,
                    items: currentCategories.map((c) {
                      return DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(c.name, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setModalState(() => selectedCategoryId = val);
                    },
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
                  final amount = double.tryParse(amountController.text) ?? 0.0;
                  if (amount <= 0 || titleController.text.trim().isEmpty) return;

                  ref.read(financeProvider.notifier).addTransaction({
                    'amount': amount,
                    'type': txType,
                    'title': titleController.text.trim(),
                    'category_id': selectedCategoryId,
                    'transaction_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Add Log', style: TextStyle(color: Colors.black)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ──────────────────── Budgets Tab ────────────────────

  Widget _buildBudgetsTab(FinanceState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AiraColors.electricCyan));
    }

    final format = NumberFormat.simpleCurrency(locale: 'en_IN', name: 'INR');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Category Limits', style: AiraTypography.h5),
            AiraButton(
              label: 'Set Budget',
              icon: Icons.add,
              onPressed: () => _showAddBudgetDialog(state),
              isPrimary: false,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (state.budgets.isEmpty)
          _buildEmptyState('No budget limits defined yet. Establish one to prevent overspending!')
        else
          ...state.budgets.map((b) => _buildBudgetCard(b, format)),
      ],
    );
  }

  Widget _buildBudgetCard(BudgetLimit budget, NumberFormat format) {
    final ratio = budget.ratio;
    Color progressColor;
    if (ratio >= 0.9) {
      progressColor = AiraColors.error;
    } else if (ratio >= 0.75) {
      progressColor = AiraColors.warning;
    } else {
      progressColor = AiraColors.success;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(budget.categoryName ?? 'Other', style: AiraTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  '${format.format(budget.spent)} / ${format.format(budget.amount)}',
                  style: AiraTypography.bodyMedium.copyWith(color: progressColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                backgroundColor: AiraColors.surfaceDark,
                color: progressColor,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(ratio * 100).toInt()}% of budget spent',
              style: AiraTypography.caption.copyWith(color: AiraColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBudgetDialog(FinanceState state) {
    final amountController = TextEditingController();
    String? selectedCategoryId;

    final expenseCategories = state.categories.where((c) => c.type == 'expense').toList();
    if (expenseCategories.isNotEmpty) {
      selectedCategoryId = expenseCategories.first.id;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AiraColors.cardDark,
          title: Text('Set Category Budget', style: AiraTypography.h5),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AiraTextField(
                controller: amountController,
                hintText: 'Monthly Limit (₹)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                dropdownColor: AiraColors.cardDark,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AiraColors.surfaceDark,
                  labelText: 'Category',
                  labelStyle: TextStyle(color: AiraColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                initialValue: selectedCategoryId,
                items: expenseCategories.map((c) {
                  return DropdownMenuItem<String>(
                    value: c.id,
                    child: Text(c.name, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (val) {
                  setModalState(() => selectedCategoryId = val);
                },
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
                final amount = double.tryParse(amountController.text) ?? 0.0;
                if (amount <= 0 || selectedCategoryId == null) return;

                ref.read(financeProvider.notifier).addBudget({
                  'category_id': selectedCategoryId,
                  'amount': amount,
                  'period': 'monthly',
                  'start_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save Limit', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────── Reports Tab ────────────────────

  Widget _buildReportsTab(FinanceState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AiraColors.electricCyan));
    }

    // Accumulate sums by category
    final Map<String, double> categorySums = {};
    for (var tx in state.transactions.where((t) => t.isExpense)) {
      final name = tx.categoryName ?? 'Other';
      categorySums[name] = (categorySums[name] ?? 0.0) + tx.amount;
    }

    if (categorySums.isEmpty) {
      return _buildEmptyState('No expense data logged to render summary distribution!');
    }

    final total = categorySums.values.fold(0.0, (sum, val) => sum + val);

    final colors = [
      AiraColors.electricCyan,
      AiraColors.purple,
      AiraColors.success,
      AiraColors.warning,
      AiraColors.neonPink,
      AiraColors.neonBlue,
    ];

    int colorIndex = 0;

    final sections = categorySums.entries.map((entry) {
      final value = entry.value;
      final percentage = total > 0 ? (value / total * 100).toInt() : 0;
      final color = colors[colorIndex % colors.length];
      colorIndex++;

      return PieChartSectionData(
        color: color,
        value: value,
        title: '$percentage%',
        radius: 60,
        titleStyle: AiraTypography.caption.copyWith(fontWeight: FontWeight.w700, color: Colors.black),
      );
    }).toList();

    colorIndex = 0; // Reset index for legend keying

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
      children: [
        Text('Expense Distribution', style: AiraTypography.h5),
        const SizedBox(height: 24),
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 40,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Legend List
        ...categorySums.entries.map((entry) {
          final color = colors[colorIndex % colors.length];
          colorIndex++;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text(entry.key, style: AiraTypography.bodyMedium),
                const Spacer(),
                Text(
                  NumberFormat.simpleCurrency(locale: 'en_IN', name: 'INR').format(entry.value),
                  style: AiraTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ──────────────────── Common empty state ────────────────────

  Widget _buildEmptyState(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.query_stats_rounded, size: 48, color: AiraColors.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            text,
            style: AiraTypography.bodySmall.copyWith(color: AiraColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
