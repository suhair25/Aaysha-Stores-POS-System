import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:aaysha_stores/config/constants.dart';
import 'package:aaysha_stores/utils/logger.dart';

/// Service for handling notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  late FlutterLocalNotificationsPlugin _notificationsPlugin;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  /// Initialize notification service
  Future<void> initialize() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    // Android initialization
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // General initialization
    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
    AppLogger.success('Notification service initialized');
  }

  /// Show simple notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'aaysha_channel_id',
        'Aaysha Stores',
        channelDescription: 'Notifications for Aaysha Stores',
        importance: Importance.high,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(id, title, body, details, payload: payload);
      AppLogger.info('Notification shown: $title');
    } catch (e) {
      AppLogger.error('Error showing notification', e);
    }
  }

  /// Show scheduled notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'aaysha_channel_id',
        'Aaysha Stores',
        channelDescription: 'Notifications for Aaysha Stores',
        importance: Importance.high,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        payload: payload,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        // ignore: deprecated_member_use
        androidAllowWhileIdle: true,
      );

      AppLogger.success('Notification scheduled: $title');
    } catch (e) {
      AppLogger.error('Error scheduling notification', e);
    }
  }

  /// Cancel notification
  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      AppLogger.info('Notification cancelled: $id');
    } catch (e) {
      AppLogger.error('Error cancelling notification', e);
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      AppLogger.success('All notifications cancelled');
    } catch (e) {
      AppLogger.error('Error cancelling all notifications', e);
    }
  }

  // ============================================
  // Aaysha Stores Specific Notifications
  // ============================================

  /// Notify low stock
  Future<void> notifyLowStock(String productName, int currentStock) async {
    await showNotification(
      id: productName.hashCode,
      title: '⚠️ Low Stock Alert',
      body: '$productName has only $currentStock units left',
      payload: 'low_stock:$productName',
    );
  }

  /// Notify out of stock
  Future<void> notifyOutOfStock(String productName) async {
    await showNotification(
      id: productName.hashCode + 1000,
      title: '❌ Out of Stock',
      body: '$productName is out of stock',
      payload: 'out_of_stock:$productName',
    );
  }

  /// Notify expiring products
  Future<void> notifyExpiringProduct(String productName, DateTime expiryDate) async {
    final days = expiryDate.difference(DateTime.now()).inDays;
    await showNotification(
      id: productName.hashCode + 2000,
      title: '📦 Product Expiring Soon',
      body: '$productName expires in $days days (${expiryDate.toString().split(' ')[0]})',
      payload: 'expiring:$productName',
    );
  }

  /// Notify daily summary reminder
  Future<void> notifyDailySummaryReminder({
    required double totalSales,
    required double totalProfit,
    required int billCount,
  }) async {
    await showNotification(
      id: 9999,
      title: '📊 Daily Summary',
      body: 'Sales: ${AppConstants.currencySymbol} ${totalSales.toInt()} | Profit: ${AppConstants.currencySymbol} ${totalProfit.toInt()} | Bills: $billCount',
      payload: 'daily_summary',
    );
  }

  /// Schedule daily summary reminder for 10:00 PM
  Future<void> scheduleDailySummaryReminder() async {
    try {
      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, 22, 0);

      // If time has passed, schedule for next day
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _notificationsPlugin.zonedSchedule(
        9998,
        '📊 Daily Summary Ready',
        'Check today\'s sales and profit report',
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'aaysha_channel_id',
            'Aaysha Stores',
            channelDescription: 'Notifications for Aaysha Stores',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: 'daily_reminder',
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        // ignore: deprecated_member_use
        androidAllowWhileIdle: true,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      AppLogger.success('Daily summary reminder scheduled for 10:00 PM');
    } catch (e) {
      AppLogger.error('Error scheduling daily summary reminder', e);
    }
  }

  /// Notify sale completion
  Future<void> notifySaleCompleted(int billNumber, double totalAmount) async {
    await showNotification(
      id: billNumber,
      title: '✅ Sale Completed',
      body: 'Bill #$billNumber - ${AppConstants.currencySymbol} ${totalAmount.toStringAsFixed(2)}',
      payload: 'sale_completed:$billNumber',
    );
  }
}
