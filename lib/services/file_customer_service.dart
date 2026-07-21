import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:aaysha_stores/models/customer_model.dart';
import 'package:aaysha_stores/utils/logger.dart';

/// File-backed customer storage using a JSON file.
class FileCustomerService {
  static final FileCustomerService _instance = FileCustomerService._internal();
  factory FileCustomerService() => _instance;
  FileCustomerService._internal();

  Future<File> _getCustomersFile() async {
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(doc.path, 'AayshaExports', 'customers'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'customers.json'));
    if (!await file.exists()) await file.writeAsString(jsonEncode([]));
    return file;
  }

  Future<Directory> _getDailyExportDir(DateTime date) async {
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(
        doc.path,
        'AayshaExports',
        'daily',
        DateFormat('yyyy-MM-dd').format(date.toLocal()),
        'customers',
      ),
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<CustomerModel>> getAllCustomers() async {
    try {
      final f = await _getCustomersFile();
      final content = await f.readAsString();
      final arr = jsonDecode(content) as List<dynamic>;
      return arr
          .map((e) => CustomerModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to read customers file', e);
      return [];
    }
  }

  Future<void> saveCustomer(CustomerModel customer) async {
    try {
      final list = await getAllCustomers();
      final idx = list.indexWhere((c) => c.id == customer.id);
      if (idx >= 0) {
        list[idx] = customer;
      } else {
        list.insert(0, customer);
      }
      final f = await _getCustomersFile();
      final payload = jsonEncode(list.map((e) => e.toJson()).toList());
      await f.writeAsString(payload);

      final dailyDir = await _getDailyExportDir(customer.createdAt);
      final dailyFile = File(p.join(dailyDir.path, 'customers.xlsx'));
      final jsonFile = File(p.join(dailyDir.path, 'customers.json'));
      final excel = Excel.createExcel();
      final sheet = excel['Customers'];
      sheet.appendRow(['ID', 'Name', 'Phone', 'Outstanding', 'CreatedAt']);
      for (final item in list) {
        sheet.appendRow([
          item.id,
          item.name,
          item.phone,
          item.outstanding,
          item.createdAt.toIso8601String(),
        ]);
      }
      final bytes = excel.encode();
      if (bytes != null) {
        await dailyFile.writeAsBytes(bytes);
      }
      await jsonFile.writeAsString(payload);
    } catch (e) {
      AppLogger.error('Failed to save customer to file', e);
      rethrow;
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      final list = await getAllCustomers();
      final newList = list
          .where((c) => c.id != id)
          .map((c) => c.toJson())
          .toList();
      final f = await _getCustomersFile();
      await f.writeAsString(jsonEncode(newList));
    } catch (e) {
      AppLogger.error('Failed to delete customer file entry', e);
      rethrow;
    }
  }
}
