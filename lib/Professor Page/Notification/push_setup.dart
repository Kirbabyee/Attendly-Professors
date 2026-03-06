import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // required: init Firebase in background isolate
  await Firebase.initializeApp();
  // optional: do lightweight work only
}

class PushManager {
  static bool _inited = false;

  static Future<void> init() async {
    if (_inited) return;
    _inited = true;

    // Background handler (must be top-level)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Local notif init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _local.initialize(initSettings);

    // iOS permission + Android 13 permission
    await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );

    // For iOS foreground presentation
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    // Foreground messages → show local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      final n = msg.notification;
      if (n == null) return;

      const androidDetails = AndroidNotificationDetails(
        'default_channel',
        'General',
        importance: Importance.max,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

      await _local.show(
        n.hashCode,
        n.title,
        n.body,
        details,
        payload: jsonEncode(msg.data),
      );
    });

    // When app opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      // TODO: navigate based on msg.data
    });
  }

  static Future<String?> getToken() => FirebaseMessaging.instance.getToken();
}
