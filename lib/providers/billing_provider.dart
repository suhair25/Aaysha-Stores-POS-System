import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aaysha_stores/enums/payment_method.dart';
import 'package:aaysha_stores/models/product_model.dart';
import 'package:aaysha_stores/models/sale_model.dart';
import 'package:aaysha_stores/enums/sale_status.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:aaysha_stores/services/sqlite_service.dart';
import 'package:aaysha_stores/services/file_product_service.dart';
import 'package:aaysha_stores/services/sync_service.dart';
import 'package:aaysha_stores/services/auth_service.dart';
import 'package:aaysha_stores/services/file_storage_service.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'package:aaysha_stores/utils/logger.dart';

class BillingProvider extends ChangeNotifier {
  final List<SaleItemModel> _cartItems = [];
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  double _discount = 0.0;
  String? _notes;

  List<SaleItemModel> get cartItems => List.unmodifiable(_cartItems);
  PaymentMethod get paymentMethod => _paymentMethod;
  double get discount => _discount;
  String? get notes => _notes;
  bool get hasItems => _cartItems.isNotEmpty;

  double get subtotal => _cartItems.fold(
    0.0,
    (sum, item) => sum + item.sellingPrice * item.quantity,
  );
  double get total => (subtotal - _discount).clamp(0.0, double.infinity);

