import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:professor/Professor%20Page/attendance/class_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../attendance/start_session.dart';
import '../professor_session.dart';
import 'archives.dart';
import 'class_item.dart';
import 'create_class.dart';
import 'notification_ui.dart';

class Dashboard extends StatefulWidget {
  final bool unRead;

  const Dashboard({
    super.key,
    required this.unRead
  });
  @override
  State<Dashboard> createState() => _DashboardState();
}




class _DashboardState extends State<Dashboard> {
  Timer? _tick;

  Future<void> _loadClasses() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final rows = await Supabase.instance.client
          .from('classes')
          .select('id, course, course_code, class_code, room, schedule, year_section, archived')
          .eq('professor_id', uid)
          .eq('archived', false)
          .order('created_at', ascending: false);

      final classIds = (rows as List)
          .map((r) => (r as Map<String, dynamic>)['id'] as String)
          .toList();

      final startedRows = await Supabase.instance.client
          .from('class_sessions')
          .select('class_id')
          .inFilter('class_id', classIds)
          .eq('status', 'started');

      final startedSet = (startedRows as List)
          .map((s) => (s as Map<String, dynamic>)['class_id'] as String)
          .toSet();

      final endedRows = await Supabase.instance.client
          .from('class_sessions')
          .select('class_id')
          .inFilter('class_id', classIds)
          .eq('status', 'ended');

      final endedSet = (endedRows as List)
          .map((s) => (s as Map<String, dynamic>)['class_id'] as String)
          .toSet();

      final list = (rows as List).map((r) {
        final m = r as Map<String, dynamic>;
        final sched = (m['schedule'] ?? '') as String;
        final classId = m['id'] as String;

        final sessionText = startedSet.contains(classId)
            ? 'Session Started'
            : endedSet.contains(classId)
            ? 'Ended'
            : _sessionFromSched(sched);

        return ClassItem(
          id: classId,
          classCode: (m['class_code'] ?? '') as String,
          course: (m['course'] ?? '') as String,
          courseCode: (m['course_code'] ?? '') as String,
          professor: _prof?['professor_name'] ?? 'Professor',
          room: (m['room'] ?? '') as String,
          sched: (m['schedule'] ?? '') as String,
          session: sessionText,
          yearSection: (m['year_section'] ?? '') as String, // ✅ HERE
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _classes
          ..clear()
          ..addAll(list);
        _sortClasses();
      });
    } catch (e) {
      // optional: show snackbar
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load classes: $e')),
      );
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final students = <String>[
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

  final List<ClassItem> _classes = [];

  final List<ClassItem> _archivedClasses = [];

  late bool unRead;

  void _sortClasses() {
    const sessionPriority = {
      'Session Started': 0,
      'Pending': 1,
      'Upcoming': 2,
      'Ended': 3,
    };

    _classes.sort((a, b) {
      // 1) Session priority
      final aSession = sessionPriority[a.session] ?? 99;
      final bSession = sessionPriority[b.session] ?? 99;
      final sessionCompare = aSession.compareTo(bSession);
      if (sessionCompare != 0) return sessionCompare;

      // 2) Day priority
      final aDay = _daysUntilFromSched(a.sched);
      final bDay = _daysUntilFromSched(b.sched);
      final dayCompare = aDay.compareTo(bDay);
      if (dayCompare != 0) return dayCompare;

      // 3) Start time priority
      final aStart = _startMinutesFromSched(a.sched);
      final bStart = _startMinutesFromSched(b.sched);
      return aStart.compareTo(bStart);
    });
  }

  int _dayRankFromSched(String sched) {
    // Expect: "Monday: 9:00 AM - 11:00 AM"
    final day = sched.split(':').first.trim().toLowerCase();

    const dayRank = {
      'sunday': 0,
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
    };

    return dayRank[day] ?? 99;
  }

  int _daysUntilFromSched(String sched) {
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

    final target = map[dayStr];
    if (target == null) return 999;

    final today = DateTime.now().weekday; // monday=1..sunday=7

    // ✅ circular difference (0..6)
    return (target - today + 7) % 7;
  }

  int _startMinutesFromSched(String sched) {
    // Example: "Wednesday: 02:10 PM - 03:00 PM" or "Wednesday: 02:10 PM – 03:00 PM"
    final parts = sched.split(':');
    if (parts.length < 2) return 9999;

    final timePart = parts.sublist(1).join(':').trim(); // "02:10 PM - 03:00 PM"
    final range = timePart.split(RegExp(r'\s*[-–]\s*')); // ✅ handles "-" and "–"
    if (range.length < 2) return 9999;

    final startStr = range.first.trim(); // "02:10 PM"
    return _toMinutes(startStr);
  }

  int _endMinutesFromSched(String sched) {
    final parts = sched.split(':');
    if (parts.length < 2) return 9999;

    final timePart = parts.sublist(1).join(':').trim();
    final range = timePart.split(RegExp(r'\s*[-–]\s*')); // ✅ handles "-" and "–"
    if (range.length < 2) return 9999;

    final endStr = range.last.trim(); // "03:00 PM"
    return _toMinutes(endStr);
  }

  int _toMinutes(String time) {
    // time example: "9:00 AM"
    final reg = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false);
    final m = reg.firstMatch(time.trim());
    if (m == null) return 9999;

    int hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final ampm = m.group(3)!.toUpperCase();

    // Convert to 24h
    if (ampm == 'AM') {
      if (hour == 12) hour = 0;
    } else {
      if (hour != 12) hour += 12;
    }

    return hour * 60 + minute;
  }

