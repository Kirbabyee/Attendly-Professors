import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/class_session.dart';
import '../utils/error_handler.dart';

class StartSession extends StatefulWidget {
  final List<String> students;
  final VoidCallback onStarted;

  // add these fields
  final String courseTitle;
  final String classId;
  final String courseCode;
  final String professor;
  final String classCode;
  final String room;
  final String sched;

  const StartSession({
    super.key,
    required this.classId,
    required this.students,
    required this.onStarted,

    // required para di null
    required this.courseTitle,
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
  Timer? _timer;
  bool _isStartEnabled = false;

  // Realtime Channel
  RealtimeChannel? _enrollmentChannel;

  // Selection for bulk approval
  final Set<String> _selectedPendingIds = {};

  Future<void> _loadEnrolledStudents({bool silent = false}) async {
    if (!silent) {
      if (mounted) {
        setState(() {
          _loadingEnrolled = true;
          _enrolledErr = null;
        });
      }
    }

    try {
      final supabase = Supabase.instance.client;

      final rows = await supabase
          .from('class_enrollments')
          .select('student_id, status, joined_at, students(first_name, last_name, student_number, avatar_url, program, year_level, section)')
          .eq('class_id', widget.classId)
          .order('joined_at', ascending: true);

      final list = (rows as List).map((r) => r as Map<String, dynamic>).toList();

      if (!mounted) return;
      setState(() {
        _enrolled = list;
        _loadingEnrolled = false;
        // Keep selection if they still exist and are still pending
        final pendingIds = _enrolled
            .where((e) => e['status'] == 'pending')
            .map((e) => e['student_id'].toString())
            .toSet();
        _selectedPendingIds.retainWhere((id) => pendingIds.contains(id));
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _enrolledErr = ErrorHandler.getMessage(e);
          _loadingEnrolled = false;
        });
      }
    }
  }

  void _setupRealtime() {
    final supabase = Supabase.instance.client;
    
    _enrollmentChannel = supabase
        .channel('public:class_enrollments:${widget.classId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'class_enrollments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'class_id',
            value: widget.classId,
          ),
          callback: (payload) {
            debugPrint('Realtime Enrollment Update Detected');
            _loadEnrolledStudents(silent: true);
          },
        )
        .subscribe();
  }

  final ScrollController _enrolledScrollController = ScrollController();
  final ScrollController _pendingScrollController = ScrollController();
  final ScrollController _mainScrollController = ScrollController(); // ✅ Main scrollbar controller

