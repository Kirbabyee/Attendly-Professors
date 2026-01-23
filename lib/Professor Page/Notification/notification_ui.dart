import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationUI {
  static final FlutterLocalNotificationsPlugin _local =
  FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Attendly notifications',
    importance: Importance.max,
  );

  static bool _inited = false;

  static Future<void> initOnce() async {
    if (_inited) return;
    _inited = true;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _local.initialize(initSettings);

    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);

    // Android 13+ runtime permission (safe kahit di 13)
    await android?.requestNotificationsPermission();
  }

  static Future<void> showFromMessage(RemoteMessage message) async {
    final n = message.notification;

    final title = n?.title ?? (message.data['title']?.toString() ?? 'Attendly');
    final body = n?.body ?? (message.data['body']?.toString() ?? '');

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
