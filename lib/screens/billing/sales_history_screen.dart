import 'package:flutter/material.dart';
import 'package:aaysha_stores/services/sqlite_service.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'package:aaysha_stores/models/sale_model.dart';
import 'package:aaysha_stores/services/receipt_service.dart';
import 'package:provider/provider.dart';
import 'package:aaysha_stores/providers/billing_provider.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:aaysha_stores/enums/payment_method.dart';
import 'package:aaysha_stores/services/file_storage_service.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final SQLiteService _sqlite = SQLiteService();
  bool _isLoading = true;
  List<SaleModel> _sales = [];

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    try {
      final List<SaleModel> loaded = [];
      if (AppConstants.forceFileOnlyBilling) {
        final fileSvc = FileStorageService();
        final files = await fileSvc.listAllJsonFiles();
        for (final f in files) {
          try {
            final content = await f.readAsString();
            final map = SaleModel.fromJson(Map<String, dynamic>.from(jsonDecode(content)));
            loaded.add(map);
          } catch (_) {}
        }
      } else {
        final rows = await _sqlite.query('sales', orderBy: 'saleDate DESC');
        for (final row in rows) {
          // load items for this sale
          final items = await _sqlite.query('sale_items', where: 'saleId = ?', whereArgs: [row['id']]);
          final mappedItems = items.map((m) => SaleItemModel.fromJson(Map<String, dynamic>.from(m))).toList();
          final saleMap = Map<String, dynamic>.from(row);
          saleMap['items'] = mappedItems.map((i) => i.toJson()).toList();
          final sale = SaleModel.fromJson(saleMap);
          loaded.add(sale);
        }
      }
      if (mounted) setState(() => _sales = loaded);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load sales')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSaleDetail(SaleModel sale) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sale ${sale.id}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Date: ${sale.saleDate.toLocal()}'),
              const SizedBox(height: 8),
              Text('Total: ${AppConstants.currencySymbol} ${sale.totalAmount.toStringAsFixed(2)}'),
              if (sale.customerId != null && sale.customerId!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Customer: ${sale.customerId}'),
              ],
              if (sale.creditAmount > 0) ...[
                const SizedBox(height: 8),
                Text('Credit Due: ${AppConstants.currencySymbol} ${sale.creditAmount.toStringAsFixed(2)}'),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sale.items.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = sale.items[index];
                     final name = item.productName ?? item.productId;
                     return ListTile(
                       title: Text(name),
                      subtitle: Text('Qty: ${item.quantity} • ${AppConstants.currencySymbol} ${item.sellingPrice.toStringAsFixed(2)}'),
                      trailing: Text('${AppConstants.currencySymbol} ${item.total.toStringAsFixed(2)}'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
              TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final Uint8List bytes = await ReceiptService.generateSalePdf(sale);
                await Printing.sharePdf(bytes: bytes, filename: 'sale_${sale.id}.pdf');
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate receipt')));
              }
            },
            child: const Text('Export'),
          ),
          TextButton(
            onPressed: () async {
              final billingProv = context.read<BillingProvider>();
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dctx) => AlertDialog(
                  title: const Text('Confirm Delete'),
                  content: const Text('Delete this sale? This cannot be undone.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('Delete'))],
                ),
              );
              if (confirm != true) return;
              if (!mounted) return;
              Navigator.of(context).pop();
              final ok = await billingProv.deleteSale(sale.id);
              if (!mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale deleted')));
                await _loadSales();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete sale')));
              }
            },
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () async {
              final billingProv = context.read<BillingProvider>();
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dctx) => AlertDialog(
                  title: const Text('Confirm Return'),
                  content: const Text('Process return for this sale and restock items?'),
                  actions: [TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('Return'))],
                ),
              );
              if (confirm != true) return;
              if (!mounted) return;
              Navigator.of(context).pop();
              final ok = await billingProv.returnSale(sale.id);
              if (!mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return processed and items restocked')));
                await _loadSales();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to process return')));
              }
            },
            child: const Text('Return'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sales.isEmpty
              ? const Center(child: Text('No sales recorded yet'))
              : RefreshIndicator(
                  onRefresh: _loadSales,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _sales.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final s = _sales[index];
                      return Card(
                        child: ListTile(
                          title: Text('${AppConstants.currencySymbol} ${s.totalAmount.toStringAsFixed(2)}'),
                          subtitle: Text(
                            '${s.saleDate.toLocal()} • ${s.paymentMethod.displayName}${s.customerId != null ? ' • Customer: ${s.customerId}' : ''}${s.creditAmount > 0 ? ' • Credit: ${AppConstants.currencySymbol} ${s.creditAmount.toStringAsFixed(2)}' : ''}',
                          ),
                          onTap: () => _showSaleDetail(s),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
