import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushManager {
  static bool _listenersReady = false;

  static SupabaseClient get _sb => Supabase.instance.client;
  static FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  static String _platform() => Platform.isAndroid ? 'android' : 'ios';

  static Future<bool> _isPushEnabledInDb({required String userId}) async {
    final row = await _sb
        .from('professors')
        .select('push_enabled')
        .eq('id', userId)
        .maybeSingle();

    return (row?['push_enabled'] as bool?) ?? false;
  }

  static Future<void> initListenersOnce() async {
    if (_listenersReady) return;
    _listenersReady = true;

    FirebaseMessaging.onMessage.listen((message) async {
      // handle foreground notification if needed
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      // handle tap navigation if needed
    });

    // ✅ IMPORTANT: token refresh must respect push_enabled
    _fcm.onTokenRefresh.listen((newToken) async {
      final userId = _sb.auth.currentUser?.id;
      if (userId == null) return;

      final enabled = await _isPushEnabledInDb(userId: userId);

      if (!enabled) {
        // if disabled, ensure no tokens exist
        await _sb.from('device_tokens').delete().eq('user_id', userId);
        return;
      }

      // enabled → upsert refreshed token
      await _sb.from('device_tokens').upsert({
        'user_id': userId,
        'token': newToken,
        'platform': _platform(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,token');
    });
  }

  /// ✅ Call this after LOGIN and when opening Settings
  /// It enforces: professors.push_enabled => device_tokens presence
  static Future<void> syncFromDb() async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null) return;

    final enabled = await _isPushEnabledInDb(userId: userId);

    if (!enabled) {
      await _sb.from('device_tokens').delete().eq('user_id', userId);
      // optional: delete local token too (strict)
      // try { await _fcm.deleteToken(); } catch (_) {}
      return;
    }

    // enabled → ensure permission + token saved
    final perm = await _fcm.requestPermission(alert: true, badge: true, sound: true);
    if (perm.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _fcm.getToken();
    if (token == null || token.isEmpty) return;

    await _sb.from('device_tokens').upsert({
      'user_id': userId,
      'token': token,
      'platform': _platform(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,token');
  }

  /// ✅ Use this for your Settings switch
  /// Source of truth stays in professors.push_enabled
  static Future<void> setEnabled({required bool enabled}) async {
    final userId = _sb.auth.currentUser?.id;
    if (userId == null) throw Exception('No logged in user');

    // 1) Save truth
    await _sb.from('professors').update({'push_enabled': enabled}).eq('id', userId);

    // 2) Enforce token rules
    if (!enabled) {
      await _sb.from('device_tokens').delete().eq('user_id', userId);
      // optional strict local token removal:
      // try { await _fcm.deleteToken(); } catch (_) {}
      return;
    }

    final perm = await _fcm.requestPermission(alert: true, badge: true, sound: true);
    if (perm.authorizationStatus == AuthorizationStatus.denied) {
      // rollback DB if you want:
      // await _sb.from('professors').update({'push_enabled': false}).eq('id', userId);
      throw Exception('Notification permission denied');
    }

    final token = await _fcm.getToken();
    if (token == null || token.isEmpty) throw Exception('No FCM token');

    await _sb.from('device_tokens').upsert({
      'user_id': userId,
      'token': token,
      'platform': _platform(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,token');
  }
}
