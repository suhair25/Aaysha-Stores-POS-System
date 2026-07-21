import 'package:flutter/material.dart';
import 'package:aaysha_stores/config/constants.dart';

/// Simple role selection screen shown on app start when not authenticated.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Role')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.person),
              label: const Text('Owner'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: () {
                // Owner requires authentication — navigate to login
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_outline),
              label: const Text('Cashier'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: () {
                // Cashier mode — proceed to billing without login
                Navigator.of(context).pushReplacementNamed(AppRoutes.billing);
              },
            ),
          ],
        ),
      ),
    );
  }
}
