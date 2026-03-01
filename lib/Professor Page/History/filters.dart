import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
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
  bool _offline = false;
  StreamSubscription? _connSub;
  RealtimeChannel? _realtimeChannel; // ✅ Variable for Realtime

  Future<bool> _hasInternet() async {
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) return false;
    return InternetConnection().hasInternetAccess;
  }

  void _showNoInternetSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No internet connection'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  final supabase = Supabase.instance.client;

  bool _loading = true;
  String? _err;

  List<String> classOptions = ['All'];
  final TextEditingController searchController = TextEditingController();

  String selectedStatus = 'All';
  String selectedClass = 'All';

  DateTimeRange? selectedRange;

  List<AttendanceRecord> allRecords = [];
  List<AttendanceRecord> filteredRecords = [];


  int _currentPage = 1;
  final int _itemsPerPage = 10; 

  @override
  void initState() {
    super.initState();
    _connSub = Connectivity().onConnectivityChanged.listen((_) async {
      final ok = await _hasInternet();
      if (!mounted) return;
      setState(() => _offline = !ok);
    });

    _loadSessions();
    _setupRealtime(); // ✅ Initialize Realtime listener
  }

  // ✅ Supabase Realtime setup
  void _setupRealtime() {
    final profId = supabase.auth.currentUser?.id;
    if (profId == null) return;

    _realtimeChannel = supabase
        .channel('public:attendance_history')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance_history',
          callback: (payload) {
            debugPrint('Realtime Change Detected: ${payload.toString()}');
            _loadSessions(isRealtime: true); // Refresh without full loading state
          },
        )
        .subscribe();
  }

  Future<void> _loadSessions({bool isRealtime = false}) async {
    final ok = await _hasInternet();
    if (!ok) {
      if (!isRealtime) {
        if (!mounted) return;
        setState(() {
          _offline = true;
          _loading = false;
          _err = null;
        });
        _showNoInternetSnack();
      }
      return;
    }

    if (!mounted) return;
    if (!isRealtime) {
      setState(() {
        _offline = false;
        _loading = true;
        _err = null;
      });
    }

    try {
      final profId = supabase.auth.currentUser?.id;
      if (profId == null) throw 'No logged in professor.';

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

      final seen = <String>{};
      final list = <AttendanceRecord>[];

      for (final r in raw) {
        final sessionId = (r['session_id'] ?? '').toString();
        if (sessionId.isEmpty) continue;
        if (seen.contains(sessionId)) continue;
        seen.add(sessionId);

        final cs = r['class_sessions'] as Map<String, dynamic>?;
        if (cs == null) continue;

        final cls = cs['classes'] as Map<String, dynamic>?;
        if (cls == null) continue;

        final classId = (cls['id'] ?? '').toString();
        final courseName = (cls['course'] ?? '').toString();
        final courseCode = (cls['course_code'] ?? '').toString();

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
      
      final query = searchController.text.trim().toLowerCase();
      filteredRecords = allRecords.where((record) {
        final matchesSearch = record.courseName.toLowerCase().contains(query) ||
            record.courseCode.toLowerCase().contains(query);

        final matchesClass =
            selectedClass == 'All' || record.courseName == selectedClass;

        final matchesDate = selectedRange == null || (() {
          final d = DateTime(record.date.year, record.date.month, record.date.day);
          final start = DateTime(selectedRange!.start.year, selectedRange!.start.month, selectedRange!.start.day);
          final end = DateTime(selectedRange!.end.year, selectedRange!.end.month, selectedRange!.end.day);
          return !d.isBefore(start) && !d.isAfter(end);
        })();

        return matchesSearch && matchesClass && matchesDate;
      }).toList();

      classOptions = [
        'All',
        ...{ for (final r in allRecords) r.courseName }
            .where((x) => x.trim().isNotEmpty && x != '-')
      ];

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!isRealtime) {
        if (!mounted) return;
        setState(() {
          _offline = true;
          _loading = false;
          _err = null;
        });
        _showNoInternetSnack();
      }
    }
  }

  void applyFilters() {
    final query = searchController.text.trim().toLowerCase();

    setState(() {
      filteredRecords = allRecords.where((record) {
        final matchesSearch = record.courseName.toLowerCase().contains(query) ||
            record.courseCode.toLowerCase().contains(query);

        final matchesClass =
            selectedClass == 'All' || record.courseName == selectedClass;

        final matchesDate = selectedRange == null || (() {
          final d = DateTime(record.date.year, record.date.month, record.date.day);
          final start = DateTime(selectedRange!.start.year, selectedRange!.start.month, selectedRange!.start.day);
          final end = DateTime(selectedRange!.end.year, selectedRange!.end.month, selectedRange!.end.day);
          return !d.isBefore(start) && !d.isAfter(end);
        })();

        return matchesSearch && matchesClass && matchesDate;
      }).toList();

      _currentPage = 1;
    });
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
              maxDate: DateTime.now(),
              selectionMode: DateRangePickerSelectionMode.range,
              startRangeSelectionColor: const Color(0xFF004280),
              endRangeSelectionColor: const Color(0xFF004280),
              rangeSelectionColor: const Color(0xFF004280),
              rangeTextStyle: const TextStyle(color: Colors.white),
              toggleDaySelection: true,
              todayHighlightColor: const Color(0xFF004280),
              backgroundColor: Colors.white,
              headerStyle: const DateRangePickerHeaderStyle(
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

                  final DateTime end = r.endDate ?? start;
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
                  backgroundColor: const Color(0xFF004280)
              ),
              onPressed: () {
                setState(() => selectedRange = temp);
                applyFilters();
                Navigator.pop(context);
              },
              child: const Text('Apply', style: TextStyle(color: Colors.white),),
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
    _connSub?.cancel();
    if (_realtimeChannel != null) {
      supabase.removeChannel(_realtimeChannel!); // ✅ Cleanup Realtime
    }
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final int totalPages = (filteredRecords.length / _itemsPerPage).ceil();
    final List<AttendanceRecord> paginatedRecords = filteredRecords
        .skip((_currentPage - 1) * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

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
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
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

                const SizedBox(height: 10),

                Row(
                  children: [
                    // Date Filter Row
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.4,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: pickDateRangeDialogCalendar,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  selectedRange == null ? 'Select date' : _fmtRange(selectedRange!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
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
                              const SizedBox(width: 5),
                              const Icon(CupertinoIcons.calendar, color: Colors.black,)
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
                          dropdownColor: Colors.white,
                          underline: const SizedBox(),
                          iconEnabledColor: Colors.black,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black,
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

                const SizedBox(height: 10),

                // Title
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Record Details',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: screenHeight > 700 ? 15 : 14),
                    ),
                    screenHeight > 700 ? const SizedBox(height: 5) : const SizedBox(),
                  ],
                ),

                SizedBox(height: screenHeight > 700 ? 10 : 5),

                // LIST AREA
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : (_err != null)
                      ? Center(child: Text('Error: $_err'))
                      : RefreshIndicator(
                    onRefresh: () async {
                      await _loadSessions();
                    },
                    child: paginatedRecords.isEmpty 
                        ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No records found.')),
                      ],
                    )
                        : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: paginatedRecords.length, 
                      itemBuilder: (context, index) {
                        final record = paginatedRecords[index]; 
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
                                    final ok = await _hasInternet();
                                    if (!ok) {
                                      if (!mounted) return;
                                      _showNoInternetSnack();
                                      return;
                                    }
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
                ),

                if (filteredRecords.isNotEmpty && !_loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Showing ${((_currentPage - 1) * _itemsPerPage) + 1} - ${(_currentPage * _itemsPerPage).clamp(0, filteredRecords.length)} of ${filteredRecords.length}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                        Row(
                          children: [
                            InkWell(
                              onTap: _currentPage > 1
                                  ? () => setState(() => _currentPage--)
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _currentPage > 1 ? Colors.grey[200] : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(Icons.chevron_left, size: 20, color: _currentPage > 1 ? Colors.black : Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Page $_currentPage of $totalPages',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: _currentPage < totalPages
                                  ? () => setState(() => _currentPage++)
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _currentPage < totalPages ? Colors.grey[200] : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(Icons.chevron_right, size: 20, color: _currentPage < totalPages ? Colors.black : Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
