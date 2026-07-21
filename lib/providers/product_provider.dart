import 'package:flutter/material.dart';
import 'package:aaysha_stores/models/product_model.dart';
import 'dart:math';
import 'package:aaysha_stores/services/sqlite_service.dart';
import 'package:aaysha_stores/services/file_product_service.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'dart:io';
import 'package:aaysha_stores/services/firebase_service.dart';
import 'package:aaysha_stores/services/sync_service.dart';
import 'package:aaysha_stores/utils/logger.dart';
import 'dart:convert';

/// ProductProvider manages product CRUD and sync
class ProductProvider extends ChangeNotifier {
  final SQLiteService _sqliteService = SQLiteService();
  final SyncService _syncService = SyncService();

  final List<ProductModel> _products = [];
  bool _isLoading = false;
  String? _errorMessage;

  ProductProvider() {
    Future.microtask(() => loadProducts());
  }

  List<ProductModel> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get lowStockCount => _products.where((p) => p.isLowStock).length;

  Future<void> loadProducts() async {
    _setLoading(true);
    try {
      if (AppConstants.forceFileOnlyBilling) {
        final fileSvc = FileProductService();
        final list = await fileSvc.getAllProducts();
        _products
          ..clear()
          ..addAll(list.where((p) => !p.isDeleted));
        AppLogger.info('Loaded ${_products.length} products (file mode)');
      } else {
        final rawProducts = await _sqliteService.query(
          'products',
          where: 'isDeleted = ?',
          whereArgs: [0],
          orderBy: 'name ASC',
        );
        _products
          ..clear()
          ..addAll(rawProducts.map((json) => ProductModel.fromJson(json)));
        AppLogger.info(
          'Loaded ${_products.length} products from local database',
        );
      }
      // Ensure all products have a barcode; generate and persist if missing
      for (final p in List<ProductModel>.from(_products)) {
        if (p.barcode == null || p.barcode!.isEmpty) {
          final newBarcode = await generateUniqueBarcode();
          final updated = p.copyWith(
            barcode: newBarcode,
            updatedAt: DateTime.now(),
          );
          try {
            await updateProduct(updated);
          } catch (_) {}
        }
      }
    } catch (e) {
      AppLogger.error('Failed to load products', e);
      _errorMessage = 'Unable to load products';
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addProduct(ProductModel product) async {
    _setLoading(true);
    try {
      var productToSave = product;

      // If the product has a local image path (not a remote URL), upload it
      if (product.productImageUrl != null &&
          !product.productImageUrl!.startsWith('http')) {
        final file = File(product.productImageUrl!);
        if (await file.exists()) {
          try {
            final storagePath = 'products/${product.id}/image.jpg';
            final url = await FirebaseService().uploadFile(storagePath, file);
            productToSave = product.copyWith(productImageUrl: url);
          } catch (e) {
            AppLogger.error('Image upload failed, saving local path', e);
          }
        }
      }

      if (AppConstants.forceFileOnlyBilling) {
        await FileProductService().saveProduct(productToSave);
        _products.insert(0, productToSave);
      } else {
        await _sqliteService.insert('products', productToSave.toJson());
        _products.insert(0, productToSave);
      }

      try {
        await FileProductService().syncProductsSnapshot(_products);
      } catch (e) {
        AppLogger.warning('Product Excel snapshot sync failed after add: $e');
      }

      // Enqueue product for background sync; keep the local add successful even if sync is unavailable.
      try {
        await _syncService.enqueue('set', 'products', {
          ...productToSave.toJson(),
          'synced': false,
          'syncedAt': null,
        });
        final syncSuccess = await _syncService.processQueue();
        if (syncSuccess) {
          final syncedProduct = productToSave.copyWith(
            synced: true,
            updatedAt: DateTime.now(),
          );
          if (AppConstants.forceFileOnlyBilling) {
            await FileProductService().saveProduct(syncedProduct);
          } else {
            await _sqliteService.update(
              'products',
              syncedProduct.toJson(),
              'id = ?',
              [syncedProduct.id],
            );
          }
          final index = _products.indexWhere((item) => item.id == syncedProduct.id);
          if (index >= 0) _products[index] = syncedProduct;
          productToSave = syncedProduct;
        }
      } catch (e) {
        AppLogger.warning(
          'Product saved locally but sync queue enqueue failed: $e',
        );
      }

      AppLogger.success('Product added: ${product.name}');
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('Failed to add product', e);
      _errorMessage = 'Unable to add product';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProduct(ProductModel product) async {
    _setLoading(true);
    try {
      var productToSave = product;

      if (product.productImageUrl != null &&
          !product.productImageUrl!.startsWith('http')) {
        final file = File(product.productImageUrl!);
        if (await file.exists()) {
          try {
            final storagePath = 'products/${product.id}/image.jpg';
            final url = await FirebaseService().uploadFile(storagePath, file);
            productToSave = product.copyWith(productImageUrl: url);
          } catch (e) {
            AppLogger.error(
              'Image upload failed on update, keeping local path',
              e,
            );
          }
        }
      }

      if (AppConstants.forceFileOnlyBilling) {
        await FileProductService().saveProduct(productToSave);
        final index = _products.indexWhere((item) => item.id == product.id);
        if (index >= 0) _products[index] = productToSave;
      } else {
        await _sqliteService.update(
          'products',
          productToSave.toJson(),
          'id = ?',
          [product.id],
        );
        final index = _products.indexWhere((item) => item.id == product.id);
        if (index >= 0) _products[index] = productToSave;
      }

      try {
        await FileProductService().syncProductsSnapshot(_products);
      } catch (e) {
        AppLogger.warning(
          'Product Excel snapshot sync failed after update: $e',
        );
      }

      try {
        await _syncService.enqueue('update', 'products', {
          ...productToSave.toJson(),
          'synced': false,
          'syncedAt': null,
        });
        final syncSuccess = await _syncService.processQueue();
        if (syncSuccess) {
          final syncedProduct = productToSave.copyWith(
            synced: true,
            updatedAt: DateTime.now(),
          );
          if (AppConstants.forceFileOnlyBilling) {
            await FileProductService().saveProduct(syncedProduct);
          } else {
            await _sqliteService.update(
              'products',
              syncedProduct.toJson(),
              'id = ?',
              [syncedProduct.id],
            );
          }
          final index = _products.indexWhere((item) => item.id == syncedProduct.id);
          if (index >= 0) _products[index] = syncedProduct;
          productToSave = syncedProduct;
        }
      } catch (e) {
        AppLogger.warning(
          'Product updated locally but sync queue enqueue failed: $e',
        );
      }

      AppLogger.success('Product updated: ${product.name}');
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('Failed to update product', e);
      _errorMessage = 'Unable to update product';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteProduct(String id) async {
    _setLoading(true);
    try {
      if (AppConstants.forceFileOnlyBilling) {
        await FileProductService().deleteProduct(id);
        _products.removeWhere((item) => item.id == id);
      } else {
        await _sqliteService.delete('products', 'id = ?', [id]);
        _products.removeWhere((item) => item.id == id);
      }

      try {
        await FileProductService().syncProductsSnapshot(_products);
      } catch (e) {
        AppLogger.warning(
          'Product Excel snapshot sync failed after delete: $e',
        );
      }

      try {
        await _syncService.enqueue('delete', 'products', {'id': id});
        await _syncService.processQueue();
      } catch (e) {
        AppLogger.warning(
          'Product deleted locally but sync queue enqueue failed: $e',
        );
      }

      AppLogger.warning('Product deleted: $id');
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete product', e);
      _errorMessage = 'Unable to delete product';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  ProductModel? getById(String id) {
    try {
      return _products.firstWhere((product) => product.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Import products from an external snapshot (file-produced list).
  /// This will apply adds, updates and deletions so that the local
  /// product list matches the provided snapshot.
  Future<bool> importProductsFromFile(List<ProductModel> products) async {
    _setLoading(true);
    try {
      // Build maps for quick lookup
      final existingMap = {for (var p in List<ProductModel>.from(_products)) p.id: p};
      final incomingMap = {for (var p in products) p.id: p};

      // Delete products that are present locally but missing in snapshot
      for (final localId in existingMap.keys) {
        if (!incomingMap.containsKey(localId)) {
          // use deleteProduct which updates storage/DB and snapshot
          await deleteProduct(localId);
        }
      }

      // Add or update incoming products
      for (final incoming in products) {
        final local = existingMap[incoming.id];
        if (local == null) {
          await addProduct(incoming);
        } else {
          await updateProduct(incoming);
        }
      }

      AppLogger.info('Imported ${products.length} products from file snapshot');
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('Failed to import products from file', e);
      _errorMessage = 'Import failed';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Check for external snapshot differences compared to in-memory products.
  /// Returns null if no external snapshot file exists or there's no difference.
  Future<SnapshotDiff?> checkExternalSnapshotDiff() async {
    try {
      final fileSvc = FileProductService();
      final external = await fileSvc.getAllProducts();
      // build maps
      final localMap = {for (var p in _products) p.id: p};
      final extMap = {for (var p in external) p.id: p};

      final added = <ProductModel>[];
      final updated = <ProductModel>[];
      final deleted = <ProductModel>[];

      for (final e in external) {
        final l = localMap[e.id];
        if (l == null) {
          added.add(e);
        } else {
          // crude equality: compare json
          if (jsonEncode(l.toJson()) != jsonEncode(e.toJson())) {
            updated.add(e);
          }
        }
      }

      for (final l in _products) {
        if (!extMap.containsKey(l.id)) deleted.add(l);
      }

      if (added.isEmpty && updated.isEmpty && deleted.isEmpty) return null;
      return SnapshotDiff(added: added, updated: updated, deleted: deleted, externalProducts: external);
    } catch (e) {
      AppLogger.error('Failed to detect external snapshot diff', e);
      return null;
    }
  }

  /// Generate a numeric barcode (12 digits) that's unique among loaded products
  Future<String> generateUniqueBarcode({int length = 12}) async {
    final rng = Random.secure();
    final existing = _products
        .map((p) => p.barcode)
        .whereType<String>()
        .toSet();
    for (var attempt = 0; attempt < 10000; attempt++) {
      final code = List.generate(length, (_) => rng.nextInt(10)).join();
      if (!existing.contains(code)) return code;
    }
    // fallback: timestamp-based
    return DateTime.now().millisecondsSinceEpoch
        .toString()
        .padRight(length, '0')
        .substring(0, length);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

/// SnapshotDiff describes differences between an external snapshot and local products
class SnapshotDiff {
  final List<ProductModel> added;
  final List<ProductModel> updated;
  final List<ProductModel> deleted;
  final List<ProductModel> externalProducts;

  SnapshotDiff({required this.added, required this.updated, required this.deleted, required this.externalProducts});
}
