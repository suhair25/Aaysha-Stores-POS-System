import 'package:aaysha_stores/config/constants.dart';
import 'package:intl/intl.dart';

/// Utility functions for currency formatting and calculations
class CurrencyUtils {
  /// Format currency with symbol and commas
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: AppConstants.currencySymbol,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Format currency without symbol
  static String formatCurrencyNoSymbol(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '',
      decimalDigits: 2,
    ).format(amount);
  }

  /// Format currency compact (e.g., 1.2K for 1200)
  static String formatCurrencyCompact(double amount) {
    if (amount >= 1000000) {
      return '${AppConstants.currencySymbol}${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${AppConstants.currencySymbol}${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return '${AppConstants.currencySymbol}${amount.toStringAsFixed(0)}';
    }
  }

  /// Parse currency string to double
  static double parseCurrency(String value) {
    return double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
  }

  /// Format as percentage
  static String formatPercentage(double value, {int decimals = 2}) {
    return '${value.toStringAsFixed(decimals)}%';
  }

  /// Calculate percentage
  static double calculatePercentage(double value, double total) {
    if (total == 0) return 0;
    return (value / total) * 100;
  }

  /// Calculate discount amount
  static double calculateDiscount(double originalAmount, double discountPercent) {
    return (originalAmount * discountPercent) / 100;
  }

  /// Calculate final amount after discount
  static double calculateFinalAmount(double originalAmount, double discountPercent) {
    final discount = calculateDiscount(originalAmount, discountPercent);
    return originalAmount - discount;
  }

  /// Round to 2 decimal places
  static double roundCurrency(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  /// Format for display with proper alignment
  static String formatCurrencyAligned(double amount) {
    final formatted = formatCurrency(amount);
    return formatted.padLeft(12);
  }

  /// Get currency symbol
  static String getCurrencySymbol() {
    return AppConstants.currencySymbol;
  }

  /// Format as table cell (right-aligned, fixed width)
  static String formatTableCell(double amount) {
    return formatCurrency(amount).padLeft(12);
  }
}
