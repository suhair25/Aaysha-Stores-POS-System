import 'package:flutter/material.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'package:aaysha_stores/screens/auth/login_screen.dart';
import 'package:aaysha_stores/screens/auth/signup_screen.dart';
import 'package:aaysha_stores/screens/barcode/barcode_generator_screen.dart';
import 'package:aaysha_stores/screens/barcode/barcode_scanner_screen.dart';
import 'package:aaysha_stores/screens/dashboard/dashboard_screen.dart';
import 'package:aaysha_stores/screens/products/add_product_screen.dart';
import 'package:aaysha_stores/screens/products/edit_product_screen.dart';
import 'package:aaysha_stores/screens/products/product_list_screen.dart';
import 'package:aaysha_stores/screens/billing/billing_screen.dart';
import 'package:aaysha_stores/screens/billing/offline_bills_screen.dart';
import 'package:aaysha_stores/screens/billing/sales_history_screen.dart';
import 'package:aaysha_stores/screens/expenses/expenses_screen.dart';
import 'package:aaysha_stores/screens/reports/daily_summary_screen.dart';
import 'package:aaysha_stores/screens/reports/inventory_value_screen.dart';
import 'package:aaysha_stores/screens/settings/settings_screen.dart';
import 'package:aaysha_stores/screens/splash_screen.dart';
import 'package:aaysha_stores/models/product_model.dart';
import 'package:aaysha_stores/utils/route_guard.dart';
import 'package:aaysha_stores/enums/user_role.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case AppRoutes.signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case AppRoutes.dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case AppRoutes.products:
        return MaterialPageRoute(
          builder: (_) => RoleGuard(
            requiredRole: UserRole.owner,
            restrictedMessage:
                'Products management is only available for Owners/Admins.',
            child: const ProductListScreen(),
          ),
        );
      case AppRoutes.addProduct:
        return MaterialPageRoute(
          builder: (_) => RoleGuard(
            requiredRole: UserRole.owner,
            restrictedMessage:
                'Adding products is only available for Owners/Admins.',
            child: const AddProductScreen(),
          ),
        );
      case AppRoutes.billing:
        return MaterialPageRoute(builder: (_) => const BillingScreen());
      case AppRoutes.offlineBills:
        return MaterialPageRoute(builder: (_) => const OfflineBillsScreen());
      case AppRoutes.barcodeScanner:
        return MaterialPageRoute(builder: (_) => const BarcodeScannerScreen());
      case AppRoutes.barcodeGenerator:
        return MaterialPageRoute(
          builder: (_) => const BarcodeGeneratorScreen(),
        );
      case AppRoutes.salesHistory:
        return MaterialPageRoute(
          builder: (_) => RoleGuard(
            requiredRole: UserRole.cashier,
            restrictedMessage:
                'Sales history is available for cashiers and owners.',
            child: const SalesHistoryScreen(),
          ),
        );
      case AppRoutes.expenses:
        return MaterialPageRoute(
          builder: (_) => RoleGuard(
            requiredRole: UserRole.owner,
            restrictedMessage:
                'Expenses management is only available for Owners/Admins.',
            child: const ExpensesScreen(),
          ),
        );
      case AppRoutes.dailySummary:
        return MaterialPageRoute(
          builder: (_) => RoleGuard(
            requiredRole: UserRole.owner,
            restrictedMessage:
                'Daily summary reports are only available for Owners/Admins.',
            child: const DailySummaryScreen(),
          ),
        );
      case AppRoutes.inventoryValue:
        return MaterialPageRoute(
          builder: (_) => RoleGuard(
            requiredRole: UserRole.owner,
            restrictedMessage:
                'Inventory value reports are only available for Owners/Admins.',
            child: const InventoryValueScreen(),
          ),
        );
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case AppRoutes.editProduct:
        final product = settings.arguments as dynamic;
        if (product is! ProductModel) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('Invalid product data')),
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => RoleGuard(
            requiredRole: UserRole.owner,
            restrictedMessage:
                'Editing products is only available for Owners/Admins.',
            child: EditProductScreen(product: product),
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }
}
