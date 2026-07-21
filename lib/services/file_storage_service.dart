import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:aaysha_stores/models/sale_model.dart';
import 'package:aaysha_stores/utils/logger.dart';
import 'package:aaysha_stores/utils/storage_path.dart';

/// FileStorageService
/// Saves sales as Excel and JSON files in both legacy and daily folders.
class FileStorageService {
  static final FileStorageService _instance = FileStorageService._internal();
  factory FileStorageService() => _instance;
  FileStorageService._internal();

  Future<Directory> _getBaseDir() async {
    final doc = await StoragePathHelper.resolveExportDirectory();
    AppLogger.info('Storage root -> ${doc.path}');
    String baseRoot = doc.path;
    try {
      final testDir = Directory(baseRoot);
      if (!await testDir.exists()) {
        final userProfile = Platform.environment['USERPROFILE'] ?? '';
        if (userProfile.isNotEmpty) {
          baseRoot = p.join(userProfile, 'Documents');
        }
      }
    } catch (_) {}

    final base = Directory(p.join(baseRoot, 'AayshaExports', 'bills'));
    if (!await base.exists()) await base.create(recursive: true);
    final unsynced = Directory(p.join(base.path, 'unsynced'));
    if (!await unsynced.exists()) await unsynced.create(recursive: true);
    final synced = Directory(p.join(base.path, 'synced'));
    if (!await synced.exists()) await synced.create(recursive: true);
    AppLogger.info('AayshaExports base path: ${base.path}');
    return base;
  }

  Future<Directory> _getDailyExportDir(DateTime date) async {
    final base = await _getBaseDir();
    final dayKey = DateFormat('yyyy-MM-dd').format(date.toLocal());
    final dailyRoot = Directory(p.join(base.parent.path, dayKey));
    if (!await dailyRoot.exists()) await dailyRoot.create(recursive: true);
    final dir = Directory(p.join(dailyRoot.path, 'bills'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Save sale as an Excel file and a companion JSON file in both legacy and daily folders.
  Future<String> saveSaleAsExcel(SaleModel sale) async {
    try {
      final base = await _getBaseDir();
      final unsyncedDir = Directory(p.join(base.path, 'unsynced'));
      final fileName = '${sale.id}.xlsx';
      final jsonName = '${sale.id}.json';
      final filePath = p.join(unsyncedDir.path, fileName);
      final jsonPath = p.join(unsyncedDir.path, jsonName);
      final dailyDir = await _getDailyExportDir(sale.saleDate);
      final dailyFilePath = p.join(dailyDir.path, fileName);
      final dailyJsonPath = p.join(dailyDir.path, jsonName);

      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      sheet.appendRow(['Sale ID', sale.id]);
      sheet.appendRow(['Date', sale.saleDate.toIso8601String()]);
      sheet.appendRow(['Total', sale.totalAmount]);
      sheet.appendRow(['Discount', sale.discount]);
      sheet.appendRow(['PaymentMethod', sale.paymentMethod.name]);
      sheet.appendRow(['CashierId', sale.cashierId]);
      sheet.appendRow(['CustomerId', sale.customerId ?? '']);
      sheet.appendRow(['CreditAmount', sale.creditAmount]);
      sheet.appendRow(['Status', sale.status.name]);
      sheet.appendRow([]);
      sheet.appendRow([
        'ItemId',
        'ProductId',
        'ProductName',
        'Qty',
        'Price',
        'Discount',
        'ItemTotal',
      ]);
      for (final it in sale.items) {
        sheet.appendRow([
          it.id,
          it.productId,
          it.productName,
          it.quantity,
          it.sellingPrice,
          it.discount,
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel bytes');

      final outFile = File(filePath);
      await outFile.writeAsBytes(bytes);
      final dailyFile = File(dailyFilePath);
      await dailyFile.writeAsBytes(bytes);

      final jsonContent = jsonEncode(sale.toJson());
      await File(jsonPath).writeAsString(jsonContent);
      await File(dailyJsonPath).writeAsString(jsonContent);

      AppLogger.success('Saved sale Excel: $dailyFilePath');
      AppLogger.info('Saved sale JSON: $dailyJsonPath');
      return dailyFilePath;
    } catch (e) {
      AppLogger.error('Error saving sale as Excel', e);
      rethrow;
    }
  }

  /// List unsynced JSON files
  Future<List<File>> listUnsyncedJsonFiles() async {
    final base = await _getBaseDir();
    final unsyncedDir = Directory(p.join(base.path, 'unsynced'));
    if (!await unsyncedDir.exists()) return [];
    final files = await unsyncedDir
        .list()
        .where((f) => f is File && p.extension(f.path).toLowerCase() == '.json')
        .map((f) => f as File)
        .toList();
    return files;
  }

  /// List all JSON files from legacy and daily folders.
  Future<List<File>> listAllJsonFiles() async {
    final base = await _getBaseDir();
    final exportRoot = Directory(base.parent.path);
    final files = <String, File>{};
    if (await exportRoot.exists()) {
      await for (final entity in exportRoot.list(recursive: true)) {
        if (entity is File && p.extension(entity.path).toLowerCase() == '.json') {
          final name = p.basename(entity.path);
          // dedupe by filename (saleId.json). prefer first seen (daily or unsynced)
          files.putIfAbsent(name, () => entity);
        }
      }
    }
    return files.values.toList();
  }

  /// Move file pair (json + xlsx) to synced folder after successful upload
  Future<void> markAsSynced(String saleId) async {
    final base = await _getBaseDir();
    final unsynced = Directory(p.join(base.path, 'unsynced'));
    final synced = Directory(p.join(base.path, 'synced'));
    final jsonPath = p.join(unsynced.path, '$saleId.json');
    final xlsxPath = p.join(unsynced.path, '$saleId.xlsx');
    try {
      if (await File(jsonPath).exists()) {
        await File(jsonPath).copy(p.join(synced.path, '$saleId.json'));
        await File(jsonPath).delete();
      }
      if (await File(xlsxPath).exists()) {
        await File(xlsxPath).copy(p.join(synced.path, '$saleId.xlsx'));
        await File(xlsxPath).delete();
      }
    } catch (e) {
      AppLogger.error('Error marking files as synced for $saleId', e);
    }
  }

  /// Delete both json and xlsx files for a sale id from legacy and daily folders.
  Future<void> deleteSaleFiles(String saleId) async {
    final base = await _getBaseDir();
    final unsynced = Directory(p.join(base.path, 'unsynced'));
    final jsonPath = p.join(unsynced.path, '$saleId.json');
    final xlsxPath = p.join(unsynced.path, '$saleId.xlsx');
    try {
      if (await File(jsonPath).exists()) await File(jsonPath).delete();
      if (await File(xlsxPath).exists()) await File(xlsxPath).delete();
      final exportRoot = Directory(base.parent.path);
      if (await exportRoot.exists()) {
        await for (final entity in exportRoot.list(recursive: true)) {
          if (entity is File &&
              (p.basename(entity.path) == '$saleId.json' ||
                  p.basename(entity.path) == '$saleId.xlsx')) {
            await entity.delete();
          }
        }
      }
      AppLogger.info('Deleted offline files for $saleId');
    } catch (e) {
      AppLogger.error('Error deleting files for $saleId', e);
      rethrow;
    }
  }
}
