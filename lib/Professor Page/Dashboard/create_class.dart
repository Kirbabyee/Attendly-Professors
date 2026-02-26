import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../professor_session.dart';
import 'class_item.dart';

class CreateClassSheet extends StatefulWidget {
  final ClassItem? initialItem; //  optional for edit

  const CreateClassSheet({super.key, this.initialItem});

  @override
  State<CreateClassSheet> createState() => _CreateClassSheetState();
}

class _CreateClassSheetState extends State<CreateClassSheet> {
  List<Map<String, dynamic>> _wifiList = []; // Listahan ng lahat ng wifi sa campus
  String _autoWifiSSID = 'ClassroomWifi'; //  Default to ClassroomWifi

  List<Map<String, dynamic>> _roomSchedules = []; // Schedules taken in this room
  bool _loadingSchedules = false;

  List<Map<String, dynamic>> _availableSubjects = []; // Subjects for dropdown
  bool _loadingSubjects = false;

  List<Map<String, dynamic>> _availablePrograms = []; //  Programs from DB
  bool _loadingPrograms = false;

  String? _conflictError; // ✅ Real-time conflict error message
  bool _isValidating = false;

  final supabase = Supabase.instance.client;

  // Pre-defined room list (Value validation)
  final List<String> _rooms = [
    for (int i = 100; i <= 110; i++) i.toString(),
    for (int i = 200; i <= 210; i++) i.toString(),
    for (int i = 300; i <= 310; i++) i.toString(),
    '400', '410'
  ];

  Future<void> _loadCampusWifi() async {
    try {
      final data = await supabase.from('campus_networks').select('ssid, room_name');
      if (!mounted) return;
      setState(() {
        _wifiList = List<Map<String, dynamic>>.from(data);
      });
      if (_room.text.isNotEmpty) {
        _updateAutoWifi(_room.text);
        _fetchRoomSchedules(_room.text);
      }
    } catch (e) {
      debugPrint('Error loading wifi: $e');
    }
  }

  Future<void> _loadSubjects() async {
    if (!mounted) return;
    setState(() => _loadingSubjects = true);
    try {
      final prof = await ProfessorSession.get();
      final department = prof?['department'];

      var query = supabase.from('subjects').select('course_code, course_name');
      if (department != null && department.toString().isNotEmpty) {
        query = query.eq('department', department);
      }

      final data = await query.order('course_name');
      if (!mounted) return;
      setState(() {
        _availableSubjects = List<Map<String, dynamic>>.from(data);
        _loadingSubjects = false;
      });
    } catch (e) {
      debugPrint('Error loading subjects: $e');
      if (mounted) setState(() => _loadingSubjects = false);
    }
  }

  Future<void> _loadPrograms() async {
    if (!mounted) return;
    setState(() => _loadingPrograms = true);
    try {
      final data = await supabase
          .from('programs')
          .select('program_abbr, program_name')
          .order('program_abbr');
      
      if (!mounted) return;
      setState(() {
        _availablePrograms = List<Map<String, dynamic>>.from(data);
        _loadingPrograms = false;
      });
    } catch (e) {
      debugPrint('Error loading programs: $e');
      if (mounted) setState(() => _loadingPrograms = false);
    }
  }

  void _updateAutoWifi(String roomValue) {
    setState(() {
      //  Set to ClassroomWifi for now
      _autoWifiSSID = 'ClassroomWifi';
    });
  }

  Future<void> _fetchRoomSchedules(String roomNum) async {
    final roomVal = roomNum.trim();
    if (roomVal.isEmpty) {
      setState(() => _roomSchedules = []);
      return;
    }

    setState(() => _loadingSchedules = true);

    try {
      // Prepend "Room " for DB query
      final roomStr = 'Room $roomVal';
      var query = supabase
          .from('classes')
          .select('day_of_week, start_time, end_time, course, professor_id')
          .eq('room', roomStr)
          .eq('archived', false);

      if (isEdit) {
        query = query.neq('id', widget.initialItem!.id);
      }

      final res = await query;
      if (!mounted) return;
      setState(() {
        _roomSchedules = List<Map<String, dynamic>>.from(res);
        _loadingSchedules = false;
      });
      _updateScheduleConflict(); // ✅ Trigger validation after fetching schedules
    } catch (e) {
      debugPrint('Error fetching room schedules: $e');
      if (mounted) setState(() => _loadingSchedules = false);
    }
  }

