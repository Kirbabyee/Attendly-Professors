import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'professor_session.dart';

import '../main.dart'; // LandingPage
import 'mainshell.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late final StreamSubscription<AuthState> _sub;

  bool _loading = true;
  bool _routing = false;

  final Duration _minSplashDuration = const Duration(milliseconds: 2500);
  late final DateTime _start;

  late final AnimationController _logoCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
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

      if (session != null) {
        ProfessorSession.clear();
        try {
          await ProfessorSession.get(force: true);
        } catch (_) {}
      } else {
        ProfessorSession.clear();
      }

      await _finishSplash();
      if (!mounted) return;

      await _go(session);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = supabase.auth.currentSession;

      if (session != null) {
        ProfessorSession.clear();
        try {
          await ProfessorSession.get(force: true);
        } catch (_) {}
      } else {
        ProfessorSession.clear();
      }

      await _finishSplash();
      if (!mounted) return;

      await _go(session);
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

  Future<void> _go(Session? session) async {
    if (_routing) return;
    _routing = true;

    try {
      // ✅ logged out → landing
      if (session == null) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LandingPage()),
              (route) => false,
        );
        return;
      }

      // ✅ logged in: check professor row
      int terms = 0;
      bool twoFA = false;
      String emailToUse = session.user.email?.trim().toLowerCase() ?? "";

      try {
        final row = await supabase
            .from('professors')
            .select('terms_conditions, two_fa_enabled, email, status, archived')
            .eq('id', session.user.id)
            .maybeSingle();

        final rawTerms = row?['terms_conditions'];
        terms = (rawTerms is num) ? rawTerms.toInt() : int.tryParse('$rawTerms') ?? 0;

        twoFA = row?['two_fa_enabled'] == true;

        final emailReal = (row?['email'] ?? '').toString().trim().toLowerCase();
        if (emailReal.isNotEmpty) emailToUse = emailReal;

        // ✅ if no professor row, or archived/inactive → logout
        final isArchived = (row?['archived'] == true);
        final status = (row?['status'] ?? '').toString().trim().toLowerCase();

        if (row == null || isArchived || status == 'inactive') {
          await supabase.auth.signOut();
          ProfessorSession.clear();

          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LandingPage()),
                (route) => false,
          );
          return;
        }

      } catch (_) {
        // safe default: not accepted / block
        terms = 0;
        twoFA = false;
      }

      // ✅ terms not accepted → sign out
      if (terms != 1) {
        await supabase.auth.signOut();
        ProfessorSession.clear();

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LandingPage()),
              (route) => false,
        );
        return;
      }

      // ✅ 2FA enabled: must be verified in twofa_otps
      if (twoFA) {
        bool verified = false;

        try {
          if (emailToUse.isEmpty) {
            verified = false;
          } else {
            final otpRow = await supabase
                .from('twofa_otps')
                .select('verified, expires_at')
                .eq('email', emailToUse)
                .maybeSingle();

            final v = otpRow?['verified'];
            verified = (v == true);

            // optional extra safety: if expired, treat as not verified
            final expRaw = otpRow?['expires_at'];
            if (verified && expRaw != null) {
              final exp = DateTime.tryParse(expRaw.toString());
              if (exp != null && exp.isBefore(DateTime.now().toUtc())) {
                verified = false;
              }
            }
          }
        } catch (_) {
          verified = false;
        }

        if (!verified) {
          await supabase.auth.signOut();
          ProfessorSession.clear();

          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LandingPage()),
                (route) => false,
          );
          return;
        }
      }

      // ✅ accepted (+ verified if 2FA) → mainshell
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Mainshell()),
            (route) => false,
      );
    } finally {
      _routing = false;
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _logoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _routing) {
      return Scaffold(
        backgroundColor: const Color(0xFFEAF5FB),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Image.asset('assets/logo.png', width: 180),
              ),
              const SizedBox(height: 18),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 12),
              Text(
                _routing ? 'Checking your account...' : 'Loading Attendly...',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return const Scaffold(
      backgroundColor: Color(0xFFEAF5FB),
      body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
