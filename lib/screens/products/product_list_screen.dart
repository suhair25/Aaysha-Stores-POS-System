import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aaysha_stores/config/app_theme.dart';
import 'package:aaysha_stores/providers/product_provider.dart';
import 'package:aaysha_stores/screens/products/add_product_screen.dart';
import 'package:aaysha_stores/screens/products/edit_product_screen.dart';
import 'package:aaysha_stores/services/label_service.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> with WidgetsBindingObserver {
  final Set<String> _selectedProductIds = {};
  bool _selectionMode = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ProductProvider>();
      unawaited(_initializeProducts(provider));
    });
  }

  Future<void> _initializeProducts(ProductProvider provider) async {
    try {
      await provider.loadProducts();
      if (!mounted) return;
      await _checkExternalSnapshot();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkExternalSnapshot();
    }
  }

  Future<void> _checkExternalSnapshot() async {
    try {
      final provider = context.read<ProductProvider>();
      final messenger = ScaffoldMessenger.of(context);
      final prefs = await SharedPreferences.getInstance();
      final autoCheckEnabled = prefs.getBool('autoCheckSnapshotChanges') ?? true;
      if (!autoCheckEnabled) return;

      final diff = await provider.checkExternalSnapshotDiff();
      if (diff == null) return;
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('External product snapshot detected'),
          content: Text('Found changes in exported product snapshot:\nAdded: ${diff.added.length}, Updated: ${diff.updated.length}, Deleted: ${diff.deleted.length}.\n\nApply these changes to the app?\nDeleted products will be removed from the app.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Ignore')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Import')),
          ],
        ),
      );
      if (confirmed != true) return;
      messenger.showSnackBar(const SnackBar(content: Text('Applying product snapshot...')));
      final ok = await provider.importProductsFromFile(diff.externalProducts);
      if (ok) {
        messenger.showSnackBar(const SnackBar(content: Text('Product snapshot applied')));
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Failed to apply snapshot')));
      }
    } catch (e) {
      // ignore errors silently
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();

    return Scaffold(
      appBar: AppBar(
        title: _selectionMode
            ? Text('${_selectedProductIds.length} selected')
            : const Text('Products'),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selectionMode = false;
                  _selectedProductIds.clear();
                }),
              )
            : null,
        actions: [
          if (!_selectionMode && productProvider.lowStockCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Chip(
                  backgroundColor: AppColors.error.withValues(alpha: 0.12),
                  label: Text(
                    '${productProvider.lowStockCount} low',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ),
          if (_selectionMode)
            IconButton(
              tooltip: 'Print labels for selected',
              icon: const Icon(Icons.print_outlined),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final selectedProducts = productProvider.products.where((p) => _selectedProductIds.contains(p.id)).toList();
                  if (selectedProducts.isEmpty) return;
                  final bytes = await LabelService().generateLabelsForProducts(selectedProducts, copiesPerProduct: 2);
                  final filename = 'labels_${DateTime.now().millisecondsSinceEpoch}.pdf';
                  final path = await LabelService().savePdfToFile(bytes, filename);
                  if (!mounted) return;
                  messenger.showSnackBar(SnackBar(content: Text('Labels saved: $path')));
                  await Printing.sharePdf(bytes: bytes, filename: filename);
                  setState(() {
                    _selectionMode = false;
                    _selectedProductIds.clear();
                  });
                } catch (e) {
                  messenger.showSnackBar(const SnackBar(content: Text('Failed to generate labels')));
                }
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: productProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : productProvider.products.isEmpty
                ? const Center(child: Text('No products found. Add your first item.'))
                : ListView.separated(
                    itemCount: productProvider.products.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final product = productProvider.products[index];
                      final selected = _selectedProductIds.contains(product.id);
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        clipBehavior: Clip.antiAlias,
                        color: selected ? AppColors.primary.withValues(alpha: 0.06) : null,
                        child: ListTile(
                          onTap: () async {
                            if (_selectionMode) {
                              setState(() {
                                if (selected) {
                                  _selectedProductIds.remove(product.id);
                                } else {
                                  _selectedProductIds.add(product.id);
                                }
                                if (_selectedProductIds.isEmpty) {
                                  _selectionMode = false;
                                }
                              });
                              return;
                            }
                            final provider = context.read<ProductProvider>();
                            final didUpdate = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => EditProductScreen(product: product),
                              ),
                            );
                            if (!mounted) return;
                            if (didUpdate == true) {
                              provider.loadProducts();
                            }
                          },
                          onLongPress: () {
                            setState(() {
                              _selectionMode = true;
                              _selectedProductIds.add(product.id);
                            });
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                          ),
                          subtitle: Text(
                            product.synced ? 'Cloud synced' : 'Sync pending',
                            style: TextStyle(
                              color: product.synced ? Colors.green[700] : Colors.orange[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Icon(
                            product.synced ? Icons.cloud_done : Icons.cloud_upload_outlined,
                            color: product.synced ? Colors.green[700] : Colors.orange[800],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final provider = context.read<ProductProvider>();
          final didAdd = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddProductScreen()),
          );
          if (!mounted) return;
          if (didAdd == true) {
            provider.loadProducts();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
