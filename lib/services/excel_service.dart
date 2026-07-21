import 'dart:io';
import 'package:excel/excel.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'package:aaysha_stores/utils/logger.dart';
import 'package:aaysha_stores/utils/storage_path.dart';

/// Excel export service
/// Handles generation and export of Excel reports
class ExcelService {
  static final ExcelService _instance = ExcelService._internal();

  factory ExcelService() {
    return _instance;
  }

  ExcelService._internal();

  /// Create Excel file for products
  Future<File?> exportProductsToExcel(List<Map<String, dynamic>> products) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel[AppConstants.productsSheetName];

      // Add headers
      _addHeaders(sheet, [
        'Product ID',
        'Name',
        'Barcode',
        'Category',
        'Cost Price',
        'Selling Price',
        'Profit/Unit',
        'Quantity',
        'Supplier',
        'Expiry Date',
      ]);

      // Add products
      for (int i = 0; i < products.length; i++) {
        final product = products[i];
        sheet.appendRow([
          product['id'] ?? '',
          product['name'] ?? '',
          product['barcode'] ?? '',
          product['category'] ?? '',
          (product['costPrice'] ?? 0) as num,
          (product['sellingPrice'] ?? 0) as num,
          ((product['sellingPrice'] ?? 0) - (product['costPrice'] ?? 0)) as num,
          (product['quantity'] ?? 0) as num,
          product['supplierName'] ?? '',
          product['expiryDate'] ?? '',
        ]);
      }

      // Auto-resize columns
      _autoResizeColumns(sheet, 10);

