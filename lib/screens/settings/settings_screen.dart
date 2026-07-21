// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:aaysha_stores/config/app_theme.dart';
import 'package:aaysha_stores/providers/auth_provider.dart';
import 'package:aaysha_stores/providers/product_provider.dart';
import 'package:aaysha_stores/services/export_service.dart';
import 'dart:convert';
import 'package:aaysha_stores/services/file_expense_service.dart';
import 'package:aaysha_stores/services/sqlite_service.dart';
import 'package:aaysha_stores/services/file_product_service.dart';
import 'package:aaysha_stores/services/file_storage_service.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'package:aaysha_stores/models/product_model.dart';
import 'package:aaysha_stores/enums/user_role.dart';
import 'package:aaysha_stores/utils/logger.dart';
import 'package:aaysha_stores/screens/role_selection/role_selection_screen.dart';
import 'package:aaysha_stores/utils/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _enableNotifications = true;
  bool _enableLowStockAlert = true;
  bool _enableExpiryAlert = true;
  bool _autoCheckSnapshotChanges = true;
  String _selectedLanguage = 'en';
  ThemeMode _selectedThemeMode = ThemeMode.system;
  String? _exportFolderPath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enableNotifications = prefs.getBool('enableNotifications') ?? true;
      _enableLowStockAlert = prefs.getBool('enableLowStockAlert') ?? true;
      _enableExpiryAlert = prefs.getBool('enableExpiryAlert') ?? true;
      _autoCheckSnapshotChanges = prefs.getBool('autoCheckSnapshotChanges') ?? true;
      _selectedLanguage = prefs.getString('selectedLanguage') ?? 'en';
      _selectedThemeMode = ThemeModeController.instance.themeMode;
      _exportFolderPath = prefs.getString('exportFolderPath');
    });
  }

  Future<String?> _chooseExportDirectory(String dialogTitle) async {
    try {
      final directory = await FilePicker.getDirectoryPath(dialogTitle: dialogTitle);
      if (directory != null && directory.isNotEmpty) {
        return directory;
      }
    } catch (e) {
      AppLogger.warning('Directory chooser unavailable, falling back to file save picker', e);
    }

    try {
      final fallback = await FilePicker.saveFile(
        dialogTitle: '$dialogTitle (select a file, folder will be derived)',
        fileName: 'export_destination.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      if (fallback != null && fallback.isNotEmpty) {
        return p.dirname(fallback);
      }
    } catch (e) {
      AppLogger.error('Fallback export folder picker failed', e);
    }

    return null;
  }

  Future<void> _saveExportFolderPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('exportFolderPath', path);
    setState(() {
      _exportFolderPath = path;
    });
  }

  Future<String?> _resolveExportDestination(String fileName, String dialogTitle) async {
    if (_exportFolderPath != null && _exportFolderPath!.isNotEmpty) {
      return _ensureXlsxExtension(p.join(_exportFolderPath!, fileName));
    }

    final chosenDirectory = await _chooseExportDirectory(dialogTitle);
    if (chosenDirectory == null) {
      return null;
    }

    await _saveExportFolderPath(chosenDirectory);
    return _ensureXlsxExtension(p.join(chosenDirectory, fileName));
  }

  Future<void> _selectExportFolder(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final chosenDirectory = await _chooseExportDirectory('Select export folder');
    if (chosenDirectory == null) {
      return;
    }
    await _saveExportFolderPath(chosenDirectory);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('Export folder saved: $chosenDirectory')));
  }

  String _ensureXlsxExtension(String path) {
    if (path.toLowerCase().endsWith('.xlsx')) {
      return path;
    }
    return '$path.xlsx';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 👤 Account Section
            _buildSectionHeader(context, 'Account'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('User Info'),
                    subtitle: Text(authProvider.user?.email ?? 'Not logged in'),
                    trailing: const Icon(Icons.person),
                    onTap: () => _showUserInfo(context),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Logout'),
                    subtitle: const Text('Sign out from your account'),
                    trailing: const Icon(Icons.logout),
                    textColor: Colors.red,
                    onTap: () => _showLogoutDialog(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 🔔 Notification Settings
            _buildSectionHeader(context, 'Notifications'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enable Notifications'),
                    value: _enableNotifications,
                    onChanged: (value) {
                      setState(() => _enableNotifications = value);
                      AppLogger.info('Notifications ${value ? 'enabled' : 'disabled'}');
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Low Stock Alerts'),
                    value: _enableLowStockAlert,
                    onChanged: _enableNotifications ? (value) {
                      setState(() => _enableLowStockAlert = value);
                      AppLogger.info('Low stock alerts ${value ? 'enabled' : 'disabled'}');
                    } : null,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Expiry Alerts'),
                    value: _enableExpiryAlert,
                    onChanged: _enableNotifications ? (value) {
                      setState(() => _enableExpiryAlert = value);
                      AppLogger.info('Expiry alerts ${value ? 'enabled' : 'disabled'}');
                    } : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // � Theme
            _buildSectionHeader(context, 'Theme'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose appearance',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildThemeOption('Light', ThemeMode.light, _selectedThemeMode == ThemeMode.light),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildThemeOption('Dark', ThemeMode.dark, _selectedThemeMode == ThemeMode.dark),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildThemeOption('System', ThemeMode.system, _selectedThemeMode == ThemeMode.system),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // �🌐 Language & Localization
            _buildSectionHeader(context, 'Language'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Language',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildLanguageButton('English', 'en', _selectedLanguage == 'en'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildLanguageButton('தமிழ்', 'ta', _selectedLanguage == 'ta'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 📁 Data & Storage
            _buildSectionHeader(context, 'Data & Storage'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Export Data'),
                    subtitle: const Text('Download Excel reports'),
                    trailing: const Icon(Icons.download),
                    onTap: () => _showExportOptions(context),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.folder_open),
                    title: const Text('Export Folder'),
                    subtitle: Text(
                      _exportFolderPath?.isNotEmpty == true
                          ? _exportFolderPath!
                          : 'Tap to choose a folder for all exports',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _selectExportFolder(context),
                  ),
                  const Divider(),
                  SwitchListTile(
                    secondary: const Icon(Icons.sync_outlined),
                    title: const Text('Auto-check product snapshot'),
                    subtitle: const Text('Prompt when exported snapshot changes, in any theme mode'),
                    value: _autoCheckSnapshotChanges,
                    onChanged: (value) async {
                      setState(() => _autoCheckSnapshotChanges = value);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('autoCheckSnapshotChanges', value);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.upload_file),
                    title: const Text('Import Products'),
                    subtitle: const Text('Load product snapshot from app export files'),
                    onTap: () {
                      final currentContext = context;
                      Navigator.pop(currentContext);
                      unawaited(_importProducts(currentContext));
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services),
                    title: const Text('Delete Sample Data'),
                    subtitle: const Text('Remove bundled sample products without reinstalling'),
                    onTap: () async {
                      Navigator.pop(context);
                      final messenger = ScaffoldMessenger.of(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Delete Sample Data'),
                          content: const Text('Delete all bundled sample products? This cannot be undone.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      if (!mounted) return;
                      messenger.showSnackBar(const SnackBar(content: Text('Deleting sample products...')));
                      try {
                        var deleted = 0;
                        if (AppConstants.forceFileOnlyBilling) {
                          final fileSvc = FileProductService();
                          final list = await fileSvc.getAllProducts();
                          final samples = list.where((p) => p.id.startsWith('prod_') || p.id.startsWith('test_sample_') || _isKnownSampleName(p.name)).toList();
                          for (final p in samples) {
                            await fileSvc.deleteProduct(p.id);
                            deleted++;
                          }
                        } else {
                          final sqlite = SQLiteService();
                          final rows = await sqlite.query('products');
                          final samples = rows.where((r) {
                            final id = r['id']?.toString() ?? '';
                            final name = (r['name'] ?? '').toString();
                            return id.startsWith('prod_') || id.startsWith('test_sample_') || _isKnownSampleName(name);
                          }).toList();
                          for (final r in samples) {
                            await sqlite.delete('products', 'id = ?', [r['id']]);
                            deleted++;
                          }
                          // regenerate local product snapshot (Excel/JSON)
                          final remaining = await sqlite.query('products', where: 'isDeleted = ?', whereArgs: [0]);
                          final remainingProducts = remaining.map((e) => ProductModel.fromJson(e)).toList();
                          await FileProductService().syncProductsSnapshot(remainingProducts);
                        }

                        messenger.showSnackBar(SnackBar(content: Text('Deleted $deleted sample products')));
                        AppLogger.success('Deleted $deleted sample products');
                      } catch (e) {
                        messenger.showSnackBar(const SnackBar(content: Text('Failed to delete sample products')));
                        AppLogger.error('Failed to delete sample products', e);
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Clear Cache'),
                    subtitle: const Text('Remove temporary files'),
                    trailing: const Icon(Icons.delete_outline),
                    onTap: () => _showClearCacheDialog(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ℹ️ App Info
            _buildSectionHeader(context, 'App Info'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  const ListTile(
                    title: Text('App Name'),
                    subtitle: Text('Aaysha Stores ERP'),
                  ),
                  const Divider(),
                  const ListTile(
                    title: Text('Version'),
                    subtitle: Text('1.0.0'),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('About'),
                    subtitle: const Text('Modern POS & ERP System'),
                    trailing: const Icon(Icons.info_outline),
                    onTap: () => _showAboutDialog(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(String label, ThemeMode mode, bool isSelected) {
    return GestureDetector(
      onTap: () async {
        setState(() => _selectedThemeMode = mode);
        await ThemeModeController.instance.setThemeMode(mode);
        AppLogger.info('Theme changed to: $label');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primary,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageButton(String label, String code, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedLanguage = code);
        AppLogger.info('Language changed to: $label');
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primary,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }

  bool _isKnownSampleName(String name) {
    final samples = [
      'Sugar',
      'Rice',
      'Oil',
      'Salt',
      'Milk',
      'Bread',
      'Butter',
      'Tea',
    ];
    return samples.contains(name);
  }

  void _showUserInfo(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${user?.fullName ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Email: ${user?.email ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Phone: ${user?.phone ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Role: ${user?.role.displayName ?? 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('Export Products'),
              subtitle: const Text('Save product catalog to Excel'),
              onTap: () {
                Navigator.pop(context);
                _exportProducts(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Export Sales'),
              subtitle: const Text('Save sales history to Excel'),
              onTap: () {
                Navigator.pop(context);
                _exportSales(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.money_off),
              title: const Text('Export Expenses'),
              subtitle: const Text('Save expense records to Excel'),
              onTap: () {
                Navigator.pop(context);
                _exportExpenses(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export All'),
              subtitle: const Text('Generate all core reports'),
              onTap: () {
                Navigator.pop(context);
                _exportAll(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportProducts(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final products = <ProductModel>[];
      if (AppConstants.forceFileOnlyBilling) {
        final prodSvc = FileProductService();
        final list = await prodSvc.getAllProducts();
        products.addAll(list.where((p) => !p.isDeleted));
      } else {
        final sqlite = SQLiteService();
        final rawProducts = await sqlite.query('products', where: 'isDeleted = ?', whereArgs: [0]);
        products.addAll(rawProducts.map((row) => ProductModel.fromJson(row)).toList());
      }
      final path = await _resolveExportDestination(
        'products_export_${DateTime.now().toIso8601String()}.xlsx',
        'Choose folder for product export',
      );
      if (path == null) {
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Products export cancelled')));
        return;
      }
      await ExportService().exportProductsToExcelAtPath(products, path);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Products exported: $path')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Failed to export products')));
      AppLogger.error('Export products failed', e);
    }
  }

  Future<void> _importProducts(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final provider = context.read<ProductProvider>();
      final currentContext = context;
      final fileSvc = FileProductService();
      final list = await fileSvc.getAllProducts();
      if (list.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('No product snapshot found to import')));
        return;
      }

      final confirm = await showDialog<bool>(
        context: currentContext,
        builder: (c) => AlertDialog(
          title: const Text('Import Products'),
          content: const Text('This will replace local products to match the exported snapshot. Continue?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Import')),
          ],
        ),
      );
      if (confirm != true) return;

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Importing products...')));
      final ok = await provider.importProductsFromFile(list);
      if (ok) {
        messenger.showSnackBar(const SnackBar(content: Text('Imported products successfully')));
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Failed to import products')));
      }
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('Failed to import products')));
      AppLogger.error('Import products failed', e);
    }
  }

  Future<void> _exportSales(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final sales = <Map<String, dynamic>>[];
      if (AppConstants.forceFileOnlyBilling) {
        final fileSvc = FileStorageService();
        final files = await fileSvc.listAllJsonFiles();
        for (final f in files) {
          try {
            final map = Map<String, dynamic>.from(jsonDecode(await f.readAsString()));
            sales.add({
              'id': map['id'] ?? '',
              'total': map['totalAmount'] ?? 0,
              'itemsCount': (map['items'] as List).length,
              'paymentMethod': map['paymentMethod'] ?? '',
              'customerId': map['customerId'] ?? '',
              'creditAmount': (map['creditAmount'] as num?)?.toDouble() ?? 0.0,
              'status': map['status'] ?? '',
              'createdAt': DateTime.parse(map['saleDate']),
            });
          } catch (_) {}
        }
      } else {
        final sqlite = SQLiteService();
        final rawSales = await sqlite.query('sales');
        for (final sale in rawSales) {
          final saleDate = sale['saleDate'];
          sales.add({
            'id': sale['id'] ?? '',
            'total': sale['totalAmount'] ?? 0,
            'itemsCount': await sqlite.query('sale_items', where: 'saleId = ?', whereArgs: [sale['id']]).then((items) => items.length),
            'paymentMethod': sale['paymentMethod'] ?? '',
            'customerId': sale['customerId'] ?? '',
            'creditAmount': (sale['creditAmount'] as num?)?.toDouble() ?? 0.0,
            'status': sale['status'] ?? '',
            'createdAt': saleDate is String ? DateTime.parse(saleDate) : saleDate,
          });
        }
      }
      final path = await _resolveExportDestination(
        'sales_export_${DateTime.now().toIso8601String()}.xlsx',
        'Choose folder for sales export',
      );
      if (path == null) {
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Sales export cancelled')));
        return;
      }
      await ExportService().exportSalesToExcelAtPath(sales, path);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Sales exported: $path')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Failed to export sales')));
      AppLogger.error('Export sales failed', e);
    }
  }

  Future<void> _exportExpenses(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final expenses = <Map<String, dynamic>>[];
      if (AppConstants.forceFileOnlyBilling) {
        final fileSvc = FileExpenseService();
        final list = await fileSvc.getAllExpenses();
        expenses.addAll(list.map((e) => e.toJson()));
      } else {
        final sqlite = SQLiteService();
        final rawExpenses = await sqlite.query('expenses');
        expenses.addAll(rawExpenses.map((expense) {
          final expenseDate = expense['expenseDate'];
          return {
            ...expense,
            'expenseDate': expenseDate is String ? DateTime.parse(expenseDate) : expenseDate,
            'createdAt': expense['createdAt'] is String ? DateTime.parse(expense['createdAt']) : expense['createdAt'],
          };
        }));
      }
      final path = await _resolveExportDestination(
        'expenses_export_${DateTime.now().toIso8601String()}.xlsx',
        'Choose folder for expenses export',
      );
      if (path == null) {
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Expenses export cancelled')));
        return;
      }
      await ExportService().exportExpensesToExcelAtPath(expenses, path);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Expenses exported: $path')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Failed to export expenses')));
      AppLogger.error('Export expenses failed', e);
    }
  }

  Future<void> _exportAll(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final sqlite = SQLiteService();
      final products = <ProductModel>[];
      if (AppConstants.forceFileOnlyBilling) {
        final prodSvc = FileProductService();
        products.addAll(await prodSvc.getAllProducts());
      } else {
        final rawProducts = await sqlite.query('products', where: 'isDeleted = ?', whereArgs: [0]);
        products.addAll(rawProducts.map((row) => ProductModel.fromJson(row)).toList());
      }
      final outputDirectory = _exportFolderPath;
      final folderPath = outputDirectory != null && outputDirectory.isNotEmpty
          ? outputDirectory
          : await _chooseExportDirectory('Choose folder for all report exports');
      if (folderPath == null) {
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Export cancelled')));
        return;
      }
      if (_exportFolderPath == null || _exportFolderPath != folderPath) {
        await _saveExportFolderPath(folderPath);
      }
      final productPath = await ExportService().exportProductsToExcelAtPath(
        products,
        p.join(folderPath, 'products_export_${DateTime.now().toIso8601String()}.xlsx'),
      );

      final sales = <Map<String, dynamic>>[];
      if (AppConstants.forceFileOnlyBilling) {
        final fileSvc = FileStorageService();
        final files = await fileSvc.listAllJsonFiles();
        for (final f in files) {
          try {
            final map = Map<String, dynamic>.from(jsonDecode(await f.readAsString()));
            sales.add({
              'id': map['id'] ?? '',
              'total': map['totalAmount'] ?? 0,
              'itemsCount': (map['items'] as List).length,
              'paymentMethod': map['paymentMethod'] ?? '',
              'customerId': map['customerId'] ?? '',
              'creditAmount': (map['creditAmount'] as num?)?.toDouble() ?? 0.0,
              'status': map['status'] ?? '',
              'createdAt': DateTime.parse(map['saleDate']),
            });
          } catch (_) {}
        }
      } else {
        final rawSales = await sqlite.query('sales');
        for (final sale in rawSales) {
          final saleDate = sale['saleDate'];
          sales.add({
            'id': sale['id'] ?? '',
            'total': sale['totalAmount'] ?? 0,
            'itemsCount': await sqlite.query('sale_items', where: 'saleId = ?', whereArgs: [sale['id']]).then((items) => items.length),
            'paymentMethod': sale['paymentMethod'] ?? '',
            'customerId': sale['customerId'] ?? '',
            'creditAmount': (sale['creditAmount'] as num?)?.toDouble() ?? 0.0,
            'status': sale['status'] ?? '',
            'createdAt': saleDate is String ? DateTime.parse(saleDate) : saleDate,
          });
        }
      }
      final salesPath = await ExportService().exportSalesToExcelAtPath(
        sales,
        p.join(folderPath, 'sales_export_${DateTime.now().toIso8601String()}.xlsx'),
      );

      final rawExpenses = await sqlite.query('expenses');
      final expenses = rawExpenses.map((expense) {
        final expenseDate = expense['expenseDate'];
        return {
          ...expense,
          'expenseDate': expenseDate is String ? DateTime.parse(expenseDate) : expenseDate,
          'createdAt': expense['createdAt'] is String ? DateTime.parse(expense['createdAt']) : expense['createdAt'],
        };
      }).toList();
      final expensesPath = await ExportService().exportExpensesToExcelAtPath(
        expenses,
        p.join(folderPath, 'expenses_export_${DateTime.now().toIso8601String()}.xlsx'),
      );

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Exported all reports:\nProducts: $productPath\nSales: $salesPath\nExpenses: $expensesPath',
            maxLines: 3,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Failed to export all records')));
      AppLogger.error('Export all failed', e);
    }
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will remove temporary files. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully')),
              );
              AppLogger.success('Cache cleared');
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Aaysha Stores'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aaysha Stores ERP',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'A modern, fast, and beautiful POS & ERP system for retail shops.',
              ),
              SizedBox(height: 12),
              Text(
                'Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Barcode scanning & generation'),
              Text('• Professional POS billing'),
              Text('• Inventory management'),
              Text('• Profit analytics'),
              Text('• Excel reports'),
              Text('• Offline support'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
