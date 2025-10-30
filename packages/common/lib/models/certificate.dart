import 'package:meta/meta.dart';

@immutable
class Certificate {
  const Certificate({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.issuedAt,
    this.pdfUrl,
  });

  factory Certificate.fromJson(Map<String, dynamic> json) {
    return Certificate(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      courseId: json['course_id'] as String,
      issuedAt: DateTime.parse(json['issued_at'] as String),
      pdfUrl: json['pdf_url'] as String?,
    );
  }

  final String id;
  final String userId;
  final String courseId;
  final DateTime issuedAt;
  final String? pdfUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'course_id': courseId,
        'issued_at': issuedAt.toIso8601String(),
        'pdf_url': pdfUrl,
      };

  Certificate copyWith({
    String? id,
    String? userId,
    String? courseId,
    DateTime? issuedAt,
    String? pdfUrl,
  }) {
    return Certificate(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      issuedAt: issuedAt ?? this.issuedAt,
      pdfUrl: pdfUrl ?? this.pdfUrl,
    );
  }

  @override
  int get hashCode => Object.hash(id, userId, courseId, issuedAt, pdfUrl);

  @override
  bool operator ==(Object other) {
    return other is Certificate &&
        other.id == id &&
        other.userId == userId &&
        other.courseId == courseId &&
        other.issuedAt == issuedAt &&
        other.pdfUrl == pdfUrl;
  }
}
