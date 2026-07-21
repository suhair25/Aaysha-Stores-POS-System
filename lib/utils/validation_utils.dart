import 'package:aaysha_stores/config/constants.dart';

/// Utility functions for validation
class ValidationUtils {
  /// Validate email
  static bool isValidEmail(String email) {
    final regex = RegExp(RegexPatterns.email);
    return regex.hasMatch(email);
  }

  /// Validate phone number (10 digits)
  static bool isValidPhone(String phone) {
    final regex = RegExp(RegexPatterns.phone);
    return regex.hasMatch(phone);
  }

  /// Validate barcode (8-13 digits)
  static bool isValidBarcode(String barcode) {
    final regex = RegExp(RegexPatterns.barcode);
    return regex.hasMatch(barcode);
  }

  /// Validate currency amount
  static bool isValidCurrencyAmount(String amount) {
    final regex = RegExp(RegexPatterns.currencyAmount);
    return regex.hasMatch(amount);
  }

  /// Validate password (minimum 6 characters)
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  /// Validate not empty
  static bool isNotEmpty(String value) {
    return value.trim().isNotEmpty;
  }

  /// Validate minimum length
  static bool hasMinLength(String value, int minLength) {
    return value.length >= minLength;
  }

  /// Validate maximum length
  static bool hasMaxLength(String value, int maxLength) {
    return value.length <= maxLength;
  }

  /// Validate product name (alphanumeric and spaces)
  static bool isValidProductName(String name) {
    final regex = RegExp(RegexPatterns.alphanumeric);
    return regex.hasMatch(name) && name.isNotEmpty;
  }

  /// Get email error message
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!isValidEmail(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// Get password error message
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (!isValidPassword(value)) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Get phone error message
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone is required';
    }
    if (!isValidPhone(value)) {
      return 'Please enter a valid 10-digit phone number';
    }
    return null;
  }

  /// Get barcode error message
  static String? validateBarcode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Barcode is required';
    }
    if (!isValidBarcode(value)) {
      return 'Barcode must be 8-13 digits';
    }
    return null;
  }

  /// Get amount error message
  static String? validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Amount is required';
    }
    if (!isValidCurrencyAmount(value)) {
      return 'Please enter a valid amount';
    }
    if (double.parse(value) <= 0) {
      return 'Amount must be greater than 0';
    }
    return null;
  }

  /// Get generic field error message
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
}
