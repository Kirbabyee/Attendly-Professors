import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:professor/Professor%20Page/attendance/class_session.dart';

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

  final List<ClassItem> _classes = [
    ClassItem(
      course: 'Introduction to Human Computer Interaction',
      classCode: 'CCS101',
      professor: 'Mr. Leviticio Dowell',
      room: 'Room 301',
      sched: 'Monday: 9:00 AM - 11:00 AM',
      session: 'Pending',
    ),
    ClassItem(
      course: 'Information Assurance and Security 2',
      classCode: 'IT 108',
      professor: 'Mr. Leviticio Dowell',
      room: 'Room 303',
      sched: 'Thursday: 4:30 PM - 7:30 PM',
      session: 'Upcoming',
    ),
    ClassItem(
      course: 'Software Engineering 1',
      classCode: 'IT 101',
      professor: 'Mr. Leviticio Dowell',
      room: 'Room 301',
      sched: 'Wednesday: 2:00 PM - 5:00 PM',
      session: 'Upcoming',
    ),
  ];

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
      final aDay = _dayRankFromSched(a.sched);
      final bDay = _dayRankFromSched(b.sched);
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

  int _startMinutesFromSched(String sched) {
    // Get "9:00 AM" from "Monday: 9:00 AM - 11:00 AM"
    final parts = sched.split(':');
    if (parts.length < 2) return 9999;

    final timePart = parts.sublist(1).join(':').trim(); // in case course has ":" etc
    final startStr = timePart.split('-').first.trim();  // "9:00 AM"

    return _toMinutes(startStr);
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


  @override
  void initState() {
    super.initState();
    _sortClasses();
    unRead = widget.unRead;
    _sortClasses();
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
  Widget classCard(String course,
      String classCode,
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
                      Text(classCode),
                      SizedBox(height: 10,),
                    ],
                  ),
                  session == 'Pending' || session == 'Session Started'
                      ? IconButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClassSession(
                            session: session,
                            students: students,
                            onSessionStarted: () {
                              setState(() {
                                final idx = _classes.indexWhere((c) => c.classCode == classCode);
                                if (idx != -1) {
                                  final old = _classes[idx];
                                  _classes[idx] = old.copyWith(session: 'Session Started');
                                  _sortClasses();
                                }
                              });
                            },
                            onSessionEnded: () {
                              setState(() {
                                final idx = _classes.indexWhere((c) => c.classCode == classCode);
                                if (idx != -1) {
                                  final old = _classes[idx];
                                  _classes[idx] = old.copyWith(session: 'Ended');
                                  _sortClasses();
                                }
                              });
                            },
                          ),
                        ),
                      );
                    },
                    icon: Icon(CupertinoIcons.right_chevron, size: screenHeight > 700 ? 16 : 14),
                  )
                      : SizedBox(),
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
                              course: course,
                              classCode: classCode,
                              professor: professor,
                              room: room,
                              sched: sched,
                              session: session,
                            ),
                          ),
                        );

                        if (updated != null) {
                          setState(() {
                            final idx = _classes.indexWhere((c) => c.classCode == classCode);
                            if (idx != -1) {
                              _classes[idx] = updated;
                              _sortClasses();
                            }
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
    print(screenWidth);
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
                              'Leviticio!',
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
                              final newClass = await showModalBottomSheet<ClassItem>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const CreateClassSheet(),
                              );

                              if (newClass != null) {
                                setState(() {
                                  _classes.add(newClass);
                                  _sortClasses();
                                });
                              }
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

                    return classCard(
                      c.course,
                      c.classCode,
                      c.professor,
                      c.room,
                      c.sched,
                      c.session,
                      screenHeight,
                        () {
                          setState(() {
                            _archivedClasses.add(_classes[i]);
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
}
