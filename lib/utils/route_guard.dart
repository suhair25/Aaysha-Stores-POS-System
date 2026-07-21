import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aaysha_stores/providers/auth_provider.dart';
import 'package:aaysha_stores/enums/user_role.dart';

/// Widget that restricts access based on user role
class RoleGuard extends StatelessWidget {
  final Widget child;
  final UserRole requiredRole;
  final String? restrictedMessage;

  const RoleGuard({
    super.key,
    required this.child,
    required this.requiredRole,
    this.restrictedMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final userRole = authProvider.user?.role;

        // Allow if user has required role
        if (userRole == requiredRole || userRole == UserRole.owner) {
          return child;
        }

        // Show restricted access screen
        return Scaffold(
          appBar: AppBar(title: const Text('Access Restricted')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 80, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  'Access Denied',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  restrictedMessage ?? 'This feature is only available for Owners/Admins.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
