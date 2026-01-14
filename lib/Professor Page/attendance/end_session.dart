import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../widgets/class_session.dart';

class EndSession extends StatefulWidget {
  final List<String> students;
  final VoidCallback onEnded;

  // ✅ add these fields
  final String courseTitle;
  final String classId;
  final String courseCode;
  final String professor;
  final String classCode;
  final String room;
  final String sched;

  const EndSession({
    super.key,
    required this.students,
    required this.onEnded,

    // ✅ required para di null
    required this.courseTitle,
    required this.classId,
    required this.courseCode,
    required this.professor,
    required this.classCode,
    required this.room,
    required this.sched,
  });

  @override
  State<EndSession> createState() => _EndSessionState();
}

class _EndSessionState extends State<EndSession> {
  DateTime? _startedAt;
  bool _loadingSessionInfo = true;

  @override
  void initState() {
    super.initState();
    _loadSessionInfo();
  }

  Future<void> _loadSessionInfo() async {
    try {
      final supabase = Supabase.instance.client;

      // ✅ kunin latest started session (or last session)
      final rows = await supabase
          .from('class_sessions')
          .select('started_at, status')
          .eq('class_id', widget.classId)
          .order('started_at', ascending: false)
          .limit(1);

      if (rows is List && rows.isNotEmpty) {
        final startedAtStr = rows.first['started_at'] as String?;
        if (startedAtStr != null) {
          _startedAt = DateTime.parse(startedAtStr);
        }
      }
    } catch (_) {
      // ignore, fallback sa UI
    } finally {
      if (!mounted) return;
      setState(() => _loadingSessionInfo = false);
    }
  }

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool viewAllList = false;

  Future<void> _confirmEndSession() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text(
            'Are you sure?',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'This will end the current class session.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadiusGeometry.circular(8)
                )
              ),
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.black
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB60202),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadiusGeometry.circular(8)
                )
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
               'End Session',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (_ending) return;
      setState(() => _ending = true);

      try {
        final supabase = Supabase.instance.client;

        // ✅ end the active session for this class
        await supabase
            .from('class_sessions')
            .update({
          'status': 'ended',
          'ended_at': DateTime.now().toIso8601String(),
        })
            .eq('class_id', widget.classId)
            .eq('status', 'started');

        if (!mounted) return;
        widget.onEnded(); // ✅ pop back via ClassSession
      } catch (e) {
        if (!mounted) return;
        setState(() => _ending = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to end session: $e')),
        );
      }
    }
  }

  Widget student(String studentName) {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                child: Row(
                  children: [
                    Image.asset(
                        width: 20,
                        'assets/avatar.png'
                    ),
                    SizedBox(width: 10,),
                    Text(
                      studentName,
                      style: TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                child: Row(
                  children: [
                    Icon(CupertinoIcons.check_mark_circled, color: Color(0xFF018832), size: 15,),
                    Text('Present', style: TextStyle(color: Color(0xFF018832), fontSize: 12),)
                  ],
                ),
              )
            ],
          ),
        ),
        SizedBox(height: 10,),
      ],
    );
  }

  bool _ending = false;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.width;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AttendlyBlueHeader(
                    onBack: false,
                    courseTitle: widget.courseTitle,
                    courseCode: widget.courseCode,
                    professor: widget.professor,
                    icon: CupertinoIcons.book,
                    iconColor: const Color(0xFFFBD600),
                  ),

                  const SizedBox(height: 20),

                  ClassInfo(
                    classCode: widget.classCode,
                    room: widget.room,
                    sched: widget.sched,
                  ),
                  const SizedBox(height: 10),

                  // Back Button
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 30),
                    child: Row(
                      children: [
                        IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: Icon(CupertinoIcons.arrow_left)),
                        Text('Back')
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // End Session
                  Container(
                    padding: EdgeInsets.all(20),
                    width: 350,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadiusGeometry.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End Class Session',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        SizedBox(height: 10,),
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Color(0x509BC9F5),
                            borderRadius: BorderRadiusGeometry.circular(8)
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.clock,
                                size: 20,
                                color: Color(0xFF043B6F)
                              ),
                              SizedBox(width: 5,),
                              Text(
                                _loadingSessionInfo
                                    ? 'Loading session time...'
                                    : _startedAt == null
                                    ? 'Session Started'
                                    : 'Session Started at ${DateFormat('h:mm a').format(_startedAt!.toUtc())}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF043B6F),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10,),
                        Center(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFB60202),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _ending ? null : _confirmEndSession,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_ending) ...[
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Text(
                                    _ending ? 'Ending...' : 'End Class Session',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      ],
                    ),
                  ),

                  SizedBox(height: 10,),

                  // Attendance
                  Container(
                    width: 350,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadiusGeometry.circular(8),
                            color: Colors.white,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 2,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '4',
                                style: TextStyle(
                                  fontSize: 30
                                ),
                              ),
                              Text(
                                'Present',
                                style: TextStyle(
                                  fontSize: 12
                                ),
                              )
                            ],
                          ),
                        ),
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadiusGeometry.circular(8),
                            color: Colors.white,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 2,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '39',
                                style: TextStyle(
                                    fontSize: 28
                                ),
                              ),
                              Text(
                                'Pending',
                                style: TextStyle(
                                    fontSize: 12
                                ),
                              )
                            ],
                          ),
                        ),
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadiusGeometry.circular(8),
                            color: Colors.white,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 2,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '43',
                                style: TextStyle(
                                    fontSize: 30
                                ),
                              ),
                              Text(
                                'Total',
                                style: TextStyle(
                                    fontSize: 12
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20,),

                  // Attendance Log
                  Container(
                    width: 350,
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadiusGeometry.circular(8)
                    ),
                    child: Column(
                      children: [
                        Container(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Attendance Log'),
                              Container(
                                child: Row(
                                  children: [
                                    Icon(Icons.people_alt_outlined),
                                    Text('${widget.students.length}/39'),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                        Divider(
                          color: Colors.black,
                        ),
                        SizedBox(
                          height: 110,
                          child: Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true, // always show scrollbar
                            radius: const Radius.circular(8),
                            thickness: 4,
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: widget.students.length,
                              itemBuilder: (context, index) {
                                return student(widget.students[index]);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