  // ✅ REAL-TIME CONFLICT VALIDATION
  Future<void> _updateScheduleConflict() async {
    if (_selectedDay == null || _room.text.isEmpty) {
      if (mounted) setState(() => _conflictError = null);
      return;
    }

    if (mounted) setState(() => _isValidating = true);

    final conflicts = await _checkRoomConflicts();

    if (!mounted) return;
    setState(() {
      if (conflicts.isNotEmpty) {
        _conflictError = "Conflict detected with: ${conflicts.first}";
      } else {
        _conflictError = null;
      }
      _isValidating = false;
    });
  }

  Future<bool> _confirmSave({required bool isEdit}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(isEdit ? 'Save changes?' : 'Create this class?'),
        content: Text(
          isEdit
              ? 'This will update the class information.'
              : 'This will create a new class.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004280),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isEdit ? 'Save' : 'Create', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  int _to24hMinutes(int hour12, int minute, bool isAm) {
    var h = hour12 % 12;
    if (!isAm) h += 12;
    return h * 60 + minute;
  }

  int _classDurationMinutes() {
    final startMin = _to24hMinutes(_startHour, _startMinute, _startIsAm);
    final endMin = _to24hMinutes(_endHour, _endMinute, _endIsAm);

    var diff = endMin - startMin;
    if (diff <= 0) diff += 24 * 60;
    return diff;
  }

  String _formatDurationPretty(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}hr';
    return '${h}hr ${m}min';
  }