  @override
  void initState() {
    super.initState();
    _loadEnrolledStudents();
    _setupRealtime();
    _checkStartCondition();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkStartCondition();
    });
  }

  void _checkStartCondition() {
    final enabled = _canStartFromSched10mins(widget.sched);
    if (enabled != _isStartEnabled) {
      setState(() => _isStartEnabled = enabled);
    }
  }

  bool _canStartFromSched10mins(String sched) {
    final now = DateTime.now();
    final dayStr = sched.split(':').first.trim().toLowerCase();

    const map = {
      'sunday': DateTime.sunday,
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
    };

    final schedWeekday = map[dayStr];
    if (schedWeekday == null) return false;

    final startMin = _startMinutesFromSched(sched);
    final endMinRaw = _endMinutesFromSched(sched);
    if (startMin == 9999 || endMinRaw == 9999) return false;

    final nowMin = now.hour * 60 + now.minute;

    final overnight = endMinRaw <= startMin;
    final endMin = overnight ? endMinRaw + 1440 : endMinRaw;

    // startable window = 10 mins before start
    final startableFrom = startMin - 10;

    int prevDay(int d) => d == DateTime.monday ? DateTime.sunday : d - 1;
    int nextDay(int d) => d == DateTime.sunday ? DateTime.monday : d + 1;

    int? nowAdj;

    if (now.weekday == schedWeekday) {
      nowAdj = nowMin;
    } else if (startableFrom < 0 && now.weekday == prevDay(schedWeekday)) {
      nowAdj = nowMin - 1440; // spill to prev day
    } else if (overnight && now.weekday == nextDay(schedWeekday)) {
      nowAdj = nowMin + 1440; // continuation day
    } else {
      return false;
    }

    if (nowAdj >= endMin) return false;
    return nowAdj >= startableFrom;
  }

  int _startMinutesFromSched(String sched) {
    final parts = sched.split(':');
    if (parts.length < 2) return 9999;
    final timePart = parts.sublist(1).join(':').trim();
    final range = timePart.split(RegExp(r'\s*[-–]\s*'));
    if (range.length < 2) return 9999;
    return _toMinutes(range.first.trim());
  }

  int _endMinutesFromSched(String sched) {
    final parts = sched.split(':');
    if (parts.length < 2) return 9999;
    final timePart = parts.sublist(1).join(':').trim();
    final range = timePart.split(RegExp(r'\s*[-–]\s*'));
    if (range.length < 2) return 9999;
    return _toMinutes(range.last.trim());
  }

  int _toMinutes(String time) {
    final reg = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false);
    final m = reg.firstMatch(time.trim());
    if (m == null) return 9999;
    int hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final ampm = m.group(3)!.toUpperCase();
    if (ampm == 'AM' && hour == 12) hour = 0;
    else if (ampm == 'PM' && hour != 12) hour += 12;
    return hour * 60 + minute;
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_enrollmentChannel != null) {
      Supabase.instance.client.removeChannel(_enrollmentChannel!);
    }
    _enrolledScrollController.dispose();
    _pendingScrollController.dispose();
    _mainScrollController.dispose();
    super.dispose();
  }

  bool viewAllEnrolled = false;
  bool viewAllPending = false;

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Container(
          width: double.maxFinite,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded( // ✅ Fix overflow
                child: Text(message, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSuccessModal(String message) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 50),
            const SizedBox(height: 14),
            const Text(
              "Success",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004280),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Got it!", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget studentRow({
    required String name,
    required String status,
    required String studentId,
    String? avatarUrl,
    String? program,
    String? yearLevel,
    String? section,
  }) {
    final hasUrl = avatarUrl != null && avatarUrl.trim().isNotEmpty;
    final isPending = status == 'pending';

    // Extract abbreviation from program (e.g., "BSIT - Bachelor of...")
    String progAbbr = '';
    if (program != null && program.isNotEmpty) {
      progAbbr = program.split('-').first.trim();
    }

    final String infoText = progAbbr.isNotEmpty
        ? '$progAbbr $yearLevel-$section'
        : '';

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10), // Reduced margin
          child: Row(
            children: [
              if (isPending) ...[
                SizedBox(
                  width: 24,
                  child: Checkbox(
                    value: _selectedPendingIds.contains(studentId),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedPendingIds.add(studentId);
                        } else {
                          _selectedPendingIds.remove(studentId);
                        }
                      });
                    },
                    activeColor: const Color(0xFF018832),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: hasUrl
                    ? Image.network(
                  avatarUrl!,
                  width: 20,
                  height: 20,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/avatar.png',
                    width: 20,
                    height: 20,
                    fit: BoxFit.cover,
                  ),
                )
                    : Image.asset(
                  'assets/avatar.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        if (infoText.isNotEmpty)
                          Flexible(
                            child: Text(
                              '$infoText  ${isPending ? '•  ' : ''}',
                              style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (isPending)
                          const Text(
                            'Pending Approval',
                            style: TextStyle(fontSize: 8, color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isPending)
                SizedBox(
                  height: 22,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF018832),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      elevation: 0,
                    ),
                    onPressed: () => _handleApproveStudent(studentId, name),
                    child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 9)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _handleApproveStudent(String studentId, String studentName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Confirm Approval', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
        content: Text('Accept $studentName into this class?', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.black))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF018832), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _showLoadingDialog('Approving $studentName...');

    final supabase = Supabase.instance.client;
    try {
      await supabase
          .from('class_enrollments')
          .update({'status': 'enrolled'})
          .eq('class_id', widget.classId)
          .eq('student_id', studentId);
      
      // ✅ Queue Notification for approval
      await supabase.from('notification_queue').insert({
        'target_role': 'student',
        'target_user_id': studentId,
        'type': 'enrollment_approved',
        'class_id': widget.classId,
        'title': 'Enrollment Approved!',
        'body': 'You have been accepted into ${widget.courseTitle}.',
        'status': 'pending',
      });

      // Trigger the edge function to process immediately
      try {
        await supabase.functions.invoke('process_notification', body: {'reason': 'start_session'});
      } catch (_) {}

      await _loadEnrolledStudents(silent: true);
      
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading
      
      await _showSuccessModal('$studentName has been approved and enrolled.');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving student: ${ErrorHandler.getMessage(e)}')),
      );
    }
  }

  Future<void> _handleBulkApprove() async {
    if (_selectedPendingIds.isEmpty) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Confirm Approval', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
        content: Text('Approve all ${_selectedPendingIds.length} selected students?', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.black))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF018832), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _showLoadingDialog('Approving selected students...');

    final supabase = Supabase.instance.client;
    try {
      final List<String> ids = _selectedPendingIds.toList();
      final count = ids.length;
      
      await supabase
          .from('class_enrollments')
          .update({'status': 'enrolled'})
          .eq('class_id', widget.classId)
          .inFilter('student_id', ids);
      
      // ✅ Queue Notifications for all approved students
      final notificationPayload = ids.map((studentId) => {
        'target_role': 'student',
        'target_user_id': studentId,
        'type': 'enrollment_approved',
        'class_id': widget.classId,
        'title': 'Enrollment Approved!',
        'body': 'You have been accepted into ${widget.courseTitle}.',
        'status': 'pending',
      }).toList();

      await supabase.from('notification_queue').insert(notificationPayload);

      // Trigger the edge function
      try {
        await supabase.functions.invoke('process_notification', body: {'reason': 'start_session'});
      } catch (_) {}

      await _loadEnrolledStudents(silent: true);
      
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading
      setState(() {
        _selectedPendingIds.clear();
      });

      await _showSuccessModal('$count students have been approved and enrolled.');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving students: ${ErrorHandler.getMessage(e)}')),
      );
    }
  }

  bool _starting = false;

  Future<void> _confirmStartSession() async { 
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

        // create session row
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
          debugPrint('process_notification invoke failed: $e');
        }

        if (!mounted) return;
        widget.onStarted(); 
      } catch (e) {
        if (!mounted) return;
        setState(() => _starting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start session: ${ErrorHandler.getMessage(e)}')),
        );
      }
    }
  }

  Widget buildStudentRow(Map<String, dynamic> row) {
    final s = row['students'] as Map<String, dynamic>?;
    final status = (row['status'] ?? 'enrolled').toString();
    final studentId = (row['student_id'] ?? '').toString();

    final name = s == null
        ? 'Unknown Student'
        : '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim();

    final avatarUrl = s?['avatar_url'] as String?;
    final program = s?['program'] as String?;
    final yearLevel = (s?['year_level'] ?? '').toString();
    final section = (s?['section'] ?? '').toString();

    return studentRow(
      name: name.isEmpty ? 'Unknown Student' : name,
      avatarUrl: avatarUrl,
      status: status,
      studentId: studentId,
      program: program,
      yearLevel: yearLevel,
      section: section,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    final pendingOnes = _enrolled.where((e) => e['status'] == 'pending').toList();
    final enrolledOnes = _enrolled.where((e) => e['status'] == 'enrolled').toList();
    
    final pendingCount = pendingOnes.length;
    final enrolledCount = enrolledOnes.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Fixed Header
            AttendlyBlueHeader(
              onBack: false,
              courseTitle: widget.courseTitle,
              courseCode: widget.courseCode,
              professor: widget.professor,
              icon: CupertinoIcons.book,
              iconColor: const Color(0xFFFBD600),
            ),

            // Scrollable Body with Scrollbar
            Expanded(
              child: Scrollbar(
                controller: _mainScrollController,
                thumbVisibility: true,
                radius: const Radius.circular(8),
                thickness: 6,
                child: SingleChildScrollView(
                  controller: _mainScrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
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
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                icon: const Icon(CupertinoIcons.arrow_left)),
                            const Text('Back')
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Start Session
                      Container(
                        padding: const EdgeInsets.all(20),
                        width: 350,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
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
                            const Text(
                              'Start Class Session',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold
                              ),
                            ),
                            const SizedBox(height: 10,),
                            Center(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: _isStartEnabled 
                                    ? const Color(0xFF018832) 
                                    : Colors.grey, // Disabled color
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: (_starting || !_isStartEnabled) ? null : _confirmStartSession,
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
                            ),
                            if (!_isStartEnabled)
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Center(
                                  child: Text(
                                    'Start button will enabled 10 minutes before the schedule',
                                    style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15,),

                      // ENROLLED STUDENTS SECTION
                      Container(
                        width: 350,
                        padding: const EdgeInsets.all(10), // Reduced from 20 to match end_session
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Enrolled Students',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold
                                  ),
                                ),
                                Text(
                                  _loadingEnrolled ? 'Loading...' : '$enrolledCount Enrolled',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF018832)
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.black26),
                            const SizedBox(height: 5,),

                            if (_loadingEnrolled) ...[
                              const SizedBox(height: 20),
                              const Center(child: CircularProgressIndicator()),
                            ] else if (enrolledOnes.isEmpty) ...[
                              const SizedBox(height: 10),
                              const Center(child: Text('No enrolled students yet.', style: TextStyle(fontSize: 12, color: Colors.grey))),
                            ] else ...[
                              SizedBox(
                                height: viewAllEnrolled ? screenHeight * .25 : screenHeight * .12,
                                child: Scrollbar(
                                  controller: _enrolledScrollController,
                                  thumbVisibility: viewAllEnrolled,
                                  child: ListView.builder(
                                    controller: _enrolledScrollController,
                                    shrinkWrap: true,
                                    itemCount: viewAllEnrolled ? enrolledOnes.length : (enrolledOnes.length > 3 ? 3 : enrolledOnes.length),
                                    itemBuilder: (context, index) => buildStudentRow(enrolledOnes[index]),
                                  ),
                                ),
                              ),
                              if (enrolledOnes.length > 3)
                                Center(
                                  child: TextButton(
                                    onPressed: () => setState(() => viewAllEnrolled = !viewAllEnrolled),
                                    child: Text(
                                      !viewAllEnrolled ? 'View all enrolled' : 'Show less',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF105698)),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 15,),

                      // PENDING APPROVALS SECTION
                      Container(
                        width: 350,
                        padding: const EdgeInsets.all(10), // Reduced from 20 to match end_session
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Pending Approvals',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold
                                  ),
                                ),
                                if (!_loadingEnrolled && pendingCount > 0)
                                  Text(
                                    '$pendingCount',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange
                                    ),
                                  ),
                              ],
                            ),
                            const Divider(color: Colors.black26),
                            const SizedBox(height: 5,),
                            
                            if (!_loadingEnrolled && pendingCount > 0)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (_selectedPendingIds.length == pendingCount) {
                                            _selectedPendingIds.clear();
                                          } else {
                                            _selectedPendingIds.clear();
                                            _selectedPendingIds.addAll(
                                              pendingOnes.map((e) => e['student_id'].toString())
                                            );
                                          }
                                        });
                                      },
                                      child: Text(_selectedPendingIds.length == pendingCount ? 'Deselect All' : 'Select All', style: const TextStyle(fontSize: 11, color: Color(0xFF105698))),
                                    ),
                                    if (_selectedPendingIds.isNotEmpty)
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF018832),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          elevation: 0,
                                        ),
                                        onPressed: _handleBulkApprove,
                                        child: Text('Approve (${_selectedPendingIds.length})', style: const TextStyle(color: Colors.white, fontSize: 11)),
                                      ),
                                  ],
                                ),
                              ),

                            if (_loadingEnrolled) ...[
                              const SizedBox(height: 20),
                              const Center(child: CircularProgressIndicator()),
                            ] else if (pendingOnes.isEmpty) ...[
                              const SizedBox(height: 10),
                              const Center(child: Text('No pending approvals.', style: TextStyle(fontSize: 12, color: Colors.grey))),
                            ] else ...[
                              SizedBox(
                                height: viewAllPending ? screenHeight * .25 : screenHeight * .18,
                                child: Scrollbar(
                                  controller: _pendingScrollController,
                                  thumbVisibility: viewAllPending,
                                  child: ListView.builder(
                                    controller: _pendingScrollController,
                                    shrinkWrap: true,
                                    itemCount: viewAllPending ? pendingOnes.length : (pendingOnes.length > 3 ? 3 : pendingOnes.length),
                                    itemBuilder: (context, index) => buildStudentRow(pendingOnes[index]),
                                  ),
                                ),
                              ),
                              if (pendingOnes.length > 3)
                                Center(
                                  child: TextButton(
                                    onPressed: () => setState(() => viewAllPending = !viewAllPending),
                                    child: Text(
                                      !viewAllPending ? 'View all pending' : 'Show less',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF105698)),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
