import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aaysha_stores/config/app_theme.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'dart:convert';
import 'package:aaysha_stores/services/sqlite_service.dart';
import 'package:aaysha_stores/services/file_storage_service.dart';
import 'package:aaysha_stores/services/file_expense_service.dart';
import 'package:aaysha_stores/services/file_product_service.dart';
import 'package:aaysha_stores/services/export_service.dart';
import 'package:aaysha_stores/models/product_model.dart';
import 'package:aaysha_stores/utils/profit_calculator.dart';

class DailySummaryScreen extends StatefulWidget {
  const DailySummaryScreen({super.key});

  @override
  State<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime? _fromDate;
  DateTime? _toDate;
  List<String> _categories = [];
  String? _selectedCategory;
  // Diagnostics
  int _salesCount = 0;
  int _saleItemsCount = 0;
  int _expensesCount = 0;
  Map<String, dynamic>? _latestSale;

  Future<Map<String, double>> _calculateDayMetrics(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    double totalSales = 0;
    double totalCost = 0;
    int itemCount = 0;
    double totalExpenses = 0;

    if (AppConstants.forceFileOnlyBilling) {
      final fileSvc = FileStorageService();
      final files = await fileSvc.listAllJsonFiles();
      for (final f in files) {
        try {
          final content = await f.readAsString();
          final map = Map<String, dynamic>.from(jsonDecode(content));
          final saleDate = DateTime.parse(map['saleDate']);
          if (saleDate.isBefore(startOfDay) || saleDate.isAfter(endOfDay)) continue;
          totalSales += (map['totalAmount'] as num).toDouble();
          final items = (map['items'] as List).cast<Map<String, dynamic>>();
          itemCount += items.length;
          for (final item in items) {
            totalCost += ((item['sellingPrice'] as num).toDouble() - 10) * (item['quantity'] as int);
          }
        } catch (_) {}
      }
      // Sum expenses from file-backed expenses
      final expSvc = FileExpenseService();
      final exps = await expSvc.getAllExpenses();
      for (final e in exps) {
        final dt = e.expenseDate;
        if (!dt.isBefore(startOfDay) && dt.isBefore(endOfDay)) {
          totalExpenses += e.amount;
        }
      }
    } else {
      final sqlite = SQLiteService();

      // Calculate total sales
      final sales = await sqlite.query(
        'sales',
        where: 'saleDate >= ? AND saleDate < ?',
        whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      );

      for (final sale in sales) {
        totalSales += (sale['totalAmount'] as num).toDouble();

        // Get items for this sale
        final items = await sqlite.query('sale_items', where: 'saleId = ?', whereArgs: [sale['id']]);
        itemCount += items.length;

        // Estimate cost (simplified - in real app, join with products table)
        for (final item in items) {
          totalCost += ((item['sellingPrice'] as num).toDouble() - 10) * (item['quantity'] as int);
        }
      }

      // Get total expenses for the day
      final expenses = await sqlite.query(
        'expenses',
        where: 'expenseDate >= ? AND expenseDate < ?',
        whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      );

      for (final expense in expenses) {
        totalExpenses += (expense['amount'] as num).toDouble();
      }
    }

    final profit = ProfitCalculator.calculateNetProfit(totalSales, totalCost, totalExpenses);
    // Determine bill count depending on storage mode
    int billCount = 0;
    if (AppConstants.forceFileOnlyBilling) {
      final fileSvc = FileStorageService();
      final files = await fileSvc.listAllJsonFiles();
      for (final f in files) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(await f.readAsString()));
          final saleDate = DateTime.parse(map['saleDate']);
          if (!saleDate.isBefore(startOfDay) && saleDate.isBefore(endOfDay)) billCount++;
        } catch (_) {}
      }
    } else {
      final sqlite = SQLiteService();
      final sales = await sqlite.query(
        'sales',
        where: 'saleDate >= ? AND saleDate < ?',
        whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      );
      billCount = sales.length;
    }

    return {
      'totalSales': totalSales,
      'totalCost': totalCost,
      'totalExpenses': totalExpenses,
      'profit': profit,
      'itemCount': itemCount.toDouble(),
      'billCount': billCount.toDouble(),
    };
  }

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now();
    _toDate = DateTime.now();
    _loadCategories();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    try {
      if (AppConstants.forceFileOnlyBilling) {
        final fileSvc = FileStorageService();
        final files = await fileSvc.listAllJsonFiles();
        int itemCount = 0;
        Map<String, dynamic>? latest;
        for (final f in files) {
          try {
            final map = Map<String, dynamic>.from(jsonDecode(await f.readAsString()));
            itemCount += (map['items'] as List).length;
            latest ??= map;
          } catch (_) {}
        }
        setState(() {
          _salesCount = files.length;
          _saleItemsCount = itemCount;
          _expensesCount = 0; // expenses not yet file-backed
          _latestSale = latest;
        });
      } else {
        final sqlite = SQLiteService();
        final sales = await sqlite.query('sales', orderBy: 'saleDate DESC', limit: 1);
        final allSales = await sqlite.getRecordCount('sales');
        final allItems = await sqlite.getRecordCount('sale_items');
        final allExpenses = await sqlite.getRecordCount('expenses');

        setState(() {
          _salesCount = allSales;
          _saleItemsCount = allItems;
          _expensesCount = allExpenses;
          _latestSale = sales.isNotEmpty ? sales.first : null;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadCategories() async {
    final sqlite = SQLiteService();
    try {
      final rows = await sqlite.rawQuery("SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category != ''");
      final cats = rows.map((r) => (r['category'] as String?) ?? '').where((s) => s.isNotEmpty).toSet().toList();
      setState(() {
        _categories = cats;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Summary'),
        actions: [
          IconButton(
            tooltip: 'Export Products to Excel',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportProducts,
          ),
          IconButton(
            tooltip: 'Export Sales to Excel',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: _exportSales,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                title: const Text('Select Date'),
                subtitle: Text(df.format(_selectedDate)),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            title: const Text('From'),
                            subtitle: Text(_fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : 'Not set'),
                            trailing: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _fromDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) setState(() => _fromDate = picked);
                              },
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            title: const Text('To'),
                            subtitle: Text(_toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : 'Not set'),
                            trailing: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _toDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) setState(() => _toDate = picked);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _selectedCategory,
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('All categories')),
                              ..._categories.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c)))
                            ],
                            onChanged: (String? v) => setState(() => _selectedCategory = v),
                            decoration: const InputDecoration(labelText: 'Category (optional)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => setState(() {
                            _fromDate = DateTime.now();
                            _toDate = DateTime.now();
                            _selectedCategory = null;
                          }),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Diagnostic panel to help debug missing data
            Card(
              color: Colors.grey.withValues(alpha: 0.04),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Diagnostics', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Sales count: $_salesCount'),
                    Text('Sale items count: $_saleItemsCount'),
                    Text('Expenses count: $_expensesCount'),
                    const SizedBox(height: 8),
                    Text('Latest sale: ${_latestSale != null ? _latestSale!['id'] ?? 'N/A' : 'None'}'),
                  ],
                ),
              ),
            ),
            FutureBuilder<Map<String, double>>(
              future: _calculateDayMetrics(_selectedDate),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData) {
                  return const Center(child: Text('Failed to load metrics'));
                }

                final data = snapshot.data!;
                final totalSales = data['totalSales'] ?? 0;
                final totalExpenses = data['totalExpenses'] ?? 0;
                final profit = data['profit'] ?? 0;
                final billCount = (data['billCount'] ?? 0).toInt();
                final itemCount = (data['itemCount'] ?? 0).toInt();

                return Column(
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _MetricCard(
                          label: 'Total Sales',
                          value: '${AppConstants.currencySymbol} ${totalSales.toStringAsFixed(2)}',
                          color: AppColors.primary,
                        ),
                        _MetricCard(
                          label: 'Bills',
                          value: billCount.toString(),
                          color: Colors.blue,
                        ),
                        _MetricCard(
                          label: 'Expenses',
                          value: '${AppConstants.currencySymbol} ${totalExpenses.toStringAsFixed(2)}',
                          color: Colors.orange,
                        ),
                        _MetricCard(
                          label: 'Items Sold',
                          value: itemCount.toString(),
                          color: Colors.teal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: profit >= 0 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text('Net Profit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text(
                              '${AppConstants.currencySymbol} ${profit.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: profit >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportProducts() async {
    try {
      // Apply category filter if selected
      final where = _selectedCategory != null ? 'category = ?' : null;
      final whereArgs = _selectedCategory != null ? [_selectedCategory] : null;
      final products = <ProductModel>[];
      if (AppConstants.forceFileOnlyBilling) {
        final prodSvc = FileProductService();
        final list = await prodSvc.getAllProducts();
        final filtered = where != null ? list.where((p) => p.category == whereArgs?.first).toList() : list;
        products.addAll(filtered);
      } else {
        final sqlite = SQLiteService();
        final raw = await sqlite.query('products', where: where, whereArgs: whereArgs);
        products.addAll(raw.map((j) => ProductModel.fromJson(j)).toList());
      }
      final path = await ExportService().exportProductsToExcel(products);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Products exported: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export products')),
      );
    }
  }

  Future<void> _exportSales() async {
    final sqlite = SQLiteService();
    try {
      // Build date filters
      String? where;
      List<dynamic>? whereArgs;
      if (_fromDate != null && _toDate != null) {
        final start = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
        final end = DateTime(_toDate!.year, _toDate!.month, _toDate!.day).add(const Duration(days: 1));
        where = 'saleDate >= ? AND saleDate < ?';
        whereArgs = [start.toIso8601String(), end.toIso8601String()];
      }

      final List<Map<String, dynamic>> sales = [];
      if (AppConstants.forceFileOnlyBilling) {
        final fileSvc = FileStorageService();
        final files = await fileSvc.listAllJsonFiles();
        for (final f in files) {
          try {
            final map = Map<String, dynamic>.from(jsonDecode(await f.readAsString()));
            final sdate = DateTime.parse(map['saleDate']);
            if (where != null) {
              // apply date filter if present
              final start = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
              final end = DateTime(_toDate!.year, _toDate!.month, _toDate!.day).add(const Duration(days: 1));
              if (sdate.isBefore(start) || sdate.isAfter(end)) continue;
            }
            sales.add({
              'id': map['id'],
              'total': map['totalAmount'],
              'itemsCount': (map['items'] as List).length,
              'paymentMethod': map['paymentMethod'] ?? '',
              'customerId': map['customerId'] ?? '',
              'creditAmount': (map['creditAmount'] as num?)?.toDouble() ?? 0.0,
              'status': map['status'] ?? '',
              'createdAt': sdate,
            });
          } catch (_) {}
        }
      } else {
        final rawSales = await sqlite.query('sales', where: where, whereArgs: whereArgs);
        for (final s in rawSales) {
          final items = await sqlite.query('sale_items', where: 'saleId = ?', whereArgs: [s['id']]);
          sales.add({
            'id': s['id'],
            'total': s['totalAmount'],
            'itemsCount': items.length,
            'paymentMethod': s['paymentMethod'] ?? '',
            'customerId': s['customerId'] ?? '',
            'creditAmount': (s['creditAmount'] as num?)?.toDouble() ?? 0.0,
            'status': s['status'] ?? '',
            'createdAt': s['saleDate'] is String ? DateTime.parse(s['saleDate']) : s['saleDate'],
          });
        }
      }

      final path = await ExportService().exportSalesToExcel(sales);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sales exported: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export sales')),
      );
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withValues(alpha: 0.08),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
