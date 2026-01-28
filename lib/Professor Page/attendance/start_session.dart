import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/class_session.dart';

class StartSession extends StatefulWidget {
  final List<String> students;
  final VoidCallback onStarted;

  // ✅ add these fields
  final String courseTitle;
  final String classId;
  final String courseCode;
  final String professor;
  final String classCode;
  final String room;
  final String sched;

  const StartSession({
    super.key,
    required this.students,
    required this.onStarted,

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
  State<StartSession> createState() => _StartSessionState();
}


class _StartSessionState extends State<StartSession> {
  bool _loadingEnrolled = true;
  String? _enrolledErr;
  List<Map<String, dynamic>> _enrolled = [];

  Future<void> _loadEnrolledStudents() async {
    setState(() {
      _loadingEnrolled = true;
      _enrolledErr = null;
    });

    try {
      final supabase = Supabase.instance.client;

      final rows = await supabase
          .from('class_enrollments')
          .select('student_id, students(first_name, last_name, student_number, avatar_url)')
          .eq('class_id', widget.classId)
          .order('joined_at', ascending: true);

      final list = (rows as List).map((r) => r as Map<String, dynamic>).toList();

      if (!mounted) return;
      setState(() {
        _enrolled = list;
        _loadingEnrolled = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enrolledErr = e.toString();
        _loadingEnrolled = false;
      });
    }
  }

  final ScrollController _studentScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadEnrolledStudents();
  }

  @override
  void dispose() {
    _studentScrollController.dispose();
    super.dispose();
  }

  bool viewAllList = false;

  List Students = [
    'John Doe',
    'Nicole Margarette',
    'Trisha Lorraine',
    'Arthur Morgan',
    'Clark Kent',
    'Lex Luthor',
    'Lois Lane',
    'Lana Lang',
    'Tony Stark',
  ];

  Widget studentRow({
    required String name,
    String? avatarUrl,
  }) {
    final hasUrl = avatarUrl != null && avatarUrl.trim().isNotEmpty;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: hasUrl
                    ? Image.network(
                  avatarUrl!,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/avatar.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                )
                    : Image.asset(
                  'assets/avatar.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  bool _starting = false;

  Future<void> _confirmStartSession() async { // Start session confirmation
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
            'This will start the class session.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF018832),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Start Session',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (_starting) return;
      setState(() => _starting = true);

      try {
        final supabase = Supabase.instance.client;

        // ✅ create session row
        final inserted = await supabase
            .from('class_sessions')
            .insert({
          'class_id': widget.classId,
          'started_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'started',
        })
            .select('id')
            .single();

        final sessionId = inserted['id'];

        final session = supabase.auth.currentSession;

        if (session == null) {
          throw Exception("Not logged in / session expired.");
        }

        try {
          await supabase.functions.invoke(
            'process_notification',
            body: {
              'reason': 'start_session',
              'class_id': widget.classId,
              'session_id': sessionId,
            },
          );
        } catch (e) {
          // ok lang: queued pa rin, puwede cron/backoff later
          debugPrint('process_notification invoke failed: $e');
        }

        if (!mounted) return;
        widget.onStarted(); // ✅ update UI/dashboard
      } catch (e) {
        if (!mounted) return;
        setState(() => _starting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start session: $e')),
        );
      }
    }
  }

  Widget buildStudentRow(Map<String, dynamic> row) {
    final s = row['students'] as Map<String, dynamic>?;

    final name = s == null
        ? 'Unknown Student'
        : '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim();

    final avatarUrl = s?['avatar_url'] as String?;

    return studentRow(
      name: name.isEmpty ? 'Unknown Student' : name,
      avatarUrl: avatarUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
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

                  // Start Session
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
                          'Start Class Session',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        SizedBox(height: 10,),
                        Center(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFF018832),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _starting ? null : _confirmStartSession,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_starting) ...[
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ] else ...[
                                    const Icon(CupertinoIcons.play, color: Colors.white),
                                    const SizedBox(width: 10),
                                  ],
                                  Text(
                                    _starting ? 'Starting...' : 'Start Class Session',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),

                  SizedBox(height: 30,),

                  // Student in the class
                  Container(
                    width: 350,
                    padding: EdgeInsets.all(20),
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
                        Container(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Students',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold
                                ),
                              ),
                              Text(
                                  _loadingEnrolled ? 'Loading...' : '${_enrolled.length} students',
                                  style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold
                                ),
                              )
                            ],
                          ),
                        ),
                        SizedBox(height: 10,),
                        if (_loadingEnrolled) ...[
                          const SizedBox(height: 20),
                          const Center(child: CircularProgressIndicator()),
                        ] else if (_enrolledErr != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _enrolledErr!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ] else if (_enrolled.isEmpty) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'No enrolled students yet.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ] else ...[
                          !viewAllList
                              ? SizedBox(
                            height: screenHeight * .18,
                            child: Column(
                              children: _enrolled
                                  .take(5)
                                  .map((r) => buildStudentRow(r))
                                  .toList(),
                            ),
                          )
                              : SizedBox(
                            height: screenHeight * .22,
                            child: Scrollbar(
                              controller: _studentScrollController,
                              thumbVisibility: true,
                              radius: const Radius.circular(8),
                              thickness: 4,
                              child: ListView.builder(
                                controller: _studentScrollController,
                                itemCount: _enrolled.length,
                                itemBuilder: (context, index) => buildStudentRow(_enrolled[index]),
                              ),
                            ),
                          ),
                        ],
                        if (!_loadingEnrolled && _enrolled.isNotEmpty)
                        Center(
                          child: TextButton(
                            onPressed: () => setState(() => viewAllList = !viewAllList),
                            child: Text(
                              !viewAllList ? 'View all students' : 'Show less',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF105698)),
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
