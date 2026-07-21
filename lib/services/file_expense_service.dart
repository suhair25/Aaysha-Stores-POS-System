import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:aaysha_stores/models/expense_model.dart';
import 'package:aaysha_stores/utils/logger.dart';

class FileExpenseService {
  static final FileExpenseService _instance = FileExpenseService._internal();
  factory FileExpenseService() => _instance;
  FileExpenseService._internal();

  Future<File> _getExpensesFile() async {
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(doc.path, 'AayshaExports', 'expenses'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'expenses.json'));
    if (!await file.exists()) await file.writeAsString(jsonEncode([]));
    return file;
  }

  Future<Directory> _getDailyExportDir(DateTime date) async {
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(
        doc.path,
        'AayshaExports',
        'daily',
        DateFormat('yyyy-MM-dd').format(date.toLocal()),
        'expenses',
      ),
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<ExpenseModel>> getAllExpenses() async {
    try {
      final f = await _getExpensesFile();
      final content = await f.readAsString();
      final arr = jsonDecode(content) as List<dynamic>;
      return arr
          .map((e) => ExpenseModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to read expenses file', e);
      return [];
    }
  }

  Future<void> saveExpense(ExpenseModel expense) async {
    try {
      final list = await getAllExpenses();
      final idx = list.indexWhere((e) => e.id == expense.id);
      if (idx >= 0) {
        list[idx] = expense;
      } else {
        list.insert(0, expense);
      }
      final f = await _getExpensesFile();
      final payload = jsonEncode(list.map((e) => e.toJson()).toList());
      await f.writeAsString(payload);

      final dailyDir = await _getDailyExportDir(expense.expenseDate);
      final dailyFile = File(p.join(dailyDir.path, '${expense.id}.xlsx'));
      final jsonFile = File(p.join(dailyDir.path, '${expense.id}.json'));
      final excel = Excel.createExcel();
      final sheet = excel['Expenses'];
      sheet.appendRow([
        'ID',
        'Category',
        'Amount',
        'Description',
        'Date',
        'AddedBy',
      ]);
      for (final item in list.where(
        (entry) =>
            entry.expenseDate.year == expense.expenseDate.year &&
            entry.expenseDate.month == expense.expenseDate.month &&
            entry.expenseDate.day == expense.expenseDate.day,
      )) {
        sheet.appendRow([
          item.id,
          item.category.name,
          item.amount,
          item.description,
          item.expenseDate.toIso8601String(),
          item.addedBy,
        ]);
      }
      final bytes = excel.encode();
      if (bytes != null) {
        await dailyFile.writeAsBytes(bytes);
      }
      await jsonFile.writeAsString(payload);
    } catch (e) {
      AppLogger.error('Failed to save expense to file', e);
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      final list = await getAllExpenses();
      final newList = list
          .where((e) => e.id != id)
          .map((e) => e.toJson())
          .toList();
      final f = await _getExpensesFile();
      await f.writeAsString(jsonEncode(newList));
    } catch (e) {
      AppLogger.error('Failed to delete expense file entry', e);
      rethrow;
    }
  }
}
