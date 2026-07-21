import 'package:flutter/material.dart';
import 'package:aaysha_stores/config/app_theme.dart';

class ModernDialog {
  static Future<T?> show<T>(BuildContext context, {required Widget child, String? title, bool dismissible = true}) {
    return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
                ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
