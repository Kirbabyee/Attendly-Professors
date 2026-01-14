class ClassItem {
  final String course;
  final String classCode;
  final String courseCode;
  final String professor;
  final String room;
  final String sched;
  final String session;
  final String id;

  const ClassItem({
    required this.id,
    required this.classCode,
    required this.course,
    required this.courseCode,
    required this.professor,
    required this.room,
    required this.sched,
    required this.session,
  });

  ClassItem copyWith({
    String? course,
    String? courseCode,
    String? professor,
    String? room,
    String? sched,
    String? session,
    String? classCode,
  }) {
    return ClassItem(
      id: id,
      classCode: classCode ?? this.classCode,
      course: course ?? this.course,
      courseCode: courseCode ?? this.courseCode,
      professor: professor ?? this.professor,
      room: room ?? this.room,
      sched: sched ?? this.sched,
      session: session ?? this.session,
    );
  }
}
