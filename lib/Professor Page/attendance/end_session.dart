import 'dart:async'; // Added for Timer
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../widgets/class_session.dart';

class EndSession extends StatefulWidget {
  final List<String> students;
  final VoidCallback onEnded;

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
  // PERSISTENT TIMER STATE (Survivies page navigation)
  static final Map<String, int> _globalReverifySeconds = {};
  static final Map<String, Timer?> _globalReverifyTimers = {};

  // STATE VARIABLES
  String? _sessionId;
  bool _loadingAttendance = true;
  String? _attendanceErr;
  bool _ending = false;
  DateTime? _startedAt;
  bool _loadingSessionInfo = true;

  // Lists
  List<Map<String, dynamic>> _enrolled = [];
  List<Map<String, dynamic>> _attendance = [];

  // Re-verify & Timer States
  bool _reverifying = false;
  Timer? _localSyncTimer;
  int _reverifySeconds = 0;
  bool _isReverifyActive = false;
  bool _processingAbsents = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData().then((_) {
      _checkGlobalTimer();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _localSyncTimer?.cancel(); // Cancel local sync, but global timer keeps running
    super.dispose();
  }

  // CHECK IF A TIMER IS ALREADY RUNNING FOR THIS SESSION
  void _checkGlobalTimer() {
    if (_sessionId != null && _globalReverifySeconds.containsKey(_sessionId)) {
      setState(() {
        _reverifySeconds = _globalReverifySeconds[_sessionId]!;
        _isReverifyActive = true;
      });
      _startLocalSync();
    }
  }

  // TIMER FORMATTER (09:59)
  String get timerText {
    final minutes = (_reverifySeconds / 60).floor().toString().padLeft(2, '0');
    final seconds = (_reverifySeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // START 10-MINUTE TIMER (GLOBAL)
  void _startReverifyTimer() {
    if (_sessionId == null) return;

    final sid = _sessionId!;
    _globalReverifySeconds[sid] = 600; // 10 minutes
    
    setState(() {
      _reverifySeconds = 600;
      _isReverifyActive = true;
    });

    _globalReverifyTimers[sid]?.cancel();
    _globalReverifyTimers[sid] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_globalReverifySeconds[sid]! > 0) {
        _globalReverifySeconds[sid] = _globalReverifySeconds[sid]! - 1;
      } else {
        timer.cancel();
        _globalReverifyTimers.remove(sid);
        _globalReverifySeconds.remove(sid);
        _markUnverifiedAsAbsent(reason: 'Timer expired');
      }
    });

    _startLocalSync();
  }

