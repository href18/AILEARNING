import 'package:meta/meta.dart';

@immutable
class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.role,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String displayName;
  final String role;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'role': role,
        'created_at': createdAt.toIso8601String(),
      };

  Profile copyWith({
    String? id,
    String? displayName,
    String? role,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  int get hashCode => Object.hash(id, displayName, role, createdAt);

  @override
  bool operator ==(Object other) {
    return other is Profile &&
        other.id == id &&
        other.displayName == displayName &&
        other.role == role &&
        other.createdAt == createdAt;
  }
}
