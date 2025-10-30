import 'package:meta/meta.dart';

@immutable
class Course {
  const Course({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.slug,
    this.description,
    required this.priceCents,
    required this.currency,
    required this.isPublished,
    this.thumbnailUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      title: json['title'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      priceCents: json['price_cents'] as int,
      currency: json['currency'] as String,
      isPublished: json['is_published'] as bool,
      thumbnailUrl: json['thumbnail_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String creatorId;
  final String title;
  final String slug;
  final String? description;
  final int priceCents;
  final String currency;
  final bool isPublished;
  final String? thumbnailUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'creator_id': creatorId,
        'title': title,
        'slug': slug,
        'description': description,
        'price_cents': priceCents,
        'currency': currency,
        'is_published': isPublished,
        'thumbnail_url': thumbnailUrl,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Course copyWith({
    String? id,
    String? creatorId,
    String? title,
    String? slug,
    String? description,
    int? priceCents,
    String? currency,
    bool? isPublished,
    String? thumbnailUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Course(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      priceCents: priceCents ?? this.priceCents,
      currency: currency ?? this.currency,
      isPublished: isPublished ?? this.isPublished,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  int get hashCode => Object.hash(id, creatorId, slug, updatedAt);

  @override
  bool operator ==(Object other) {
    return other is Course &&
        other.id == id &&
        other.creatorId == creatorId &&
        other.slug == slug &&
        other.updatedAt == updatedAt;
  }
}