  Future<bool> _confirmOvernightDuration({
    required bool isEdit,
    required String prettyDuration,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Confirm duration'),
        content: Text(
          'End time is earlier than start time, so this class will be treated as an overnight class.\n\n'
              'Are you sure you want to ${isEdit ? "edit" : "create"} this class to a $prettyDuration class?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004280),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  late final bool isEdit = widget.initialItem != null;

  bool _hasChanges() {
    if (!isEdit) return true;

    final item = widget.initialItem!;
    final currentYearSection = '${_selectedProgram?.toUpperCase()} ${_selectedYear}-${_selectedSection?.toUpperCase()}';
    // Check with "Room " prefix
    final currentRoom = 'Room ${_room.text.trim()}';
    final currentSchedule = '$_selectedDay: ${_formatTime(_startHour, _startMinute, _startIsAm)} - ${_formatTime(_endHour, _endMinute, _endIsAm)}';

    return _className.text.trim() != item.course ||
        _courseCode.text.trim().toUpperCase() != item.courseCode ||
        currentYearSection != item.yearSection ||
        currentRoom != item.room ||
        currentSchedule != item.sched;
  }

  (int, int, bool) _parseTime(String time) {
    time = time.trim();

    // Check para sa 12-hour format (e.g., "08:00 AM" o "12:00 PM")
    final reg12 = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false);
    final m12 = reg12.firstMatch(time);
    if (m12 != null) {
      final hour = int.parse(m12.group(1)!);
      final minute = int.parse(m12.group(2)!);
      final am = m12.group(3)!.toUpperCase() == 'AM';
      return (hour, minute, am);
    }

    // Check para sa 24-hour format mula sa database (e.g., "13:00" o "13:00:00")
    final reg24 = RegExp(r'^(\d{1,2}):(\d{2})(:\d{2})?$');
    final m24 = reg24.firstMatch(time);
    if (m24 != null) {
      final hour = int.parse(m24.group(1)!);
      final minute = int.parse(m24.group(2)!);
      final am = hour < 12;

      int hour12 = hour % 12;
      if (hour12 == 0) hour12 = 12; // Handle 00:00 to 12 AM and 12:00 to 12 PM
      return (hour12, minute, am);
    }

    // Default to Midnight kung totally sira ang string para hindi mag-crash
    debugPrint("Failed to parse time: $time. Defaulting to 12:00 AM.");
    return (12, 0, true);
  }

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _randomCode({int len = 7}) {
    final now = DateTime.now().microsecondsSinceEpoch;
    var x = now;
    final b = StringBuffer();
    for (var i = 0; i < len; i++) {
      x = (x * 1103515245 + 12345) & 0x7fffffff;
      final idx = x % _alphabet.length;
      b.write(_alphabet[idx]);
    }
    return b.toString();
  }

  Future<bool> _classCodeExists(String code) async {
    final res = await supabase
        .from('classes')
        .select('id')
        .eq('class_code', code)
        .limit(1);

    return (res as List).isNotEmpty;
  }

  Future<String> _generateUniqueClassCode() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = _randomCode(len: 7);
      final exists = await _classCodeExists(code);
      if (!exists) return code;
    }
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = _randomCode(len: 9);
      final exists = await _classCodeExists(code);
      if (!exists) return code;
    }
    throw Exception('Could not generate unique class code. Try again.');
  }

  Future<void> _ensureAutoClassCode() async {
    if (isEdit || _classCode.text.isNotEmpty) return;
    try {
      final code = await _generateUniqueClassCode();
      if (!mounted) return;
      setState(() {
        _classCode.text = code;
      });
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadCampusWifi(); 
    _loadSubjects(); 
    _loadPrograms(); //  Load programs from DB

    _room.addListener(() {
      _updateAutoWifi(_room.text);
      _fetchRoomSchedules(_room.text);
    });

    final item = widget.initialItem;
    if (item != null) {
      _className.text = item.course;
      _courseCode.text = item.courseCode;

      // Strip "Room " prefix when loading into the dropdown variable
      _room.text = item.room
          .replaceFirst(RegExp(r'^\s*Room\s+', caseSensitive: false), '')
          .trim();

      _selectedDay = item.sched.split(':').first.trim();

      final timePart = item.sched.split(':').sublist(1).join(':').trim();
      final startStr = timePart.split('-').first.trim();
      final endStr = timePart.split('-').last.trim();

      final start = _parseTime(startStr);
      _startHour = start.$1; _startMinute = start.$2; _startIsAm = start.$3;

      final end = _parseTime(endStr);
      _endHour = end.$1; _endMinute = end.$2; _endIsAm = end.$3;

      final raw = item.yearSection ?? ''; 
      if (raw.isNotEmpty) {
        final m = RegExp(r'^(\w+)\s+(\d)\s*[- ]\s*([A-Z])$').firstMatch(raw.toUpperCase());
        if (m != null) {
          _selectedProgram = m.group(1);
          _selectedYear = m.group(2);
          _selectedSection = m.group(3);
        }
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureAutoClassCode());
  }

  final List<String> _days = const [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  final List<String> _years = const ['1', '2', '3', '4'];
  final List<String> _sections = const ['A', 'B', 'C', 'D'];

  String? _selectedProgram, _selectedYear, _selectedSection, _selectedDay;
  final _formKey = GlobalKey<FormState>();

  final _className = TextEditingController();
  final _courseCode = TextEditingController();
  final _classCode = TextEditingController();
  final _room = TextEditingController();

  // Enforce 6 AM - 9 PM restriction
  int _startHour = 8, _startMinute = 0, _endHour = 9, _endMinute = 0;
  bool _startIsAm = true, _endIsAm = true, _saving = false;

  @override
  void dispose() {
    _className.dispose(); _courseCode.dispose(); _room.dispose(); _classCode.dispose();
    super.dispose();
  }

  InputDecoration _input(String hint, {double hintSize = 12}) => InputDecoration(
    hintText: hint, 
    filled: true, 
    fillColor: const Color(0xFFEAEAEA),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    isDense: true, 
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    hintStyle: TextStyle(fontSize: hintSize), 
    errorStyle: const TextStyle(fontSize: 10),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Row(children: [Text(text, style: const TextStyle(fontSize: 12)), const SizedBox(width: 4), const Text('*', style: TextStyle(color: Colors.red))]),
  );

  Widget _timeRow({required String label, required int hour, required int minute, required bool isAm, required Function(int, int, bool) onUpdate}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(label),
      GestureDetector(
        onTap: () => _showCustomTimePicker(context: context, initialHour: hour, initialMinute: minute, initialIsAm: isAm, onConfirm: onUpdate),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: const Color(0xFFEAEAEA), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_formatTime(hour, minute, isAm), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const Icon(Icons.access_time_rounded, size: 18, color: Colors.grey),
          ]),
        ),
      ),
    ],
  );

  String _formatTime(int h, int m, bool am) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} ${am ? "AM" : "PM"}';

  String _convert24To12(String time) {
    if (time.isEmpty || time.toUpperCase().contains('AM') || time.toUpperCase().contains('PM')) return time;
    final parts = time.split(':');
    if (parts.length < 2) return time;
    int? h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
    if (h == null || m == null) return time;
    return _formatTime(h % 12 == 0 ? 12 : h % 12, m, h < 12);
  }

  // ✅ 2. UPDATE: Solidified conflict detection
  Future<List<String>> _checkRoomConflicts() async {
    final day = _selectedDay;
    final roomVal = _room.text.trim();
    if (day == null || roomVal.isEmpty) return [];

    final startMin = _to24hMinutes(_startHour, _startMinute, _startIsAm);
    int endMin = _to24hMinutes(_endHour, _endMinute, _endIsAm);
    if (endMin <= startMin) endMin += 1440; // Kapag tumawid ng midnight

    // Prepend "Room " for DB conflict check
    final roomStr = 'Room $roomVal';
    var query = supabase.from('classes')
        .select('course, start_time, end_time, room')
        .eq('room', roomStr)
        .eq('day_of_week', day)
        .eq('archived', false);

    if (isEdit) query = query.neq('id', widget.initialItem!.id);

    final res = await query;
    final existing = List<Map<String, dynamic>>.from(res);
    List<String> conflicts = [];

    for (final cls in existing) {
      final eStartStr = cls['start_time']?.toString() ?? '';
      final eEndStr = cls['end_time']?.toString() ?? '';
      if (eStartStr.isEmpty || eEndStr.isEmpty) continue;

      final eStartParts = _parseTime(eStartStr);
      final eEndParts = _parseTime(eEndStr);

      final eStartMin = _to24hMinutes(eStartParts.$1, eStartParts.$2, eStartParts.$3);
      int eEndMin = _to24hMinutes(eEndParts.$1, eEndParts.$2, eEndParts.$3);
      if (eEndMin <= eStartMin) eEndMin += 1440; // Kapag existing class ay tumawid ng midnight

      // STRICT OVERLAP CONDITION:
      // (Bago pumasok < Luma matapos) AND (Bago matapos > Luma magsimula)
      // Kung 12:00 PM matatapos ang bago (endMin), at 12:00 PM magsisimula ang luma (eStartMin),
      // ang `720 > 720` ay FALSE. Kaya papasa siya at hindi magco-conflict.
      if (startMin < eEndMin && endMin > eStartMin) {
        final fmtStart = _convert24To12(eStartStr);
        final fmtEnd = _convert24To12(eEndStr);
        conflicts.add('${cls['course']} ($fmtStart - $fmtEnd)');
      }
    }
    return conflicts;
  }

  void _showConflictModal(List<String> conflicts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text("Schedule Conflict", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("This room is already occupied during this time:", style: TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            ...conflicts.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text("• $c", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.red)),
            )),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004280),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  final ScrollController _conflictScrollController = ScrollController(); //  Conflict scrollbar

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 50),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [const Icon(Icons.book_outlined, size: 20), const SizedBox(width: 10), Text(isEdit ? 'Edit Class' : 'Create Class', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))]),
                    InkWell(onTap: () => Navigator.pop(context), child: const Icon(CupertinoIcons.xmark))
                  ]),
                  const SizedBox(height: 18),

                  _label('Course Name'),
                  _loadingSubjects 
                    ? const Center(child: CupertinoActivityIndicator(radius: 8))
                    : DropdownButtonFormField<String>(
                        value: _availableSubjects.any((s) => s['course_name'] == _className.text) ? _className.text : null,
                        isExpanded: true,
                        isDense: true, 
                        style: const TextStyle(fontSize: 12, color: Colors.black),
                        decoration: _input('Select Course Name'),
                        dropdownColor: Colors.white,
                        items: _availableSubjects.map((s) => DropdownMenuItem<String>(value: s['course_name'].toString(), child: Text(s['course_name'].toString(), style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (v) { 
                          if (v != null) {
                            setState(() { 
                              _className.text = v; 
                              final sub = _availableSubjects.firstWhere((s) => s['course_name'] == v); 
                              _courseCode.text = sub['course_code'] ?? ''; 
                            }); 
                          }
                        },
                        validator: (v) => (_className.text.isEmpty) ? 'Required' : null,
                      ),
                  const SizedBox(height: 8),

                  _label('Course Code'),
                  TextFormField(controller: _courseCode, readOnly: true, style: const TextStyle(fontSize: 12), decoration: _input('Course code will auto-fill'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                  const SizedBox(height: 8),

                  _label('Program'),
                  _loadingPrograms
                    ? const Center(child: CupertinoActivityIndicator(radius: 8))
                    : DropdownButtonFormField<String>(
                        value: _availablePrograms.any((p) => p['program_abbr'] == _selectedProgram) ? _selectedProgram : null, 
                        isExpanded: true, 
                        isDense: true, 
                        style: const TextStyle(fontSize: 12, color: Colors.black), 
                        decoration: _input('Select Program'), 
                        dropdownColor: Colors.white, 
                        items: _availablePrograms.map((p) => DropdownMenuItem<String>(
                          value: p['program_abbr'], 
                          child: Text('${p['program_abbr']} - ${p['program_name']}', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)
                        )).toList(), 
                        onChanged: (v) => setState(() => _selectedProgram = v), 
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null
                      ),
                  const SizedBox(height: 8),

                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Year'), DropdownButtonFormField<String>(value: _selectedYear, isDense: true, style: const TextStyle(fontSize: 12, color: Colors.black), decoration: _input('Year', hintSize: 10), dropdownColor: Colors.white, items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) => setState(() => _selectedYear = v), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null)])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Section'), DropdownButtonFormField<String>(value: _selectedSection, isDense: true, style: const TextStyle(fontSize: 12, color: Colors.black), decoration: _input('Section', hintSize: 10), dropdownColor: Colors.white, items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) => setState(() => _selectedSection = v), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null)])),
                  ]),

                  _label('Room'),
                  DropdownButtonFormField<String>(
                    value: _rooms.contains(_room.text) ? _room.text : null,
                    isExpanded: true,
                    isDense: true,
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                    decoration: _input('Select Room'),
                    dropdownColor: Colors.white,
                    items: [
                      // 1st Floor Header
                      const DropdownMenuItem<String>(
                        enabled: false,
                        value: 'HDR_1',
                        child: Text('1st Floor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004280))),
                      ),
                      ...[for (int i = 100; i <= 110; i++) i.toString()].map((r) => DropdownMenuItem<String>(
                        value: r,
                        child: Padding(padding: const EdgeInsets.only(left: 12), child: Text(r, style: const TextStyle(fontSize: 12))),
                      )),
                      
                      // 2nd Floor Header
                      const DropdownMenuItem<String>(
                        enabled: false,
                        value: 'HDR_2',
                        child: Text('2nd Floor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004280))),
                      ),
                      ...[for (int i = 200; i <= 210; i++) i.toString()].map((r) => DropdownMenuItem<String>(
                        value: r,
                        child: Padding(padding: const EdgeInsets.only(left: 12), child: Text(r, style: const TextStyle(fontSize: 12))),
                      )),

                      // 3rd Floor Header
                      const DropdownMenuItem<String>(
                        enabled: false,
                        value: 'HDR_3',
                        child: Text('3rd Floor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004280))),
                      ),
                      ...[for (int i = 300; i <= 310; i++) i.toString()].map((r) => DropdownMenuItem<String>(
                        value: r,
                        child: Padding(padding: const EdgeInsets.only(left: 12), child: Text(r, style: const TextStyle(fontSize: 12))),
                      )),

                      // 4th Floor Header
                      const DropdownMenuItem<String>(
                        enabled: false,
                        value: 'HDR_4',
                        child: Text('4th Floor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004280))),
                      ),
                      ...['400', '410'].map((r) => DropdownMenuItem<String>(
                        value: r,
                        child: Padding(padding: const EdgeInsets.only(left: 12), child: Text(r, style: const TextStyle(fontSize: 12))),
                      )),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _room.text = v;
                        });
                        _fetchRoomSchedules(v); // ✅ Update schedules when room changes
                      }
                    },
                    validator: (v) => (_room.text.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 18),

                  _label('Assigned Room WiFi'),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: const Color(0xFFDCDCDC), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade400)),
                    child: Row(children: [const Icon(Icons.wifi, size: 18, color: Color(0xFF004280)), const SizedBox(width: 10), Expanded(child: Text(_autoWifiSSID, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)))]),
                  ),
                  const SizedBox(height: 18),

                  if (_room.text.trim().isNotEmpty) ...[
                    Row(children: [const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey), const SizedBox(width: 6), Text('Schedules in Room ${_room.text.trim()}${_selectedDay != null ? " on $_selectedDay" : ""}:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey))]),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB), 
                        borderRadius: BorderRadius.circular(8), 
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: _loadingSchedules 
                        ? const Padding(padding: EdgeInsets.all(12), child: Center(child: CupertinoActivityIndicator(radius: 8))) 
                        : (() {
                            final filtered = _roomSchedules.where((s) {
                              if (_selectedDay == null) return true; 
                              return s['day_of_week'] == _selectedDay;
                            }).toList();

                            if (filtered.isEmpty) {
                              return const Padding(padding: EdgeInsets.all(12), child: Text('No other classes found for this room.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54)));
                            }

                            return ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 85), 
                              child: Scrollbar(
                                controller: _conflictScrollController,
                                thumbVisibility: true, 
                                thickness: 4,
                                radius: const Radius.circular(8),
                                child: SingleChildScrollView(
                                  controller: _conflictScrollController,
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: filtered.map((s) {
                                      final start = _convert24To12(s['start_time']?.toString() ?? '');
                                      final end = _convert24To12(s['end_time']?.toString() ?? '');
                                      return Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• ${s['day_of_week']}: $start - $end (${s['course']})', style: const TextStyle(fontSize: 11, color: Colors.black87)));
                                    }).toList(),
                                  ),
                                ),
                              ),
                            );
                          })(),
                    ),
                    const SizedBox(height: 18),
                  ],

                  _label('Day'),
                  DropdownButtonFormField<String>(
                    value: _selectedDay, 
                    isDense: true, 
                    style: const TextStyle(fontSize: 12, color: Colors.black), 
                    decoration: _input('Select Day'), 
                    dropdownColor: Colors.white, 
                    items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))).toList(), 
                    onChanged: (v) {
                      setState(() => _selectedDay = v);
                      _updateScheduleConflict(); // ✅ Real-time validation on day change
                    }, 
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null
                  ),
                  const SizedBox(height: 8),

                  _timeRow(
                    label: 'Time Start', 
                    hour: _startHour, 
                    minute: _startMinute, 
                    isAm: _startIsAm, 
                    onUpdate: (h, m, am) {
                      setState(() { 
                        _startHour = h; _startMinute = m; _startIsAm = am; 
                      });
                      _updateScheduleConflict(); // ✅ Real-time validation
                    }
                  ),
                  const SizedBox(height: 16),
                  _timeRow(
                    label: 'Time End', 
                    hour: _endHour, 
                    minute: _endMinute, 
                    isAm: _endIsAm, 
                    onUpdate: (h, m, am) {
                      setState(() { 
                        _endHour = h; _endMinute = m; _endIsAm = am; 
                      });
                      _updateScheduleConflict(); // ✅ Real-time validation
                    }
                  ),

                  // ✅ Real-time conflict warning message
                  if (_conflictError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 16),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_conflictError!, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),

                  const SizedBox(height: 22),

                  Center(
                    child: SizedBox(
                      width: 180, height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_conflictError != null) ? Colors.grey : const Color(0xFF004280), 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                        onPressed: (_saving || _conflictError != null || (isEdit && !_hasChanges())) ? null : () async {
                          if (!_formKey.currentState!.validate()) return;
                          if (_saving) return;

                          setState(() { _saving = true; });

                          try {
                            final ok = await _confirmSave(isEdit: isEdit);
                            if (!ok) { setState(() => _saving = false); return; }

                            final startMin = _to24hMinutes(_startHour, _startMinute, _startIsAm);
                            int endMin = _to24hMinutes(_endHour, _endMinute, _endIsAm);
                            if (endMin < startMin) {
                              final durationMin = _classDurationMinutes();
                              final pretty = _formatDurationPretty(durationMin);
                              final okOvernight = await _confirmOvernightDuration(isEdit: isEdit, prettyDuration: pretty);
                              if (!okOvernight) { setState(() => _saving = false); return; }
                            }

                            final uid = supabase.auth.currentUser?.id;
                            if (uid == null) throw Exception('Not logged in');

                            final courseName = _className.text.trim();
                            final courseCode = _courseCode.text.trim().toUpperCase();
                            final yearSection = '${_selectedProgram!.toUpperCase()} ${_selectedYear!}-${_selectedSection!.toUpperCase()}';
                            // FORCE "Room " prefix for database storage
                            final room = 'Room ${_room.text.trim()}';
                            final day = _selectedDay!;
                            final start = _formatTime(_startHour, _startMinute, _startIsAm);
                            final end = _formatTime(_endHour, _endMinute, _endIsAm);
                            final classCode  = _classCode.text.trim().toUpperCase();
                            final assignedWifi = _autoWifiSSID;
                            final schedule = '$day: $start - $end';

                            Map<String, dynamic> row;
                            if (isEdit) {
                              row = await supabase.from('classes').update({
                                'course': courseName, 'course_code': courseCode, 'year_section': yearSection, 'room': room,
                                'day_of_week': day, 'start_time': start, 'end_time': end, 'schedule': schedule, 'room_ap': assignedWifi,
                              }).eq('id', widget.initialItem!.id).select().single();
                              await supabase.from('class_sessions').update({'status': null}).eq('class_id', widget.initialItem!.id);
                            } else {
                              row = await supabase.from('classes').insert({
                                'professor_id': uid, 'course': courseName, 'course_code': courseCode, 'year_section': yearSection,
                                'room': room, 'day_of_week': day, 'start_time': start, 'end_time': end, 'schedule': schedule,
                                'class_code': classCode, 'room_ap': assignedWifi,
                              }).select().single();
                            }

                            if (!mounted) return;
                            Navigator.pop(context, ClassItem(
                              id: row['id'] as String, yearSection: row['year_section'] as String, classCode: row['class_code'] as String,
                              course: row['course'] as String, courseCode: row['course_code'] as String, professor: widget.initialItem?.professor ?? 'Professor',
                              room: row['room'] as String, sched: row['schedule'] as String, session: widget.initialItem?.session ?? 'Upcoming',
                            ));
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save class: $e')));
                          } finally {
                            if (!mounted) return;
                            setState(() => _saving = false);
                          }
                        },
                        child: Text(_saving ? 'Saving...' : (isEdit ? 'Save Changes' : 'Create'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showCustomTimePicker({required BuildContext context, required int initialHour, required int initialMinute, required bool initialIsAm, required Function(int, int, bool) onConfirm}) {
  int selectedHour = initialHour, selectedMinute = initialMinute; bool selectedIsAm = initialIsAm;
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final totalMinutes = (selectedHour % 12 + (selectedIsAm ? 0 : 12)) * 60 + selectedMinute;
        final isValid = totalMinutes >= 360 && totalMinutes <= 1260; // 6 AM - 9 PM

        return Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8, height: 280, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Column(children: [
              Expanded(child: Row(children: [
                _buildPicker(initialItem: selectedIsAm ? 0 : 1, children: ['AM', 'PM'], onChanged: (i) => setState(() => selectedIsAm = i == 0)),
                _buildPicker(initialItem: selectedHour - 1, children: List.generate(12, (i) => (i + 1).toString().padLeft(2, '0')), onChanged: (i) => setState(() => selectedHour = i + 1)),
                _buildPicker(initialItem: selectedMinute, children: List.generate(60, (i) => i.toString().padLeft(2, '0')), onChanged: (i) => setState(() => selectedMinute = i)),
              ])),
              if (!isValid)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Time must be between 6 AM and 9 PM',
                    style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.black))),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: isValid ? const Color(0xFF004280) : Colors.grey,
                  ), 
                  onPressed: !isValid ? null : () { 
                    onConfirm(selectedHour, selectedMinute, selectedIsAm); 
                    Navigator.pop(context); 
                  }, 
                  child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                ),
              ])
            ]),
          ),
        );
      }
    ),
  );
}

Widget _buildPicker({required int initialItem, required List<String> children, required ValueChanged<int> onChanged}) {
  return Expanded(child: CupertinoPicker(scrollController: FixedExtentScrollController(initialItem: initialItem), itemExtent: 40, useMagnifier: true, magnification: 1.2, onSelectedItemChanged: onChanged, children: children.map((text) => Center(child: Text(text, style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w400)))).toList()));
}
