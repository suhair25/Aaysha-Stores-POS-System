import 'dart:convert';
import 'dart:io';

import 'package:aaysha_stores/models/product_model.dart';
import 'package:aaysha_stores/services/file_product_service.dart';
import 'package:aaysha_stores/utils/storage_path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FileProductService service;

  setUp(() async {
    service = FileProductService();

    final docDir = await StoragePathHelper.resolveDocumentsDirectory();
    final productsDir = Directory(
      p.join(docDir.path, 'AayshaExports', 'products'),
    );
    if (await productsDir.exists()) {
      await productsDir.delete(recursive: true);
    }
  });

  test(
    'offline add, update and delete persist locally and in daily export snapshot',
    () async {
      final now = DateTime.now();
      final product = ProductModel(
        id: 'offline-product-1',
        name: 'Test Product',
        barcode: '123456789012',
        category: 'Groceries',
        costPrice: 10,
        sellingPrice: 15,
        quantity: 5,
        supplierName: 'Supplier',
        lowStockThreshold: 2,
        createdAt: now,
        updatedAt: now,
      );

      await service.saveProduct(product);
      var stored = await service.getAllProducts();
      expect(stored, hasLength(1));
      expect(stored.single.name, 'Test Product');

      final updated = product.copyWith(
        name: 'Updated Product',
        quantity: 12,
        updatedAt: now.add(const Duration(minutes: 5)),
      );
      await service.saveProduct(updated);
      stored = await service.getAllProducts();
      expect(stored.single.name, 'Updated Product');
      expect(stored.single.quantity, 12);

      await service.deleteProduct(product.id);
      stored = await service.getAllProducts();
      expect(stored, isEmpty);

      final docDir = await StoragePathHelper.resolveDocumentsDirectory();
      final dailyExportFile = File(
        p.join(
          docDir.path,
          'AayshaExports',
          'daily',
          DateFormat('yyyy-MM-dd').format(now.toLocal()),
          'products',
          'products.json',
        ),
      );

      expect(await dailyExportFile.exists(), isTrue);
      final payload =
          jsonDecode(await dailyExportFile.readAsString()) as List<dynamic>;
      expect(payload, isEmpty);
    },
  );
}
