import 'package:intl/intl.dart';

class Assignment {
  Assignment({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.course,
    required this.progress,
    this.dueAt,
    this.certificate,
  });

  final String id;
  final String status;
  final DateTime? dueAt;
  final DateTime createdAt;
  final AssignmentCourse course;
  final AssignmentProgress progress;
  final AssignmentCertificate? certificate;

  String get statusLabel {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'in_progress':
        return 'In progress';
      case 'overdue':
        return 'Overdue';
      case 'expired':
        return 'Expired';
      default:
        return 'Assigned';
    }
  }

  String? get dueLabel =>
      dueAt != null ? DateFormat.yMMMMd().format(dueAt!.toLocal()) : null;

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'assigned',
      dueAt: _parseDate(json['dueAt'] as String?),
      createdAt: _parseDate(json['createdAt'] as String)!,
      course: AssignmentCourse.fromJson(json['course'] as Map<String, dynamic>),
      progress: AssignmentProgress.fromJson(json['progress'] as Map<String, dynamic>),
      certificate: json['certificate'] == null
          ? null
          : AssignmentCertificate.fromJson(json['certificate'] as Map<String, dynamic>),
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}

class AssignmentCourse {
  AssignmentCourse({
    required this.id,
    required this.code,
    required this.title,
  });

  final String id;
  final String code;
  final String title;

  factory AssignmentCourse.fromJson(Map<String, dynamic> json) {
    return AssignmentCourse(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
    );
  }
}

class AssignmentProgress {
  AssignmentProgress({
    required this.modulesTotal,
    required this.modulesCompleted,
    required this.percent,
    this.lastActivityAt,
  });

  final int modulesTotal;
  final int modulesCompleted;
  final int percent;
  final DateTime? lastActivityAt;

  double get completionRatio => modulesTotal == 0 ? 0 : percent / 100;

  String? get lastActivityLabel => lastActivityAt == null
      ? null
      : DateFormat.yMMMd().add_Hm().format(lastActivityAt!.toLocal());

  factory AssignmentProgress.fromJson(Map<String, dynamic> json) {
    return AssignmentProgress(
      modulesTotal: json['modulesTotal'] as int? ?? 0,
      modulesCompleted: json['modulesCompleted'] as int? ?? 0,
      percent: json['percent'] as int? ?? 0,
      lastActivityAt: Assignment._parseDate(json['lastActivityAt'] as String?),
    );
  }
}

class AssignmentCertificate {
  AssignmentCertificate({
    required this.id,
    required this.issuedAt,
    required this.expiresAt,
    required this.url,
  });

  final String id;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final String? url;

  String? get issuedLabel =>
      issuedAt != null ? DateFormat.yMMMd().format(issuedAt!.toLocal()) : null;
  String? get expiresLabel =>
      expiresAt != null ? DateFormat.yMMMd().format(expiresAt!.toLocal()) : null;

  factory AssignmentCertificate.fromJson(Map<String, dynamic> json) {
    return AssignmentCertificate(
      id: json['id'] as String,
      issuedAt: Assignment._parseDate(json['issuedAt'] as String?),
      expiresAt: Assignment._parseDate(json['expiresAt'] as String?),
      url: json['url'] as String?,
    );
  }
}
