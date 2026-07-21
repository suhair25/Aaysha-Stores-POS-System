import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aaysha_stores/config/app_theme.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'package:aaysha_stores/enums/payment_method.dart';
import 'package:aaysha_stores/models/product_model.dart';
import 'package:aaysha_stores/providers/billing_provider.dart';
import 'package:aaysha_stores/providers/auth_provider.dart';
import 'package:aaysha_stores/providers/customer_provider.dart';
import 'package:aaysha_stores/screens/billing/bill_preview_screen.dart';
import 'package:aaysha_stores/services/receipt_service.dart';
// models imported where needed by other files; avoid unused imports here
import 'package:aaysha_stores/providers/product_provider.dart';
import 'package:aaysha_stores/enums/user_role.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(
    text: '0',
  );
  final TextEditingController _notesController = TextEditingController();
  String _searchTerm = '';
  String? _selectedCustomerId;

  @override
  void dispose() {
    _searchController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _resetBillingState() {
    final billingProvider = context.read<BillingProvider>();
    billingProvider.clearCart();
    billingProvider.setPaymentMethod(PaymentMethod.cash);
    billingProvider.setDiscount(0.0);
    billingProvider.setNotes(null);
    _searchTerm = '';
    _searchController.clear();
    _discountController.text = '0';
    _notesController.clear();
    _selectedCustomerId = null;
  }

  Future<void> _showAddCustomerDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final customerProv = context.read<CustomerProvider>();
    final res = await showDialog<Map<String, String>?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogContext, {'name': name, 'phone': phone});
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (res != null) {
      final name = res['name']!;
      final phone = res['phone'];
      final ok = await customerProv.addCustomer(
        name: name,
        phone: phone?.isEmpty == true ? null : phone,
      );
      if (!mounted) {
        return;
      }
      if (ok) {
        await customerProv.loadCustomers();
        final customers = customerProv.customers;
        if (customers.isNotEmpty) {
          setState(() {
            _selectedCustomerId = customers.first.id;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final billingProvider = context.watch<BillingProvider>();
    final customerProvider = context.watch<CustomerProvider>();
    final availableProducts = _searchTerm.isEmpty
        ? productProvider.products
        : productProvider.products
              .where(
                (product) =>
                    product.name.toLowerCase().contains(
                      _searchTerm.toLowerCase(),
                    ) ||
                    (product.barcode?.contains(_searchTerm) ?? false),
              )
              .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('POS Billing')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search product or scan barcode',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final products = productProvider.products;

                        final barcode = await Navigator.of(
                          context,
                        ).pushNamed<String>(AppRoutes.barcodeScanner);

                        if (!mounted || barcode == null || barcode.isEmpty) {
                          return;
                        }

                        // Normalize barcode for matching (remove leading/trailing spaces)
                        final cleanBarcode = barcode.trim();

                        // Find product by barcode with case-insensitive comparison
                        ProductModel? product;
                        for (final item in products) {
                          if (item.barcode != null &&
                              item.barcode!.trim().toLowerCase() ==
                                  cleanBarcode.toLowerCase()) {
                            product = item;
                            break;
                          }
                        }

                        if (product != null) {
                          // Add product directly to cart
                          billingProvider.addProductToCart(product);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                '✓ Added ${product.name} to cart',
                              ),
                              duration: const Duration(seconds: 2),
                              backgroundColor: Colors.green,
                            ),
                          );

                          // Clear search field and focus back to search
                          _searchController.clear();
                          _searchTerm = '';
                          setState(() {});

                          // Keep scanner active so user can continue scanning
                        } else {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'No product found for barcode: $cleanBarcode',
                              ),
                              duration: const Duration(seconds: 3),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() {
                    _searchTerm = value.trim();
                  }),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<PaymentMethod>(
                        initialValue: billingProvider.paymentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Payment Method',
                          border: OutlineInputBorder(),
                        ),
                        items: PaymentMethod.values
                            .map(
                              (method) => DropdownMenuItem(
                                value: method,
                                child: Text(method.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (method) {
                          if (method != null) {
                            billingProvider.setPaymentMethod(method);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _discountController,
                        decoration: const InputDecoration(
                          labelText: 'Discount',
                          prefixText: '₹',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (value) {
                          final discount = double.tryParse(value) ?? 0.0;
                          billingProvider.setDiscount(discount);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _openBarcodeGeneratorForProduct(null);
                        },
                        icon: const Icon(Icons.qr_code),
                        label: const Text('Generate Barcode'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showManualItemDialog(context),
                      icon: const Icon(Icons.edit),
                      label: const Text('Add Manual Item'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Customer selection for credit
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCustomerId,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Select Customer (for credit)',
                        ),
                        items: customerProvider.customers
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(
                                  '${c.name} (LKR ${c.outstanding.toStringAsFixed(2)})',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCustomerId = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _showAddCustomerDialog(context),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available products',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: productProvider.isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : availableProducts.isEmpty
                              ? const Center(
                                  child: Text('No matching products found'),
                                )
                              : ListView.separated(
                                  itemCount: availableProducts.length,
                                  separatorBuilder: (_, index) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final product = availableProducts[index];
                                    return ListTile(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      tileColor: Colors.white,
                                      title: Text(
                                        product.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        '${AppConstants.currencySymbol} ${product.sellingPrice.toStringAsFixed(2)} • ${product.quantity} available',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (product.barcode == null ||
                                              product.barcode!.isEmpty)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.qr_code_2,
                                                size: 20,
                                              ),
                                              tooltip:
                                                  'Generate barcode for this product',
                                              onPressed: () =>
                                                  _openBarcodeGeneratorForProduct(
                                                    product,
                                                  ),
                                            ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add_shopping_cart_outlined,
                                            ),
                                            onPressed: () {
                                              billingProvider.addProductToCart(
                                                product,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    color: AppColors.surfaceLight,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cart',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: billingProvider.cartItems.isEmpty
                                ? const Center(child: Text('Cart is empty'))
                                : ListView.separated(
                                    itemCount: billingProvider.cartItems.length,
                                    separatorBuilder: (_, index) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final item =
                                          billingProvider.cartItems[index];
                                      return Card(
                                        elevation: 3,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Product name and remove button row
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      item.productName ??
                                                          item.productId,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 15,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  GestureDetector(
                                                    onTap: () =>
                                                        billingProvider
                                                            .removeItem(
                                                              item.productId,
                                                            ),
                                                    child: const Icon(
                                                      Icons.close,
                                                      size: 20,
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              // Price and quantity row
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    '${AppConstants.currencySymbol} ${item.sellingPrice.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                        color: Colors.grey
                                                            .shade300,
                                                        width: 1,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        6,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        InkWell(
                                                          onTap: () {
                                                            if (item.quantity >
                                                                1) {
                                                              billingProvider
                                                                  .updateQuantity(
                                                                    item
                                                                        .productId,
                                                                    item
                                                                            .quantity -
                                                                        1,
                                                                  );
                                                            }
                                                          },
                                                          child: const Padding(
                                                            padding:
                                                                EdgeInsets.all(
                                                              4,
                                                            ),
                                                            child: Icon(
                                                              Icons.remove,
                                                              size: 14,
                                                            ),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 10,
                                                          ),
                                                          child: Text(
                                                            '${item.quantity}',
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                        InkWell(
                                                          onTap: () {
                                                            billingProvider
                                                                .updateQuantity(
                                                                  item
                                                                      .productId,
                                                                  item.quantity +
                                                                      1,
                                                                );
                                                          },
                                                          child: const Padding(
                                                            padding:
                                                                EdgeInsets.all(
                                                              4,
                                                            ),
                                                            child: Icon(
                                                              Icons.add,
                                                              size: 14,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              // Total row
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  const Text(
                                                    'Total:',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${AppConstants.currencySymbol} ${item.total.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const Divider(height: 32),
                          Text(
                            'Subtotal: ${AppConstants.currencySymbol} ${billingProvider.subtotal.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Discount: ${AppConstants.currencySymbol} ${billingProvider.discount.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total: ${AppConstants.currencySymbol} ${billingProvider.total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                            onChanged: (value) =>
                                billingProvider.setNotes(value),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: billingProvider.hasItems
                                ? () async {
                                    final bp = context.read<BillingProvider>();
                                    final cashierId =
                                        context.read<AuthProvider>().user?.uid ??
                                            'local';
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final customerProv =
                                        context.read<CustomerProvider>();

                                    // Prompt for amount paid (LKR)
                                    final paid = await showDialog<double?>(
                                      context: context,
                                      builder: (dialogContext) {
                                        final paidCtrl = TextEditingController(
                                          text: billingProvider.total
                                              .toStringAsFixed(2),
                                        );
                                        return AlertDialog(
                                          title: const Text('Payment'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Total: ${AppConstants.currencySymbol} ${billingProvider.total.toStringAsFixed(2)}',
                                              ),
                                              const SizedBox(height: 8),
                                              TextField(
                                                controller: paidCtrl,
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                decoration:
                                                    const InputDecoration(
                                                      labelText:
                                                          'Amount paid (LKR)',
                                                    ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dialogContext, null),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                final v =
                                                    double.tryParse(
                                                      paidCtrl.text.trim(),
                                                    ) ??
                                                    0.0;
                                                if (v <= 0) {
                                                  return;
                                                }
                                                Navigator.pop(dialogContext, v);
                                              },
                                              child: const Text('Confirm'),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    if (paid == null) {
                                      return;
                                    }
                                    if (paid <= 0) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Enter a valid payment amount.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    if (!mounted) {
                                      return;
                                    }

                                    final total = bp.total;
                                    final creditAmount = (total - paid).clamp(
                                      0.0,
                                      double.infinity,
                                    );

                                    if (creditAmount > 0 &&
                                        _selectedCustomerId == null) {
                                      // Prompt user to select/add customer or proceed without linking credit
                                      if (!mounted) {
                                        return;
                                      }
                                      final currentContext = context;
                                      final proceed = await showDialog<bool>(
                                        context: currentContext, // ignore: use_build_context_synchronously
                                        builder: (dialogContext) => AlertDialog(
                                          title: const Text(
                                            'Customer Required',
                                          ),
                                          content: const Text(
                                            'This sale will result in a credit (amount due). Would you like to select/add a customer now?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dialogContext, false),
                                              child: const Text(
                                                'Select Customer',
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dialogContext, null),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(dialogContext, true),
                                              child: const Text(
                                                'Proceed Anyway',
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (!mounted) {
                                        return;
                                      }
                                      if (proceed == null) {
                                        return;
                                      }
                                      if (proceed == false) {
                                        // let the UI remain so user can pick a customer
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Please select or add a customer for credit',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      // proceed == true -> continue without customer
                                    }

                                    // finalizeSale may perform async DB work; we've captured
                                    // all needed objects (bp, messenger, customerProv) above.
                                    try {
                                      final sale = await bp.finalizeSale(
                                        cashierId,
                                        customerId: _selectedCustomerId,
                                        creditAmount: creditAmount,
                                      );
                                      if (!mounted) {
                                        return;
                                      }
                                      if (sale != null) {
                                        if (creditAmount > 0 &&
                                            _selectedCustomerId != null) {
                                          await customerProv.addCredit(
                                            customerId: _selectedCustomerId!,
                                            saleId: sale.id,
                                            amount: creditAmount,
                                          );
                                        }

                                        final savedPdf =
                                            await ReceiptService.saveSalePdf(
                                              sale,
                                            );
                                        final pdfBytes =
                                            await ReceiptService.generateSalePdf(
                                              sale,
                                            );
                                        if (!mounted) {
                                          return;
                                        }
                                        final navigator = Navigator.of(context); // ignore: use_build_context_synchronously
                                        await navigator.push(
                                          MaterialPageRoute(
                                            builder: (_) => BillPreviewScreen(
                                              pdfBytes: pdfBytes,
                                              saleId: sale.id,
                                            ),
                                          ),
                                        );
                                        await showDialog<void>(
                                          context: context, // ignore: use_build_context_synchronously
                                          builder: (dialogContext) => AlertDialog(
                                            title: const Text(
                                              'Bill generated',
                                            ),
                                            content: Text(
                                              savedPdf != null
                                                  ? 'Bill PDF saved to: ${savedPdf.path}.\n\nThe bill preview has been opened. You can also print or share the bill.'
                                                  : 'Bill preview opened, but the file could not be saved. Please check storage access or app permissions.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(dialogContext),
                                                child: const Text('Close'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (creditAmount > 0 &&
                                            _selectedCustomerId != null) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Bill saved. Credit ${AppConstants.currencySymbol} ${creditAmount.toStringAsFixed(2)} recorded',
                                              ),
                                            ),
                                          );
                                        } else {
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Bill saved successfully',
                                              ),
                                            ),
                                          );
                                        }

                                        if (!mounted) {
                                          return;
                                        }
                                        setState(() {
                                          _resetBillingState();
                                        });
                                      }
                                    } catch (e) {
                                      final msg = e.toString();
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to save bill: $msg',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: const Text('Create Bill'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBarcodeGeneratorForProduct(ProductModel? product) async {
    final productProvider = context.read<ProductProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final authProvider = context.read<AuthProvider>();

    final value = await Navigator.of(
      context,
    ).pushNamed<String>(AppRoutes.barcodeGenerator);
    if (!mounted || value == null || value.isEmpty) {
      return;
    }

    if (product == null) {
      // user just generated a barcode without selecting a product; copy to search field
      setState(() {
        _searchTerm = value;
        _searchController.text = value;
        _searchController.selection = TextSelection.collapsed(
          offset: value.length,
        );
      });
      return;
    }

    // If current user is owner allow saving barcode to product, otherwise copy barcode to search field
    final isOwner = authProvider.user?.role == UserRole.owner;

    if (!isOwner) {
      // cashier: do not save barcode to product; copy to search so it can be used immediately
      setState(() {
        _searchTerm = value;
        _searchController.text = value;
        _searchController.selection = TextSelection.collapsed(
          offset: value.length,
        );
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Barcode generated (not saved). Owner can save to product.',
          ),
        ),
      );
      return;
    }

    // Owner: assign barcode to product and save
    final updated = product.copyWith(barcode: value, updatedAt: DateTime.now());
    final ok = await productProvider.updateProduct(updated);
    if (!mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Barcode saved for ${product.name}' : 'Failed to save barcode',
        ),
      ),
    );
  }

  Future<void> _showManualItemDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final messenger = ScaffoldMessenger.of(context);
    final billingProv = context.read<BillingProvider>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Manual Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Item name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: qtyCtrl,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
              if (name.isEmpty || price <= 0 || qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid values')),
                );
                return;
              }
              billingProv.addCustomItem(
                name: name,
                price: price,
                quantity: qty,
              );
              Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Manual item added to cart')),
      );
    }
  }
}
