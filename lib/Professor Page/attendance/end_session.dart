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
  Future<void> _finalizeAttendanceAndLogHistory(String endedAtIso) async {
    final supabase = Supabase.instance.client;

    if (_sessionId == null) throw 'No active session id';

    // safety: make sure enrolled + attendance are loaded
    if (_enrolled.isEmpty) {
      final enrolledRows = await supabase
          .from('class_enrollments')
          .select('student_id, students(first_name,last_name,student_number,avatar_url)')
          .eq('class_id', widget.classId)
          .order('joined_at', ascending: true);

      _enrolled = (enrolledRows as List).cast<Map<String, dynamic>>();
    }

    // 1) get existing attendance rows (with id)
    final existingRows = await supabase
        .from('attendance')
        .select('id, student_id, status')
        .eq('session_id', _sessionId!);

    final existingList = (existingRows as List).cast<Map<String, dynamic>>();

    final existingByStudent = <String, Map<String, dynamic>>{};
    for (final r in existingList) {
      existingByStudent[r['student_id'] as String] = r;
    }

    // 2) compute missing -> absent
    final enrolledIds = _enrolled.map((e) => e['student_id'] as String).toList();
    final missingIds = enrolledIds.where((sid) => !existingByStudent.containsKey(sid)).toList();

    // 3) upsert absents into attendance (so EVERYONE has a row)
    if (missingIds.isNotEmpty) {
      final absentPayload = missingIds.map((sid) => {
        'session_id': _sessionId,
        'student_id': sid,
        'status': 'absent',
        'time_in': null,
        'time_out': null,
      }).toList();

      await supabase.from('attendance').upsert(
        absentPayload,
        onConflict: 'session_id,student_id',
      );
    }

    // ✅ set time_out for all PRESENT/LATE using the session end time
    await supabase
        .from('attendance')
        .update({'time_out': endedAtIso})
        .eq('session_id', _sessionId!)
        .inFilter('status', ['present', 'late'])
        .filter('time_out', 'is', null); // ✅ THIS IS THE CORRECT ONE


    // 4) re-fetch ALL attendance rows now (present/late/absent) with IDs
    final allRows = await supabase
        .from('attendance')
        .select('id, student_id, status')
        .eq('session_id', _sessionId!);

    final allList = (allRows as List).cast<Map<String, dynamic>>();

    // 5) insert history for ALL rows
    final nowIso = endedAtIso; // same end time
    final changedBy = supabase.auth.currentUser?.id;

    String actionFromStatus(String st) {
      // IMPORTANT: must match your CHECK constraint allowed values
      if (st == 'absent') return 'auto_absent';
      if (st == 'late') return 'mark_late';
      return 'mark_present';
    }

    final historyPayload = allList.map((r) {
      final st = (r['status'] as String?) ?? 'present';
      return {
        'attendance_id': r['id'],
        'session_id': _sessionId,
        'student_id': r['student_id'],

        'professor_id': changedBy, // ok if same auth uid
        'old_status': null,
        'new_status': st,
        'action': actionFromStatus(st),
        'changed_by': changedBy,
        'changed_by_role': 'professor',
        'reason': 'Session ended - finalized attendance',
        'changed_at': nowIso,
      };
    }).toList();

    await supabase.from('attendance_history').insert(historyPayload);
  }

  String? _sessionId; // active started session id
  bool _loadingAttendance = true;
  String? _attendanceErr;

  List<Map<String, dynamic>> _enrolled = [];   // from class_enrollments + students
  List<Map<String, dynamic>> _attendance = []; // from attendance + students

  Future<void> _loadData() async {
    setState(() {
      _loadingAttendance = true;
      _attendanceErr = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // 1) active session
      final sessionRow = await supabase
          .from('class_sessions')
          .select('id, started_at, status')
          .eq('class_id', widget.classId)
          .eq('status', 'started')
          .order('started_at', ascending: false)
          .maybeSingle();

      if (sessionRow == null) {
        throw 'No active session (started) found.';
      }

      _sessionId = sessionRow['id'] as String?;
      final startedAtStr = sessionRow['started_at'] as String?;
      if (startedAtStr != null) _startedAt = DateTime.parse(startedAtStr);

      // 2) enrolled students (for total + pending)
      final enrolledRows = await supabase
          .from('class_enrollments')
          .select('student_id, students(first_name,last_name,student_number,avatar_url)')
          .eq('class_id', widget.classId)
          .order('joined_at', ascending: true);

      _enrolled = (enrolledRows as List).cast<Map<String, dynamic>>();

      // 3) attendance for this session
      final attendRows = await supabase
          .from('attendance')
          .select('student_id, status, time_in, students(first_name,last_name,student_number,avatar_url)')
          .eq('session_id', _sessionId!)
          .order('time_in', ascending: true);

      _attendance = (attendRows as List).cast<Map<String, dynamic>>();

      if (!mounted) return;
      setState(() {
        _loadingAttendance = false;
        _loadingSessionInfo = false; // ✅ ADD THIS
      });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _attendanceErr = e.toString();
        _loadingAttendance = false;
        _loadingSessionInfo = false; // ✅ ADD THIS
      });
    }
  }

  DateTime? _startedAt;
  bool _loadingSessionInfo = true;

  int get totalStudents => _enrolled.length;

  int get presentCount {
    return _attendance.where((r) {
      final st = (r['status'] as String?) ?? '';
      return st == 'present' || st == 'late';
    }).length;
  }

  int get pendingCount => totalStudents - presentCount;