  // SYNC LOCAL UI WITH GLOBAL TIMER
  void _startLocalSync() {
    _localSyncTimer?.cancel();
    _localSyncTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_sessionId != null && _globalReverifySeconds.containsKey(_sessionId)) {
        setState(() {
          _reverifySeconds = _globalReverifySeconds[_sessionId]!;
          _isReverifyActive = true;
        });
      } else {
        setState(() {
          _isReverifyActive = false;
          _reverifySeconds = 0;
        });
        timer.cancel();
      }
    });
  }

  // AUTO-MARK ABSENT LOGIC
  Future<void> _markUnverifiedAsAbsent({String reason = 'Re-verification ended'}) async {
    if (_processingAbsents || _sessionId == null) return;
    
    _processingAbsents = true;
    if (mounted) setState(() => _isReverifyActive = false);

    try {
      final supabase = Supabase.instance.client;
      final changedBy = supabase.auth.currentUser?.id;
      final nowIso = DateTime.now().toUtc().toIso8601String(); // UTC ONLY

      // 1. Get current students who are 'pending' from DB
      final existingRows = await supabase
          .from('attendance')
          .select('student_id')
          .eq('session_id', _sessionId!)
          .eq('status', 'pending');

      final pendingStudentIds = (existingRows as List)
          .map((row) => row['student_id'] as String)
          .toList();

      if (pendingStudentIds.isNotEmpty) {
        // 2. Bulk Update status to 'absent'
        final absentPayload = pendingStudentIds.map((sid) => {
          'session_id': _sessionId,
          'student_id': sid,
          'status': 'absent',
          'time_in': null,
          'time_out': null,
        }).toList();

        await supabase.from('attendance').upsert(
            absentPayload,
            onConflict: 'session_id,student_id'
        );

        // 3. Log to history
        final updatedRows = await supabase
            .from('attendance')
            .select('id, student_id')
            .eq('session_id', _sessionId!)
            .inFilter('student_id', pendingStudentIds);

        final historyPayload = (updatedRows as List).map((r) {
          return {
            'attendance_id': r['id'],
            'session_id': _sessionId,
            'student_id': r['student_id'],
            'professor_id': changedBy,
            'old_status': 'pending',
            'new_status': 'absent',
            'action': 'auto_absent',
            'changed_by': changedBy,
            'changed_by_role': 'professor',
            'reason': reason,
            'changed_at': nowIso, // UTC
          };
        }).toList();

        await supabase.from('attendance_history').insert(historyPayload);
      }

      if (mounted) {
        await _loadData();
        
        if (pendingStudentIds.isNotEmpty) {
          _showCustomModal(
            title: 'Verification Finished',
            content: '${pendingStudentIds.length} student(s) did not verify and were marked ABSENT.',
          );
        } else {
          _showCustomModal(
            title: 'Verification Ended',
            content: '', // No extra message
          );
        }
      }

    } catch (e) {
      debugPrint('Error marking absents: $e');
    } finally {
      _processingAbsents = false;
      if (mounted) setState(() {});
    }
  }

  // RE-VERIFY SESSION ACTION
  Future<void> _reverifySession() async {
    if (_sessionId == null) return;

    if (_isReverifyActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Re-verification is already in progress.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text('Re-verify Attendance?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: const Text(
            'This will set current (non-absent) attendance to PENDING.\n\nStudents will have 10 MINUTES to scan again. Afterwards, unverified students will be marked ABSENT.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004280),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start Timer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _reverifying = true);

    try {
      final supabase = Supabase.instance.client;

      // 1. Set records to 'pending' ONLY IF they are NOT already 'absent'
      await supabase
          .from('attendance')
          .update({'status': 'pending'})
          .eq('session_id', _sessionId!)
          .neq('status', 'absent'); // Students marked absent stay absent

      // 2. Queue Notifications (Exclude students who are already 'absent')
      if (_enrolled.isNotEmpty) {
        // Find IDs of students who are currently marked as absent
        final absentIds = _attendance
            .where((a) => (statusByStudentId[a['student_id']] ?? '') == 'absent')
            .map((a) => a['student_id'] as String)
            .toSet();

        final notificationPayload = _enrolled
            .where((student) => !absentIds.contains(student['student_id'])) // Don't notify absent students
            .map((student) {
          final studentId = student['student_id'] as String;
          return {
            'target_role': 'student',
            'target_user_id': studentId,
            'type': 'reverify_attendance',
            'class_id': widget.classId,
            'session_id': _sessionId,
            'title': 'Attendance Re-verification',
            'body': 'You have 10 MINUTES to re-verify your attendance!',
            'status': 'pending',
            'created_at': DateTime.now().toUtc().toIso8601String(), // UTC
          };
        }).toList();

        if (notificationPayload.isNotEmpty) {
          await supabase.from('notification_queue').insert(notificationPayload);

          try {
            // Using 'start_session' as trigger reason might be more reliable for current Edge Function
            await supabase.functions.invoke(
              'process_notification',
              body: {
                'reason': 'start_session', 
                'class_id': widget.classId,
                'session_id': _sessionId,
              },
            );
          } catch (e) {
            debugPrint('process_notification invoke failed: $e');
          }
        }
      }

      // 3. Start Timer & Refresh
      await _loadData();
      _startReverifyTimer();

      if (!mounted) return;
      _showCustomModal(
        title: 'Timer Started',
        content: 'Non-absent records are now pending. Students have 10 minutes to re-verify.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to re-verify: $e')),
      );
    } finally {
      if (mounted) setState(() => _reverifying = false);
    }
  }

  // HELPER FOR SMALL WHITE MODALS
  void _showCustomModal({required String title, required String content}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 60), // Small width
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: content.isEmpty ? null : Text(content, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  // --- EXISTING HELPER METHODS ---

  Future<void> _openPendingActions({
    required String studentId,
    required String studentName,
    required String? currentStatus,
  }) async {
    final bool isPending = currentStatus == null || currentStatus == 'pending';
    final bool isPresent = currentStatus == 'present' || currentStatus == 'late';
    final bool isAbsent = currentStatus == 'absent';

    final List<Widget> actions = [];
    
    actions.add(
      TextButton(
        onPressed: () => Navigator.pop(context, null),
        child: const Text('Cancel', style: TextStyle(fontSize: 12, color: Colors.black)),
      ),
    );

    if (isAbsent || isPending) {
      actions.add(
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF018832),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(context, 'present'),
          child: const Text('Present', style: TextStyle(fontSize: 12, color: Colors.white)),
        ),
      );
    }

    if (isPresent) {
      actions.add(
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB60202),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(context, 'absent'),
          child: const Text('Absent', style: TextStyle(fontSize: 12, color: Colors.white)),
        ),
      );
    }

    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 70, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        title: Text(
          studentName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        content: const Text('Update student status:', style: TextStyle(fontSize: 12)),
        actions: actions,
      ),
    );

    if (choice == null) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 90, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        title: const Text('Confirm', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        content: Text(
          choice == 'present' ? 'Mark as Present?' : 'Mark as Absent?',
          style: const TextStyle(fontSize: 12),
        ),
        actions: [
          SizedBox(
            height: 32,
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No', style: TextStyle(fontSize: 12, color: Colors.black)),
            ),
          ),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004280),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final String finalStatus = await _markStudentStatus(studentId: studentId, newStatus: choice);
      await _loadData();

      await _showSuccessModal(
        finalStatus == 'present' 
            ? 'Student marked as PRESENT' 
            : (finalStatus == 'late' ? 'Student marked as LATE (15m Rule)' : 'Student marked as ABSENT'),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _showSuccessModal(String message) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 110, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.check_mark_circled_solid,
                color: Color(0xFF018832), size: 40),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) Navigator.pop(context);
  }

  Future<String> _markStudentStatus({
    required String studentId,
    required String newStatus,
  }) async {
    final supabase = Supabase.instance.client;
    if (_sessionId == null) throw 'No active session id';

    final nowUtc = DateTime.now().toUtc(); // FORCE UTC
    final nowIso = nowUtc.toIso8601String();
    final changedBy = supabase.auth.currentUser?.id;

    // 1. Fetch ORIGINAL time_in from DB
    final existing = await supabase
        .from('attendance')
        .select('id, status, time_in')
        .eq('session_id', _sessionId!)
        .eq('student_id', studentId)
        .maybeSingle();

    final oldStatus = (existing?['status'] as String?);
    final existingTimeInStr = existing?['time_in'] as String?;

    // 15-MINUTE RULE LOGIC (Based on original time_in)
    String calculatedStatus = newStatus;
    if (newStatus == 'present' && _startedAt != null) {
      // Use existing time_in if it was already recorded, otherwise use now (UTC)
      DateTime referenceTime = nowUtc;
      if (existingTimeInStr != null) {
        referenceTime = DateTime.parse(existingTimeInStr).toUtc(); // Ensure UTC
      }
      
      final diff = referenceTime.difference(_startedAt!.toUtc());
      if (diff.inMinutes >= 15) {
        calculatedStatus = 'late';
      }
    }

    // 2. Upsert with calculated status and preserved/new time_in (UTC)
    await supabase.from('attendance').upsert({
      'session_id': _sessionId,
      'student_id': studentId,
      'status': calculatedStatus,
      'time_in': (calculatedStatus == 'present' || calculatedStatus == 'late') 
          ? (existingTimeInStr ?? nowIso) 
          : null,
      'time_out': null,
    }, onConflict: 'session_id,student_id');

    final action = calculatedStatus == 'excused' 
        ? 'mark_excused' 
        : (calculatedStatus == 'absent' ? 'mark_absent' : (calculatedStatus == 'late' ? 'mark_late' : 'mark_present'));

    final after = await supabase
        .from('attendance')
        .select('id')
        .eq('session_id', _sessionId!)
        .eq('student_id', studentId)
        .maybeSingle();

    final attendanceId = after?['id'];

    if (attendanceId != null) {
      await supabase.from('attendance_history').insert({
        'attendance_id': attendanceId,
        'session_id': _sessionId,
        'student_id': studentId,
        'professor_id': changedBy,
        'old_status': oldStatus,
        'new_status': calculatedStatus,
        'action': action,
        'changed_by': changedBy,
        'changed_by_role': 'professor',
        'reason': 'Manual update during session',
        'changed_at': nowIso, // UTC
      });
    }
    
    return calculatedStatus;
  }

  Future<void> _finalizeAttendanceAndLogHistory(String endedAtIso) async {
    final supabase = Supabase.instance.client;
    if (_sessionId == null) throw 'No active session id';

    // safety: make sure enrolled + attendance are loaded
    if (_enrolled.isEmpty) {
      final enrolledRows = await supabase
          .from('class_enrollments')
          .select(
          'student_id, students(first_name,last_name,student_number,avatar_url)')
          .eq('class_id', widget.classId)
          .order('joined_at', ascending: true);
      _enrolled = (enrolledRows as List).cast<Map<String, dynamic>>();
    }

    final existingRows = await supabase
        .from('attendance')
        .select('id, student_id, status')
        .eq('session_id', _sessionId!);
    final existingList = (existingRows as List).cast<Map<String, dynamic>>();

    final existingByStudent = <String, Map<String, dynamic>>{};
    for (final r in existingList) {
      existingByStudent[r['student_id'] as String] = r;
    }

    final enrolledIds = _enrolled.map((e) => e['student_id'] as String).toList();
    final missingIds = enrolledIds.where((sid) =>
    !existingByStudent.containsKey(sid)).toList();

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

    // Set time_out for present/late
    await supabase
        .from('attendance')
        .update({'time_out': endedAtIso}) // endedAtIso should be UTC
        .eq('session_id', _sessionId!)
        .inFilter('status', ['present', 'late'])
        .filter('time_out', 'is', null);

    final allRows = await supabase
        .from('attendance')
        .select('id, student_id, status')
        .eq('session_id', _sessionId!);

    final allList = (allRows as List).cast<Map<String, dynamic>>();
    final changedBy = supabase.auth.currentUser?.id;

    String actionFromStatus(String st) {
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
        'professor_id': changedBy,
        'old_status': null,
        'new_status': st,
        'action': actionFromStatus(st),
        'changed_by': changedBy,
        'changed_by_role': 'professor',
        'reason': 'Session ended - finalized attendance',
        'changed_at': endedAtIso, // UTC
      };
    }).toList();

    await supabase.from('attendance_history').insert(historyPayload);
  }

  Future<void> _loadData() async {
    setState(() {
      _loadingAttendance = true;
      _attendanceErr = null;
    });

    try {
      final supabase = Supabase.instance.client;

      final sessionRow = await supabase
          .from('class_sessions')
          .select('id, started_at, status')
          .eq('class_id', widget.classId)
          .inFilter('status', ['started'])
          .order('started_at', ascending: false)
          .maybeSingle();

      if (sessionRow == null) throw 'No active session (started) found.';

      _sessionId = sessionRow['id'] as String?;
      final startedAtStr = sessionRow['started_at'] as String?;
      if (startedAtStr != null) _startedAt = DateTime.parse(startedAtStr);

      final enrolledRows = await supabase
          .from('class_enrollments')
          .select('student_id, students(first_name,last_name,student_number,avatar_url)')
          .eq('class_id', widget.classId)
          .order('joined_at', ascending: true);

      _enrolled = (enrolledRows as List).cast<Map<String, dynamic>>();

      final attendRows = await supabase
          .from('attendance')
          .select('student_id, status, time_in, students(first_name,last_name,student_number,avatar_url)')
          .eq('session_id', _sessionId!)
          .order('time_in', ascending: true);

      _attendance = (attendRows as List).cast<Map<String, dynamic>>();

      if (!mounted) return;
      setState(() {
        _loadingAttendance = false;
        _loadingSessionInfo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _attendanceErr = e.toString();
        _loadingAttendance = false;
        _loadingSessionInfo = false;
      });
    }
  }

  int get totalStudents => _enrolled.length;
  int get presentCount => _attendance.where((r) {
    final st = (r['status'] as String?) ?? '';
    return st == 'present' || st == 'late';
  }).length;
  int get absentCount => _attendance.where((r) {
    final st = (r['status'] as String?) ?? '';
    return st == 'absent';
  }).length;
  int get excusedCount => _attendance.where((r) {
    final st = (r['status'] as String?) ?? '';
    return st == 'excused';
  }).length;
  int get pendingCount => totalStudents - presentCount - absentCount - excusedCount;

  Map<String, String> get statusByStudentId {
    return {
      for (final r in _attendance)
        (r['student_id'] as String): ((r['status'] as String?) ?? 'present')
    };
  }

  Future<void> _confirmEndSession() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text('Are you sure?', textAlign: TextAlign.center),
          content: const Text('This will end the current class session.', textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.circular(8))),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB60202),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.circular(8))),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('End Session', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (_ending) return;
      setState(() => _ending = true);

      try {
        final sid = _sessionId!;
        _globalReverifyTimers[sid]?.cancel();
        _globalReverifyTimers.remove(sid);
        _globalReverifySeconds.remove(sid);

        final supabase = Supabase.instance.client;
        final endedAtIso = DateTime.now().toUtc().toIso8601String(); // UTC ONLY

        await _finalizeAttendanceAndLogHistory(endedAtIso);

        final inserted = await supabase.from('class_sessions').update({
          'status': 'ended',
          'ended_at': endedAtIso,
        }).eq('class_id', widget.classId)
            .eq('status', 'started')
            .select('id')
            .single();

        await _loadData();
        final sessionId = inserted['id'];

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
          debugPrint('process_notification invoke failed: $e');
        }

        if (!mounted) return;
        widget.onEnded();
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
    final name = s == null ? 'Unknown Student' : '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim();
    final avatarUrl = s?['avatar_url'] as String?;
    final st = statusByStudentId[sid];
    
    final isPresent = st == 'present' || st == 'late';
    final isLate = st == 'late';
    final isAbsent = st == 'absent';
    final isExcused = st == 'excused';
    final isPending = st == null || st == 'pending';

    return InkWell(
      onTap: () => _openPendingActions(studentId: sid, studentName: name, currentStatus: st),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
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
                          errorBuilder: (_, __, ___) => Image.asset('assets/avatar.png', width: 20, height: 20),
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
                        isPresent
                            ? CupertinoIcons.check_mark_circled
                            : (isExcused ? CupertinoIcons.info_circle : (isAbsent ? CupertinoIcons.xmark_circle : CupertinoIcons.clock)),
                        color: isPresent
                            ? (isLate ? Colors.orange : const Color(0xFF018832))
                            : (isExcused ? Colors.blue : (isAbsent ? Colors.red : const Color(0xFFF7CB73))),
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPresent ? (isLate ? 'Late' : 'Present') : (isExcused ? 'Excused' : (isAbsent ? 'Absent' : 'Pending')),
                        style: TextStyle(
                          color: isPresent
                              ? (isLate ? Colors.orange : const Color(0xFF018832))
                              : (isExcused ? Colors.blue : (isAbsent ? Colors.red : const Color(0xFFF7CB73))),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit, size: 14, color: Colors.grey),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadData();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header
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
                    margin: const EdgeInsets.symmetric(horizontal: 30),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(CupertinoIcons.arrow_left),
                        ),
                        const Text('Back')
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // End Session Container
                  Container(
                    padding: const EdgeInsets.all(20),
                    width: 350,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadiusGeometry.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'End Class Session',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0x509BC9F5),
                            borderRadius: BorderRadiusGeometry.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.clock, size: 20, color: Color(0xFF043B6F)),
                              const SizedBox(width: 5),
                              Text(
                                _loadingSessionInfo
                                    ? 'Loading session time...'
                                    : _startedAt == null
                                    ? 'Session Started'
                                    : 'Session Started at ${DateFormat('h:mm a').format(_startedAt!.toLocal())}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF043B6F)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFB60202),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _ending ? null : _confirmEndSession,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_ending) ...[
                                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                    const SizedBox(width: 10),
                                  ],
                                  Text(_ending ? 'Ending...' : 'End Class Session', style: const TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  // RE-VERIFY BUTTON & TIMER UI
                  SizedBox(
                    width: 350,
                    child: _isReverifyActive
                        ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5), // Light Orange bg
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Re-verification Active',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Time left: $timerText',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: _processingAbsents ? null : () {
                              // Manual stop early
                              final sid = _sessionId!;
                              _globalReverifyTimers[sid]?.cancel();
                              _globalReverifyTimers.remove(sid);
                              _globalReverifySeconds.remove(sid);
                              _markUnverifiedAsAbsent(reason: 'Manual stop by professor');
                            },
                            child: _processingAbsents 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Stop Now', style: TextStyle(fontSize: 12)),
                          )
                        ],
                      ),
                    )
                        : OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFEDF4FC),
                        side: const BorderSide(color: Color(0xFF004280)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _reverifying ? null : _reverifySession,
                      icon: _reverifying
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(CupertinoIcons.arrow_2_circlepath,
                          color: Color(0xFF004280), size: 18),
                      label: Text(
                        _reverifying ? 'Sending Notifications...' : 'Re-verify Students (10m Timer)',
                        style: const TextStyle(
                          color: Color(0xFF004280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Attendance Stats
                  SizedBox(
                    width: 350,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadiusGeometry.circular(8),
                            color: Colors.white,
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$presentCount', style: const TextStyle(fontSize: 30)),
                              const Text('Present', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadiusGeometry.circular(8),
                            color: Colors.white,
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$pendingCount', style: const TextStyle(fontSize: 28)),
                              const Text('Pending', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadiusGeometry.circular(8),
                            color: Colors.white,
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$totalStudents', style: const TextStyle(fontSize: 30)),
                              const Text('Total', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Attendance Log
                  Container(
                    width: 350,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadiusGeometry.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Attendance Log'),
                            Row(
                              children: [
                                const Icon(Icons.people_alt_outlined),
                                Text('$presentCount/$totalStudents'),
                              ],
                            ),
                          ],
                        ),
                        const Divider(color: Colors.black),
                        SizedBox(
                          height: 110,
                          child: Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            radius: const Radius.circular(8),
                            thickness: 4,
                            child: _loadingAttendance
                                ? const Center(child: CircularProgressIndicator())
                                : ListView.builder(
                              controller: _scrollController,
                              physics: const ClampingScrollPhysics(),
                              itemCount: _enrolled.length,
                              itemBuilder: (context, index) {
                                return studentRowFromEnrollment(_enrolled[index]);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
