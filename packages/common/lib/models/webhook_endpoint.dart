import 'package:meta/meta.dart';

@immutable
class WebhookEndpoint {
  const WebhookEndpoint({
    required this.id,
    required this.ownerId,
    required this.url,
    this.description,
    required this.secret,
    required this.isActive,
    required this.eventTypes,
  });

  factory WebhookEndpoint.fromJson(Map<String, dynamic> json) {
    final events = json['event_types'];
    return WebhookEndpoint(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      url: json['url'] as String,
      description: json['description'] as String?,
      secret: json['secret'] as String,
      isActive: json['is_active'] as bool,
      eventTypes: events == null
          ? const <String>[]
          : List<String>.from(events as List<dynamic>),
    );
  }

  final String id;
  final String ownerId;
  final String url;
  final String? description;
  final String secret;
  final bool isActive;
  final List<String> eventTypes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'owner_id': ownerId,
        'url': url,
        'description': description,
        'secret': secret,
        'is_active': isActive,
        'event_types': eventTypes,
      };

  WebhookEndpoint copyWith({
    String? id,
    String? ownerId,
    String? url,
    String? description,
    String? secret,
    bool? isActive,
    List<String>? eventTypes,
  }) {
    return WebhookEndpoint(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      url: url ?? this.url,
      description: description ?? this.description,
      secret: secret ?? this.secret,
      isActive: isActive ?? this.isActive,
      eventTypes: eventTypes ?? List<String>.from(this.eventTypes),
    );
  }

  @override
  int get hashCode => Object.hash(id, ownerId, url, isActive);

  @override
  bool operator ==(Object other) {
    return other is WebhookEndpoint &&
        other.id == id &&
        other.ownerId == ownerId &&
        other.url == url &&
        other.isActive == isActive;
  }
}
