import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:aaysha_stores/models/product_model.dart';
import 'package:aaysha_stores/utils/logger.dart';
import 'package:aaysha_stores/utils/storage_path.dart';

/// Simple file-backed product storage using a JSON array file.
class FileProductService {
  static final FileProductService _instance = FileProductService._internal();
  factory FileProductService() => _instance;
  FileProductService._internal();

  Future<File> _getProductsFile() async {
    final exportRoot = await StoragePathHelper.resolveExportDirectory();
    final dir = Directory(p.join(exportRoot.path, 'AayshaExports', 'products'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'products.json'));
    if (!await file.exists()) await file.writeAsString(jsonEncode([]));
    return file;
  }

  Future<Directory> _getDailyExportDir(DateTime date) async {
    final exportRoot = await StoragePathHelper.resolveExportDirectory();
    final dir = Directory(
      p.join(
        exportRoot.path,
        'AayshaExports',
        'daily',
        DateFormat('yyyy-MM-dd').format(date.toLocal()),
        'products',
      ),
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<ProductModel>> getAllProducts() async {
    try {
      final f = await _getProductsFile();
      final content = await f.readAsString();
      final arr = jsonDecode(content) as List<dynamic>;
      return arr
          .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to read products file', e);
      return [];
    }
  }

  Future<void> saveProduct(ProductModel product) async {
    try {
      final list = await getAllProducts();
      final idx = list.indexWhere((p) => p.id == product.id);
      if (idx >= 0) {
        list[idx] = product;
      } else {
        list.add(product);
      }
      await syncProductsSnapshot(list);
    } catch (e) {
      AppLogger.error('Failed to save product to file', e);
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      final list = await getAllProducts();
      final newList = list.where((p) => p.id != id).toList();
      await syncProductsSnapshot(newList);
    } catch (e) {
      AppLogger.error('Failed to delete product file entry', e);
      rethrow;
    }
  }

  Future<void> syncProductsSnapshot(
    List<ProductModel> products, {
    DateTime? date,
  }) async {
    final payload = jsonEncode(products.map((e) => e.toJson()).toList());

    final f = await _getProductsFile();
    await f.writeAsString(payload);

    final dailyDir = await _getDailyExportDir(date ?? DateTime.now());
    final dailyFile = File(p.join(dailyDir.path, 'products.xlsx'));
    final jsonFile = File(p.join(dailyDir.path, 'products.json'));
    final excel = Excel.createExcel();
    final sheet = excel['Products'];
    sheet.appendRow([
      'ID',
      'Name',
      'Barcode',
      'Category',
      'Cost Price',
      'Selling Price',
      'Stock',
    ]);
    for (final item in products) {
      sheet.appendRow([
        item.id,
        item.name,
        item.barcode ?? '',
        item.category,
        item.costPrice,
        item.sellingPrice,
        item.quantity,
      ]);
    }
    final bytes = excel.encode();
    if (bytes != null) {
      await dailyFile.writeAsBytes(bytes);
    }
    await jsonFile.writeAsString(payload);
  }
}
