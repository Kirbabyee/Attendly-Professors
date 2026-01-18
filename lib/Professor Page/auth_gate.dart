import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'Notifications/push_manager.dart';
import 'professor_session.dart';

import '../main.dart'; // LandingPage
import 'mainshell.dart';
import 'login.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late final StreamSubscription<AuthState> _sub;

  bool _loading = true;
  final Duration _minSplashDuration = const Duration(milliseconds: 2500);
  late final DateTime _start;

  late final AnimationController _logoCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _initAfterLogin();
    _start = DateTime.now();

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.96, end: 1.03).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeInOut),
    );

    _sub = supabase.auth.onAuthStateChange.listen((data) async {
      if (!mounted) return;

      final session = data.session;

      // ✅ preload student when logged in
      if (session != null) {
        ProfessorSession.clear(); // important when switching accounts
        try {
          await ProfessorSession.get(force: true);
        } catch (_) {}
      } else {
        ProfessorSession.clear();
      }

      await _finishSplash();
      if (!mounted) return;

      _go(session);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = supabase.auth.currentSession;

      // ✅ preload student when app starts + already logged in
      if (session != null) {
        ProfessorSession.clear(); // safety
        try {
          await ProfessorSession.get(force: true);
        } catch (_) {}
      } else {
        ProfessorSession.clear();
      }

      await _finishSplash();
      if (!mounted) return;

      _go(session);
    });
  }

  Future<void> _finishSplash() async {
    final elapsed = DateTime.now().difference(_start);
    final remaining = _minSplashDuration - elapsed;
    if (!remaining.isNegative && remaining != Duration.zero) {
      await Future.delayed(remaining);
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _go(Session? session) {
    // if logged in -> mainshell
    if (session != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Mainshell()),
            (route) => false,
      );
      return;
    }

    // logged out -> LandingPage (or Login if gusto mo)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingPage()),
          (route) => false,
    );
  }

  @override
  void dispose() {
    _sub.cancel();
    _logoCtrl.dispose();
    super.dispose();
  }
  bool _pushReady = false;
  Future<void> _initAfterLogin() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (_pushReady) return;

    await PushManager.initListenersOnce();
    _pushReady = true;
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFEAF5FB),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Image.asset(
                  'assets/logo.png',
                  width: 180,
                ),
              ),
              const SizedBox(height: 18),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 12),
              const Text(
                'Loading Attendly...',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
