import 'package:meta/meta.dart';

@immutable
class CourseCompletion {
  const CourseCompletion({
    required this.courseId,
    required this.userId,
    required this.isCompleted,
    this.avgScore,
  });

  factory CourseCompletion.fromJson(Map<String, dynamic> json) {
    return CourseCompletion(
      courseId: json['course_id'] as String,
      userId: json['user_id'] as String,
      isCompleted: json['is_completed'] as bool,
      avgScore: json['avg_score'] as int?,
    );
  }

  final String courseId;
  final String userId;
  final bool isCompleted;
  final int? avgScore;

  Map<String, dynamic> toJson() => {
        'course_id': courseId,
        'user_id': userId,
        'is_completed': isCompleted,
        'avg_score': avgScore,
      };

  CourseCompletion copyWith({
    String? courseId,
    String? userId,
    bool? isCompleted,
    int? avgScore,
  }) {
    return CourseCompletion(
      courseId: courseId ?? this.courseId,
      userId: userId ?? this.userId,
      isCompleted: isCompleted ?? this.isCompleted,
      avgScore: avgScore ?? this.avgScore,
    );
  }

  @override
  int get hashCode => Object.hash(courseId, userId, isCompleted, avgScore);

  @override
  bool operator ==(Object other) {
    return other is CourseCompletion &&
        other.courseId == courseId &&
        other.userId == userId &&
        other.isCompleted == isCompleted &&
        other.avgScore == avgScore;
  }
}
