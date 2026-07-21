import 'package:aaysha_stores/models/product_model.dart';
import 'package:aaysha_stores/models/expense_model.dart';
import 'package:aaysha_stores/enums/expense_category.dart';
import 'package:aaysha_stores/services/sqlite_service.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:aaysha_stores/services/file_product_service.dart';
import 'package:aaysha_stores/services/file_expense_service.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'package:aaysha_stores/services/firebase_service.dart';
import 'package:aaysha_stores/utils/logger.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Database Initializer - Seeds sample data
class DatabaseInitializer {
  static final SQLiteService _db = SQLiteService();

  /// Initialize database with sample data
  static Future<void> initializeWithSampleData() async {
    if (kIsWeb) {
      AppLogger.info('Running on web — skipping SQLite sample data initialization');
      return;
    }

    try {
      AppLogger.info('Starting database initialization...');

      // Add sample products
      await _seedProducts();

      // Add sample expenses
      await _seedExpenses();

      // Also seed sample products to Firestore if Firebase is available
      await _seedProductsToFirestore();

      AppLogger.success('Database initialization completed successfully');
    } catch (e) {
      AppLogger.error('Database initialization failed', e);
    }
  }

  /// Seed sample products
  static Future<void> _seedProducts() async {
    try {
      final sampleProducts = [
        ProductModel(
          id: 'prod_001',
          name: 'Sugar (1kg)',
          barcode: '8901234567001',
          category: 'Grocery',
          costPrice: 30.0,
          sellingPrice: 45.0,
          quantity: 50,
          supplierName: 'ABC Wholesale',
          expiryDate: DateTime.now().add(Duration(days: 180)),
          lowStockThreshold: 10,
          createdAt: DateTime.now(),
        ),
        ProductModel(
          id: 'prod_002',
          name: 'Rice (5kg)',
          barcode: '8901234567002',
          category: 'Grocery',
          costPrice: 120.0,
          sellingPrice: 180.0,
          quantity: 30,
          supplierName: 'ABC Wholesale',
          expiryDate: DateTime.now().add(Duration(days: 200)),
          lowStockThreshold: 5,
          createdAt: DateTime.now(),
        ),
        ProductModel(
          id: 'prod_003',
          name: 'Oil (1L)',
          barcode: '8901234567003',
          category: 'Oils & Spices',
          costPrice: 80.0,
          sellingPrice: 120.0,
          quantity: 25,
          supplierName: 'XYZ Traders',
          expiryDate: DateTime.now().add(Duration(days: 150)),
          lowStockThreshold: 8,
          createdAt: DateTime.now(),
        ),
        ProductModel(
          id: 'prod_004',
          name: 'Salt (1kg)',
          barcode: '8901234567004',
          category: 'Grocery',
          costPrice: 15.0,
          sellingPrice: 25.0,
          quantity: 100,
          supplierName: 'ABC Wholesale',
          expiryDate: DateTime.now().add(Duration(days: 365)),
          lowStockThreshold: 20,
          createdAt: DateTime.now(),
        ),
        ProductModel(
          id: 'prod_005',
          name: 'Milk (500ml)',
          barcode: '8901234567005',
          category: 'Dairy',
          costPrice: 25.0,
          sellingPrice: 40.0,
          quantity: 45,
          supplierName: 'Fresh Dairy Co',
          expiryDate: DateTime.now().add(Duration(days: 7)),
          lowStockThreshold: 15,
          createdAt: DateTime.now(),
        ),
        ProductModel(
          id: 'prod_006',
          name: 'Bread (400g)',
          barcode: '8901234567006',
          category: 'Bakery',
          costPrice: 30.0,
          sellingPrice: 50.0,
          quantity: 20,
          supplierName: 'Local Bakery',
          expiryDate: DateTime.now().add(Duration(days: 3)),
          lowStockThreshold: 5,
          createdAt: DateTime.now(),
        ),
        ProductModel(
          id: 'prod_007',
          name: 'Butter (200g)',
          barcode: '8901234567007',
          category: 'Dairy',
          costPrice: 80.0,
          sellingPrice: 130.0,
          quantity: 15,
          supplierName: 'Fresh Dairy Co',
          expiryDate: DateTime.now().add(Duration(days: 30)),
          lowStockThreshold: 3,
          createdAt: DateTime.now(),
        ),
        ProductModel(
          id: 'prod_008',
          name: 'Tea (500g)',
          barcode: '8901234567008',
          category: 'Beverages',
          costPrice: 120.0,
          sellingPrice: 200.0,
          quantity: 35,
          supplierName: 'Tea Imports Ltd',
          expiryDate: DateTime.now().add(Duration(days: 180)),
          lowStockThreshold: 10,
          createdAt: DateTime.now(),
        ),
      ];

      for (final product in sampleProducts) {
        try {
          if (AppConstants.forceFileOnlyBilling) {
            await FileProductService().saveProduct(product);
          } else {
            await _db.insert('products', product.toJson());
          }
          AppLogger.debug('Added sample product: ${product.name}');
        } catch (e) {
          AppLogger.debug('Sample product ${product.name} already exists or error: $e');
        }
      }

      AppLogger.success('Sample products seeded successfully');
    } catch (e) {
      AppLogger.error('Failed to seed products', e);
    }
  }

