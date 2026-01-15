import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<Map<String, dynamic>> fetchSessionHeader(String sessionId) async {
  final supabase = Supabase.instance.client;

  final row = await supabase
      .from('class_sessions')
      .select('id, started_at, ended_at, classes(course, course_code)')
      .eq('id', sessionId)
      .maybeSingle();

  if (row == null) throw 'Session not found';

  final cls = row['classes'] as Map<String, dynamic>?;
  return {
    'session_id': row['id'],
    'course': (cls?['course'] ?? '').toString(),
    'course_code': (cls?['course_code'] ?? '').toString(),
    'started_at': row['started_at'],
    'ended_at': row['ended_at'],
  };
}

Future<List<Map<String, dynamic>>> fetchSessionAttendance(String sessionId) async {
  final supabase = Supabase.instance.client;

  final rows = await supabase
      .from('attendance')
      .select('status, time_in, time_out, students(first_name,last_name,student_number)')
      .eq('session_id', sessionId)
      .order('time_in', ascending: true);

  return (rows as List).cast<Map<String, dynamic>>();
}

Future<void> exportSessionToExcel({
  required String sessionId,
  required String fileLabel, // e.g. "CCS101_2026-01-15"
}) async {
  final supabase = Supabase.instance.client;

  // ✅ 0) Pull session header info (course, code, start/end)
  final header = await fetchSessionHeader(sessionId);
  final course = (header['course'] ?? '').toString();
  final courseCode = (header['course_code'] ?? '').toString();
  final startedAt = fmtDateTime(header['started_at']);
  final endedAt = fmtDateTime(header['ended_at']);

  // ✅ 1) Pull attendance rows for this session
  final rows = await supabase
      .from('attendance')
      .select('status, time_in, time_out, students(first_name,last_name,student_number)')
      .eq('session_id', sessionId)
      .order('time_in', ascending: true);

  final data = (rows as List).cast<Map<String, dynamic>>();

  // ✅ 2) Build Excel
  final excel = Excel.createExcel();
  final sheet = excel['Attendance'];

  // ✅ Session header rows (top)
  sheet.appendRow([TextCellValue('Course'), TextCellValue(course.isEmpty ? '-' : course)]);
  sheet.appendRow([TextCellValue('Course Code'), TextCellValue(courseCode.isEmpty ? '-' : courseCode)]);
  sheet.appendRow([TextCellValue('Session Started'), TextCellValue(startedAt)]);
  sheet.appendRow([TextCellValue('Session Ended'), TextCellValue(endedAt)]);
  sheet.appendRow([TextCellValue('')]);

  // ✅ Table header
  sheet.appendRow([
    TextCellValue('Student Number'),
    TextCellValue('Name'),
    TextCellValue('Status'),
    TextCellValue('Time In'),
    TextCellValue('Time Out'),
  ]);

  for (final r in data) {
    final s = r['students'] as Map<String, dynamic>?;

    final studNo = (s?['student_number'] ?? '').toString();
    final name =
    '${(s?['first_name'] ?? '').toString()} ${(s?['last_name'] ?? '').toString()}'
        .trim();

    final status = (r['status'] ?? '').toString();
    final timeIn = fmtDateTime(r['time_in'] ?? '').toString();
    final timeOut = fmtDateTime(r['time_out'] ?? '').toString();

    sheet.appendRow([
      TextCellValue(studNo.isEmpty ? '-' : studNo),
      TextCellValue(name.isEmpty ? 'Unknown' : name),
      TextCellValue(status.isEmpty ? '-' : status),
      TextCellValue(timeIn.isEmpty ? '-' : timeIn),
      TextCellValue(timeOut.isEmpty ? '-' : timeOut),
    ]);
  }

  // ✅ 3) Save file
  final bytes = excel.save();
  if (bytes == null) throw 'Failed to generate Excel file';

  final dir = await getApplicationDocumentsDirectory();
  final safeLabel = fileLabel.replaceAll(RegExp(r'[^\w\-]+'), '_');
  final file = File('${dir.path}/attendance_$safeLabel.xlsx');

  await file.writeAsBytes(bytes, flush: true);

  // ✅ 4) Open the file
  await OpenFilex.open(file.path);
}

String fmtDateTime(dynamic v) {
  if (v == null) return '-';

  try {
    final d = DateTime.parse(v.toString()).toLocal();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}:'
        '${d.second.toString().padLeft(2, '0')}';
  } catch (_) {
    return '-';
  }
}