  String _sessionFromSched(String sched) {
    final now = DateTime.now();

    final dayStr = sched.split(':').first.trim().toLowerCase();

    final startMin = _startMinutesFromSched(sched);
    final endMinRaw = _endMinutesFromSched(sched);
    final nowMin = now.hour * 60 + now.minute;

    if (startMin == 9999 || endMinRaw == 9999) return 'Upcoming';

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
    if (schedWeekday == null) return 'Upcoming';

    int prevDay(int d) => d == DateTime.monday ? DateTime.sunday : d - 1;
    int nextDay(int d) => d == DateTime.sunday ? DateTime.monday : d + 1;

    // ✅ detect overnight (ex: 11:30 PM - 12:59 AM)
    final overnight = endMinRaw <= startMin;
    final endMin = overnight ? endMinRaw + 1440 : endMinRaw;

    // ✅ pending window (can be negative if start is 12:00 AM)
    final pendingWindowStart = startMin - 120;

    // ✅ place "now" on the same timeline as the schedule
    int? nowAdj;

    if (now.weekday == schedWeekday) {
      // same day as schedule start
      nowAdj = nowMin;
    } else if (pendingWindowStart < 0 && now.weekday == prevDay(schedWeekday)) {
      // ✅ pending window spills to previous day (ex: 12:00 AM start)
      nowAdj = nowMin - 1440;
    } else if (overnight && now.weekday == nextDay(schedWeekday)) {
      // overnight continuation day
      nowAdj = nowMin + 1440;
    } else {
      return 'Upcoming';
    }

    if (nowAdj >= endMin) return 'Ended';
    if (nowAdj >= pendingWindowStart) return 'Pending';
    return 'Upcoming';
  }

  Map<String, dynamic>? _prof;
  bool _loadingProf = true;
  String? _profErr;

  @override
  void initState() {
    super.initState();

    unRead = widget.unRead;

    _loadProfessor().then((_) => _loadClasses());

    // ✅ DB is the single source of truth
    _tick = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!mounted) return;
      await _loadClasses();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _loadProfessor() async {
    setState(() {
      _loadingProf = true;
      _profErr = null;
    });

    try {
      final p = await ProfessorSession.get(force: true);
      if (!mounted) return;
      setState(() {
        _prof = p;
        _loadingProf = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profErr = e.toString();
        _loadingProf = false;
      });
    }
  }

