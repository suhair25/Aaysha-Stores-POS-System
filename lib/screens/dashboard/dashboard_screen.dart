import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aaysha_stores/config/app_theme.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'package:aaysha_stores/providers/auth_provider.dart';
import 'package:aaysha_stores/enums/user_role.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  return Text(
                    authProvider.user?.role.displayName ?? 'User',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final isOwner = authProvider.user?.role == UserRole.owner;
          final isCashier = authProvider.user?.role == UserRole.cashier;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 80,
                  color: Color.fromARGB(255, 16, 185, 129),
                ),
                const SizedBox(height: 24),
                Text(
                  'Aaysha Stores',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                // OWNER/ADMIN ONLY SECTION
                if (isOwner) ...[
                  _buildSectionTitle('📦 Inventory Management', context),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.products),
                    child: const Text('Manage Products'),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('💰 Billing & Sales', context),
                ],
                // CASHIER & OWNER CAN ACCESS BILLING
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.billing),
                  child: const Text('Billing (Cashier)'),
                ),
                // OWNER ONLY FEATURES
                if (isOwner) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.salesHistory),
                    child: const Text('Sales History'),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('📊 Reports & Analysis', context),
                  ElevatedButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.inventoryValue),
                    child: const Text('Inventory Value Report'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.dailySummary),
                    child: const Text('Daily Summary'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.expenses),
                    child: const Text('Expenses'),
                  ),
                ],
                // CASHIER RESTRICTED MESSAGE
                if (isCashier) ...[
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.info),
                    ),
                    child: const Text(
                      '✓ Billing only role\nOwner: Can access all features',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.info),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: const Color.fromARGB(255, 16, 185, 129),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
