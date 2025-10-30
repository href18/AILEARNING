import 'package:meta/meta.dart';

@immutable
class Module {
  const Module({
    required this.id,
    required this.courseId,
    required this.title,
    required this.orderIndex,
    required this.required,
    this.passingScore,
  });

  factory Module.fromJson(Map<String, dynamic> json) {
    return Module(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      title: json['title'] as String,
      orderIndex: json['order_index'] as int,
      required: json['required'] as bool,
      passingScore: json['passing_score'] as int?,
    );
  }

  final String id;
  final String courseId;
  final String title;
  final int orderIndex;
  final bool required;
  final int? passingScore;

  Map<String, dynamic> toJson() => {
        'id': id,
        'course_id': courseId,
        'title': title,
        'order_index': orderIndex,
        'required': required,
        'passing_score': passingScore,
      };

  Module copyWith({
    String? id,
    String? courseId,
    String? title,
    int? orderIndex,
    bool? required,
    int? passingScore,
  }) {
    return Module(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      orderIndex: orderIndex ?? this.orderIndex,
      required: required ?? this.required,
      passingScore: passingScore ?? this.passingScore,
    );
  }

  @override
  int get hashCode => Object.hash(id, courseId, orderIndex);

  @override
  bool operator ==(Object other) {
    return other is Module &&
        other.id == id &&
        other.courseId == courseId &&
        other.orderIndex == orderIndex;
  }
}
