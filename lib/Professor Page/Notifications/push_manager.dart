import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class PushManager {
  static bool _listenersReady = false;

  static Future<void> initListenersOnce() async {
    if (_listenersReady) return;
    _listenersReady = true;

    FirebaseMessaging.onMessage.listen((message) async {
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      // TODO: navigation
    });

    // ✅ keep DB updated when token refreshes
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final authUserId = Supabase.instance.client.auth.currentUser?.id;
      if (authUserId == null) return;

      final platform = Platform.isAndroid ? 'android' : 'ios';

      await Supabase.instance.client.from('device_tokens').upsert({
        'user_id': authUserId,
        'token': newToken,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,token');
    });
  }

  /// professorId = professors.id (for professors table)
  static Future<void> enableAndRegisterToken({
    required String professorId,
    required bool enabled,
  }) async {
    final supabase = Supabase.instance.client;
    final fcm = FirebaseMessaging.instance;

    final authUserId = supabase.auth.currentUser?.id;
    if (authUserId == null) throw Exception('No logged in user');

    // 1) Save preference in professors table using professors.id
    await supabase.from('professors').update({'push_enabled': enabled}).eq('id', professorId);

    // 2) Disable: remove ONLY this user's tokens
    if (!enabled) {
      await supabase.from('device_tokens').delete().eq('user_id', authUserId);
      // optional: don't deleteToken() (it can cause UNREGISTERED churn)
      return;
    }

    // 3) Enable: request permission, then save token under auth.users.id
    final perm = await fcm.requestPermission(alert: true, badge: true, sound: true);
    if (perm.authorizationStatus == AuthorizationStatus.denied) {
      throw Exception('Notification permission denied');
    }

    final token = await fcm.getToken();
    if (token == null || token.isEmpty) throw Exception('No FCM token');

    final platform = Platform.isAndroid ? 'android' : 'ios';

    await supabase.from('device_tokens').upsert({
      'user_id': authUserId, // ✅ auth.users.id
      'token': token,
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,token');
  }
}
