import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
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
  final VoidCallback onOpenNotifications;

  const Dashboard({
    super.key,
    required this.unRead,
    required this.onOpenNotifications,
  });
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _FloatingToast extends StatefulWidget {
  final String message;
  final Duration duration;

  const _FloatingToast({
    Key? key,
    required this.message,
    this.duration = const Duration(milliseconds: 1200),
  }) : super(key: key);

  @override
  State<_FloatingToast> createState() => _FloatingToastState();
}

class _FloatingToastState extends State<_FloatingToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180), // fade in speed
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _controller.forward();

    // start fade out near the end
    Future.delayed(widget.duration - const Duration(milliseconds: 220), () async {
      if (!mounted) return;
      await _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  widget.message,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardState extends State<Dashboard> {
  bool _offline = false;
  StreamSubscription? _connSub;
  RealtimeChannel? _classesChannel; // For realtime listener

  Future<bool> _hasInternet() async {
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) return false;
    return InternetConnection().hasInternetAccess;
  }

  Future<void> _updateOffline() async {
    final ok = await _hasInternet();
    if (!mounted) return;
    setState(() => _offline = !ok);
  }

  // INITIALIZE REALTIME LISTENER
  void _setupRealtimeListener() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _classesChannel = Supabase.instance.client
        .channel('public:classes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'classes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'professor_id',
            value: uid,
          ),
          callback: (payload) {
            debugPrint('Realtime change received: ${payload.toString()}');
            _loadClasses(); // Reload list on any change (archived, new class, edit)
          },
        )
        .subscribe();
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

    //  startable window = 10 mins before start
    final startableFrom = startMin - 10;

    int prevDay(int d) => d == DateTime.monday ? DateTime.sunday : d - 1;
    int nextDay(int d) => d == DateTime.sunday ? DateTime.monday : d + 1;

    int? nowAdj;

    if (now.weekday == schedWeekday) {
      nowAdj = nowMin;
    } else if (startableFrom < 0 && now.weekday == prevDay(schedWeekday)) {
      nowAdj = nowMin - 1440; // spill to prev day (midnight start)
    } else if (overnight && now.weekday == nextDay(schedWeekday)) {
      nowAdj = nowMin + 1440; // continuation day
    } else {
      return false;
    }

    if (nowAdj >= endMin) return false;
    return nowAdj >= startableFrom;
  }

  Future<void> _showShareClassCodeModal(String classCode) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            'Share Class Code',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Give this code to your students:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        classCode,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Copy',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: classCode));
                        if (!mounted) return;

                        _showFloatingBubble('Class code copied');
                      },
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              height: 36,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        );
      },
    );
  }

  OverlayEntry? _toastEntry;

  void _showFloatingBubble(String message) {
    _toastEntry?.remove();
    _toastEntry = null;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 120,
        left: 40,
        right: 40,
        child: _FloatingToast(message: message),
      ),
    );

    _toastEntry = entry;
    overlay.insert(entry);

    Future.delayed(const Duration(milliseconds: 1300), () {
      entry.remove();
      if (_toastEntry == entry) _toastEntry = null;
    });
  }

  Timer? _tick;

  Future<void> _loadClasses() async {
    final ok = await _hasInternet();
    if (!ok) {
      if (!mounted) return;
      setState(() => _offline = true);
      return;
    } else {
      if (mounted && _offline) setState(() => _offline = false);
    }
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      // 1. Fetch all non-archived classes
      final rows = await Supabase.instance.client
          .from('classes')
          .select('id, course, course_code, class_code, room, schedule, year_section, archived')
          .eq('professor_id', uid)
          .eq('archived', false)
          .order('created_at', ascending: false);

      // 2. Fetch all archived classes separately for the Archive page state
      final archRows = await Supabase.instance.client
          .from('classes')
          .select('id, course, course_code, class_code, room, schedule, year_section, archived')
          .eq('professor_id', uid)
          .eq('archived', true)
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
          yearSection: (m['year_section'] ?? '') as String,
        );
      }).toList();

      // For Archives
      final archList = (archRows as List).map((r) {
        final m = r as Map<String, dynamic>;
        return ClassItem(
          id: m['id'] as String,
          classCode: (m['class_code'] ?? '') as String,
          course: (m['course'] ?? '') as String,
          courseCode: (m['course_code'] ?? '') as String,
          professor: _prof?['professor_name'] ?? 'Professor',
          room: (m['room'] ?? '') as String,
          sched: (m['schedule'] ?? '') as String,
          session: 'Archived',
          yearSection: (m['year_section'] ?? '') as String,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _classes.clear();
        _classes.addAll(list);
        _archivedClasses.clear();
        _archivedClasses.addAll(archList);
        _sortClasses();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _offline = true);
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final students = <String>[
    'John Doe', 'Nicole Margarette', 'Trisha Lorraine', 'Arthur Morgan', 'Clark Kent', 'Lex Luthor', 'Lois Lane', 'Lana Lang', 'Tony Stark',
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
      final aSession = sessionPriority[a.session] ?? 99;
      final bSession = sessionPriority[b.session] ?? 99;
      final sessionCompare = aSession.compareTo(bSession);
      if (sessionCompare != 0) return sessionCompare;

      final aDay = _daysUntilFromSched(a.sched);
      final bDay = _daysUntilFromSched(b.sched);
      final dayCompare = aDay.compareTo(bDay);
      if (dayCompare != 0) return dayCompare;

      final aStart = _startMinutesFromSched(a.sched);
      final bStart = _startMinutesFromSched(b.sched);
      return aStart.compareTo(bStart);
    });
  }

  int _daysUntilFromSched(String sched) {
    final dayStr = sched.split(':').first.trim().toLowerCase();

    const map = {
      'sunday': DateTime.sunday, 'monday': DateTime.monday, 'tuesday': DateTime.tuesday, 'wednesday': DateTime.wednesday, 'thursday': DateTime.thursday, 'friday': DateTime.friday, 'saturday': DateTime.saturday,
    };

    final target = map[dayStr];
    if (target == null) return 999;

    final today = DateTime.now().weekday;
    return (target - today + 7) % 7;
  }

  int _startMinutesFromSched(String sched) {
    final parts = sched.split(':');
    if (parts.length < 2) return 9999;

    final timePart = parts.sublist(1).join(':').trim();
    final range = timePart.split(RegExp(r'\s*[-–]\s*'));
    if (range.length < 2) return 9999;

    final startStr = range.first.trim();
    return _toMinutes(startStr);
  }

  int _endMinutesFromSched(String sched) {
    final parts = sched.split(':');
    if (parts.length < 2) return 9999;

    final timePart = parts.sublist(1).join(':').trim();
    final range = timePart.split(RegExp(r'\s*[-–]\s*'));
    if (range.length < 2) return 9999;

    final endStr = range.last.trim();
    return _toMinutes(endStr);
  }

  int _toMinutes(String time) {
    final reg = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false);
    final m = reg.firstMatch(time.trim());
    if (m == null) return 9999;

    int hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final ampm = m.group(3)!.toUpperCase();

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
      'sunday': DateTime.sunday, 'monday': DateTime.monday, 'tuesday': DateTime.tuesday, 'wednesday': DateTime.wednesday, 'thursday': DateTime.thursday, 'friday': DateTime.friday, 'saturday': DateTime.saturday,
    };

    final schedWeekday = map[dayStr];
    if (schedWeekday == null) return 'Upcoming';

    int prevDay(int d) => d == DateTime.monday ? DateTime.sunday : d - 1;
    int nextDay(int d) => d == DateTime.sunday ? DateTime.monday : d + 1;

    final overnight = endMinRaw <= startMin;
    final endMin = overnight ? endMinRaw + 1440 : endMinRaw;
    final pendingWindowStart = startMin - 120;

    int? nowAdj;
    if (now.weekday == schedWeekday) {
      nowAdj = nowMin;
    } else if (pendingWindowStart < 0 && now.weekday == prevDay(schedWeekday)) {
      nowAdj = nowMin - 1440;
    } else if (overnight && now.weekday == nextDay(schedWeekday)) {
      nowAdj = nowMin + 1440;
    } else {
      return 'Upcoming';
    }
    if (nowAdj >= endMin) return 'Ended';
    if (nowAdj >= pendingWindowStart) return 'Pending';
    return 'Upcoming';
  }

  DateTime? _scheduleEndToday(String sched) {
    final now = DateTime.now();
    final dayStr = sched.split(':').first.trim().toLowerCase();

    const map = {
      'sunday': DateTime.sunday, 'monday': DateTime.monday, 'tuesday': DateTime.tuesday, 'wednesday': DateTime.wednesday, 'thursday': DateTime.thursday, 'friday': DateTime.friday, 'saturday': DateTime.saturday,
    };

    final schedWeekday = map[dayStr];
    if (schedWeekday == null) return null;
    if (now.weekday != schedWeekday) return null;

    final endMin = _endMinutesFromSched(sched);
    if (endMin == 9999) return null;

    final base = DateTime(now.year, now.month, now.day);
    return base.add(Duration(minutes: endMin));
  }

  Map<String, dynamic>? _prof;
  bool _loadingProf = true;
  String? _profErr;

  @override
  void initState() {
    super.initState();
    unRead = widget.unRead;

    _connSub = Connectivity().onConnectivityChanged.listen((_) async {
      await _updateOffline();
      if (!_offline && mounted) {
        await _loadProfessor();
        await _loadClasses();
      }
    });

    _updateOffline().then((_) async {
      if (_offline) return;
      await _loadProfessor();
      await _loadClasses();
      _setupRealtimeListener(); // Setup listener on startup
    });

    _tick = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!mounted) return;
      if (_offline) return;
      await _loadClasses();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _connSub?.cancel();
    _classesChannel?.unsubscribe(); // Cleanup listener
    super.dispose();
  }

  Future<void> _loadProfessor() async {
    final ok = await _hasInternet();
    if (!ok) {
      if (!mounted) return;
      setState(() {
        _offline = true;
        _loadingProf = false;
        _profErr = null;
      });
      return;
    } else {
      if (mounted && _offline) setState(() => _offline = false);
    }
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

  Widget _avatarWidget(double size) {
    final url = _prof?['avatar_url'] as String?;
    if (url == null || url.trim().isEmpty) return Image.asset('assets/avatar.png', width: size, height: size);
    return ClipRRect(borderRadius: BorderRadius.circular(size / 2), child: Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset('assets/avatar.png', width: size, height: size), loadingBuilder: (context, child, loadingProgress) { if (loadingProgress == null) return child; return SizedBox(width: size, height: size, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))); }));
  }

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
    final s = session.trim();

    final isEnded = s == 'Ended' || s == 'System Ended' || s == 'system ended';
    final isStarted = s == 'Session Started';
    final isPending = s == 'Pending';

    final showArrow = !isEnded && (isStarted || (isPending && _canStartFromSched10mins(sched)));

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
                  showArrow
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
                              await _loadClasses();
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
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Archive'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Share'),
                          ],
                        ),
                      ),
                    ],

                    onSelected: (value) async {
                      if (value == 'archive') {
                        final ok = await _confirmArchive();
                        if (!ok) return;

                        final s = session.trim();
                        final isStarted = s == 'Session Started';

                        if (isStarted) {
                          final ok2 = await _confirmArchiveStartedSessionEnd();
                          if (!ok2) return;

                          try {
                            await _endActiveSessionForClass(id);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to end session: $e')),
                            );
                            return;
                          }
                        }
                        onArchive();
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
                            await _loadClasses();
                          });
                        }
                      }

                      if (value == 'share') {
                        await _showShareClassCodeModal(classCode);
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
        return AlertDialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
  Future<bool> _confirmArchiveStartedSessionEnd() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Session is currently started',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Archiving this class will END the ongoing session. Continue?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End & Archive', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _endActiveSessionForClass(String classId) async {
    final sb = Supabase.instance.client;
    final sessionRow = await sb
        .from('class_sessions')
        .select('id')
        .eq('class_id', classId)
        .eq('status', 'started')
        .order('started_at', ascending: false)
        .maybeSingle();

    final sessionId = sessionRow?['id'] as String?;
    if (sessionId == null) return;

    await sb.from('class_sessions').update({
      'status': 'ended',
      'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final displayName = (_prof?['professor_name'] ?? 'Professor') as String;
    final firstName = displayName.trim().split(' ').first;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: screenHeight * .16, // Reduced height since info is gone
              decoration: const BoxDecoration(
                color: Color(0xFF004280),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome to Attendly',
                              style: TextStyle(color: Colors.white, fontSize: screenHeight * .016)
                            ),
                            Text(
                              _loadingProf ? 'Loading...' : 'Prof. $firstName!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: screenHeight * .025,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                IconButton(
                                  onPressed: () => widget.onOpenNotifications(),
                                  icon: const Icon(CupertinoIcons.bell),
                                  color: Colors.white,
                                ),
                                if (widget.unRead)
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
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(8),
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
                                    if (_prof == null) {
                                      await _loadProfessor();
                                    }
                                    await _loadClasses();
                                  });
                                },
                                icon: const Icon(CupertinoIcons.plus, size: 30),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Card removed
                ],
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final ok = await _hasInternet();
                  if (!ok) {
                    if (!mounted) return;
                    setState(() => _offline = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No internet connection'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)),
                    );
                    return;
                  }
                  setState(() => _offline = false);
                  await _loadProfessor();
                  await _loadClasses();
                },
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: screenHeight > 700 ? 20 : 15),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'My Classes',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: screenHeight * .017),
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
                            size: screenHeight * .025,
                          ),
                        ),
                      ],
                    ),
                    ..._classes.asMap().entries.map((entry) {
                      final i = entry.key;
                      final c = entry.value;
                      final profName = _loadingProf ? 'Loading...' : ((_prof?['professor_name'] as String?) ?? 'Professor');

                      return classCard(
                        c.id,
                        c.yearSection,
                        c.course,
                        c.classCode,
                        c.courseCode,
                        profName,
                        c.room,
                        c.sched,
                        c.session,
                        screenHeight,
                            () async {
                          await Supabase.instance.client.from('classes').update({'archived': true}).eq('id', c.id);
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
      if (mounted) Navigator.pop(context);
    }
  }
}
