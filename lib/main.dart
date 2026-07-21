import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:aaysha_stores/config/app_theme.dart';
import 'package:aaysha_stores/config/app_router.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'package:aaysha_stores/providers/auth_provider.dart';
import 'package:aaysha_stores/providers/billing_provider.dart';
import 'package:aaysha_stores/providers/product_provider.dart';
import 'package:aaysha_stores/providers/expense_provider.dart';
import 'package:aaysha_stores/providers/customer_provider.dart';
import 'package:aaysha_stores/services/database_initializer.dart';
import 'package:aaysha_stores/services/notification_service.dart';
import 'package:aaysha_stores/services/sqlite_service.dart';
import 'package:aaysha_stores/services/sync_service.dart';
import 'package:aaysha_stores/models/product_model.dart';
import 'package:aaysha_stores/services/file_product_service.dart';
import 'package:aaysha_stores/utils/theme_mode_controller.dart';
// Platform and foundation imports removed (unused after migration)

/// Main entry point of Aaysha Stores ERP Application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SQLite FFI initialization removed — app uses file-backed storage now.

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase initialization error - continue with local database
  }

  // Initialize database with sample data
  await DatabaseInitializer.initializeWithSampleData();

  // Initialize notifications and schedule daily summary reminder
  try {
    await NotificationService().initialize();
    await NotificationService().scheduleDailySummaryReminder();
    SyncService().start();
      // Attempt to upload any saved offline sales files at startup
      try {
        await SyncService().uploadSavedSales();
      } catch (e) {
        // ignore startup upload failures
      }

    // One-time low-stock scan and notify
    if (AppConstants.forceFileOnlyBilling) {
      final prodSvc = FileProductService();
      final products = await prodSvc.getAllProducts();
      for (final p in products) {
        if (p.isOutOfStock) {
          await NotificationService().notifyOutOfStock(p.name);
        } else if (p.isLowStock) {
          await NotificationService().notifyLowStock(p.name, p.quantity);
        }
      }
    } else {
      final sqlite = SQLiteService();
      final rows = await sqlite.query('products', where: 'isDeleted = ?', whereArgs: [0]);
      final products = rows.map((r) => ProductModel.fromJson(r)).toList();
      for (final p in products) {
        if (p.isOutOfStock) {
          await NotificationService().notifyOutOfStock(p.name);
        } else if (p.isLowStock) {
          await NotificationService().notifyLowStock(p.name, p.quantity);
        }
      }
    }
  } catch (e) {
    // Ignore notification initialization failures
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => BillingProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
      ],
      child: const AayshaStoresApp(),
    ),
  );
}

/// Main App Widget
class AayshaStoresApp extends StatefulWidget {
  const AayshaStoresApp({super.key});

  @override
  State<AayshaStoresApp> createState() => _AayshaStoresAppState();
}

class _AayshaStoresAppState extends State<AayshaStoresApp> {
  @override
  void initState() {
    super.initState();
    ThemeModeController.instance.addListener(_handleThemeChanged);
    ThemeModeController.instance.loadThemeMode();
  }

  @override
  void dispose() {
    ThemeModeController.instance.removeListener(_handleThemeChanged);
    super.dispose();
  }

  void _handleThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeModeController.instance.themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ta', 'IN'),
      ],
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
