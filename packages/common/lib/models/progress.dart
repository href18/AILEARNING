import 'package:meta/meta.dart';

@immutable
class Progress {
  const Progress({
    required this.id,
    required this.userId,
    required this.lessonId,
    required this.isCompleted,
    this.score,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Progress.fromJson(Map<String, dynamic> json) {
    return Progress(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      lessonId: json['lesson_id'] as String,
      isCompleted: json['is_completed'] as bool,
      score: json['score'] as int?,
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String userId;
  final String lessonId;
  final bool isCompleted;
  final int? score;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'lesson_id': lessonId,
        'is_completed': isCompleted,
        'score': score,
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Progress copyWith({
    String? id,
    String? userId,
    String? lessonId,
    bool? isCompleted,
    int? score,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Progress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lessonId: lessonId ?? this.lessonId,
      isCompleted: isCompleted ?? this.isCompleted,
      score: score ?? this.score,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  int get hashCode => Object.hash(id, userId, lessonId, updatedAt);

  @override
  bool operator ==(Object other) {
    return other is Progress &&
        other.id == id &&
        other.userId == userId &&
        other.lessonId == lessonId &&
        other.updatedAt == updatedAt;
  }
}
