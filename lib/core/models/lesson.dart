class Lesson {
  final String id;
  final String courseId;
  final String courseName;
  final String courseType; // 'group' | 'personal'
  final DateTime startTime;
  final DateTime endTime;
  final int capacity;

  const Lesson({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.courseType,
    required this.startTime,
    required this.endTime,
    required this.capacity,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    final course = json['courses'] as Map<String, dynamic>;
    return Lesson(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      courseName: course['name'] as String,
      courseType: course['type'] as String,
      startTime: DateTime.parse(json['starts_at'] as String).toLocal(),
      endTime: DateTime.parse(json['ends_at'] as String).toLocal(),
      capacity: json['capacity'] as int,
    );
  }
}