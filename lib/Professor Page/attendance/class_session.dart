import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'start_session.dart';
import 'end_session.dart';

class ClassSession extends StatefulWidget {
  final String session;
  final List<String> students;

  const ClassSession({
    super.key,
    required this.session,
    required this.students,
  });

  @override
  State<ClassSession> createState() => _ClassSessionState();
}

class _ClassSessionState extends State<ClassSession> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: widget.session == 'Pending'
            ? StartSession(students: widget.students)
            : EndSession(students: widget.students),
      ),
    );
  }
}