  Widget textBold(tag, name, double screenHeight) {
    return Text.rich(
      TextSpan(
        text: tag,
        style: TextStyle(fontSize: screenHeight > 700 ? 14 : 13),
        children: [
          TextSpan(
            text: name,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: screenHeight > 700 ? 14 : 13),
          ),
        ],
      ),
    );
  }

  // Classcard Template
  Widget classCard(
      String id,
      String yearSection,
      String course,
      String classCode,
      String courseCode,
      String professor,
      String room,
      String sched,
      String session,
      double screenHeight,
      VoidCallback onArchive,
    ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isUpcoming = session == 'Upcoming' || session == 'Ended';

    return Opacity(
      opacity: isUpcoming ? 0.5 : 1.0,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: screenHeight > 700 ? 20 : 12),
        padding: EdgeInsets.all(10),
        width: 350,
        decoration: BoxDecoration(
          color: session == 'Pending' || session == 'Session Started' ? Colors.white : Colors.grey[300],
          borderRadius: BorderRadiusGeometry.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 2,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            fontSize: screenHeight > 700 ? 12 : 11,
            color: Colors.black,
            fontFamily: 'Montserrat',
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 280,
                        child: Text(
                          course,
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      SizedBox(height: 5,),
                      Text(courseCode),
                      SizedBox(height: 8,),
                      Text(yearSection, style: TextStyle(fontSize: 10),),
                      SizedBox(height: 10,),
                    ],
                  ),
                  session == 'Pending' || session == 'Session Started'
                      ? IconButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClassSession(
                            session: session,
                            students: students,
                            onSessionStarted: () async {
                              await _loadClasses();
                            },
                            onSessionEnded: () async {
                              await _loadClasses(); // refresh
                            },
                            classId: id,
                            courseTitle: course,
                            courseCode: courseCode,
                            professor: professor,
                            classCode: classCode,
                            room: room,
                            sched: sched,
                          ),
                        ),
                      );
                      await _loadClasses();
                    },
                    icon: Icon(CupertinoIcons.right_chevron, size: screenHeight > 700 ? 16 : 14),
                  )
                      : const SizedBox(),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(CupertinoIcons.person, size: screenHeight > 700 ? 20 : 18),
                          SizedBox(width: 5),
                          Container(width: 145,child: Text(professor,softWrap: true,)),
                        ],
                      ),
                      SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.pin_drop_outlined, size: screenHeight > 700 ? 20 : 18),
                          SizedBox(width: 5),
                          Text(room),
                        ],
                      ),
                      SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(CupertinoIcons.clock, size: screenHeight > 700 ? 20 : 18),
                          SizedBox(width: 5),
                          Container(width: 140,child: Text(sched)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    margin: EdgeInsets.fromLTRB(screenWidth > 400 ? 33 : screenWidth < 370 ? 9 : 10, 0, 0, screenWidth < 370 ? 3 : 10),
                    padding: EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadiusGeometry.circular(75),
                      border: Border.all(
                        color: session == 'Pending'
                            ? Color(0xFFB09602)
                            : session == 'Session Started' ? Color(0xFFBBE6CB)
                            : session == 'Ended' ? Color(0xFFFB8C7A)
                            : Color(0x90A9CBF9),
                      ),
                      color:
                      session == 'Session Started' ? Color(0xFFDBFCE7) : session == 'Pending' ? Color(0x25FBD600) : session == 'Ended' ? Color(0xFFFDDCDC) : Color(0x90DBEAFE),
                    ),
                    width: screenHeight > 700 ? 100 : 100,
                    height: screenWidth < 370 ? 18 : 20,
                    child: Text(
                      session,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenHeight > 700 ? 11 : screenWidth < 370 ? 9 : 10,
                        color: session == 'Session Started'
                          ? Color(0xFF016224)
                          : session == 'Pending' ? Color(0xFFB09602)
                          : session == 'Ended' ? Color(0xFFFB8C7A)
                          : Color(0x90004280),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    color: Colors.white,
                    icon: const Icon(Icons.more_vert_outlined),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Archive'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'archive') {
                        final ok = await _confirmArchive();
                        if (ok) onArchive();
                      }

                      if (value == 'edit') {
                        final updated = await showModalBottomSheet<ClassItem>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => CreateClassSheet(
                            initialItem: ClassItem(
                              id: id,
                              yearSection: yearSection,
                              classCode: classCode,
                              course: course,
                              courseCode: courseCode,
                              professor: professor,
                              room: room,
                              sched: sched,
                              session: session,
                            ),
                          ),
                        );

                        if (updated != null) {
                          await _showBlockingLoaderWhile(() async {
                            await _loadClasses(); // refresh from DB para consistent
                          });
                        }
                      }
                    },
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmArchive() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final w = MediaQuery.of(context).size.width;

        return AlertDialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24), // smaller dialog width
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8), // tighter inside
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

          title: const Text(
            'Archive this class?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: const Text(
            'This class will be moved to Archives.',
            style: TextStyle(fontSize: 13),
          ),

          actionsAlignment: MainAxisAlignment.end,
          actions: [
            SizedBox(
              height: 36,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  elevation: 0,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Archive', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final displayName = (_prof?['professor_name'] ??
        'Professor') as String;

    final firstName = displayName.trim().split(' ').first;

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: NotificationsDrawer(
        unRead: unRead,
        onUnreadChanged: (value) {
          setState(() => unRead = value);
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: screenHeight > 700 ? 140 : 120,
              decoration: BoxDecoration(
                color: Color(0xFF004280),
                borderRadius: BorderRadius.vertical(
                  top: Radius.zero,
                  bottom: Radius.circular(20),
                ),
              ),
              padding: EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Notification Bell
                  Container(
                    margin: EdgeInsets.fromLTRB(0,0,15,0),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          onPressed: () {
                            _scaffoldKey.currentState?.openEndDrawer();
                          },
                          icon: const Icon(CupertinoIcons.bell),
                          color: Colors.white,
                        ),
                        if (unRead)
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    )
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome to Attendly',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenHeight > 700 ? 14 : 12
                              )
                            ),
                            Text(
                              _loadingProf ? 'Loading...' : '$firstName!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: screenHeight > 700 ? 30 : 25,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFFDBEAFE),
                            borderRadius: BorderRadiusGeometry.circular(8)
                          ),
                          child: IconButton(
                              onPressed: () async {
                                final saved = await showModalBottomSheet<ClassItem>(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => const CreateClassSheet(),
                                );

                                if (saved == null) return;

                                await _showBlockingLoaderWhile(() async {
                                  // optional: ensure prof loaded too
                                  if (_prof == null) {
                                    await _loadProfessor();
                                  }
                                  await _loadClasses(); // ✅ ito ang “duration” na gusto mo
                                });
                              },
                              icon: Icon(
                            CupertinoIcons.plus,
                            size: 30,
                            )
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: screenHeight > 700 ? 20 : 15),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Classes',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: screenHeight > 700 ? 16 : 14),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Archives(
                                archivedClasses: _archivedClasses,
                                onRestore: (item) {
                                  setState(() {
                                    _classes.add(item);
                                    _sortClasses();
                                  });
                                },
                              ),
                            ),
                          );
                        },
                        icon: Icon(
                          CupertinoIcons.archivebox,
                          size: screenHeight > 700 ? 25 : 20,
                        ),
                      ),
                    ],
                  ),
                  ..._classes.asMap().entries.map((entry) {
                    final i = entry.key;
                    final c = entry.value;

                    final profName = _loadingProf
                        ? 'Loading...'
                        : ((_prof?['professor_name'] as String?) ?? 'Professor');

                    return classCard(
                      c.id,
                      c.yearSection,
                      c.course,
                      c.classCode,
                      c.courseCode,
                      profName, // always updated pag dumating si _prof
                      c.room,
                      c.sched,
                      c.session,
                      screenHeight,
                          () async {
                        // 🔹 1. Update DB
                        await Supabase.instance.client
                            .from('classes')
                            .update({'archived': true})
                            .eq('id', c.id);

                        // 🔹 2. Update UI
                        if (!mounted) return;
                        setState(() {
                          _archivedClasses.add(c);
                          _classes.removeAt(i);
                          _sortClasses();
                        });
                      },
                    );

                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _showBlockingLoaderWhile(Future<void> Function() task) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        backgroundColor: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Saving...'),
            ],
          ),
        ),
      ),
    );

    try {
      await task();
    } finally {
      if (mounted) Navigator.pop(context); // close loader
    }
  }
}


