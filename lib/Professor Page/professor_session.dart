import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfessorSession {
  static final supabase = Supabase.instance.client;

  static Map<String, dynamic>? professor; // cached row
  static Completer<void>? _loading;     // prevents double fetch
  static String? _cachedUserId;         // track which user owns the cache

  static void set(Map<String, dynamic>? data) {
    professor = data;
    _cachedUserId = supabase.auth.currentUser?.id;
  }

  static Future<Map<String, dynamic>?> get({bool force = false}) async {
    final user = supabase.auth.currentUser;
    final uid = user?.id;

    // if user changed, clear cache automatically
    if (_cachedUserId != uid) {
      professor = null;
      _cachedUserId = uid;
      force = true;
    }

    if (!force && professor != null) return professor;

    // if already loading, await it
    if (_loading != null) {
      await _loading!.future;
      return professor;
    }

    _loading = Completer<void>();

    try {
      if (user == null) {
        professor = null;
        _loading!.complete();
        _loading = null;
        return null;
      }

      final data = await supabase
          .from('professors')
          .select('*')
          .eq('id', user.id) // keep your column name
          .maybeSingle();

      professor = data;
      _loading!.complete();
      _loading = null;
      return professor;
    } catch (e) {
      _loading!.complete();
      _loading = null;
      rethrow;
    }
  }

  static void clear() {
    professor = null;
    _cachedUserId = null;
  }
}
