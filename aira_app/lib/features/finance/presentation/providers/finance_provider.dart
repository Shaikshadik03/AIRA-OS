import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/core/services/api_service.dart';

// ──────────────────── Models ────────────────────

class FinanceCategory {
  final String id;
  final String name;
  final String? icon;
  final String? color;
  final String type; // income | expense

  const FinanceCategory({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    required this.type,
  });

  factory FinanceCategory.fromJson(Map<String, dynamic> json) {
    return FinanceCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'],
      color: json['color'],
      type: json['type'] ?? 'expense',
    );
  }
}

class TransactionItem {
  final String id;
  final String? categoryId;
  final double amount;
  final String type; // income | expense
  final String title;
  final String? notes;
  final DateTime transactionDate;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;

  const TransactionItem({
    required this.id,
    this.categoryId,
    required this.amount,
    required this.type,
    required this.title,
    this.notes,
    required this.transactionDate,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  bool get isExpense => type == 'expense';

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    final cat = json['finance_categories'] as Map<String, dynamic>?;
    return TransactionItem(
      id: json['id'] ?? '',
      categoryId: json['category_id'],
      amount: (json['amount'] ?? 0.0).toDouble(),
      type: json['type'] ?? 'expense',
      title: json['title'] ?? '',
      notes: json['notes'],
      transactionDate: json['transaction_date'] != null
          ? DateTime.parse(json['transaction_date'])
          : DateTime.now(),
      categoryName: cat?['name'],
      categoryIcon: cat?['icon'],
      categoryColor: cat?['color'],
    );
  }
}

class BudgetLimit {
  final String id;
  final String categoryId;
  final double amount;
  final String period; // weekly | monthly | yearly
  final DateTime startDate;
  final double spent;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;

  const BudgetLimit({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.period,
    required this.startDate,
    required this.spent,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  factory BudgetLimit.fromJson(Map<String, dynamic> json) {
    final cat = json['finance_categories'] as Map<String, dynamic>?;
    return BudgetLimit(
      id: json['id'] ?? '',
      categoryId: json['category_id'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      period: json['period'] ?? 'monthly',
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : DateTime.now(),
      spent: (json['spent'] ?? 0.0).toDouble(),
      categoryName: cat?['name'],
      categoryIcon: cat?['icon'],
      categoryColor: cat?['color'],
    );
  }

  double get ratio => amount > 0 ? spent / amount : 0.0;
}

// ──────────────────── State ────────────────────

class FinanceState {
  final List<TransactionItem> transactions;
  final List<BudgetLimit> budgets;
  final List<FinanceCategory> categories;
  final bool isLoading;
  final String? error;

  const FinanceState({
    this.transactions = const [],
    this.budgets = const [],
    this.categories = const [],
    this.isLoading = false,
    this.error,
  });

  FinanceState copyWith({
    List<TransactionItem>? transactions,
    List<BudgetLimit>? budgets,
    List<FinanceCategory>? categories,
    bool? isLoading,
    String? error,
  }) {
    return FinanceState(
      transactions: transactions ?? this.transactions,
      budgets: budgets ?? this.budgets,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  double get totalIncome => transactions
      .where((t) => t.type == 'income')
      .fold(0.0, (sum, item) => sum + item.amount);

  double get totalExpense => transactions
      .where((t) => t.type == 'expense')
      .fold(0.0, (sum, item) => sum + item.amount);
}

// ──────────────────── Notifier ────────────────────

class FinanceNotifier extends StateNotifier<FinanceState> {
  final ApiService _api = ApiService();

  FinanceNotifier() : super(const FinanceState());

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final txData = await _api.listTransactions();
      final budgetData = await _api.listBudgets();
      final catData = await _api.listCategories();

      final transactions = txData.map((json) => TransactionItem.fromJson(json)).toList();
      final budgets = budgetData.map((json) => BudgetLimit.fromJson(json)).toList();
      final categories = catData.map((json) => FinanceCategory.fromJson(json)).toList();

      state = state.copyWith(
        transactions: transactions,
        budgets: budgets,
        categories: categories,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addTransaction(Map<String, dynamic> txData) async {
    state = state.copyWith(isLoading: true);
    try {
      await _api.createTransaction(txData);
      await loadAll(); // Reload everything to update budget spent metrics
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to log transaction: $e');
    }
  }

  Future<void> addBudget(Map<String, dynamic> budgetData) async {
    state = state.copyWith(isLoading: true);
    try {
      await _api.createBudget(budgetData);
      await loadAll();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to save budget limit: $e');
    }
  }

  Future<void> deleteTransaction(String txId) async {
    final previousTx = state.transactions;
    state = state.copyWith(
      transactions: state.transactions.where((t) => t.id != txId).toList(),
    );
    try {
      await _api.deleteTransaction(txId);
      await loadAll(); // Force re-calculate budget aggregates
    } catch (e) {
      state = state.copyWith(transactions: previousTx, error: 'Failed to delete transaction: $e');
    }
  }
}

// ──────────────────── Provider ────────────────────

final financeProvider = StateNotifierProvider<FinanceNotifier, FinanceState>((ref) {
  return FinanceNotifier();
});
