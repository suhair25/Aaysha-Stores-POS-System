import 'package:aaysha_stores/enums/payment_method.dart';
import 'package:aaysha_stores/enums/sale_status.dart';
import 'package:aaysha_stores/models/sale_model.dart';
import 'package:aaysha_stores/providers/billing_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('return adjustment flips the sale total negative for daily reports', () {
    final sale = SaleModel(
      id: 'sale-1',
      saleDate: DateTime(2026, 6, 29),
      totalAmount: 125.5,
      discount: 5.0,
      paymentMethod: PaymentMethod.cash,
      cashierId: 'cashier-1',
      status: SaleStatus.completed,
      createdAt: DateTime(2026, 6, 29),
      items: const [],
    );

    final update = BillingProvider.buildReturnSaleUpdate(sale);

    expect(update['id'], 'sale-1');
    expect(update['totalAmount'], -125.5);
    expect(update['status'], SaleStatus.refunded.name);
  });
}
