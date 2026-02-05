import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import 'package:professor/Professor%20Page/Help/help.dart';
import 'package:professor/Professor%20Page/wifi_guard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/navbar.dart';
import 'Dashboard/notification_ui.dart';
import 'Settings/settings.dart';
import 'Dashboard/dashboard.dart';
import 'History/history.dart';

class Mainshell extends StatefulWidget {
  final int initialIndex;

  const Mainshell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<Mainshell> createState() => _MainshellState();
}

class _MainshellState extends State<Mainshell> {
  final GlobalKey<ScaffoldState> _shellKey = GlobalKey<ScaffoldState>();

  late int _index;
  bool _unRead = true;

  final supabase = Supabase.instance.client;
  RealtimeChannel? _locationSub;

  late final List<Widget> _pages;

  // ✅ offline banner state
  bool _offline = false;
  StreamSubscription? _connSub;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;

    _pages = [
      Dashboard(
        unRead: _unRead,
        onOpenNotifications: openNotifications,
      ),
      const History(),
      const Help(),
      const Settings(),
    ];

    _startInternetWatcher();
    _startLocationWatcher();
  }

  void _startLocationWatcher() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _locationSub = supabase
        .channel('public:professors_check') // Identifier
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'professors', // Dapat tumugma sa table sa DB
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: userId,
      ),
      callback: (payload) {
        final newLocation = payload.newRecord['location']?.toString().toUpperCase();

        // ✅ Kapag lumabas ng classroom, automatic redirect sa WifiGuard
        if (newLocation == 'GATE' || newLocation == 'NULL') {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const WifiGuard()),
                  (route) => false,
            );
          }
        }
      },
    )
        .subscribe();
  }

  Future<void> _startInternetWatcher() async {
    await _updateOfflineStatus();
    _connSub = Connectivity().onConnectivityChanged.listen((_) async {
      await _updateOfflineStatus();
    });
  }

  Future<void> _updateOfflineStatus() async {
    final conn = await Connectivity().checkConnectivity();

    if (conn == ConnectivityResult.none) {
      if (!mounted) return;
      setState(() => _offline = true);
      return;
    }

    final hasInternet = await InternetConnection().hasInternetAccess;

    if (!mounted) return;
    setState(() => _offline = !hasInternet);
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _locationSub?.unsubscribe();
    super.dispose();
  }

  void openNotifications() {
    _shellKey.currentState?.openEndDrawer();
  }

  void _handleUnreadChanged(bool v) {
    if (!mounted) return;
    setState(() => _unRead = v);

    _pages[0] = Dashboard(
      unRead: _unRead,
      onOpenNotifications: openNotifications,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _shellKey,

      endDrawer: NotificationsDrawer(
        unRead: _unRead,
        onUnreadChanged: _handleUnreadChanged,
      ),

      // ✅ overlay banner (no layout shift)
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: _pages,
          ),

          Positioned(
            left: 12,
            right: 12,
            top: MediaQuery.of(context).padding.top + 10,
            child: IgnorePointer(
              ignoring: true, // di haharang sa taps/scroll
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                offset: _offline ? Offset.zero : const Offset(0, -0.35),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _offline ? 1 : 0,
                  child: const _NoInternetBanner(),
                ),
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: AttendlyNavBar(
        screenHeight: MediaQuery.of(context).size.width,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _NoInternetBanner extends StatelessWidget {
  const _NoInternetBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF4D4D), Color(0xFFD81B60)],
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No internet connection',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
