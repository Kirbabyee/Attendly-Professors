import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:professor/Professor%20Page/Help/help.dart';

import '../widgets/navbar.dart';
import 'Dashboard/notification_ui.dart';
import 'Settings/settings.dart';
import 'Dashboard/dashboard.dart';
import 'History/history.dart';

class Mainshell extends StatefulWidget {
  final int initialIndex;

  const Mainshell({
    super.key,
    this.initialIndex = 0, // default tab
  });

  @override
  State<Mainshell> createState() => _MainshellState();
}

class _MainshellState extends State<Mainshell> {
  final GlobalKey<ScaffoldState> _shellKey = GlobalKey<ScaffoldState>();

  late int _index;

  bool _unRead = true; // ✅ ito ang source of truth

  late final List<Widget> _pages;

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
  }

  void openNotifications() {
    _shellKey.currentState?.openEndDrawer();
  }

  void _handleUnreadChanged(bool v) {
    if (!mounted) return;
    setState(() => _unRead = v);

    // ✅ IMPORTANT: update dashboard instance too
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
        onUnreadChanged: _handleUnreadChanged, // ✅ eto yung update
      ),
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: AttendlyNavBar(
        screenHeight: MediaQuery.of(context).size.width,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

