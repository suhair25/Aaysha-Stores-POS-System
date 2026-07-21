import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:aaysha_stores/models/product_model.dart';
import 'package:aaysha_stores/services/sqlite_service.dart';
import 'package:aaysha_stores/services/file_storage_service.dart';
import 'package:aaysha_stores/services/file_product_service.dart';
import 'package:aaysha_stores/services/firebase_service.dart';
import 'package:aaysha_stores/services/file_sync_queue_service.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'package:aaysha_stores/utils/logger.dart';

/// SyncService
/// Reads `sync_queue` entries from SQLite and batches them to Firestore.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  final SQLiteService _sqlite = SQLiteService();
  final FileSyncQueueService _fileQueue = FileSyncQueueService();
  final FirebaseService _firebase = FirebaseService();
  Timer? _pollTimer;
  StreamSubscription<ConnectivityResult>? _connSub;
  bool _isRunning = false;

  factory SyncService() => _instance;
  SyncService._internal();

  /// Start background polling (optional)
  void start({Duration interval = const Duration(seconds: 20)}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => processQueue());

    // Listen to connectivity changes and trigger file-based upload when online
    _connSub?.cancel();
    _connSub = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        AppLogger.info('Connectivity regained — attempting file-based upload');
        uploadSavedSales();
      }
    });

    AppLogger.info('SyncService started (interval: ${interval.inSeconds}s)');
  }

  /// Stop polling
  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _connSub?.cancel();
    _connSub = null;
    AppLogger.info('SyncService stopped');
  }

  /// Enqueue operation into sync_queue
  /// operation: 'set' | 'update' | 'delete'
  Future<void> enqueue(String operation, String tableName, Map<String, dynamic> data) async {
    try {
      // If app is forced to file-only, persist sync ops to file queue
      if (AppConstants.forceFileOnlyBilling) {
        await _fileQueue.enqueue(operation, tableName, data);
      } else {
        final payload = jsonEncode(data);
        await _sqlite.insert('sync_queue', {
          'operation': operation,
          'tableName': tableName,
          'data': payload,
          'timestamp': DateTime.now().toIso8601String(),
          'isProcessed': 0,
        });
      }
      AppLogger.debug('Enqueued sync op: $operation $tableName');
    } catch (e) {
      AppLogger.error('Failed to enqueue sync op', e);
      rethrow;
    }
  }

  /// Process pending queue entries — batches per collection for efficiency
  Future<bool> processQueue() async {
    if (_isRunning) return false;
    _isRunning = true;
    var success = true;
    try {
      final conn = await Connectivity().checkConnectivity();
      if (conn == ConnectivityResult.none) {
        AppLogger.info('No connectivity — skipping sync');
        return false;
      }

      List<Map<String, dynamic>> pending = [];
      if (AppConstants.forceFileOnlyBilling) {
        pending = await _fileQueue.getPending();
      } else {
        pending = await _sqlite.query('sync_queue', where: 'isProcessed = ?', whereArgs: [0], orderBy: 'timestamp ASC');
      }
      if (pending.isEmpty) return true;

      // Group by tableName
      final Map<String, List<Map<String, dynamic>>> groups = {};
      for (final row in pending) {
        final table = row['tableName'] as String;
        groups.putIfAbsent(table, () => []).add(row);
      }

      // Process each group in a batch
      for (final entry in groups.entries) {
        final collection = entry.key;
        final ops = <Map<String, dynamic>>[];
        for (final row in entry.value) {
          final operation = row['operation'] as String;
          final rawData = row['data'];
          final data = rawData is String
              ? jsonDecode(rawData) as Map<String, dynamic>
              : Map<String, dynamic>.from(rawData as Map);

          if (operation == 'set') {
            final docId = data['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString();
            ops.add({'collection': collection, 'docId': docId, 'data': {...data, 'synced': true, 'syncedAt': DateTime.now().toIso8601String()}, 'type': 'set'});
          } else if (operation == 'update') {
            final docId = data['id']?.toString();
            if (docId != null) ops.add({'collection': collection, 'docId': docId, 'data': {...data, 'synced': true, 'syncedAt': DateTime.now().toIso8601String()}, 'type': 'update'});
          } else if (operation == 'delete') {
            final docId = data['id']?.toString();
            if (docId != null) ops.add({'collection': collection, 'docId': docId, 'data': {}, 'type': 'delete'});
          }
        }

        if (ops.isEmpty) continue;

        try {
          await _firebase.batchWrite(ops);

          // Mark processed
          // Remove processed entries from file queue or mark processed in SQLite
          final ids = entry.value.map((r) => r['id']?.toString()).whereType<String>().toList();
          if (AppConstants.forceFileOnlyBilling) {
            await _fileQueue.removeByIds(ids);
          } else {
            for (final row in entry.value) {
              await _sqlite.update('sync_queue', {'isProcessed': 1}, 'id = ?', [row['id']]);
            }
          }
        } catch (e) {
          AppLogger.error('Failed to sync group $collection', e);
          success = false;
        }
      }
    } catch (e) {
      AppLogger.error('Error processing sync queue', e);
      success = false;
    } finally {
      _isRunning = false;
    }
    return success;
  }

  /// Upload saved JSON bill files from FileStorageService to Firestore
  Future<void> uploadSavedSales() async {
    try {
      final conn = await Connectivity().checkConnectivity();
      if (conn == ConnectivityResult.none) {
        AppLogger.info('No connectivity — skipping file-based sync');
        return;
      }

      final fileSvc = FileStorageService();
      final files = await fileSvc.listUnsyncedJsonFiles();
      if (files.isEmpty) return;

      for (final f in files) {
        try {
          final content = await f.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          final id = data['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString();
          await _firebase.setDocument('sales', id, {...data, 'synced': true, 'syncedAt': DateTime.now().toIso8601String()});
          await fileSvc.markAsSynced(id);
          AppLogger.success('Uploaded saved sale $id from file');
        } catch (e) {
          AppLogger.error('Failed to upload saved sale file ${f.path}', e);
        }
      }
    } catch (e) {
      AppLogger.error('Error uploading saved sales', e);
    }
  }

  /// Demo function: Create, Update, Delete with Excel Integration
  /// Shows complete workflow with local Excel file storage
  Future<void> testProductSyncFlow() async {
    try {
      AppLogger.info('🧪 Starting Product Sync + Excel Test...');
      
      final fileService = FileProductService();

      // Step 1: Create a sample product
      final sampleProduct = ProductModel(
        id: 'test_sample_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test Sample Product',
        barcode: '1234567890123',
        category: 'Test Category',
        costPrice: 50.0,
        sellingPrice: 100.0,
        quantity: 25,
        supplierName: 'Test Supplier',
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        lowStockThreshold: 5,
        createdAt: DateTime.now(),
        isDeleted: false,
        synced: false,
      );

      AppLogger.info('✅ Step 1: Created sample product');
      AppLogger.info('   ID: ${sampleProduct.id}');
      AppLogger.info('   Name: ${sampleProduct.name}');
      AppLogger.info('   Price: ₹${sampleProduct.sellingPrice} (Cost: ₹${sampleProduct.costPrice})');
      AppLogger.info('   Quantity: ${sampleProduct.quantity}');

      // Step 2: Save to file storage (auto-syncs to Excel locally)
      await fileService.saveProduct(sampleProduct);
      AppLogger.success('✅ Step 2: Saved product to file storage');
      AppLogger.info('   📁 Excel file created at: AayshaExports/daily/{date}/products/products.xlsx');
      AppLogger.info('   📄 JSON file created at: AayshaExports/products/products.json');

      // Step 3: Enqueue for Firebase sync
      await enqueue('set', 'products', {
        'id': sampleProduct.id,
        'name': sampleProduct.name,
        'barcode': sampleProduct.barcode,
        'category': sampleProduct.category,
        'costPrice': sampleProduct.costPrice,
        'sellingPrice': sampleProduct.sellingPrice,
        'quantity': sampleProduct.quantity,
        'supplierName': sampleProduct.supplierName,
        'createdAt': sampleProduct.createdAt.toIso8601String(),
        'synced': false,
      });
      AppLogger.info('✅ Step 3: Enqueued for Firebase sync');

      // Step 4: Update the sample product
      final updatedProduct = ProductModel(
        id: sampleProduct.id,
        name: 'Test Sample Product - Updated',
        barcode: sampleProduct.barcode,
        category: 'Updated Category',
        costPrice: 60.0,
        sellingPrice: 120.0,
        quantity: 15,
        supplierName: 'Updated Supplier',
        expiryDate: sampleProduct.expiryDate,
        lowStockThreshold: 8,
        createdAt: sampleProduct.createdAt,
        updatedAt: DateTime.now(),
        isDeleted: false,
        synced: false,
      );

      AppLogger.info('✅ Step 4: Updated sample product');
      AppLogger.info('   Name: ${updatedProduct.name}');
      AppLogger.info('   Price: ₹${updatedProduct.sellingPrice} (Cost: ₹${updatedProduct.costPrice})');
      AppLogger.info('   Quantity: ${updatedProduct.quantity}');

      // Step 5: Save updated product (Excel auto-updates)
      await fileService.saveProduct(updatedProduct);
      AppLogger.success('✅ Step 5: Updated product saved to file storage');
      AppLogger.info('   📝 Excel file updated automatically');

      // Step 6: Enqueue update for Firebase
      await enqueue('update', 'products', {
        'id': updatedProduct.id,
        'name': updatedProduct.name,
        'category': updatedProduct.category,
        'costPrice': updatedProduct.costPrice,
        'sellingPrice': updatedProduct.sellingPrice,
        'quantity': updatedProduct.quantity,
        'supplierName': updatedProduct.supplierName,
        'updatedAt': updatedProduct.updatedAt?.toIso8601String(),
        'synced': false,
      });
      AppLogger.info('✅ Step 6: Enqueued update for Firebase sync');

      // Step 7: Check current products in file storage
      final productsInFile = await fileService.getAllProducts();
      AppLogger.info('✅ Step 7: Current Products in File Storage');
      AppLogger.info('   Total products: ${productsInFile.length}');
      for (final p in productsInFile) {
        AppLogger.info('   - ${p.name} (₹${p.sellingPrice}) - Qty: ${p.quantity}');
      }

      // Step 8: Delete the sample product
      AppLogger.info('✅ Step 8: Deleting sample product...');
      await fileService.deleteProduct(sampleProduct.id);
      AppLogger.success('✅ Product deleted from file storage');
      AppLogger.info('   📝 Excel file updated (product removed)');

      // Step 9: Enqueue deletion for Firebase
      await enqueue('delete', 'products', {
        'id': sampleProduct.id,
      });
      AppLogger.info('✅ Step 9: Enqueued deletion for Firebase sync');

      // Step 10: Check final products in file storage
      final finalProducts = await fileService.getAllProducts();
      AppLogger.info('✅ Step 10: Final Products in File Storage');
      AppLogger.info('   Total products: ${finalProducts.length}');
      for (final p in finalProducts) {
        AppLogger.info('   - ${p.name} (₹${p.sellingPrice}) - Qty: ${p.quantity}');
      }

      // Step 11: Process the sync queue (Firebase)
      AppLogger.info('✅ Step 11: Processing Firebase sync queue...');
      final syncSuccess = await processQueue();

      if (syncSuccess) {
        AppLogger.success('🎉 Product Sync + Excel Test Completed Successfully!');
        AppLogger.info('   ✓ Product created, updated, and deleted');
        AppLogger.info('   ✓ Excel files updated automatically in local storage');
        AppLogger.info('   ✓ All changes queued for Firebase sync');
        AppLogger.info('');
        AppLogger.info('📁 Local Storage Locations:');
        AppLogger.info('   • Products JSON: AayshaExports/products/products.json');
        AppLogger.info('   • Daily Excel: AayshaExports/daily/{YYYY-MM-DD}/products/products.xlsx');
        AppLogger.info('   • Daily JSON: AayshaExports/daily/{YYYY-MM-DD}/products/products.json');
      } else {
        AppLogger.warning('⚠️ Sync processing had issues (check connectivity)');
      }

      // Step 12: Show sync queue status
      final finalPending = await _sqlite.query('sync_queue', where: 'isProcessed = ?', whereArgs: [0]);
      AppLogger.info('✅ Final Sync Queue Status');
      AppLogger.info('   Remaining unsynced: ${finalPending.length}');
    } catch (e) {
      AppLogger.error('❌ Product Sync + Excel Test Failed', e);
    }
  }
}