      return await _saveExcelFile(excel, AppConstants.productsSheetName);
    } catch (e) {
      AppLogger.error('Error exporting products to Excel', e);
      return null;
    }
  }

  /// Create Excel file for sales
  Future<File?> exportSalesToExcel(List<Map<String, dynamic>> sales) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel[AppConstants.salesSheetName];

      // Add headers
      _addHeaders(sheet, [
        'Sale ID',
        'Date',
        'Total Amount',
        'Discount',
        'Net Total',
        'Payment Method',
        'Cashier ID',
        'Status',
      ]);

      // Add sales
      for (int i = 0; i < sales.length; i++) {
        final sale = sales[i];
        sheet.appendRow([
          sale['id'] ?? '',
          sale['saleDate'] ?? '',
          (sale['totalAmount'] ?? 0) as num,
          (sale['discount'] ?? 0) as num,
          ((sale['totalAmount'] ?? 0) - (sale['discount'] ?? 0)) as num,
          sale['paymentMethod'] ?? '',
          sale['cashierId'] ?? '',
          sale['status'] ?? '',
        ]);
      }

      _autoResizeColumns(sheet, 8);
      return await _saveExcelFile(excel, AppConstants.salesSheetName);
    } catch (e) {
      AppLogger.error('Error exporting sales to Excel', e);
      return null;
    }
  }

  /// Create Excel file for expenses
  Future<File?> exportExpensesToExcel(List<Map<String, dynamic>> expenses) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel[AppConstants.expensesSheetName];

      // Add headers
      _addHeaders(sheet, [
        'Expense ID',
        'Category',
        'Amount',
        'Description',
        'Date',
        'Added By',
      ]);

      // Add expenses
      for (int i = 0; i < expenses.length; i++) {
        final expense = expenses[i];
        sheet.appendRow([
          expense['id'] ?? '',
          expense['category'] ?? '',
          (expense['amount'] ?? 0) as num,
          expense['description'] ?? '',
          expense['expenseDate'] ?? '',
          expense['addedBy'] ?? '',
        ]);
      }

      _autoResizeColumns(sheet, 6);
      return await _saveExcelFile(excel, AppConstants.expensesSheetName);
    } catch (e) {
      AppLogger.error('Error exporting expenses to Excel', e);
      return null;
    }
  }

  /// Create Excel file for profit report
  Future<File?> exportProfitReportToExcel(List<Map<String, dynamic>> profitData) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel[AppConstants.profitReportSheetName];

      // Add headers
      _addHeaders(sheet, [
        'Product ID',
        'Product Name',
        'Quantity Sold',
        'Cost Price',
        'Selling Price',
        'Profit/Unit',
        'Total Profit',
      ]);

      // Add data
      for (int i = 0; i < profitData.length; i++) {
        final data = profitData[i];
        sheet.appendRow([
          data['productId'] ?? '',
          data['productName'] ?? '',
          (data['quantitySold'] ?? 0) as num,
          (data['costPrice'] ?? 0) as num,
          (data['sellingPrice'] ?? 0) as num,
          ((data['sellingPrice'] ?? 0) - (data['costPrice'] ?? 0)) as num,
          (data['totalProfit'] ?? 0) as num,
        ]);
      }

      _autoResizeColumns(sheet, 7);
      return await _saveExcelFile(excel, AppConstants.profitReportSheetName);
    } catch (e) {
      AppLogger.error('Error exporting profit report to Excel', e);
      return null;
    }
  }

  /// Create Excel file for inventory report
  Future<File?> exportInventoryReportToExcel(List<Map<String, dynamic>> inventoryData) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel[AppConstants.inventoryReportSheetName];

      // Add headers
      _addHeaders(sheet, [
        'Product ID',
        'Name',
        'Quantity',
        'Cost Price',
        'Inventory Value',
        'Status',
      ]);

      // Add data
      for (int i = 0; i < inventoryData.length; i++) {
        final data = inventoryData[i];
        final quantity = data['quantity'] ?? 0;
        final costPrice = data['costPrice'] ?? 0;
        final inventoryValue = quantity * costPrice;
        final status = quantity > 10 ? 'Good' : (quantity > 0 ? 'Low' : 'Out of Stock');

        sheet.appendRow([
          data['id'] ?? '',
          data['name'] ?? '',
          quantity as num,
          costPrice as num,
          inventoryValue as num,
          status,
        ]);
      }

      _autoResizeColumns(sheet, 6);
      return await _saveExcelFile(excel, AppConstants.inventoryReportSheetName);
    } catch (e) {
      AppLogger.error('Error exporting inventory report to Excel', e);
      return null;
    }
  }

  /// Add headers to sheet
  void _addHeaders(Sheet sheet, List<String> headers) {
    sheet.appendRow(headers);
  }

  /// Auto-resize columns
  void _autoResizeColumns(Sheet sheet, int columnCount) {
    for (int i = 0; i < columnCount; i++) {
      sheet.setColWidth(i, 15);
    }
  }

  /// Save Excel file
  Future<File?> _saveExcelFile(Excel excel, String reportName) async {
    try {
      final directory = await StoragePathHelper.resolveExportDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final fileName = 'Aaysha_${reportName}_${DateTime.now().toIso8601String().split('T')[0]}.xlsx';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      await file.writeAsBytes(excel.encode() ?? []);
      AppLogger.success('Excel file saved: $filePath');
      return file;
    } catch (e) {
      AppLogger.error('Error saving Excel file', e);
      return null;
    }
  }

  /// Get export directory
  Future<Directory> getExportDirectory() async {
    final baseDir = await StoragePathHelper.resolveExportDirectory();
    final exportDir = Directory('${baseDir.path}/${AppConstants.excelExportsPath}');
    
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    return exportDir;
  }

  /// List all exported files
  Future<List<File>> getExportedFiles() async {
    try {
      final dir = await getExportDirectory();
      final files = dir.listSync().whereType<File>().toList();
      return files;
    } catch (e) {
      AppLogger.error('Error listing exported files', e);
      return [];
    }
  }

  /// Delete exported file
  Future<bool> deleteExportedFile(String fileName) async {
    try {
      final dir = await getExportDirectory();
      final file = File('${dir.path}/$fileName');
      
      if (await file.exists()) {
        await file.delete();
        AppLogger.success('Exported file deleted: $fileName');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Error deleting exported file', e);
      return false;
    }
  }
}
