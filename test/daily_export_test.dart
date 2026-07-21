import 'dart:io';

import 'package:aaysha_stores/enums/payment_method.dart';
import 'package:aaysha_stores/models/sale_model.dart';
import 'package:aaysha_stores/services/file_storage_service.dart';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (call) async {
    if (call.method == 'getApplicationDocumentsDirectory') {
      return Directory.systemTemp.path;
    }
    return null;
  });

  test('saving a sale creates a daily export folder', () async {
    final service = FileStorageService();
    final saleId = 'test-sale-${DateTime.now().millisecondsSinceEpoch}';
    final sale = SaleModel(
      id: saleId,
      saleDate: DateTime.now(),
      totalAmount: 100,
      discount: 0,
      paymentMethod: PaymentMethod.cash,
      cashierId: 'cashier',
      createdAt: DateTime.now(),
      items: [
        SaleItemModel(
          id: 'item-1',
          saleId: 'test-sale-1',
          productId: 'p1',
          productName: 'Test Product',
          quantity: 1,
          sellingPrice: 100,
          discount: 0,
        ),
      ],
    );

    final path = await service.saveSaleAsExcel(sale);
    final file = File(path);
    expect(file.existsSync(), isTrue);
    expect(
      file.parent.path,
      contains(RegExp(r'AayshaExports[\\/]\d{4}-\d{2}-\d{2}')),
    );

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel['Sheet1'];
    expect(sheet.maxRows, greaterThan(0));
    expect(sheet.maxCols, greaterThan(0));
    final firstRow = sheet.row(0).map((cell) => cell?.value?.toString() ?? '').toList();
    expect(firstRow, contains('Sale ID'));
  });
}
