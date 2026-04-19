class Lesson {
  final String id;
  final String courseId;
  final String courseName;
  final String courseType; // 'group' | 'personal'
  final String? trainerName;
  final DateTime startTime;
  final DateTime endTime;
  final int capacity;
  final int bookedCount;
  final int waitlistCount;
  final int cancellationHours;

  const Lesson({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.courseType,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    this.trainerName,
    this.bookedCount = 0,
    this.waitlistCount = 0,
    this.cancellationHours = 0,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    final course    = json['courses'] as Map<String, dynamic>;
    final trainer   = course['users'] as Map<String, dynamic>?;
    final bookings  = json['bookings'] as List?;
    final waitlist  = json['waitlist'] as List?;
    final count     = bookings != null && bookings.isNotEmpty
        ? (bookings.first['count'] as int? ?? 0)
        : 0;
    final wCount    = waitlist != null && waitlist.isNotEmpty
        ? (waitlist.first['count'] as int? ?? 0)
        : 0;
    return Lesson(
      id:                 json['id'] as String,
      courseId:           json['course_id'] as String,
      courseName:         course['name'] as String,
      courseType:         course['type'] as String,
      trainerName:        trainer?['full_name'] as String?,
      startTime:          DateTime.parse(json['starts_at'] as String).toLocal(),
      endTime:            DateTime.parse(json['ends_at'] as String).toLocal(),
      capacity:           json['capacity'] as int,
      bookedCount:        count,
      waitlistCount:      wCount,
      cancellationHours:  course['cancellation_hours'] as int? ?? 0,
    );
  }
}
