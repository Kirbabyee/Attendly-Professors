import 'dart:io';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xcel;

Future<void> exportSessionToExcel({
  required String sessionId,
  required String fileLabel,
}) async {
  print("--- START EXPORT ---");
  print("Session ID: $sessionId");

  try {
    // 1. FETCH HEADER
    print("Step 1: Fetching Header...");
    final supabase = Supabase.instance.client;
    final headerRow = await supabase
        .from('class_sessions')
        .select('id, started_at, ended_at, classes(course, course_code)')
        .eq('id', sessionId)
        .maybeSingle();

    if (headerRow == null) {
      print("ERROR: Session Header is NULL. Check Session ID.");
      return;
    }

    // Safe extraction with Null Coalescing (??)
    final cls = headerRow['classes'] as Map<String, dynamic>?;
    final courseName = (cls?['course'] ?? 'N/A').toString();
    final courseCode = (cls?['course_code'] ?? 'N/A').toString();
    final startStr = fmtDateTime(headerRow['started_at']);
    final endStr = fmtDateTime(headerRow['ended_at']);

    print("Header Fetched: $courseName ($courseCode)");

    // 2. FETCH ATTENDANCE
    print("Step 2: Fetching Attendance Rows...");
    final rowsData = await supabase
        .from('attendance')
        .select('status, time_in, time_out, students(first_name,last_name,student_number)')
        .eq('session_id', sessionId)
        .order('time_in', ascending: true);

    final attendanceList = (rowsData as List?) ?? [];
    print("Attendance Rows: ${attendanceList.length}");

    // 3. CREATE EXCEL
    print("Step 3: Creating Excel Instance...");
    final xcel.Workbook workbook = xcel.Workbook();
    final xcel.Worksheet sheet = workbook.worksheets[0];
    sheet.name = "Attendance Report";

    // 4. INSERT LOGO (Wrap in try-catch to prevent crash)
    print("Step 4: Loading Logo...");
    try {
      // Siguraduhin na ang 'assets/attendly_logo.png' ay nasa pubspec.yaml
      final ByteData data = await rootBundle.load('assets/logo.png');
      final List<int> bytes = data.buffer.asUint8List();

      // Check if bytes are valid
      if (bytes.isNotEmpty) {
        final xcel.Picture picture = sheet.pictures.addStream(1, 2, bytes);
        picture.lastRow = 4;
        picture.lastColumn = 4;
        print("Logo Loaded Successfully.");
      } else {
        print("WARNING: Logo bytes are empty.");
      }
    } catch (e) {
      print("WARNING: Failed to load logo. Skipping... Error: $e");
      // Continue execution even if logo fails
    }

    // 5. WRITE TITLES
    print("Step 5: Writing Titles...");
    final xcel.Range titleRange = sheet.getRangeByName('A6:E6');
    titleRange.merge();
    titleRange.text = "ATTENDANCE REPORT";
    titleRange.cellStyle.hAlign = xcel.HAlignType.center;
    titleRange.cellStyle.bold = true;
    titleRange.cellStyle.fontSize = 14;

    // Generated Date
    final xcel.Range dateRange = sheet.getRangeByName('A7:E7');
    dateRange.merge();
    final now = DateTime.now();
    dateRange.text = "Generated: ${now.toString()}";
    dateRange.cellStyle.hAlign = xcel.HAlignType.center;

    // Course Info
    final xcel.Range row9 = sheet.getRangeByName('A9:E9');
    row9.merge();
    row9.text = "Course: $courseName ($courseCode)";
    row9.cellStyle.hAlign = xcel.HAlignType.center;
    row9.cellStyle.bold = true;

    // Time Info
    final xcel.Range row10 = sheet.getRangeByName('A10:E10');
    row10.merge();
    row10.text = "Session Started: $startStr";
    row10.cellStyle.hAlign = xcel.HAlignType.center;

    final xcel.Range row11 = sheet.getRangeByName('A11:E11');
    row11.merge();
    row11.text = "Session Ended: $endStr";
    row11.cellStyle.hAlign = xcel.HAlignType.center;

    // 6. WRITE DATA
    print("Step 6: Writing Table Data...");

    // Headers
    final List<String> headers = ["Student Number", "Name", "Status", "Time In", "Time Out"];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(14, i + 1);
      cell.text = headers[i];
      cell.cellStyle.bold = true;
      cell.cellStyle.borders.all.lineStyle = xcel.LineStyle.thin;
      cell.cellStyle.hAlign = xcel.HAlignType.center;
    }

    int currentRow = 15;
    for (final r in attendanceList) {
      // Safe casting inside the loop
      final rowMap = r as Map<String, dynamic>;
      final s = rowMap['students'] as Map<String, dynamic>?;

      final studNo = (s?['student_number'] ?? '-').toString();
      final firstName = (s?['first_name'] ?? '').toString();
      final lastName = (s?['last_name'] ?? '').toString();
      final fullName = "$firstName $lastName".trim();

      final status = (rowMap['status'] ?? '-').toString();
      final timeIn = fmtDateTime(rowMap['time_in']);
      final timeOut = fmtDateTime(rowMap['time_out']);

      _addCell(sheet, currentRow, 1, studNo, center: true);
      _addCell(sheet, currentRow, 2, fullName.isEmpty ? 'Unknown' : fullName, center: false);
      _addCell(sheet, currentRow, 3, status, center: true);
      _addCell(sheet, currentRow, 4, timeIn, center: true);
      _addCell(sheet, currentRow, 5, timeOut, center: true);

      currentRow++;
    }

    // 7. PAGE SETUP & SAVE
    print("Step 7: Saving File...");
    sheet.pageSetup.isFitToPage = true;
    sheet.pageSetup.fitToPagesWide = 1;

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    if (bytes.isEmpty) {
      print("ERROR: Generated Excel bytes are empty.");
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final safeLabel = fileLabel.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final fileName = "Attendance_$safeLabel.xlsx";
    final file = File('${dir.path}/$fileName');

    await file.writeAsBytes(bytes, flush: true);
    print("File saved at: ${file.path}");

    await OpenFilex.open(file.path);
    print("--- SUCCESS ---");

  } catch (e, stacktrace) {
    print("CRITICAL ERROR in Export: $e");
    print(stacktrace);
  }
}

// Helper para sa cell styling
void _addCell(xcel.Worksheet sheet, int row, int col, String val, {bool center = false}) {
  final cell = sheet.getRangeByIndex(row, col);
  cell.text = val;
  cell.cellStyle.borders.all.lineStyle = xcel.LineStyle.thin;
  if (center) {
    cell.cellStyle.hAlign = xcel.HAlignType.center;
  } else {
    cell.cellStyle.hAlign = xcel.HAlignType.left;
    cell.cellStyle.indent = 1;
  }
}

String fmtDateTime(dynamic v) {
  if (v == null) return '-';
  try {
    final d = DateTime.parse(v.toString()).toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return '-';
  }
}