  /// Seed sample products to Firestore
  static Future<void> _seedProductsToFirestore() async {
    try {
      if (!AppConstants.enableCloudSync) {
        AppLogger.info('Cloud sync disabled; skipping Firestore sample seed');
        return;
      }

      final sampleProducts = [
        ProductModel(
          id: 'prod_001',
          name: 'Sugar (1kg)',
          barcode: '8901234567001',
          category: 'Grocery',
          costPrice: 30.0,
          sellingPrice: 45.0,
          quantity: 50,
          supplierName: 'ABC Wholesale',
          expiryDate: DateTime.now().add(Duration(days: 180)),
          lowStockThreshold: 10,
          createdAt: DateTime.now(),
          synced: true,
        ),
        ProductModel(
          id: 'prod_002',
          name: 'Rice (5kg)',
          barcode: '8901234567002',
          category: 'Grocery',
          costPrice: 120.0,
          sellingPrice: 180.0,
          quantity: 30,
          supplierName: 'ABC Wholesale',
          expiryDate: DateTime.now().add(Duration(days: 200)),
          lowStockThreshold: 5,
          createdAt: DateTime.now(),
          synced: true,
        ),
        ProductModel(
          id: 'prod_003',
          name: 'Oil (1L)',
          barcode: '8901234567003',
          category: 'Oils & Spices',
          costPrice: 80.0,
          sellingPrice: 120.0,
          quantity: 25,
          supplierName: 'XYZ Traders',
          expiryDate: DateTime.now().add(Duration(days: 150)),
          lowStockThreshold: 8,
          createdAt: DateTime.now(),
          synced: true,
        ),
        ProductModel(
          id: 'prod_004',
          name: 'Salt (1kg)',
          barcode: '8901234567004',
          category: 'Grocery',
          costPrice: 15.0,
          sellingPrice: 25.0,
          quantity: 100,
          supplierName: 'ABC Wholesale',
          expiryDate: DateTime.now().add(Duration(days: 365)),
          lowStockThreshold: 20,
          createdAt: DateTime.now(),
          synced: true,
        ),
        ProductModel(
          id: 'prod_005',
          name: 'Milk (500ml)',
          barcode: '8901234567005',
          category: 'Dairy',
          costPrice: 25.0,
          sellingPrice: 40.0,
          quantity: 45,
          supplierName: 'Fresh Dairy Co',
          expiryDate: DateTime.now().add(Duration(days: 7)),
          lowStockThreshold: 15,
          createdAt: DateTime.now(),
          synced: true,
        ),
      ];

      for (final product in sampleProducts) {
        try {
          await FirebaseService().setDocument('products', product.id, product.toJson());
          AppLogger.debug('Seeded Firestore sample product: ${product.name}');
        } catch (e) {
          AppLogger.error('Failed to seed Firestore product ${product.id}', e);
        }
      }

      AppLogger.success('Sample products seeded to Firestore successfully');
    } catch (e) {
      AppLogger.error('Failed to seed sample products to Firestore', e);
    }
  }

  /// Seed sample expenses
  static Future<void> _seedExpenses() async {
    try {
      final today = DateTime.now();
      final sampleExpenses = [
        ExpenseModel(
          id: 'exp_001',
          category: ExpenseCategory.electricity,
          amount: 500.0,
          description: 'Electricity bill for May',
          expenseDate: today,
          addedBy: 'admin',
          createdAt: today,
        ),
        ExpenseModel(
          id: 'exp_002',
          category: ExpenseCategory.rent,
          amount: 1000.0,
          description: 'Store rent payment',
          expenseDate: today.subtract(Duration(days: 1)),
          addedBy: 'admin',
          createdAt: today.subtract(Duration(days: 1)),
        ),
        ExpenseModel(
          id: 'exp_003',
          category: ExpenseCategory.other,
          amount: 300.0,
          description: 'Office supplies',
          expenseDate: today.subtract(Duration(days: 2)),
          addedBy: 'admin',
          createdAt: today.subtract(Duration(days: 2)),
        ),
        ExpenseModel(
          id: 'exp_004',
          category: ExpenseCategory.transport,
          amount: 800.0,
          description: 'Delivery and transport',
          expenseDate: today.subtract(Duration(days: 3)),
          addedBy: 'admin',
          createdAt: today.subtract(Duration(days: 3)),
        ),
      ];

      for (final expense in sampleExpenses) {
        try {
          if (AppConstants.forceFileOnlyBilling) {
            await FileExpenseService().saveExpense(expense);
          } else {
            await _db.insert('expenses', expense.toJson());
          }
          AppLogger.debug('Added sample expense: ${expense.category.displayName}');
        } catch (e) {
          AppLogger.debug('Sample expense already exists or error: $e');
        }
      }

      AppLogger.success('Sample expenses seeded successfully');
    } catch (e) {
      AppLogger.error('Failed to seed expenses', e);
    }
  }

  /// Clear all data (for testing)
  static Future<void> clearAllData() async {
    try {
      if (AppConstants.forceFileOnlyBilling) {
        // Remove export files directory
        final doc = await getApplicationDocumentsDirectory();
        final dir = Directory(path.join(doc.path, 'AayshaExports'));
        if (await dir.exists()) await dir.delete(recursive: true);
      } else {
        final db = await _db.database;
        await db.delete('sync_queue');
        await db.delete('reports');
        await db.delete('admin_records');
        await db.delete('sale_items');
        await db.delete('sales');
        await db.delete('expenses');
        await db.delete('products');
        await db.delete('users');
      }
      AppLogger.success('All data cleared successfully');
    } catch (e) {
      AppLogger.error('Failed to clear database', e);
    }
  }
}
