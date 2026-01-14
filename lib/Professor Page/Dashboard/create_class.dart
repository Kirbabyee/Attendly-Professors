import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'class_item.dart';

class CreateClassSheet extends StatefulWidget {
  final ClassItem? initialItem; // ✅ optional for edit

  const CreateClassSheet({super.key, this.initialItem});

  @override
  State<CreateClassSheet> createState() => _CreateClassSheetState();
}

class _CreateClassSheetState extends State<CreateClassSheet> {
  final supabase = Supabase.instance.client;

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

  bool _saving = false;
  String? _saveError;

  (int, int, bool) _parseTime(String time) {
    // "9:00 AM"
    final reg = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false);
    final m = reg.firstMatch(time.trim());
    if (m == null) return (12, 0, true);

    final hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final am = m.group(3)!.toUpperCase() == 'AM';

    return (hour, minute, am);
  }

  // ===== Class Code Generator (Google Classroom-like) =====

  // characters: avoid confusing ones (O/0, I/1)
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _randomCode({int len = 7}) {
    final now = DateTime.now().microsecondsSinceEpoch;
    // simple pseudo-random using time seed (enough for app-level codes)
    // If you want true crypto-random, we can use Random.secure() too.
    var x = now;
    final b = StringBuffer();
    for (var i = 0; i < len; i++) {
      x = (x * 1103515245 + 12345) & 0x7fffffff; // LCG
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
    // retry a few times in case may collision
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = _randomCode(len: 7);
      final exists = await _classCodeExists(code);
      if (!exists) return code;
    }
    // fallback: longer code
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = _randomCode(len: 9);
      final exists = await _classCodeExists(code);
      if (!exists) return code;
    }
    throw Exception('Could not generate unique class code. Try again.');
  }

  Future<void> _ensureAutoClassCode() async {
    // only generate if CREATE mode and empty pa
    if (widget.initialItem != null) return;
    if (_classCode.text.trim().isNotEmpty) return;

    try {
      final code = await _generateUniqueClassCode();
      if (!mounted) return;
      setState(() {
        _classCode.text = code; // ✅ auto-fill class_code (join code)
      });
    } catch (_) {
      // optional: ignore, user can type manually
    }
  }

  @override
  void initState() {
    super.initState();

    final item = widget.initialItem;
    if (item != null) {
      _className.text = item.course;
      _courseCode.text = item.courseCode;

      _room.text = item.room
          .replaceFirst(RegExp(r'^\s*Room\s+', caseSensitive: false), '')
          .trim();

      _selectedDay = item.sched.split(':').first.trim();

      final timePart = item.sched.split(':').sublist(1).join(':').trim();
      final startStr = timePart.split('-').first.trim();
      final endStr = timePart.split('-').last.trim();

      final start = _parseTime(startStr);
      _startHour = start.$1;
      _startMinute = start.$2;
      _startIsAm = start.$3;

      final end = _parseTime(endStr);
      _endHour = end.$1;
      _endMinute = end.$2;
      _endIsAm = end.$3;

      // ✅ DITO MO ILALAGAY (PARSE YEAR_SECTION)
      final raw = item.yearSection ?? ''; // dapat galing DB

      final text = raw.trim();
      if (text.isNotEmpty) {
        final m = RegExp(
          r'^(\w+)\s+(\d)\s*[- ]\s*([A-Z])$',
        ).firstMatch(text.toUpperCase());

        if (m != null) {
          _selectedProgram = m.group(1);
          _selectedYear = m.group(2);
          _selectedSection = m.group(3);
        }
      }
    }
    // auto-generate code for create mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureAutoClassCode();
    });

  }

  final List<String> _days = const [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  final List<Map<String, String>> _programs = const [
    {'code': 'BSIT',  'label': 'Bachelor of Science in Information Technology'},
    {'code': 'BSCS',  'label': 'Bachelor of Science in Computer Science'},
    {'code': 'BSIS',  'label': 'Bachelor of Science in Information System'},
    {'code': 'BSEMC', 'label': 'Bachelor of Science in Entertainment and Multimedia Computing'},
  ];

  final List<String> _years = const ['1', '2', '3', '4'];
  final List<String> _sections = const ['A', 'B', 'C', 'D'];

  String? _selectedProgram;
  String? _selectedYear;
  String? _selectedSection;

  String? _selectedDay;

  final _formKey = GlobalKey<FormState>();

  final _className = TextEditingController();
  final _courseCode = TextEditingController(); // manual: IT108 / CCS101 etc
  final _classCode = TextEditingController();  // auto: join code like GClass
  final _room = TextEditingController();


  int _startHour = 12, _startMinute = 0;
  bool _startIsAm = true;

  int _endHour = 3, _endMinute = 0;
  bool _endIsAm = true;

  @override
  void dispose() {
    _className.dispose();
    _courseCode.dispose();
    _room.dispose();
    _classCode.dispose();
    super.dispose();
  }

  InputDecoration _input(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFEAEAEA),
      errorMaxLines: 1,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      helperText: ' ',
      helperStyle: const TextStyle(fontSize: 12),
      errorStyle: const TextStyle(fontSize: 10),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(text, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          const Text('*', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  Widget _timeRow({
    required int hour,
    required int minute,
    required bool isAm,
    required ValueChanged<int> onHour,
    required ValueChanged<int> onMinute,
    required ValueChanged<bool> onAmPm,
  }) {
    Widget box({required String text, double w = 58}) {
      return Container(
        width: w,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEAEAEA),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
      );
    }

    return Row(
      children: [
        GestureDetector(
          onTap: () async {
            final picked = await _pickNumber(
              context,
              title: 'Hour',
              initial: hour,
              min: 1,
              max: 12,
            );
            if (picked != null) onHour(picked);
          },
          child: box(text: hour.toString().padLeft(2, '0')),
        ),
        const SizedBox(width: 8),
        const Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            final picked = await _pickNumber(
              context,
              title: 'Minute',
              initial: minute,
              min: 0,
              max: 59,
            );
            if (picked != null) onMinute(picked);
          },
          child: box(text: minute.toString().padLeft(2, '0')),
        ),
        const SizedBox(width: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black26),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ampmButton('AM', isSelected: isAm, onTap: () => onAmPm(true)),
              _ampmButton('PM', isSelected: !isAm, onTap: () => onAmPm(false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ampmButton(String label, {required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF004280) : Colors.transparent,
          borderRadius: label == 'AM'
              ? const BorderRadius.vertical(top: Radius.circular(10))
              : const BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  String _formatTime(int h, int m, bool am) {
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    return '$hh:$mm ${am ? "AM" : "PM"}';
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialItem != null;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 50),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.book_outlined, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Create Class',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  _label('Course Name'),
                  TextFormField(
                    controller: _className,
                    style: const TextStyle(fontSize: 12),
                    decoration: _input('Enter Course Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),

                  _label('Course Code'),
                  TextFormField(
                    controller: _courseCode,
                    style: const TextStyle(fontSize: 12),
                    decoration: _input('Enter Class Code'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),

                  _label('Program'),
                  DropdownButtonFormField<String>(
                    value: _selectedProgram,
                    isExpanded: true,

                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                    ),

                    decoration: InputDecoration(
                      hintText: 'Select Program',
                      filled: true,
                      fillColor: const Color(0xFFEAEAEA),
                      isDense: true, // ✅ mas maliit height
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                      helperText: ' ',
                      helperStyle: const TextStyle(fontSize: 12),
                      errorStyle: const TextStyle(fontSize: 10),
                    ),

                    dropdownColor: Colors.white,

                    selectedItemBuilder: (context) {
                      return _programs.map((p) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            p['code']!,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList();
                    },

                    items: _programs.map((p) {
                      return DropdownMenuItem<String>(
                        value: p['code'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              p['code']!,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              p['label']!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    onChanged: (v) => setState(() => _selectedProgram = v),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),

                  _label('Year'),
                  DropdownButtonFormField<String>(
                    value: _selectedYear,
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                    decoration: _input('Select Year'),
                    dropdownColor: Colors.white,
                    items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                    onChanged: (v) => setState(() => _selectedYear = v),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),

                  _label('Section'),
                  DropdownButtonFormField<String>(
                    value: _selectedSection,
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                    decoration: _input('Select Section'),
                    dropdownColor: Colors.white,
                    items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _selectedSection = v),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),

                  _label('Room'),
                  TextFormField(
                    controller: _room,
                    style: const TextStyle(fontSize: 12),
                    decoration: _input('Enter Room Number'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 18),

                  _label('Day'),
                  DropdownButtonFormField<String>(
                    value: _selectedDay,
                    style: const TextStyle(fontSize: 12, color: Colors.black),
                    decoration: _input('Select Day'),
                    dropdownColor: Colors.white,
                    items: _days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setState(() => _selectedDay = v),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),

                  _label('Time Start'),
                  _timeRow(
                    hour: _startHour,
                    minute: _startMinute,
                    isAm: _startIsAm,
                    onHour: (v) => setState(() => _startHour = v),
                    onMinute: (v) => setState(() => _startMinute = v),
                    onAmPm: (v) => setState(() => _startIsAm = v),
                  ),
                  const SizedBox(height: 16),

                  _label('Time End'),
                  _timeRow(
                    hour: _endHour,
                    minute: _endMinute,
                    isAm: _endIsAm,
                    onHour: (v) => setState(() => _endHour = v),
                    onMinute: (v) => setState(() => _endMinute = v),
                    onAmPm: (v) => setState(() => _endIsAm = v),
                  ),

                  const SizedBox(height: 22),

                  if (_saveError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _saveError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),

                  Center(
                    child: SizedBox(
                      width: 180,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004280),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          if (_saving) return;

                          final ok = await _confirmSave(isEdit: isEdit);
                          if (!ok) return;

                          setState(() {
                            _saving = true;
                            _saveError = null;
                          });

                          try {
                            final uid = supabase.auth.currentUser?.id;
                            if (uid == null) throw Exception('Not logged in');

                            final courseName = _className.text.trim();
                            final courseCode = _courseCode.text.trim().toUpperCase();
                            final yearSection =
                                '${_selectedProgram!.toUpperCase()} ${_selectedYear!}-${_selectedSection!.toUpperCase()}';
                            final room = 'Room ${_room.text.trim()}';
                            final day = _selectedDay!;
                            final start = _formatTime(_startHour, _startMinute, _startIsAm);
                            final end = _formatTime(_endHour, _endMinute, _endIsAm);
                            final classCode  = _classCode.text.trim().toUpperCase();

                            // ✅ since DB uses single string column "schedule"
                            final schedule = '$day: $start - $end';

                            Map<String, dynamic> row;

                            if (isEdit) {
                              // ✅ UPDATE
                              row = await supabase
                                  .from('classes')
                                  .update({
                                'course': courseName,
                                'course_code': courseCode,
                                'year_section': yearSection,
                                'room': room,
                                'day_of_week': day,
                                'start_time': start,
                                'end_time': end,
                                'schedule': schedule,
                              })
                                  .eq('id', widget.initialItem!.id) // requires ClassItem.id
                                  .select()
                                  .single();
                            } else {
                              // ✅ INSERT
                              row = await supabase
                                  .from('classes')
                                  .insert({
                                'professor_id': uid,
                                'course': courseName,
                                'course_code': courseCode,
                                'year_section': yearSection,
                                'room': room,
                                'day_of_week': day,
                                'start_time': start,
                                'end_time': end,
                                'schedule': schedule,
                                'class_code': classCode,
                              })
                                  .select()
                                  .single();
                            }

                            if (!mounted) return;

                            // ✅ return the saved row (correct keys)
                            Navigator.pop(
                              context,
                              ClassItem(
                                id: row['id'] as String,
                                yearSection: row['year_section'] as String, // ✅ HERE
                                classCode: row['class_code'] as String,
                                course: row['course'] as String,
                                courseCode: row['course_code'] as String,
                                professor: widget.initialItem?.professor ?? 'Professor',
                                room: row['room'] as String,
                                sched: row['schedule'] as String,
                                session: widget.initialItem?.session ?? 'Upcoming',
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            setState(() => _saveError = e.toString());
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to save class: $e')),
                            );
                          } finally {
                            if (!mounted) return;
                            setState(() => _saving = false);
                          }
                        },
                        child: Text(
                          _saving ? 'Saving...' : (isEdit ? 'Save Changes' : 'Create'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
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

/// Simple number picker dialog for hour/minute
Future<int?> _pickNumber(
    BuildContext context, {
      required String title,
      required int initial,
      required int min,
      required int max,
    }) {
  int temp = initial;

  return showDialog<int>(
    context: context,
    builder: (_) {
      return AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title),
        content: StatefulBuilder(
          builder: (context, setLocal) {
            return SizedBox(
              height: 120,
              child: Column(
                children: [
                  Text('Select $title: $temp'),
                  Slider(
                    thumbColor: const Color(0xFF004280),
                    activeColor: const Color(0xFF004280),
                    inactiveColor: Colors.grey.shade300,
                    value: temp.toDouble(),
                    min: min.toDouble(),
                    max: max.toDouble(),
                    divisions: max - min,
                    onChanged: (v) => setLocal(() => temp = v.round()),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, temp), child: const Text('OK')),
        ],
      );
    },
  );
}
