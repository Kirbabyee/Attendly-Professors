// lib/utils/schedule_utils.dart
class ScheduleParse {
  final int weekday; // DateTime.monday..DateTime.sunday
  final int startMin; // minutes from 00:00
  final int endMinRaw; // minutes from 00:00 (raw)
  final bool overnight;

  const ScheduleParse({
    required this.weekday,
    required this.startMin,
    required this.endMinRaw,
    required this.overnight,
  });

  int get endMin => overnight ? endMinRaw + 1440 : endMinRaw;
}

class ScheduleWindow {
  final DateTime start;
  final DateTime end;
  final bool overnight;
  const ScheduleWindow({required this.start, required this.end, required this.overnight});
}

class ScheduleUtils {
  static const Map<String, int> _weekdayMap = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  /// "Wednesday: 02:10 PM - 03:00 PM"
  /// also supports en-dash "–"
  static ScheduleParse? parse(String sched) {
    if (sched.trim().isEmpty) return null;

    final parts = sched.split(':');
    if (parts.length < 2) return null;

    final dayStr = parts.first.trim().toLowerCase();
    final weekday = _weekdayMap[dayStr];
    if (weekday == null) return null;

    final timePart = parts.sublist(1).join(':').trim();
    final range = timePart.split(RegExp(r'\s*[-–]\s*'));
    if (range.length < 2) return null;

    final startMin = _toMinutes(range.first.trim());
    final endMinRaw = _toMinutes(range.last.trim());
    if (startMin == null || endMinRaw == null) return null;

    final overnight = endMinRaw <= startMin; // 11:30 PM - 12:30 AM
    return ScheduleParse(
      weekday: weekday,
      startMin: startMin,
      endMinRaw: endMinRaw,
      overnight: overnight,
    );
  }

  /// Returns schedule window that is relevant "today":
  /// - if today is sched weekday => window is today start..today end (with overnight support)
  /// - if overnight and today is the "next day" continuation => window is yesterday start..today end
  /// else null
  static ScheduleWindow? windowForNow(String sched, DateTime now) {
    final p = parse(sched);
    if (p == null) return null;

    DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

    int prevDay(int d) => d == DateTime.monday ? DateTime.sunday : d - 1;
    int nextDay(int d) => d == DateTime.sunday ? DateTime.monday : d + 1;

    // base date of "start day"
    DateTime? startDay;
    if (now.weekday == p.weekday) {
      startDay = startOfDay(now);
    } else if (p.overnight && now.weekday == nextDay(p.weekday)) {
      // overnight continuation day: start was yesterday (sched weekday)
      startDay = startOfDay(now).subtract(const Duration(days: 1));
    } else {
      return null;
    }

    final start = startDay.add(Duration(minutes: p.startMin));
    final end = startDay.add(Duration(minutes: p.endMin)); // already adjusted for overnight
    return ScheduleWindow(start: start, end: end, overnight: p.overnight);
  }

  /// UI status based purely on schedule:
  /// - Upcoming: before (start - pendingMinutes) OR not the sched day context
  /// - Pending: from (start - pendingMinutes) until end
  /// - Ended: after end (but only within the sched day/overnight context)
  ///
  /// NOTE: This matches your old behavior na "Ended" only on that day,
  /// and kapag lumipas na yung day context, babalik siya sa Upcoming.
  static String statusFromSchedule(
      String sched,
      DateTime now, {
        int pendingMinutes = 10,
      }) {
    final w = windowForNow(sched, now);
    if (w == null) return 'Upcoming';

    final pendingStart = w.start.subtract(Duration(minutes: pendingMinutes));

    if (now.isBefore(pendingStart)) return 'Upcoming';
    if (now.isBefore(w.end)) return 'Pending';
    return 'Ended';
  }

  static int? _toMinutes(String time) {
    final reg = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false);
    final m = reg.firstMatch(time.trim());
    if (m == null) return null;

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
}
