import 'dart:io';

import 'package:aaysha_stores/models/product_model.dart';
import 'package:aaysha_stores/services/file_product_service.dart';
import 'package:aaysha_stores/utils/storage_path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('syncProductsSnapshot writes products json and excel files', () async {
    final service = FileProductService();
    final docDir = await StoragePathHelper.resolveDocumentsDirectory();
    final exportRoot = Directory(p.join(docDir.path, 'AayshaExports'));
    if (await exportRoot.exists()) {
      await exportRoot.delete(recursive: true);
    }

    final product = ProductModel(
      id: 'p-001',
      name: 'Test Product',
      category: 'General',
      costPrice: 20,
      sellingPrice: 25,
      quantity: 10,
      supplierName: 'Supplier',
      lowStockThreshold: 5,
      createdAt: DateTime(2024, 1, 1),
    );

    await service.syncProductsSnapshot([product]);

    final dailyDir = Directory(
      p.join(
        docDir.path,
        'AayshaExports',
        'daily',
        DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal()),
        'products',
      ),
    );

    final excelFile = File(p.join(dailyDir.path, 'products.xlsx'));
    final jsonFile = File(p.join(dailyDir.path, 'products.json'));

    expect(await excelFile.exists(), isTrue);
    expect(await jsonFile.exists(), isTrue);
    expect(await excelFile.length(), greaterThan(0));

    final jsonContent = await jsonFile.readAsString();
    expect(jsonContent, contains('Test Product'));
  });
}
