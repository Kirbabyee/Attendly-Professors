import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CreateClassSheet extends StatefulWidget {
  const CreateClassSheet({super.key});

  @override
  State<CreateClassSheet> createState() => _CreateClassSheetState();
}

class _CreateClassSheetState extends State<CreateClassSheet> {
  final _formKey = GlobalKey<FormState>();

  final _className = TextEditingController();
  final _course = TextEditingController();
  final _day = TextEditingController();
  final _room = TextEditingController();

  int _startHour = 12, _startMinute = 0;
  bool _startIsAm = true;

  int _endHour = 3, _endMinute = 0;
  bool _endIsAm = true;

  @override
  void dispose() {
    _className.dispose();
    _course.dispose();
    _day.dispose();
    _room.dispose();
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
      helperStyle: TextStyle(
        fontSize: 10,
      ),
      errorStyle: TextStyle(
        fontSize: 10,
      )
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
        // Hour
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
        // Minute
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

        // AM/PM
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
                  // Title
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

                  // Class Name
                  _label('Class Name'),
                  TextFormField(
                    controller: _className,
                    decoration: _input('Enter Class Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),

                  // Course
                  _label('Course'),
                  TextFormField(
                    controller: _course,
                    decoration: _input('Enter Course'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),

                  // Day
                  _label('Day'),
                  TextFormField(
                    controller: _day,
                    decoration: _input('Enter Day'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),

                  // Room
                  _label('Room'),
                  TextFormField(
                    controller: _room,
                    decoration: _input('Enter Room Number'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 18),

                  // Time Start
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

                  // Time End
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

                  // Create button
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
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;

                          // Close the Create Class modal first
                          Navigator.pop(context);

                          // Show success dialog after closing
                          Future.microtask(() {
                            showDialog(
                              context: context,
                              barrierDismissible: true, // tap outside closes
                              builder: (context) {
                                return Stack(
                                  children: [
                                    Positioned.fill(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => Navigator.pop(context),
                                      ),
                                    ),

                                    Center(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => Navigator.pop(context),
                                        child: Dialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(18),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(Icons.check_circle, size: 60, color: Colors.green),
                                                SizedBox(height: 12),
                                                Text(
                                                  'Created successfully!',
                                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                ),
                                                SizedBox(height: 8),
                                                Text('Your class has been added.'),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          });
                        },
                        child: const Text(
                          'Create',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
                    thumbColor: Color(0xFF004280),
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

