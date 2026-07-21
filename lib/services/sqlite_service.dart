import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:aaysha_stores/utils/logger.dart';
import 'package:aaysha_stores/utils/storage_path.dart';

/// File-backed storage layer used in place of SQLite.
class SQLiteService {
  static final SQLiteService _instance = SQLiteService._internal();

  factory SQLiteService() => _instance;
  SQLiteService._internal();

  Future<dynamic> get database async => null;

  Future<Directory> _getStoreDir() async {
    final doc = await StoragePathHelper.resolveDocumentsDirectory();
    final dir = Directory(p.join(doc.path, 'AayshaExports', 'db'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _getTableFile(String table) async {
    final dir = await _getStoreDir();
    final file = File(p.join(dir.path, '$table.json'));
    if (!await file.exists()) {
      await file.writeAsString(jsonEncode([]));
    }
    return file;
  }

  Future<List<Map<String, dynamic>>> _readRows(String table) async {
    try {
      final file = await _getTableFile(table);
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (e) {
      AppLogger.error('Failed to read $table rows', e);
      return [];
    }
  }

  Future<void> _writeRows(String table, List<Map<String, dynamic>> rows) async {
    try {
      final file = await _getTableFile(table);
      await file.writeAsString(jsonEncode(rows));
    } catch (e) {
      AppLogger.error('Failed to write $table rows', e);
      rethrow;
    }
  }

  bool _matchesCondition(
    Map<String, dynamic> row,
    String condition,
    dynamic expectedValue,
  ) {
    final parts = condition.split(RegExp(r'\s+'));
    if (parts.length < 3) return false;
    final column = parts[0];
    final operator = parts[1];
    final actualValue = row[column];
    switch (operator) {
      case '=':
        return actualValue.toString() == expectedValue.toString();
      case '!=':
        return actualValue.toString() != expectedValue.toString();
      case '>=':
        return actualValue.toString().compareTo(expectedValue.toString()) >= 0;
      case '<=':
        return actualValue.toString().compareTo(expectedValue.toString()) <= 0;
      case '>':
        return actualValue.toString().compareTo(expectedValue.toString()) > 0;
      case '<':
        return actualValue.toString().compareTo(expectedValue.toString()) < 0;
      default:
        return false;
    }
  }

  bool _rowMatches(
    Map<String, dynamic> row,
    String? where,
    List<dynamic>? whereArgs,
  ) {
    if (where == null || where.trim().isEmpty) return true;
    final clauses = where.split(' AND ');
    for (var i = 0; i < clauses.length; i++) {
      final clause = clauses[i].trim();
      if (clause.isEmpty) continue;
      final expectedValue = whereArgs != null && i < whereArgs.length
          ? whereArgs[i]
          : null;
      if (!_matchesCondition(row, clause, expectedValue)) return false;
    }
    return true;
  }

  List<Map<String, dynamic>> _applyOrder(
    List<Map<String, dynamic>> rows,
    String? orderBy,
  ) {
    if (orderBy == null || orderBy.trim().isEmpty) return rows;
    final direction = orderBy.toUpperCase().endsWith(' DESC') ? 'DESC' : 'ASC';
    final column = orderBy.replaceFirst(RegExp(r'\s+DESC$|\s+ASC$'), '').trim();
    final sorted = List<Map<String, dynamic>>.from(rows);
    sorted.sort((a, b) {
      final aValue = a[column];
      final bValue = b[column];
      final comparison = aValue.toString().compareTo(bValue.toString());
      return direction == 'DESC' ? -comparison : comparison;
    });
    return sorted;
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final rows = await _readRows(table);
    rows.add(Map<String, dynamic>.from(data));
    await _writeRows(table, rows);
    return 1;
  }

  Future<int> addCustomer(Map<String, dynamic> data) async =>
      insert('customers', data);

  Future<List<Map<String, dynamic>>> getCustomers() async => query('customers');

  Future<int> addCredit(Map<String, dynamic> data) async =>
      insert('credits', data);

  Future<List<Map<String, dynamic>>> getCreditsByCustomer(
    String customerId,
  ) async {
    return query('credits', where: 'customerId = ?', whereArgs: [customerId]);
  }

  Future<int> deleteCreditById(String id) async {
    return delete('credits', 'id = ?', [id]);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final rows = await _readRows(table);
    var updated = 0;
    for (final row in rows) {
      if (_rowMatches(row, where, whereArgs)) {
        for (final entry in data.entries) {
          row[entry.key] = entry.value;
        }
        updated++;
      }
    }
    if (updated > 0) {
      await _writeRows(table, rows);
    }
    return updated;
  }

  Future<int> delete(
    String table,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final rows = await _readRows(table);
    final filtered = rows
        .where((row) => !_rowMatches(row, where, whereArgs))
        .toList();
    if (filtered.length != rows.length) {
      await _writeRows(table, filtered);
      return rows.length - filtered.length;
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final rows = await _readRows(table);
    final filtered = rows
        .where((row) => _rowMatches(row, where, whereArgs))
        .toList();
    final ordered = _applyOrder(filtered, orderBy);
    if (limit != null && limit > 0) {
      return ordered.take(limit).toList();
    }
    return ordered;
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final lower = sql.toLowerCase();
    if (lower.contains('select distinct category') &&
        lower.contains('from products')) {
      final rows = await query('products');
      final categories = rows
          .map((row) => row['category'])
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .toSet()
          .toList();
      return categories.map((category) => {'category': category}).toList();
    }
    return [];
  }

  Future<int> getRecordCount(String table) async => (await query(table)).length;

  Future<List<Map<String, dynamic>>> getAllProducts() async =>
      query('products');

  Future<void> close() async {}
}
