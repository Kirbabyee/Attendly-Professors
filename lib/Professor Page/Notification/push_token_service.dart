import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushTokenService {
  final SupabaseClient supabase;
  PushTokenService(this.supabase);

  String get _platform => Platform.isIOS ? 'ios' : 'android';
  Future<String?> _getToken() => FirebaseMessaging.instance.getToken();

  /// ✅ delete ALL old tokens then insert current token
  Future<void> replaceTokenForUser({required String professorId}) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) return;

    // remove all old tokens for this user
    await supabase.from('device_tokens').delete().eq('user_id', professorId);

    // insert new token
    await supabase.from('device_tokens').insert({
      'user_id': professorId,
      'token': token,
      'platform': _platform,
      'role': 'professor', // ✅ REQUIRED (fix)
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(), // optional but nice
    });
  }

  /// ✅ remove tokens (used for OFF and logout)
  Future<void> removeAllForUser({required String professorId}) async {
    await supabase.from('device_tokens').delete().eq('user_id', professorId);
  }
}
