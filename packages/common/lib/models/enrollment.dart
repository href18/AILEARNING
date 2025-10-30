import 'package:meta/meta.dart';

@immutable
class Enrollment {
  const Enrollment({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.createdAt,
  });

  factory Enrollment.fromJson(Map<String, dynamic> json) {
    return Enrollment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      courseId: json['course_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String userId;
  final String courseId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'course_id': courseId,
        'created_at': createdAt.toIso8601String(),
      };

  Enrollment copyWith({
    String? id,
    String? userId,
    String? courseId,
    DateTime? createdAt,
  }) {
    return Enrollment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  int get hashCode => Object.hash(id, userId, courseId);

  @override
  bool operator ==(Object other) {
    return other is Enrollment &&
        other.id == id &&
        other.userId == userId &&
        other.courseId == courseId;
  }
}
