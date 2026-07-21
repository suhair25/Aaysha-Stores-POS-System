import 'package:flutter/material.dart';
import 'package:aaysha_stores/models/expense_model.dart';
import 'package:aaysha_stores/enums/expense_category.dart';
import 'package:aaysha_stores/services/sqlite_service.dart';
import 'package:aaysha_stores/services/sync_service.dart';
import 'package:aaysha_stores/services/file_expense_service.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'package:aaysha_stores/utils/logger.dart';

class ExpenseProvider extends ChangeNotifier {
  final SQLiteService _sqliteService = SQLiteService();
  final SyncService _syncService = SyncService();

  ExpenseProvider() {
    // Load expenses when provider is created so seeded data appears
    Future.microtask(() => loadExpenses());
  }
  final List<ExpenseModel> _expenses = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ExpenseModel> get expenses => List.unmodifiable(_expenses);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasExpenses => _expenses.isNotEmpty;

  double get totalExpenses => _expenses.fold(0.0, (sum, e) => sum + e.amount);

  Future<void> loadExpenses() async {
    _setLoading(true);
    try {
      if (AppConstants.forceFileOnlyBilling) {
        final fileSvc = FileExpenseService();
        final list = await fileSvc.getAllExpenses();
        _expenses
          ..clear()
          ..addAll(list);
        AppLogger.info('Loaded ${_expenses.length} expenses (file mode)');
      } else {
        final rawExpenses = await _sqliteService.query(
          'expenses',
          orderBy: 'expenseDate DESC',
        );
        _expenses
          ..clear()
          ..addAll(rawExpenses.map((json) => ExpenseModel.fromJson(json)));
        AppLogger.info('Loaded ${_expenses.length} expenses from local database');
      }
    } catch (e) {
      AppLogger.error('Failed to load expenses', e);
      _errorMessage = 'Unable to load expenses';
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addExpense(ExpenseModel expense) async {
    _setLoading(true);
    try {
      // Save locally (sqlite or file)
      if (AppConstants.forceFileOnlyBilling) {
        final fileSvc = FileExpenseService();
        await fileSvc.saveExpense(expense);
        _expenses.insert(0, expense);
      } else {
        await _sqliteService.insert('expenses', expense.toJson());
        _expenses.insert(0, expense);
      }

      // Enqueue expense for background sync
      await _syncService.enqueue('set', 'expenses', {
        ...expense.toJson(),
        'synced': false,
        'syncedAt': null,
      });

      AppLogger.success('Expense added: ${expense.category.displayName}');
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('Failed to add expense', e);
      _errorMessage = 'Unable to add expense';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteExpense(String id) async {
    _setLoading(true);
    try {
      // Delete locally (sqlite or file)
      if (AppConstants.forceFileOnlyBilling) {
        final fileSvc = FileExpenseService();
        await fileSvc.deleteExpense(id);
        _expenses.removeWhere((item) => item.id == id);
      } else {
        await _sqliteService.delete('expenses', 'id = ?', [id]);
        _expenses.removeWhere((item) => item.id == id);
      }

      // Enqueue deletion for background sync
      await _syncService.enqueue('delete', 'expenses', {'id': id});

      AppLogger.warning('Expense deleted: $id');
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete expense', e);
      _errorMessage = 'Unable to delete expense';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  double getTotalByDateRange(DateTime start, DateTime end) {
    return _expenses
        .where((e) => e.expenseDate.isAfter(start) && e.expenseDate.isBefore(end.add(const Duration(days: 1))))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