  void addProductToCart(ProductModel product) {
    final existing = _cartItems.indexWhere(
      (item) => item.productId == product.id,
    );
    if (existing >= 0) {
      final current = _cartItems[existing];
      _cartItems[existing] = current.copyWith(quantity: current.quantity + 1);
    } else {
      _cartItems.add(
        SaleItemModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          saleId: '',
          productId: product.id,
          productName: product.name,
          quantity: 1,
          sellingPrice: product.sellingPrice,
          discount: 0.0,
        ),
      );
    }
    AppLogger.debug('Added product to cart: ${product.name}');
    notifyListeners();
  }

  /// Add a custom/manual item to the cart (no product record)
  void addCustomItem({
    required String name,
    required double price,
    required int quantity,
  }) {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    _cartItems.add(
      SaleItemModel(
        id: id,
        saleId: '',
        productId: id,
        productName: name,
        quantity: quantity,
        sellingPrice: price,
        discount: 0.0,
      ),
    );
    AppLogger.debug('Added custom item to cart: $name x$quantity @ $price');
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index < 0) return;
    if (quantity <= 0) {
      _cartItems.removeAt(index);
    } else {
      final item = _cartItems[index];
      _cartItems[index] = item.copyWith(quantity: quantity);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _cartItems.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  void setPaymentMethod(PaymentMethod method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setDiscount(double value) {
    _discount = value.clamp(0.0, subtotal);
    notifyListeners();
  }

  void setNotes(String? value) {
    _notes = value;
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    _discount = 0.0;
    _notes = null;
    notifyListeners();
  }

  static Map<String, dynamic> buildReturnSaleUpdate(
    SaleModel sale, {
    DateTime? timestamp,
  }) {
    final effectiveTimestamp = timestamp ?? DateTime.now();
    return {
      'id': sale.id,
      'totalAmount': -sale.totalAmount.abs(),
      'status': SaleStatus.refunded.name,
      'updatedAt': effectiveTimestamp.toIso8601String(),
    };
  }

  /// Persist a sale and its items to local SQLite
  Future<bool> persistSale(SaleModel sale) async {
    final sqlite = SQLiteService();

    try {
      // Insert sale row
      await sqlite.insert('sales', {
        'id': sale.id,
        'saleDate': sale.saleDate.toIso8601String(),
        'totalAmount': sale.totalAmount,
        'discount': sale.discount,
        'paymentMethod': sale.paymentMethod.name,
        'cashierId': sale.cashierId,
        'customerId': sale.customerId,
        'creditAmount': sale.creditAmount,
        'adminRecordId': sale.adminRecordId,
        'status': sale.status.name,
        'createdAt': sale.createdAt.toIso8601String(),
        'updatedAt': sale.updatedAt?.toIso8601String(),
      });

      // Insert sale items
      for (final item in sale.items) {
        await sqlite.insert('sale_items', {
          'id': item.id,
          'saleId': sale.id,
          'productId': item.productId,
          'quantity': item.quantity,
          'sellingPrice': item.sellingPrice,
          'discount': item.discount,
        });
      }

      // Enqueue sale and items for background sync
      try {
        final sync = SyncService();

        // Prepare sale JSON and ensure items have saleId
        final saleJson = sale.toJson();
        saleJson['synced'] = false;
        saleJson['syncedAt'] = null;
        saleJson['items'] = sale.items.map((i) {
          final itemJson = i.toJson();
          itemJson['saleId'] = sale.id;
          return itemJson;
        }).toList();

        await sync.enqueue('set', 'sales', saleJson);

        // Enqueue individual sale items as well (optional, keeps Firestore documents per item)
        for (final item in sale.items) {
          final itemJson = item.toJson();
          itemJson['saleId'] = sale.id;
          await sync.enqueue('set', 'sale_items', itemJson);
        }
      } catch (e) {
        AppLogger.warning('Failed to enqueue sale for sync: $e');
      }

      AppLogger.success(
        'Persisted sale ${sale.id} with ${sale.items.length} items',
      );
      return true;
    } catch (e) {
      AppLogger.error('Failed to persist sale', e);
      // Rethrow so callers (UI) can show the error message to users
      rethrow;
    }
  }

  /// Create a sale and persist it atomically, then clear the cart on success
  Future<SaleModel?> finalizeSale(
    String cashierId, {
    String? customerId,
    double creditAmount = 0.0,
  }) async {
    // If running without an authenticated owner, persist sales under a local cashier id
    // so they appear in Sales History. This keeps offline records and still queues them
    // for sync when an owner signs in or network becomes available.
    final auth = AuthService();
    final isAuthenticated = auth.currentUser != null;

    var effectiveCashierId = cashierId;
    if (!isAuthenticated && (cashierId == 'local' || cashierId.isEmpty)) {
      effectiveCashierId = 'local_cashier';
    }

    final sale = createSale(
      effectiveCashierId,
      customerId: customerId,
      creditAmount: creditAmount,
    );
    AppLogger.info(
      'Finalizing sale ${sale.id} total=${sale.totalAmount} cashier=$effectiveCashierId fileMode=${AppConstants.forceFileOnlyBilling}',
    );

    // If configured to force file-only billing, save directly to Excel/JSON
    if (AppConstants.forceFileOnlyBilling) {
      try {
        final fileSvc = FileStorageService();
        AppLogger.info('Saving sale ${sale.id} to file (file-only mode)');
        final path = await fileSvc.saveSaleAsExcel(sale);
        AppLogger.info('Sale ${sale.id} saved to file: $path');
        unawaited(SyncService().uploadSavedSales());
        clearCart();
        return sale;
      } catch (e) {
        AppLogger.error('File-only billing failed', e);
        return null;
      }
    }

    try {
      AppLogger.info('Attempting to persist sale ${sale.id} to SQLite');
      final ok = await persistSale(sale);
      AppLogger.info('persistSale returned $ok for sale ${sale.id}');
      if (ok) {
        clearCart();
        return sale;
      }
      return null;
    } catch (e) {
      // If DB isn't available, fallback to file-based Excel + JSON save
      final msg = e.toString();
      AppLogger.warning(
        'persistSale failed for sale ${sale.id}, falling back to file save: $msg',
      );
      try {
        final fileSvc = FileStorageService();
        AppLogger.info('Fallback: saving sale ${sale.id} to file');
        final path = await fileSvc.saveSaleAsExcel(sale);
        AppLogger.info('Fallback: sale ${sale.id} saved to file: $path');
        // Trigger a file-based sync attempt in background
        unawaited(SyncService().uploadSavedSales());
        clearCart();
        return sale;
      } catch (e2) {
        AppLogger.error('File fallback also failed for sale ${sale.id}', e2);
        return null;
      }
    }
  }

  /// Delete a sale and its items locally and enqueue delete ops for sync
  Future<bool> deleteSale(String saleId) async {
    // If running in file-only mode, remove JSON/XLSX files and enqueue delete
    if (AppConstants.forceFileOnlyBilling) {
      try {
        final fileSvc = FileStorageService();
        await fileSvc.deleteSaleFiles(saleId);
        await SyncService().enqueue('delete', 'sales', {'id': saleId});
        AppLogger.success('Deleted sale files for $saleId and enqueued delete');
        return true;
      } catch (e) {
        AppLogger.error('Failed to delete sale files $saleId', e);
        return false;
      }
    }

    final sqlite = SQLiteService();
    try {
      // load items to enqueue deletes
      final items = await sqlite.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [saleId],
      );

      // delete items then sale
      await sqlite.delete('sale_items', 'saleId = ?', [saleId]);
      await sqlite.delete('sales', 'id = ?', [saleId]);

      // enqueue delete ops
      final sync = SyncService();
      await sync.enqueue('delete', 'sales', {'id': saleId});
      for (final it in items) {
        final id = it['id']?.toString();
        if (id != null) await sync.enqueue('delete', 'sale_items', {'id': id});
      }

      AppLogger.success(
        'Deleted sale $saleId locally and enqueued delete for sync',
      );
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete sale $saleId', e);
      return false;
    }
  }

  /// Process a return for a sale: restock products and mark sale as returned
  Future<bool> returnSale(String saleId) async {
    if (AppConstants.forceFileOnlyBilling) {
      try {
        final fileSvc = FileStorageService();
        final files = await fileSvc.listAllJsonFiles();
        final file = files.firstWhere(
          (f) => p.basename(f.path) == '$saleId.json',
          orElse: () => throw Exception('Sale file not found'),
        );
        final content = await file.readAsString();
        final map = Map<String, dynamic>.from(jsonDecode(content));
        final items = (map['items'] as List).cast<Map<String, dynamic>>();
        if (items.isEmpty) return false;

        final prodSvc = FileProductService();
        final products = await prodSvc.getAllProducts();

        final currentSale = SaleModel.fromJson(map);
        final returnUpdate = BillingProvider.buildReturnSaleUpdate(currentSale);
        final currentStatus = (map['status'] as String?)?.toUpperCase();
        if (currentStatus == SaleStatus.refunded.name ||
            currentStatus == 'RETURNED') {
          AppLogger.info(
            'Sale $saleId already marked as refunded; skipping duplicate return',
          );
          return true;
        }

        for (final it in items) {
          final productId = it['productId'] as String?;
          final qty = (it['quantity'] as int?) ?? 0;
          if (productId != null && qty > 0) {
            final idx = products.indexWhere((p) => p.id == productId);
            if (idx >= 0) {
              final pcur = products[idx];
              final updated = pcur.copyWith(
                quantity: pcur.quantity + qty,
                updatedAt: DateTime.now(),
              );
              await prodSvc.saveProduct(updated);
              await SyncService().enqueue(
                'update',
                'products',
                updated.toJson(),
              );
            }
          }
        }

        // mark sale as refunded in file and subtract it from daily sales totals
        map['totalAmount'] = returnUpdate['totalAmount'];
        map['status'] = returnUpdate['status'];
        map['updatedAt'] = returnUpdate['updatedAt'];
        await file.writeAsString(jsonEncode(map));
        await SyncService().enqueue('update', 'sales', {
          'id': saleId,
          'totalAmount': returnUpdate['totalAmount'],
          'status': returnUpdate['status'],
          'updatedAt': returnUpdate['updatedAt'],
        });
        AppLogger.success(
          'Processed return for sale $saleId (file mode) and restocked items',
        );
        return true;
      } catch (e) {
        AppLogger.error(
          'Failed to process return for sale $saleId (file mode)',
          e,
        );
        return false;
      }
    }

    final sqlite = SQLiteService();
    try {
      final items = await sqlite.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [saleId],
      );
      if (items.isEmpty) return false;

      final saleRows = await sqlite.query(
        'sales',
        where: 'id = ?',
        whereArgs: [saleId],
      );
      final saleRow = saleRows.isNotEmpty ? saleRows.first : null;
      final currentStatus = (saleRow?['status'] as String?)?.toUpperCase();
      if (currentStatus == SaleStatus.refunded.name ||
          currentStatus == 'RETURNED') {
        AppLogger.info(
          'Sale $saleId already marked as refunded; skipping duplicate return',
        );
        return true;
      }

      final originalSale = SaleModel(
        id: saleId,
        saleDate: DateTime.parse(
          saleRow?['saleDate'] as String? ?? DateTime.now().toIso8601String(),
        ),
        totalAmount: (saleRow?['totalAmount'] as num?)?.toDouble() ?? 0.0,
        discount: (saleRow?['discount'] as num?)?.toDouble() ?? 0.0,
        paymentMethod: PaymentMethodExtension.fromString(
          saleRow?['paymentMethod'] as String? ?? 'CASH',
        ),
        cashierId: saleRow?['cashierId'] as String? ?? 'local',
        status: SaleStatusExtension.fromString(
          saleRow?['status'] as String? ?? 'COMPLETED',
        ),
        createdAt: DateTime.parse(
          saleRow?['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        ),
        updatedAt: saleRow?['updatedAt'] != null
            ? DateTime.parse(saleRow!['updatedAt'] as String)
            : null,
        items: [],
      );
      final returnUpdate = BillingProvider.buildReturnSaleUpdate(originalSale);

      // Restock products
      for (final it in items) {
        final productId = it['productId'] as String?;
        final qty = (it['quantity'] as int?) ?? 0;
        if (productId != null && qty > 0) {
          // read product
          final rows = await sqlite.query(
            'products',
            where: 'id = ?',
            whereArgs: [productId],
          );
          if (rows.isNotEmpty) {
            final current = rows.first;
            final currentQty = (current['quantity'] as int?) ?? 0;
            await sqlite.update(
              'products',
              {
                'quantity': currentQty + qty,
                'updatedAt': DateTime.now().toIso8601String(),
              },
              'id = ?',
              [productId],
            );
            // enqueue update for product
            await SyncService().enqueue('update', 'products', {
              ...current,
              'quantity': currentQty + qty,
            });
          }
        }
      }

      // mark sale status as refunded and subtract it from daily sales totals
      await sqlite.update(
        'sales',
        {
          'totalAmount': returnUpdate['totalAmount'],
          'status': returnUpdate['status'],
          'updatedAt': returnUpdate['updatedAt'],
        },
        'id = ?',
        [saleId],
      );
      await SyncService().enqueue('update', 'sales', {
        'id': saleId,
        'totalAmount': returnUpdate['totalAmount'],
        'status': returnUpdate['status'],
        'updatedAt': returnUpdate['updatedAt'],
      });

      AppLogger.success(
        'Processed return for sale $saleId and restocked items',
      );
      return true;
    } catch (e) {
      AppLogger.error('Failed to process return for sale $saleId', e);
      return false;
    }
  }

  SaleModel createSale(
    String cashierId, {
    String? customerId,
    double creditAmount = 0.0,
  }) {
    return SaleModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      saleDate: DateTime.now(),
      totalAmount: subtotal,
      discount: _discount,
      paymentMethod: _paymentMethod,
      cashierId: cashierId,
      customerId: customerId,
      creditAmount: creditAmount,
      status: SaleStatus.completed,
      createdAt: DateTime.now(),
      items: List.unmodifiable(_cartItems),
    );
  }
}
