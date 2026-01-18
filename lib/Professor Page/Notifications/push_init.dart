import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initPush() async {
  final fcm = FirebaseMessaging.instance;

  // permissions
  await fcm.requestPermission(alert: true, badge: true, sound: true);

  // foreground messages
  /*FirebaseMessaging.onMessage.listen((message) async {
    final title = message.notification?.title ?? 'Attendly';
    final body = message.notification?.body ?? '';
    await NotificationsService.show(title: title, body: body);
  });*/

  // token
  final token = await fcm.getToken();
  if (token != null) {
    await Supabase.instance.client.from('device_tokens').upsert({
      'user_id': Supabase.instance.client.auth.currentUser!.id,
      'token': token,
      'platform': 'android',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}