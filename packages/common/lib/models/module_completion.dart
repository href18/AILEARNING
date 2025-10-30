import 'package:meta/meta.dart';

@immutable
class ModuleCompletion {
  const ModuleCompletion({
    required this.moduleId,
    required this.userId,
    required this.isCompleted,
    this.avgScore,
  });

  factory ModuleCompletion.fromJson(Map<String, dynamic> json) {
    return ModuleCompletion(
      moduleId: json['module_id'] as String,
      userId: json['user_id'] as String,
      isCompleted: json['is_completed'] as bool,
      avgScore: json['avg_score'] as int?,
    );
  }

  final String moduleId;
  final String userId;
  final bool isCompleted;
  final int? avgScore;

  Map<String, dynamic> toJson() => {
        'module_id': moduleId,
        'user_id': userId,
        'is_completed': isCompleted,
        'avg_score': avgScore,
      };

  ModuleCompletion copyWith({
    String? moduleId,
    String? userId,
    bool? isCompleted,
    int? avgScore,
  }) {
    return ModuleCompletion(
      moduleId: moduleId ?? this.moduleId,
      userId: userId ?? this.userId,
      isCompleted: isCompleted ?? this.isCompleted,
      avgScore: avgScore ?? this.avgScore,
    );
  }

  @override
  int get hashCode => Object.hash(moduleId, userId, isCompleted, avgScore);

  @override
  bool operator ==(Object other) {
    return other is ModuleCompletion &&
        other.moduleId == moduleId &&
        other.userId == userId &&
        other.isCompleted == isCompleted &&
        other.avgScore == avgScore;
  }
}
