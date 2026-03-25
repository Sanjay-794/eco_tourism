import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlertNotificationService {
  AlertNotificationService._();

  static const String _androidChannelId = 'trail_alerts';
  static const String _androidChannelName = 'Trail Alerts';
  static const String _androidChannelDescription =
      'Critical weather and trail safety alerts';
  static const String _checkedInTrailsKey = 'checked_in_trails';

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    await _requestPermissions();
    await _initializeLocalNotifications();
    await _initializeForegroundMessageHandling();

    _initialized = true;
  }

  static Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('[ALERTS] Notification permission: ${settings.authorizationStatus}');
  }

  static Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: _androidChannelDescription,
      importance: Importance.max,
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(channel);
  }

  static Future<void> _initializeForegroundMessageHandling() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification == null || android == null) {
        return;
      }

      await _localNotifications.show(
        notification.hashCode,
        notification.title ?? 'Trail Alert',
        notification.body ?? 'Critical condition detected for your checked-in trek.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannelId,
            _androidChannelName,
            channelDescription: _androidChannelDescription,
            importance: Importance.max,
            priority: Priority.high,
            colorized: true,
            color: Color(0xFFD32F2F),
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    });
  }

  static String topicForTrail(String trailId) {
    final normalized = trailId.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
    return 'trail_alert_$normalized';
  }

  static Future<void> subscribeToTrailAlerts(String trailId) async {
    final topic = topicForTrail(trailId);
    await _messaging.subscribeToTopic(topic);
    await _saveCheckedInTrail(trailId);
    debugPrint('[ALERTS] Subscribed to topic: $topic');
  }

  static Future<void> unsubscribeFromTrailAlerts(String trailId) async {
    final topic = topicForTrail(trailId);
    await _messaging.unsubscribeFromTopic(topic);
    await _removeCheckedInTrail(trailId);
    debugPrint('[ALERTS] Unsubscribed from topic: $topic');
  }

  static Future<void> _saveCheckedInTrail(String trailId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_checkedInTrailsKey) ?? <String>[];

    if (!current.contains(trailId)) {
      current.add(trailId);
      await prefs.setStringList(_checkedInTrailsKey, current);
    }
  }

  static Future<List<String>> getCheckedInTrails() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_checkedInTrailsKey) ?? <String>[];
  }

  static Future<void> _removeCheckedInTrail(String trailId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_checkedInTrailsKey) ?? <String>[];
    current.remove(trailId);
    await prefs.setStringList(_checkedInTrailsKey, current);
  }
}
