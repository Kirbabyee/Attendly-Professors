import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:professor/Professor%20Page/device_registration.dart';
import 'package:professor/Professor%20Page/wifi_guard.dart';
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
  StreamSubscription? _netSub;
  bool _offline = false;

  Future<bool> _hasInternet() async {
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) return false;
    return InternetConnection().hasInternetAccess;
  }

  Future<T> _timeout<T>(Future<T> f, {Duration d = const Duration(seconds: 10)}) {
    return f.timeout(d);
  }

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

    _hasInternet().then((ok) {
      if (!mounted) return;
      setState(() => _offline = !ok);
    });

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

    _netSub = Connectivity().onConnectivityChanged.listen((_) async {
      final ok = await _hasInternet();
      if (!mounted) return;

      setState(() => _offline = !ok);

      // ✅ auto retry kapag bumalik net at may session
      if (ok && !_routing) {
        final s = supabase.auth.currentSession;
        if (s != null) {
          // try routing again
          await _go(s);
        }
      }
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
      // ✅ 1. Logged out → Landing
      if (session == null) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LandingPage()),
              (route) => false,
        );
        return;
      }

      // ✅ 2. Offline Check
      final okNet = await _hasInternet();
      if (!okNet) {
        if (!mounted) return;
        setState(() => _offline = true);
        return;
      }

      int terms = 0;
      bool twoFA = false;
      String location = "NULL";
      String? macAddress; // Idagdag ito para sa hardware check
      String emailToUse = session.user.email?.trim().toLowerCase() ?? "";

      Map<String, dynamic>? row;
      try {
        row = await _timeout(
          supabase
              .from('professors')
          // ✅ Sinama natin ang 'location' sa select
              .select('terms_conditions, two_fa_enabled, email, status, archived, location, mac_address')
              .eq('id', session.user.id)
              .maybeSingle(),
        );

        if (row == null || row['archived'] == true || row['status'] == 'inactive') {
          try { await _timeout(supabase.auth.signOut()); } catch (_) {}
          ProfessorSession.clear();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LandingPage()),
                (route) => false,
          );
          return;
        }

        // Kunin ang current location
        location = (row['location'] ?? "NULL").toString().toUpperCase();
        macAddress = row['mac_address']; // Kunin ang mac_address

        final rawTerms = row['terms_conditions'];
        terms = (rawTerms is num) ? rawTerms.toInt() : int.tryParse('$rawTerms') ?? 0;
        twoFA = row['two_fa_enabled'] == true;
        final emailReal = (row['email'] ?? '').toString().trim().toLowerCase();
        if (emailReal.isNotEmpty) emailToUse = emailReal;

      } catch (_) {
        if (!mounted) return;
        setState(() => _offline = true);
        return;
      }

      // ✅ 3. Terms Check
      if (terms != 1) {
        try { await _timeout(supabase.auth.signOut()); } catch (_) {}
        ProfessorSession.clear();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LandingPage()),
              (route) => false,
        );
        return;
      }

      if (twoFA) {
        bool verified = false;

        try {
          if (emailToUse.isNotEmpty) {
            final otpRow = await _timeout(
              supabase
                  .from('twofa_otps')
                  .select('verified, expires_at')
                  .eq('email', emailToUse)
                  .maybeSingle(),
            );

            verified = (otpRow?['verified'] == true);

            final expRaw = otpRow?['expires_at'];
            if (verified && expRaw != null) {
              final exp = DateTime.tryParse(expRaw.toString());
              if (exp != null && exp.isBefore(DateTime.now().toUtc())) verified = false;
            }
          }
        } catch (_) {
          if (!mounted) return;
          setState(() => _offline = true);
          return;
        }

        if (!verified) {
          try { await _timeout(supabase.auth.signOut()); } catch (_) {}
          ProfessorSession.clear();

          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LandingPage()),
                (route) => false,
          );
          return;
        }
      }

      if (macAddress == null || macAddress.isEmpty) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          // Palitan ang '/add_device' kung iba ang route name mo
          MaterialPageRoute(builder: (_) => const DeviceRegistration()),
              (route) => false,
        );
        return;
      }

      // ✅ passed checks → mainshell
      if (!mounted) return;

      // ✅ 5. Location-Based Routing (Same as Student)
      if (location == "GATE") {
        Navigator.of(context).pushAndRemoveUntil(
          // Gamitin ang parehong WifiGuard page na ginawa natin
          MaterialPageRoute(builder: (_) => const WifiGuard()),
              (route) => false,
        );
      } else {
        // Kapag CLASSROOM o NULL (default), pasok sa Mainshell
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Mainshell()),
              (route) => false,
        );
      }

    } finally {
      _routing = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _netSub?.cancel();
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
                _offline
                    ? 'No internet connection. Reconnecting...'
                    : (_routing ? 'Checking your account...' : 'Loading Attendly...'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              if (_offline)
                OutlinedButton(
                  onPressed: () async {
                    final ok = await _hasInternet();
                    if (!ok) return;
                    final s = supabase.auth.currentSession;
                    await _go(s);
                  },
                  child: const Text('Retry'),
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
