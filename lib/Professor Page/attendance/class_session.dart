import 'package:flutter/material.dart';
import 'start_session.dart';
import 'end_session.dart';

class ClassSession extends StatefulWidget {
  final String session;
  final List<String> students;

  final VoidCallback? onSessionStarted; // update dashboard
  final VoidCallback? onSessionEnded;   // update dashboard

  const ClassSession({
    super.key,
    required this.session,
    required this.students,
    this.onSessionStarted,
    this.onSessionEnded,
  });

  @override
  State<ClassSession> createState() => _ClassSessionState();
}

class _ClassSessionState extends State<ClassSession> {
  late String _session; // local state inside ClassSession

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  void _handleStarted() {
    // 1) update dashboard
    widget.onSessionStarted?.call();

    // 2) switch UI to EndSession WITHOUT leaving this page
    setState(() => _session = 'Session Started');
  }

  void _handleEnded() {
    // 1) update dashboard
    widget.onSessionEnded?.call();

    // 2) exit this page and go back to dashboard
    Navigator.pop(context, 'ended');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _session == 'Pending'
            ? StartSession(
          students: widget.students,
          onStarted: _handleStarted,
        )
            : EndSession(
          students: widget.students,
          onEnded: _handleEnded,
        ),
      ),
    );
  }
}
