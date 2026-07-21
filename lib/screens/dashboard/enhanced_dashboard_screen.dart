import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:aaysha_stores/config/app_theme.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'package:aaysha_stores/providers/auth_provider.dart';
// provider imports not required in this file
import 'package:aaysha_stores/enums/user_role.dart';
import 'package:aaysha_stores/services/sqlite_service.dart';
import 'package:aaysha_stores/utils/profit_calculator.dart';

class EnhancedDashboardScreen extends StatefulWidget {
  const EnhancedDashboardScreen({super.key});

  @override
  State<EnhancedDashboardScreen> createState() => _EnhancedDashboardScreenState();
}

class _EnhancedDashboardScreenState extends State<EnhancedDashboardScreen> {
  late Future<Map<String, dynamic>> _dashboardDataFuture;

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _loadDashboardData();
  }

  Future<Map<String, dynamic>> _loadDashboardData() async {
    final sqlite = SQLiteService();
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Today's sales
    final todaySales = await sqlite.query(
      'sales',
      where: 'saleDate >= ? AND saleDate < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );

    double totalSales = 0;
    double totalCost = 0;
    for (final sale in todaySales) {
      totalSales += (sale['totalAmount'] as num).toDouble();
    }

    // Today's expenses
    final todayExpenses = await sqlite.query(
      'expenses',
      where: 'expenseDate >= ? AND expenseDate < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );

    double totalExpenses = 0;
    for (final expense in todayExpenses) {
      totalExpenses += (expense['amount'] as num).toDouble();
    }

    // All products for stock check
    final allProducts = await sqlite.getAllProducts();
    
    int lowStockCount = 0;
    int outOfStockCount = 0;
    for (final product in allProducts) {
      if (product['quantity'] == 0) {
        outOfStockCount++;
      } else if ((product['quantity'] as int) < (product['lowStockThreshold'] as int? ?? 10)) {
        lowStockCount++;
      }
    }

    // Last 7 days sales for chart
    List<double> last7DaysSales = [];
    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      
      final daySales = await sqlite.query(
        'sales',
        where: 'saleDate >= ? AND saleDate < ?',
        whereArgs: [dayStart.toIso8601String(), dayEnd.toIso8601String()],
      );
      
      double daySalesTotal = 0;
      for (final sale in daySales) {
        daySalesTotal += (sale['totalAmount'] as num).toDouble();
      }
      last7DaysSales.add(daySalesTotal);
    }

    final profit = ProfitCalculator.calculateNetProfit(totalSales, totalCost, totalExpenses);

    return {
      'totalSales': totalSales,
      'totalExpenses': totalExpenses,
      'profit': profit,
      'billCount': todaySales.length,
      'lowStockCount': lowStockCount,
      'outOfStockCount': outOfStockCount,
      'totalProducts': allProducts.length,
      'last7DaysSales': last7DaysSales,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  return Text(
                    authProvider.user?.role.displayName ?? 'User',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Failed to load dashboard'));
          }

          final data = snapshot.data!;
          final isOwner = context.read<AuthProvider>().user?.role == UserRole.owner;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _dashboardDataFuture = _loadDashboardData();
              });
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📊 Today's Metrics
                  _buildMetricsRow(data),
                  const SizedBox(height: 24),

                  // 📈 Sales Chart (Last 7 Days)
                  if (isOwner) ...[
                    Text(
                      'Sales Trend (7 Days)',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildSalesChart(data['last7DaysSales'] ?? []),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 📦 Stock Status
                  Text(
                    'Stock Status',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildStockStatusCards(data),
                  const SizedBox(height: 24),

                  // 🚀 Quick Actions
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildQuickActionsGrid(context, isOwner),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricsRow(Map<String, dynamic> data) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildMetricCard(
          label: 'Today Sales',
          value: '${AppConstants.currencySymbol} ${(data['totalSales'] as num).toStringAsFixed(0)}',
          icon: Icons.trending_up,
          color: AppColors.primary,
        ),
        if (context.read<AuthProvider>().user?.role == UserRole.owner)
          _buildMetricCard(
            label: 'Today Profit',
            value: '${AppConstants.currencySymbol} ${(data['profit'] as num).toStringAsFixed(0)}',
            icon: Icons.monetization_on,
            color: Colors.green,
          )
        else
          _buildMetricCard(
            label: 'Bills',
            value: (data['billCount'] as int).toString(),
            icon: Icons.receipt_long,
            color: Colors.blue,
          ),
        _buildMetricCard(
          label: 'Expenses',
          value: '${AppConstants.currencySymbol} ${(data['totalExpenses'] as num).toStringAsFixed(0)}',
          icon: Icons.money_off,
          color: Colors.orange,
        ),
        _buildMetricCard(
          label: 'Low Stock',
          value: (data['lowStockCount'] as int).toString(),
          icon: Icons.warning_amber,
          color: Colors.amber,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart(List<double> salesData) {
    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                  return Text(days[value.toInt() % 7]);
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                salesData.length,
                (i) => FlSpot(i.toDouble(), salesData[i]),
              ),
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockStatusCards(Map<String, dynamic> data) {
    final outOfStockCount = data['outOfStockCount'] as int;
    final lowStockCount = data['lowStockCount'] as int;

    return Row(
      children: [
        Expanded(
          child: Card(
            color: outOfStockCount > 0 ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Icon(Icons.cancel, color: outOfStockCount > 0 ? Colors.red : Colors.green, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    outOfStockCount.toString(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text('Out of Stock', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            color: lowStockCount > 0 ? Colors.amber.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Icon(Icons.warning_amber, color: lowStockCount > 0 ? Colors.amber : Colors.green, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    lowStockCount.toString(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text('Low Stock', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, bool isOwner) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildActionButton(
          context,
          icon: Icons.shopping_cart,
          label: 'Billing',
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.billing),
        ),
        if (isOwner)
          _buildActionButton(
            context,
            icon: Icons.inventory,
            label: 'Products',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.products),
          )
        else
          _buildActionButton(
            context,
            icon: Icons.qr_code_scanner,
            label: 'Scan',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.barcodeScanner),
          ),
        if (isOwner)
          _buildActionButton(
            context,
            icon: Icons.money_off,
            label: 'Expenses',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.expenses),
          )
        else
          _buildActionButton(
            context,
            icon: Icons.receipt_long,
            label: 'History',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.salesHistory),
          ),
        if (isOwner)
          _buildActionButton(
            context,
            icon: Icons.assessment,
            label: 'Reports',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.dailySummary),
          ),
        _buildActionButton(
          context,
          icon: Icons.settings,
          label: 'Settings',
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.settings),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 32),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

