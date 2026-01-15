import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  DateTime? selectedDate;

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

      // Get ended sessions (or all sessions if you want)
      final rows = await supabase
          .from('class_sessions')
          .select('''
          id,
          started_at,
          class_id,
          classes:classes!inner(
            id,
            course,
            course_code,
            professor_id
          )
        ''')
          .eq('classes.professor_id', profId)
          .order('started_at', ascending: false);

      final raw = (rows as List).cast<Map<String, dynamic>>();

      final list = <AttendanceRecord>[];

      for (final r in raw) {
        final cls = r['classes'] as Map<String, dynamic>?; // can be null

        // if join failed or no permission, skip row
        if (cls == null) continue;

        final sessionId = (r['id'] ?? '').toString();
        final startedAtStr = (r['started_at'] ?? '').toString();

        // skip if missing essentials
        if (sessionId.isEmpty || startedAtStr.isEmpty) continue;

        final classId = (cls['id'] ?? '').toString();
        final courseName = (cls['course'] ?? '').toString();
        final courseCode = (cls['course_code'] ?? '').toString();

        // skip if classId missing
        if (classId.isEmpty) continue;

        list.add(
          AttendanceRecord(
            sessionId: sessionId,
            classId: classId,
            courseName: courseName,
            courseCode: courseCode.isEmpty ? '-' : courseCode,
            date: DateTime.parse(startedAtStr),
          ),
        );
      }

      allRecords = list;
      filteredRecords = List.from(allRecords);

      classOptions = [
        'All',
        ...{ for (final r in allRecords) r.courseCode }
            .where((x) => x.trim().isNotEmpty && x != '-')
      ];

      if (!mounted) return;
      setState(() => _loading = false);

      applyFilters(); // refresh filter view
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

        final matchesDate = selectedDate == null ||
            (record.date.year == selectedDate!.year &&
                record.date.month == selectedDate!.month &&
                record.date.day == selectedDate!.day);

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

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),

      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,     // header & selected date
              onPrimary: Colors.white,  // header text
              surface: Colors.white,    // ✅ dialog background
              onSurface: Colors.black,  // body text
            ),
            dialogBackgroundColor: Colors.white, // ✅ ensures white bg
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
      applyFilters();
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
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
                          width: MediaQuery.of(context).size.width * 0.35,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFEAEAEA),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: pickDate,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedDate == null
                                      ? 'Select date'
                                      : _fmt(selectedDate!),
                                  style: const TextStyle(fontSize: 12, color: Colors.black),
                                ),
                                if (selectedDate != null)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => selectedDate = null);
                                      applyFilters();
                                    },
                                    child: const Icon(Icons.close, size: 16),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(width: screenHeight * .09),

                      // Dropdown
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.3,
                          child: DropdownButton<String>(
                            isExpanded: true, // important so it uses the SizedBox width
                            dropdownColor: Colors.white,
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            value: selectedClass,
                            items: classOptions.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c,
                                  overflow: TextOverflow.ellipsis, // prevent long text overflow
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
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : (_err != null)
                      ? Center(child: Text('Error: $_err'))
                      : (filteredRecords.isEmpty
                      ? const Center(child: Text('No records found.'))
                      : ListView.builder(
                    itemCount: filteredRecords.length,
                    itemBuilder: (context, index) {
                      final record = filteredRecords[index];
                      final bg = index.isEven ? Colors.white : Colors.grey[300];

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
                                      fileLabel: '${record.courseCode}_${record.date.toIso8601String().split("T")[0]}',
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
                  )),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

