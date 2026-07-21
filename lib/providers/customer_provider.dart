import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:aaysha_stores/models/customer_model.dart';
import 'package:aaysha_stores/services/sqlite_service.dart';
import 'package:aaysha_stores/services/firebase_service.dart';
import 'package:aaysha_stores/services/file_customer_service.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'package:aaysha_stores/utils/logger.dart';

class CustomerProvider extends ChangeNotifier {
  final SQLiteService _sqlite = SQLiteService();
  final FirebaseService _firebase = FirebaseService();
  final List<CustomerModel> _customers = [];
  bool _isLoading = false;

  List<CustomerModel> get customers => List.unmodifiable(_customers);
  bool get isLoading => _isLoading;

  CustomerProvider() {
    Future.microtask(() => loadCustomers());
  }

  Future<void> loadCustomers() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (AppConstants.forceFileOnlyBilling) {
        final fileSvc = FileCustomerService();
        final list = await fileSvc.getAllCustomers();
        _customers.clear();
        _customers.addAll(list);
        AppLogger.info('Loaded ${_customers.length} customers (file mode)');
      } else {
        final rows = await _sqlite.getCustomers();
        _customers.clear();
        _customers.addAll(rows.map((r) => CustomerModel.fromJson(r)));
        AppLogger.info('Loaded ${_customers.length} customers');
      }
    } catch (e) {
      AppLogger.error('Failed to load customers', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addCustomer({required String name, String? phone}) async {
    try {
      final id = const Uuid().v4();
      final customer = CustomerModel(id: id, name: name, phone: phone, createdAt: DateTime.now());

      // Save locally (SQLite or file)
      if (AppConstants.forceFileOnlyBilling) {
        final fileSvc = FileCustomerService();
        await fileSvc.saveCustomer(customer);
        _customers.insert(0, customer);
      } else {
        await _sqlite.addCustomer(customer.toJson());
        _customers.insert(0, customer);
      }

      // Auto-sync to Firebase
      _firebase.setDocument('customers', customer.id, {
        ...customer.toJson(),
        'synced': true,
        'syncedAt': DateTime.now().toIso8601String(),
      }).catchError((e) {
        AppLogger.warning('Firebase sync delayed: $e');
      });

      notifyListeners();
      AppLogger.success('Customer added: $name');
      return true;
    } catch (e) {
      AppLogger.error('Error adding customer', e);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getCredits(String customerId) async {
    return await _sqlite.getCreditsByCustomer(customerId);
  }

  Future<bool> addCredit({required String customerId, required String saleId, required double amount}) async {
    try {
      final id = const Uuid().v4();
      final creditData = {
        'id': id,
        'customerId': customerId,
        'saleId': saleId,
        'amount': amount,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Save locally
      await _sqlite.addCredit(creditData);

      // update customer's outstanding
      final customerIdx = _customers.indexWhere((c) => c.id == customerId);
      if (customerIdx >= 0) {
        final c = _customers[customerIdx];
        _customers[customerIdx] = CustomerModel(
          id: c.id,
          name: c.name,
          phone: c.phone,
          outstanding: c.outstanding + amount,
          createdAt: c.createdAt,
        );
      }

      // Auto-sync to Firebase
      _firebase.setDocument('credits', id, {
        ...creditData,
        'synced': true,
        'syncedAt': DateTime.now().toIso8601String(),
      }).catchError((e) {
        AppLogger.warning('Firebase sync delayed: $e');
      });

      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('Error adding credit', e);
      return false;
    }
  }

  Future<bool> deleteCredit(String creditId, String customerId, double amount) async {
    try {
      // Delete locally
      await _sqlite.deleteCreditById(creditId);
      final idx = _customers.indexWhere((c) => c.id == customerId);
      if (idx >= 0) {
        final c = _customers[idx];
        _customers[idx] = CustomerModel(
          id: c.id,
          name: c.name,
          phone: c.phone,
          outstanding: (c.outstanding - amount).clamp(0.0, double.infinity),
          createdAt: c.createdAt,
        );
      }

      // Auto-sync deletion to Firebase
      _firebase.deleteDocument('credits', creditId).catchError((e) {
        AppLogger.warning('Firebase sync delayed: $e');
      });

      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('Error deleting credit', e);
      return false;
    }
  }
}
