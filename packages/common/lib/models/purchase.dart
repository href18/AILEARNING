import 'package:meta/meta.dart';

@immutable
class Purchase {
  const Purchase({
    required this.id,
    required this.userId,
    required this.courseId,
    this.stripePaymentIntent,
    required this.amountCents,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      courseId: json['course_id'] as String,
      stripePaymentIntent: json['stripe_payment_intent'] as String?,
      amountCents: json['amount_cents'] as int,
      currency: json['currency'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String userId;
  final String courseId;
  final String? stripePaymentIntent;
  final int amountCents;
  final String currency;
  final String status;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'course_id': courseId,
        'stripe_payment_intent': stripePaymentIntent,
        'amount_cents': amountCents,
        'currency': currency,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };

  Purchase copyWith({
    String? id,
    String? userId,
    String? courseId,
    String? stripePaymentIntent,
    int? amountCents,
    String? currency,
    String? status,
    DateTime? createdAt,
  }) {
    return Purchase(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      stripePaymentIntent: stripePaymentIntent ?? this.stripePaymentIntent,
      amountCents: amountCents ?? this.amountCents,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  int get hashCode => Object.hash(id, userId, courseId, status);

  @override
  bool operator ==(Object other) {
    return other is Purchase &&
        other.id == id &&
        other.userId == userId &&
        other.courseId == courseId &&
        other.status == status;
  }
}
