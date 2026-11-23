import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pocket_plan/core/utils/currency_formatter.dart';
import 'package:pocket_plan/models/budget_model.dart';

class NotificationService {
  late final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  late final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  // Push/local notifications are mobile-only for now (web needs a service
  // worker + VAPID key). Every entry point below is a no-op on web.
  Future<void> initialize() async {
    if (kIsWeb) return;
    // Request permission (iOS requires explicit permission)
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Local notifications setup
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _local.initialize(settings);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showLocalNotification(
        title: message.notification?.title ?? 'PocketPlan',
        body: message.notification?.body ?? '',
      );
    });
  }

  // Get FCM token (save this to Firestore for targeted notifications)
  Future<String?> getToken() async {
    if (kIsWeb) return null;
    return await _fcm.getToken();
  }

  // Show a local notification immediately
  Future<void> showLocalNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    if (kIsWeb) return;
    const androidDetails = AndroidNotificationDetails(
      'pocketplan_alerts',
      'Budget Alerts',
      channelDescription: 'Notifications when budget limits are exceeded',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _local.show(id, title, body, details);
  }

  // Check budget and fire alert if any bucket is exceeded
  Future<void> checkBudgetAlerts(
    BudgetModel budget, {
    String currencyCode = 'MYR',
  }) async {
    if (budget.commitments.isExceeded) {
      await showLocalNotification(
        id: 1,
        title: '⚠️ Essential Needs Budget Exceeded',
        body:
            'You have spent ${CurrencyFormatter.format(budget.commitments.spent, code: currencyCode)} of your ${CurrencyFormatter.format(budget.commitments.limit, code: currencyCode)} essential needs budget.',
      );
    }

    if (budget.spendings.isExceeded) {
      await showLocalNotification(
        id: 2,
        title: '⚠️ Lifestyle Budget Exceeded',
        body:
            'You have spent ${CurrencyFormatter.format(budget.spendings.spent, code: currencyCode)} of your ${CurrencyFormatter.format(budget.spendings.limit, code: currencyCode)} lifestyle budget.',
      );
    }

    // Warn at 80% usage even before exceeding
    if (!budget.spendings.isExceeded && budget.spendings.percentageUsed >= 80) {
      await showLocalNotification(
        id: 3,
        title:
            '📊 Lifestyle Budget at ${budget.spendings.percentageUsed.toStringAsFixed(0)}%',
        body:
            'You are approaching your lifestyle limit. ${CurrencyFormatter.format(budget.spendings.remaining, code: currencyCode)} remaining.',
      );
    }
  }
}
