/// App-wide constants and configuration values
class AppConstants {
  // App Info
  static const String appName = 'Aaysha Stores ERP';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  // Shop Defaults
  static const String defaultShopName = 'Aaysha Stores';
  static const String defaultShopAddress = '';
  static const String defaultShopPhone = '';

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration syncTimeout = Duration(seconds: 60);
  static const Duration debounceDelay = Duration(milliseconds: 500);

  // Firebase Configuration
  static const String firebaseProjectId = 'aaysha-stores';

  // Database
  static const String databaseName = 'aaysha_stores.db';
  static const int databaseVersion = 1;

  // Storage paths
  static const String productsImagePath = 'products/';
  static const String receiptsPath = 'receipts/';
  static const String backupsPath = 'backups/';
  static const String excelExportsPath = 'exports/';

  // Daily Sales Report Time Range
  static const int dailyReportStartHour = 6; // 6:00 AM
  static const int dailyReportEndHour = 22; // 10:00 PM

  // Low Stock Alert Threshold (percentage)
  static const double lowStockThresholdPercentage = 20.0; // 20% of max quantity

  // Pagination
  static const int pageSize = 20;
  static const int maxProductsPerPage = 50;
  static const int maxSalesPerPage = 100;

  // Search Debounce
  static const Duration searchDebounce = Duration(milliseconds: 300);

  // Sync Settings
  static const Duration autoSyncInterval = Duration(minutes: 15);
  static const int maxSyncRetries = 3;
  static const Duration syncRetryDelay = Duration(seconds: 5);

  // Excel Export Configuration
  static const String productsSheetName = 'Products';
  static const String salesSheetName = 'Sales';
  static const String expensesSheetName = 'Expenses';
  static const String profitReportSheetName = 'Profit Report';
  static const String inventoryReportSheetName = 'Inventory Report';

  // Default Currency
  static const String currencySymbol = 'LKR'; // Sri Lankan Rupee display
  static const String currencyCode = 'LKR';

  // Discount Configuration
  static const double maxDiscountPercentage = 100.0;
  static const int minDiscountValue = 0;

  // Cache Duration
  static const Duration imageCacheDuration = Duration(days: 30);
  static const Duration dataCacheDuration = Duration(hours: 24);

  // Demo Data
  static const bool enableDemoData = true;
  static const int demoProduitCount = 25;

  // Notification Settings
  static const bool enableNotifications = true;
  static const bool enableLowStockNotification = true;
  static const bool enableExpiryNotification = true;
  static const int expiryAlertDays = 7; // Alert 7 days before expiry

  // Thermal Printer (Phase 2)
  static const bool enableThermalPrinter = false;

  // Features Configuration
  static const bool enableOfflineMode = true;
  static const bool enableCloudSync = true;
  // When true, bills are saved only as Excel/JSON files (no SQLite writes)
  static const bool forceFileOnlyBilling = true;
  static const bool enableDarkMode = true;
  static const bool enableMultiLanguage = true;

  // Logging
  static const bool enableDetailedLogging = true;
}

/// Feature Flags
class FeatureFlags {
  // Core Features (v1.0)
  static const bool barcodeScan = true;
  static const bool barcodeGenerate = true;
  static const bool posBilling = true;
  static const bool inventoryManagement = true;
  static const bool offlineSupport = true;
  static const bool excelExport = true;
  static const bool firebaseSync = true;

  // Analytics & Reports
  static const bool dashboardAnalytics = true;
  static const bool profitCalculation = true;
  static const bool expenseTracking = true;
  static const bool dailySummary = true;
  static const bool reportGeneration = true;

  // User Management
  static const bool roleBasedAccess = true;
  static const bool multiUser = true;
  static const bool userPermissions = true;

  // Advanced Features (v1.1+)
  static const bool thermalPrinter = false;
  static const bool whatsappSharing = false;
  static const bool qrPayment = false;
  static const bool backupRestore = true; // Phase 13
  static const bool cloudBackup = true; // Phase 13

  // UI/UX Features
  static const bool darkMode = true;
  static const bool multiLanguage = true;
  static const bool animations = true;
}

/// Routes
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String billing = '/billing';
  static const String offlineBills = '/offline-bills';
  static const String products = '/products';
  static const String addProduct = '/add-product';
  static const String editProduct = '/edit-product';
  static const String barcodeScanner = '/barcode-scanner';
  static const String barcodeGenerator = '/barcode-generator';
  static const String reports = '/reports';
  static const String expenses = '/expenses';
  static const String dailySummary = '/daily-summary';
  static const String salesHistory = '/sales-history';
  static const String inventoryValue = '/inventory-value';
  static const String settings = '/settings';
  static const String userManagement = '/user-management';
}

/// Excel Export File Names
class ExcelFileNames {
  static String get productsFileName =>
      'Products_${DateTime.now().toIso8601String().split('T')[0]}.xlsx';
  static String get salesFileName =>
      'Sales_${DateTime.now().toIso8601String().split('T')[0]}.xlsx';
  static String get expensesFileName =>
      'Expenses_${DateTime.now().toIso8601String().split('T')[0]}.xlsx';
  static String get profitReportFileName =>
      'Profit_Report_${DateTime.now().toIso8601String().split('T')[0]}.xlsx';
  static String get inventoryReportFileName =>
      'Inventory_Report_${DateTime.now().toIso8601String().split('T')[0]}.xlsx';
}

/// Error Messages
class ErrorMessages {
  static const String noInternet =
      'No internet connection. Working in offline mode.';
  static const String syncFailed = 'Failed to sync data. Please try again.';
  static const String firebaseInitFailed = 'Failed to initialize Firebase.';
  static const String databaseInitFailed =
      'Failed to initialize local database.';
  static const String authFailed = 'Authentication failed. Please try again.';
  static const String invalidCredentials = 'Invalid email or password.';
  static const String emailAlreadyExists = 'Email already registered.';
  static const String cameraPermissionDenied =
      'Camera permission is required to scan barcodes.';
  static const String storagePermissionDenied =
      'Storage permission is required.';
  static const String failedToLoadProducts = 'Failed to load products.';
  static const String failedToCreateBill = 'Failed to create bill.';
  static const String failedToExportExcel = 'Failed to export Excel file.';
  static const String fileNotFound = 'File not found.';
  static const String invalidBarcode = 'Invalid barcode format.';
  static const String productNotFound = 'Product not found.';
  static const String insufficientStock = 'Insufficient stock available.';
  static const String somethingWentWrong =
      'Something went wrong. Please try again.';
}

/// Success Messages
class SuccessMessages {
  static const String productAddedSuccess = 'Product added successfully.';
  static const String productUpdatedSuccess = 'Product updated successfully.';
  static const String productDeletedSuccess = 'Product deleted successfully.';
  static const String billCreatedSuccess = 'Bill created successfully.';
  static const String expenseAddedSuccess = 'Expense added successfully.';
  static const String syncedSuccess = 'Data synced successfully.';
  static const String exportedSuccess = 'Exported successfully.';
  static const String backupCreatedSuccess = 'Backup created successfully.';
  static const String settingsSavedSuccess = 'Settings saved successfully.';
}

/// Regex Patterns
class RegexPatterns {
  static const String email =
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String phone = r'^[0-9]{10}$';
  static const String barcode = r'^[0-9]{8,13}$';
  static const String currencyAmount = r'^\d+(\.\d{1,2})?$';
  static const String alphabetOnly = r'^[a-zA-Z ]*$';
  static const String alphanumeric = r'^[a-zA-Z0-9 ]*$';
}
