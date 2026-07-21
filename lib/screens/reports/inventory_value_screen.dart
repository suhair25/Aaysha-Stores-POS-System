import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'package:aaysha_stores/providers/product_provider.dart';
import 'package:aaysha_stores/models/product_model.dart';

class InventoryValueScreen extends StatelessWidget {
  const InventoryValueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory Value')),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, _) {
          if (productProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (productProvider.errorMessage != null) {
            return Center(child: Text(productProvider.errorMessage!));
          }

          final products = productProvider.products;
          final totalCost = products.fold<double>(
            0.0,
            (sum, product) => sum + product.costPrice * product.quantity,
          );
          final totalValue = products.fold<double>(
            0.0,
            (sum, product) => sum + product.sellingPrice * product.quantity,
          );
          final totalProfit = totalValue - totalCost;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inventory Summary',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Total cost value: ${AppConstants.currencySymbol} ${totalCost.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Total selling value: ${AppConstants.currencySymbol} ${totalValue.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Estimated profit if sold: ${AppConstants.currencySymbol} ${totalProfit.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 12),
                        Text('Products in inventory: ${products.length}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: products.isEmpty
                      ? const Center(child: Text('No products available'))
                      : Column(
                          children: [
                            Expanded(
                              child: ListView.separated(
                                itemCount: products.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final product = products[index];
                                  return _buildProductCard(context, product);
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              color: Colors.grey.withValues(alpha: 0.03),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Totals', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text('Total inventory cost value: ${AppConstants.currencySymbol} ${totalCost.toStringAsFixed(2)}'),
                                    const SizedBox(height: 4),
                                    Text('Total inventory selling value: ${AppConstants.currencySymbol} ${totalValue.toStringAsFixed(2)}'),
                                    const SizedBox(height: 4),
                                    Text('Estimated profit if sold: ${AppConstants.currencySymbol} ${totalProfit.toStringAsFixed(2)}'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, ProductModel product) {
    final inventoryCost = product.costPrice * product.quantity;
    final inventoryValue = product.sellingPrice * product.quantity;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Quantity: ${product.quantity}'),
            const SizedBox(height: 4),
            Text(
              'Cost price: ${AppConstants.currencySymbol} ${product.costPrice.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 4),
            Text(
              'Selling price: ${AppConstants.currencySymbol} ${product.sellingPrice.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 4),
            Text(
              'Inventory cost value: ${AppConstants.currencySymbol} ${inventoryCost.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 4),
            Text(
              'Inventory selling value: ${AppConstants.currencySymbol} ${inventoryValue.toStringAsFixed(2)}',
            ),
          ],
        ),
      ),
    );
  }
}
