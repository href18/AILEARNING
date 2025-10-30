import 'package:meta/meta.dart';

@immutable
class Lesson {
  const Lesson({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.orderIndex,
    this.contentUrl,
    this.quizJson,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      moduleId: json['module_id'] as String,
      title: json['title'] as String,
      orderIndex: json['order_index'] as int,
      contentUrl: json['content_url'] as String?,
      quizJson: json['quiz_json'] as Map<String, dynamic>?,
    );
  }

  final String id;
  final String moduleId;
  final String title;
  final int orderIndex;
  final String? contentUrl;
  final Map<String, dynamic>? quizJson;

  Map<String, dynamic> toJson() => {
        'id': id,
        'module_id': moduleId,
        'title': title,
        'order_index': orderIndex,
        'content_url': contentUrl,
        'quiz_json': quizJson,
      };

  Lesson copyWith({
    String? id,
    String? moduleId,
    String? title,
    int? orderIndex,
    String? contentUrl,
    Map<String, dynamic>? quizJson,
  }) {
    return Lesson(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      title: title ?? this.title,
      orderIndex: orderIndex ?? this.orderIndex,
      contentUrl: contentUrl ?? this.contentUrl,
      quizJson: quizJson ?? this.quizJson,
    );
  }

  @override
  int get hashCode => Object.hash(id, moduleId, orderIndex);

  @override
  bool operator ==(Object other) {
    return other is Lesson &&
        other.id == id &&
        other.moduleId == moduleId &&
        other.orderIndex == orderIndex;
  }
}
