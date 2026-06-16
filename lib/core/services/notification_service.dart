import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pocket_plan/models/budget_model.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
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
      _showLocalNotification(
        title: message.notification?.title ?? 'PocketPlan',
        body: message.notification?.body ?? '',
      );
    });
  }

  // Get FCM token (save this to Firestore for targeted notifications)
  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  // Show a local notification immediately
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
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
  Future<void> checkBudgetAlerts(BudgetModel budget) async {
    if (budget.commitments.isExceeded) {
      await _showLocalNotification(
        id: 1,
        title: '⚠️ Commitments Budget Exceeded',
        body:
            'You have spent RM${budget.commitments.spent.toStringAsFixed(2)} of your RM${budget.commitments.limit.toStringAsFixed(2)} commitments budget.',
      );
    }

    if (budget.spendings.isExceeded) {
      await _showLocalNotification(
        id: 2,
        title: '⚠️ Spending Budget Exceeded',
        body:
            'You have spent RM${budget.spendings.spent.toStringAsFixed(2)} of your RM${budget.spendings.limit.toStringAsFixed(2)} spending budget.',
      );
    }

    // Warn at 80% usage even before exceeding
    if (!budget.spendings.isExceeded && budget.spendings.percentageUsed >= 80) {
      await _showLocalNotification(
        id: 3,
        title:
            '📊 Spending Budget at ${budget.spendings.percentageUsed.toStringAsFixed(0)}%',
        body:
            'You are approaching your spending limit. RM${budget.spendings.remaining.toStringAsFixed(2)} remaining.',
      );
    }
  }
}
