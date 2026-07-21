import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:aaysha_stores/models/product_model.dart';
import 'package:aaysha_stores/utils/logger.dart';

/// ExportService handles Excel exports for products and sales
class ExportService {
  static final ExportService _instance = ExportService._internal();

  factory ExportService() => _instance;

  ExportService._internal();

  Uint8List _encodeExcel(Excel excel) {
    final encoded = excel.encode();
    if (encoded == null) {
      throw StateError('Failed to encode Excel workbook');
    }
    return Uint8List.fromList(encoded);
  }

  Future<String> writeBytesToPath(Uint8List bytes, String path) async {
    final file = File(path);
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<Uint8List> buildProductsExcelBytes(List<ProductModel> products) async {
    final excel = Excel.createExcel();
    final sheet = excel['Products'];

    sheet.appendRow([
      'ID',
      'Name',
      'Barcode',
      'Category',
      'CostPrice',
      'SellingPrice',
      'Quantity',
      'Supplier',
      'ImageUrl',
      'ExpiryDate',
      'LowStockThreshold',
      'CreatedAt',
      'UpdatedAt',
    ]);

    for (final p in products) {
      sheet.appendRow([
        p.id,
        p.name,
        p.barcode ?? '',
        p.category,
        p.costPrice,
        p.sellingPrice,
        p.quantity,
        p.supplierName,
        p.productImageUrl ?? '',
        p.expiryDate?.toIso8601String() ?? '',
        p.lowStockThreshold,
        p.createdAt.toIso8601String(),
        p.updatedAt?.toIso8601String() ?? '',
      ]);
    }

    return _encodeExcel(excel);
  }

  Future<String> exportProductsToExcelAtPath(List<ProductModel> products, String path) async {
    try {
      final bytes = await buildProductsExcelBytes(products);
      final filePath = await writeBytesToPath(bytes, path);
      AppLogger.success('Products exported to chosen path: $filePath');
      return filePath;
    } catch (e) {
      AppLogger.error('Failed to export products to chosen path', e);
      rethrow;
    }
  }

  /// Export a list of products to an Excel file and return the file path
  Future<String> exportProductsToExcel(List<ProductModel> products) async {
    try {
      final bytes = await buildProductsExcelBytes(products);
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'products_export_${DateTime.now().toIso8601String()}.xlsx';
      final filePath = await writeBytesToPath(bytes, '${dir.path}/$filename');
      AppLogger.success('Products exported: $filePath');
      return filePath;
    } catch (e) {
      AppLogger.error('Failed to export products to Excel', e);
      rethrow;
    }
  }

  /// Export sales (generic map) to Excel. Expects list of maps with keys: id, total, itemsCount, createdAt, paymentMethod, customerId, creditAmount, status
  Future<String> exportSalesToExcel(List<Map<String, dynamic>> sales) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sales'];

      sheet.appendRow([
        'ID',
        'Total',
        'ItemsCount',
        'PaymentMethod',
        'CustomerId',
        'CreditAmount',
        'Status',
        'CreatedAt',
      ]);

      for (final s in sales) {
        sheet.appendRow([
          s['id'] ?? '',
          s['total'] ?? 0,
          s['itemsCount'] ?? 0,
          s['paymentMethod'] ?? '',
          s['customerId'] ?? '',
          s['creditAmount'] ?? 0,
          s['status'] ?? '',
          s['createdAt'] is DateTime ? (s['createdAt'] as DateTime).toIso8601String() : (s['createdAt'] ?? ''),
        ]);
      }

      final bytes = _encodeExcel(excel);
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'sales_export_${DateTime.now().toIso8601String()}.xlsx';
      final filePath = await writeBytesToPath(bytes, '${dir.path}/$filename');
      AppLogger.success('Sales exported: $filePath');
      return filePath;
    } catch (e) {
      AppLogger.error('Failed to export sales to Excel', e);
      rethrow;
    }
  }

  Future<Uint8List> buildSalesExcelBytes(List<Map<String, dynamic>> sales) async {
    final excel = Excel.createExcel();
    final sheet = excel['Sales'];

    sheet.appendRow([
      'ID',
      'Total',
      'ItemsCount',
      'PaymentMethod',
      'CustomerId',
      'CreditAmount',
      'Status',
      'CreatedAt',
    ]);

    for (final s in sales) {
      sheet.appendRow([
        s['id'] ?? '',
        s['total'] ?? 0,
        s['itemsCount'] ?? 0,
        s['paymentMethod'] ?? '',
        s['customerId'] ?? '',
        s['creditAmount'] ?? 0,
        s['status'] ?? '',
        s['createdAt'] is DateTime ? (s['createdAt'] as DateTime).toIso8601String() : (s['createdAt'] ?? ''),
      ]);
    }

    return _encodeExcel(excel);
  }

  Future<String> exportSalesToExcelAtPath(List<Map<String, dynamic>> sales, String path) async {
    try {
      final bytes = await buildSalesExcelBytes(sales);
      final filePath = await writeBytesToPath(bytes, path);
      AppLogger.success('Sales exported to chosen path: $filePath');
      return filePath;
    } catch (e) {
      AppLogger.error('Failed to export sales to chosen path', e);
      rethrow;
    }
  }

  /// Export expenses list to Excel
  Future<String> exportExpensesToExcel(List<Map<String, dynamic>> expenses) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Expenses'];

      sheet.appendRow(['ID', 'Category', 'Amount', 'Description', 'ExpenseDate', 'AddedBy', 'CreatedAt']);

      for (final e in expenses) {
        sheet.appendRow([
          e['id'] ?? '',
          e['category'] ?? '',
          e['amount'] ?? 0,
          e['description'] ?? '',
          e['expenseDate'] is DateTime ? (e['expenseDate'] as DateTime).toIso8601String() : (e['expenseDate'] ?? ''),
          e['addedBy'] ?? '',
          e['createdAt'] is DateTime ? (e['createdAt'] as DateTime).toIso8601String() : (e['createdAt'] ?? ''),
        ]);
      }

      final bytes = _encodeExcel(excel);
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'expenses_export_${DateTime.now().toIso8601String()}.xlsx';
      final filePath = await writeBytesToPath(bytes, '${dir.path}/$filename');
      AppLogger.success('Expenses exported: $filePath');
      return filePath;
    } catch (e) {
      AppLogger.error('Failed to export expenses to Excel', e);
      rethrow;
    }
  }

  Future<Uint8List> buildExpensesExcelBytes(List<Map<String, dynamic>> expenses) async {
    final excel = Excel.createExcel();
    final sheet = excel['Expenses'];

    sheet.appendRow(['ID', 'Category', 'Amount', 'Description', 'ExpenseDate', 'AddedBy', 'CreatedAt']);

    for (final e in expenses) {
      sheet.appendRow([
        e['id'] ?? '',
        e['category'] ?? '',
        e['amount'] ?? 0,
        e['description'] ?? '',
        e['expenseDate'] is DateTime ? (e['expenseDate'] as DateTime).toIso8601String() : (e['expenseDate'] ?? ''),
        e['addedBy'] ?? '',
        e['createdAt'] is DateTime ? (e['createdAt'] as DateTime).toIso8601String() : (e['createdAt'] ?? ''),
      ]);
    }

    return _encodeExcel(excel);
  }

  Future<String> exportExpensesToExcelAtPath(List<Map<String, dynamic>> expenses, String path) async {
    try {
      final bytes = await buildExpensesExcelBytes(expenses);
      final filePath = await writeBytesToPath(bytes, path);
      AppLogger.success('Expenses exported to chosen path: $filePath');
      return filePath;
    } catch (e) {
      AppLogger.error('Failed to export expenses to chosen path', e);
      rethrow;
    }
  }
}