// para mabilis malaman kung present yung student
  Map<String, String> get statusByStudentId {
    return {
      for (final r in _attendance)
        (r['student_id'] as String): ((r['status'] as String?) ?? 'present')
    };
  }

  @override
  void initState() {
    super.initState();
    _loadData(); // instead of _loadSessionInfo()
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

        final endedAtIso = DateTime.now().toIso8601String();
        // ✅ end the active session for this class
        await _finalizeAttendanceAndLogHistory(endedAtIso);
        await supabase.from('class_sessions').update({
          'status': 'ended',
          'ended_at': endedAtIso,
        }).eq('class_id', widget.classId)
            .eq('status', 'started');

        await supabase.functions.invoke(
          'process_notification_queue',
          body: {'limit': 50},
        );

        await _loadData();

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

  Widget studentRowFromEnrollment(Map<String, dynamic> enrollRow) {
    final s = enrollRow['students'] as Map<String, dynamic>?;
    final sid = enrollRow['student_id'] as String;

    final name = s == null
        ? 'Unknown Student'
        : '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim();

    final avatarUrl = s?['avatar_url'] as String?;
    final st = statusByStudentId[sid]; // null if no attendance
    final isPresent = st == 'present' || st == 'late';
    final isLate = st == 'late';

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: (avatarUrl != null && avatarUrl.trim().isNotEmpty)
                        ? Image.network(
                      avatarUrl,
                      width: 20,
                      height: 20,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Image.asset('assets/avatar.png', width: 20, height: 20),
                    )
                        : Image.asset('assets/avatar.png', width: 20, height: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(name.isEmpty ? 'Unknown Student' : name, style: const TextStyle(fontSize: 12)),
                ],
              ),

              Row(
                children: [
                  Icon(
                    isPresent ? CupertinoIcons.check_mark_circled : CupertinoIcons.clock,
                    color: isPresent
                        ? (isLate ? Colors.orange : const Color(0xFF018832))
                        : Color(0xFFF7CB73),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPresent ? (isLate ? 'Late' : 'Present') : 'Pending',
                    style: TextStyle(
                      color: isPresent
                          ? (isLate ? Colors.orange : const Color(0xFF018832))
                          : Color(0xFFF7CB73),
                      fontSize: 12,
                    ),
                  )
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 10),
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
                                    : 'Session Started at ${DateFormat('h:mm a').format(_startedAt!)}',
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
                                '$presentCount',
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
                                '$pendingCount',
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
                                '$totalStudents',
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
                                    Text('${presentCount}/$totalStudents'),
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
                            child:
                            _loadingAttendance
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                              controller: _scrollController,
                              itemCount: _enrolled.length,
                              itemBuilder: (context, index) {
                                return studentRowFromEnrollment(_enrolled[index]);
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
