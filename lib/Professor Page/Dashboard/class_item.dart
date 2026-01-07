class ClassItem {
  final String course;
  final String classCode;
  final String professor;
  final String room;
  final String sched;
  final String session;

  const ClassItem({
    required this.course,
    required this.classCode,
    required this.professor,
    required this.room,
    required this.sched,
    required this.session,
  });

  ClassItem copyWith({
    String? course,
    String? classCode,
    String? professor,
    String? room,
    String? sched,
    String? session,
  }) {
    return ClassItem(
      course: course ?? this.course,
      classCode: classCode ?? this.classCode,
      professor: professor ?? this.professor,
      room: room ?? this.room,
      sched: sched ?? this.sched,
      session: session ?? this.session,
    );
  }
}
