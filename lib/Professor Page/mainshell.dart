import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../widgets/navbar.dart';
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
  late int _index; // Home selected by default (match your navbar order)

  final List<Widget> _pages = const [
    Dashboard(),
    History(),
    Settings()
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.width;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: AttendlyNavBar(
        screenHeight: screenHeight,
        currentIndex: _index,
        onTap: (i) {
          setState(() {
            _index = i;
          });
        },
      ),
    );
  }
}
