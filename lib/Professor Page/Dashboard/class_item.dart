class ClassItem {
  final String id;
  final String classCode;
  final String course;
  final String courseCode;
  final String professor;
  final String room;
  final String sched;
  final String session;
  final String yearSection; // ✅ ADD

  ClassItem({
    required this.id,
    required this.classCode,
    required this.course,
    required this.courseCode,
    required this.professor,
    required this.room,
    required this.sched,
    required this.session,
    required this.yearSection, // ✅ ADD
  });

  ClassItem copyWith({
    String? session,
  }) {
    return ClassItem(
      id: id,
      classCode: classCode,
      course: course,
      courseCode: courseCode,
      professor: professor,
      room: room,
      sched: sched,
      session: session ?? this.session,
      yearSection: yearSection,
    );
  }
}
