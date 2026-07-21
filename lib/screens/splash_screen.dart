import 'package:flutter/material.dart';
import 'package:aaysha_stores/config/app_theme.dart';
import 'package:aaysha_stores/config/constants.dart';
import 'package:provider/provider.dart';
import 'package:aaysha_stores/providers/auth_provider.dart';
import 'package:aaysha_stores/enums/user_role.dart';
import 'package:aaysha_stores/screens/role_selection/role_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize app services and auth, then route based on role
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.initialize();

    // Short delay for splash feel
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    if (authProvider.user != null) {
      final role = authProvider.user!.role;
      if (role == UserRole.cashier) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.billing);
        return;
      }
      // Owner/Admin and default route
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
      return;
    }

    // Not authenticated — show role selector (Owner / Cashier)
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront_outlined, size: 96, color: AppColors.white),
            const SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Modern POS and inventory management for your shop',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.9),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: AppColors.white),
          ],
        ),
      ),
    );
  }
}
