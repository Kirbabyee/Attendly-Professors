import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import 'export_function.dart';

class AttendanceRecord {
  final String sessionId;   // class_sessions.id
  final String classId;     // classes.id
  final String courseName;  // classes.course
  final String courseCode;  // classes.course_code
  final DateTime date;      // class_sessions.started_at

  AttendanceRecord({
    required this.sessionId,
    required this.classId,
    required this.courseName,
    required this.courseCode,
    required this.date,
  });
}

class DataFilter extends StatefulWidget {
  const DataFilter({super.key});

  @override
  State<DataFilter> createState() => _DataFilterState();
}

class _DataFilterState extends State<DataFilter> {
  final supabase = Supabase.instance.client;

  bool _loading = true;
  String? _err;

  List<String> classOptions = ['All'];

  final TextEditingController searchController = TextEditingController();

  String selectedStatus = 'All'; // chips: All/Present/Late/Absent
  String selectedClass = 'All';  // dropdown: Filter by class

  DateTimeRange? selectedRange;

  List<AttendanceRecord> allRecords = [];
  List<AttendanceRecord> filteredRecords = [];


  @override
  void initState() {
    super.initState();
    _loadSessions(); // ✅ load from DB instead of hardcoded list
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final profId = supabase.auth.currentUser?.id;
      if (profId == null) throw 'No logged in professor.';

      // ✅ Pull from history, join to session + class
      final rows = await supabase
          .from('attendance_history')
          .select('''
          session_id,
          changed_at,
          class_sessions:class_sessions!inner(
            id,
            started_at,
            class_id,
            classes:classes!inner(
              id,
              course,
              course_code,
              professor_id
            )
          )
        ''')
          .eq('class_sessions.classes.professor_id', profId)
          .order('changed_at', ascending: false);

      final raw = (rows as List).cast<Map<String, dynamic>>();

      // ✅ Dedup by session_id (latest changed_at per session)
      final seen = <String>{};
      final list = <AttendanceRecord>[];

      for (final r in raw) {
        final sessionId = (r['session_id'] ?? '').toString();
        if (sessionId.isEmpty) continue;
        if (seen.contains(sessionId)) continue; // keep latest only
        seen.add(sessionId);

        final cs = r['class_sessions'] as Map<String, dynamic>?;
        if (cs == null) continue;

        final cls = cs['classes'] as Map<String, dynamic>?;
        if (cls == null) continue;

        final classId = (cls['id'] ?? '').toString();
        final courseName = (cls['course'] ?? '').toString();
        final courseCode = (cls['course_code'] ?? '').toString();

        // ✅ date source: started_at if available, else changed_at (history timestamp)
        final startedAt = cs['started_at'];
        final changedAt = r['changed_at'];

        DateTime date;
        if (startedAt != null && startedAt.toString().isNotEmpty) {
          date = DateTime.parse(startedAt.toString());
        } else if (changedAt != null && changedAt.toString().isNotEmpty) {
          date = DateTime.parse(changedAt.toString());
        } else {
          continue;
        }

        list.add(
          AttendanceRecord(
            sessionId: sessionId,
            classId: classId,
            courseName: courseName,
            courseCode: courseCode.isEmpty ? '-' : courseCode,
            date: date,
          ),
        );
      }

      allRecords = list;
      filteredRecords = List.from(allRecords);

      classOptions = [
        'All',
        ...{ for (final r in allRecords) r.courseName }
            .where((x) => x.trim().isNotEmpty && x != '-')
      ];

      if (!mounted) return;
      setState(() => _loading = false);
      applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  void applyFilters() {
    final query = searchController.text.trim().toLowerCase();

    setState(() {
      filteredRecords = allRecords.where((record) {
        final matchesSearch = record.courseName.toLowerCase().contains(query) ||
            record.courseCode.toLowerCase().contains(query);

        final matchesClass =
            selectedClass == 'All' || record.courseCode == selectedClass;

        final matchesDate = selectedRange == null || (() {
          final d = DateTime(record.date.year, record.date.month, record.date.day);
          final start = DateTime(selectedRange!.start.year, selectedRange!.start.month, selectedRange!.start.day);
          final end = DateTime(selectedRange!.end.year, selectedRange!.end.month, selectedRange!.end.day);
          return !d.isBefore(start) && !d.isAfter(end);
        })();

        return matchesSearch && matchesClass && matchesDate;
      }).toList();
    });
  }

  Future<void> _exportSessionCsv(AttendanceRecord record) async {
    // pull attendance rows for this session
    final rows = await supabase
        .from('attendance')
        .select('''
        status,
        time_in,
        students(first_name,last_name,student_number)
      ''')
        .eq('session_id', record.sessionId)
        .order('time_in', ascending: true);

    final list = (rows as List).cast<Map<String, dynamic>>();

    // build CSV
    final b = StringBuffer();
    b.writeln('Course,Course Code,Date,Student No,Student Name,Status,Time In');

    for (final r in list) {
      final s = (r['students'] as Map<String, dynamic>?);
      final name = s == null
          ? 'Unknown'
          : '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim();

      final studNo = (s?['student_number'] ?? '').toString();
      final status = (r['status'] ?? '').toString();
      final timeIn = (r['time_in'] ?? '').toString();

      String esc(String v) => '"${v.replaceAll('"', '""')}"';

      b.writeln([
        esc(record.courseName),
        esc(record.courseCode),
        esc(record.date.toIso8601String().split('T').first),
        esc(studNo),
        esc(name),
        esc(status),
        esc(timeIn),
      ].join(','));
    }

    // save & share
    final dir = await getTemporaryDirectory();
    final fileName =
        'attendance_${record.courseCode}_${record.date.toIso8601String().split("T").first}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(b.toString());

    await Share.shareXFiles([XFile(file.path)], text: 'Attendance CSV');
  }

  Future<void> pickDateRangeDialogCalendar() async {
    DateTimeRange? temp = selectedRange;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            'Select date range',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: SizedBox(
            width: 340,
            height: 360,
            child: SfDateRangePicker(
              selectionMode: DateRangePickerSelectionMode.range,
              // Range color
              startRangeSelectionColor: Color(0xFF004280),
              endRangeSelectionColor: Color(0xFF004280),
              rangeSelectionColor: Color(0xFF004280),
              // Ranged date color
              rangeTextStyle: TextStyle(color: Colors.white),
              toggleDaySelection: true,
              todayHighlightColor: Color(0xFF004280),
              backgroundColor: Colors.white,
              headerStyle: DateRangePickerHeaderStyle(
                backgroundColor: Colors.white
              ),
              initialSelectedRange: temp == null
                  ? null
                  : PickerDateRange(temp!.start, temp!.end),
              onSelectionChanged: (args) {
                final r = args.value;

                if (r is PickerDateRange) {
                  final DateTime? start = r.startDate;
                  if (start == null) return;

                  final DateTime end = r.endDate ?? start; // ✅ non-null end
                  temp = DateTimeRange(start: start, end: end);
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',style: TextStyle(color: Colors.black),),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF004280)
              ),
              onPressed: () {
                setState(() => selectedRange = temp);
                applyFilters();
                Navigator.pop(context);
              },
              child: Text('Apply', style: TextStyle(color: Colors.white),),
            ),
          ],
        );
      },
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtRange(DateTimeRange r) => '${_fmt(r.start)} - ${_fmt(r.end)}';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: screenHeight > 700 ? 350 : 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Search
                Center(
                  child: SizedBox(
                    height: screenHeight > 700 ? 40 : 35,
                    child: TextField(
                      style: TextStyle(
                        fontSize: screenHeight > 700 ? 16 : 14
                      ),
                      controller: searchController,
                      onChanged: (_) => applyFilters(),
                      decoration: InputDecoration(
                        hintStyle: TextStyle(
                          fontSize: screenHeight > 700 ? 16 : 14
                        ),
                        hintText: 'Search course',
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 10,),

                Container(
                  child: Row(
                    children: [
                      // Date Filter Row
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.4,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: pickDateRangeDialogCalendar,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  child: Text(
                                    selectedRange == null ? 'Select date' : _fmtRange(selectedRange!),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Colors.black),
                                  ),
                                ),
                                if (selectedRange != null)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => selectedRange = null);
                                      applyFilters();
                                    },
                                    child: const Icon(Icons.close, size: 16),
                                  ),
                                SizedBox(width: 5,),
                                Icon(CupertinoIcons.calendar, color: Colors.black,)
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(width: screenWidth * .14),

                      // Dropdown
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: screenWidth * 0.35,
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          height: 42,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            isExpanded: true,
                            dropdownColor: Colors.white, // dropdown list bg
                            underline: const SizedBox(), // ❌ remove default underline
                            iconEnabledColor: Colors.black, // arrow color
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black, // text color
                            ),
                            value: selectedClass,
                            items: classOptions.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => selectedClass = value);
                              applyFilters();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 10,),

                // Title + Chips
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Record Details',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: screenHeight > 700 ? 15 : 14),
                    ),
                    screenHeight > 700 ? SizedBox(height: 5) : SizedBox(),
                  ],
                ),

                SizedBox(height: screenHeight > 700 ? 10 : 5),

                // ✅ LIST AREA (scrollable)
                // ✅ LIST AREA (scrollable) + PULL TO REFRESH
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : (_err != null)
                      ? Center(child: Text('Error: $_err'))
                      : RefreshIndicator(
                    onRefresh: () async {
                      await _loadSessions(); // reload from DB
                    },
                    child: filteredRecords.isEmpty
                        ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No records found.')),
                      ],
                    )
                        : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filteredRecords.length,
                      itemBuilder: (context, index) {
                        final record = filteredRecords[index];
                        final bg = index.isEven ? Colors.white : Colors.grey[200];

                        return Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: bg,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 2,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: ListTile(
                              title: Text(
                                record.courseName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: screenHeight > 700 ? 12 : 11,
                                ),
                              ),
                              subtitle: Text(
                                '${record.courseCode} • ${record.date.toIso8601String().split("T")[0]}',
                                style: TextStyle(
                                  fontSize: screenHeight > 700 ? 11 : 10,
                                ),
                              ),
                              trailing: SizedBox(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    backgroundColor: const Color(0xFF004280),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadiusGeometry.circular(6),
                                    ),
                                    side: BorderSide.none,
                                  ),
                                  onPressed: () async {
                                    try {
                                      await exportSessionToExcel(
                                        sessionId: record.sessionId,
                                        fileLabel:
                                        '${record.courseCode}_${record.date.toIso8601String().split("T")[0]}',
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Export failed: $e')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.download, size: 14, color: Colors.white),
                                  label: const Text(
                                    'Export CSV',
                                    style: TextStyle(fontSize: 10, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

