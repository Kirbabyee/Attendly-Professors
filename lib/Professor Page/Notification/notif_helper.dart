import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final FlutterLocalNotificationsPlugin _localNotifs =
FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // name
  description: 'Used for important notifications.',
  importance: Importance.max,
);

Future<void> initLocalNotifs() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

  await _localNotifs.initialize(initSettings);

  // ✅ create Android channel
  final androidPlugin = _localNotifs
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(_channel);
}

Future<void> showLocalNotif(RemoteMessage message) async {
  final n = message.notification;
  final title = n?.title ?? (message.data['title']?.toString() ?? 'Notification');
  final body  = n?.body  ?? (message.data['body']?.toString() ?? '');

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

  await _localNotifs.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000, // unique id
    title,
    body,
    details,
  );
}
