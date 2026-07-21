import 'package:intl/intl.dart';

/// Utility functions for date and time formatting
class DateUtils {
  /// Format date as 'dd MMM yyyy'
  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  /// Format date as 'dd/MM/yyyy'
  static String formatDateSimple(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Format date and time as 'dd MMM yyyy, hh:mm a'
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }

  /// Format date and time as 'dd/MM/yyyy hh:mm'
  static String formatDateTimeSimple(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy hh:mm').format(dateTime);
  }

  /// Format time as 'hh:mm a'
  static String formatTime(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }

  /// Format time as 'hh:mm'
  static String formatTime24(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  /// Format date for display as 'Today', 'Yesterday', or date
  static String formatDateRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      return formatDate(date);
    }
  }

  /// Get date difference in days
  static int getDaysDifference(DateTime date1, DateTime date2) {
    return date2.difference(date1).inDays;
  }

  /// Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day && date.month == now.month && date.year == now.year;
  }

  /// Check if date is yesterday
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.day == yesterday.day && date.month == yesterday.month && date.year == yesterday.year;
  }

  /// Get start of day (00:00:00)
  static DateTime getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Get end of day (23:59:59)
  static DateTime getEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  /// Get start of month
  static DateTime getStartOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Get end of month
  static DateTime getEndOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  /// Get start of week (Monday)
  static DateTime getStartOfWeek(DateTime date) {
    final dayOfWeek = date.weekday; // Monday = 1, Sunday = 7
    return date.subtract(Duration(days: dayOfWeek - 1));
  }

  /// Get end of week (Sunday)
  static DateTime getEndOfWeek(DateTime date) {
    final dayOfWeek = date.weekday;
    return date.add(Duration(days: 7 - dayOfWeek));
  }

  /// Get month name
  static String getMonthName(int month) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  /// Get day name
  static String getDayName(DateTime date) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }
}
