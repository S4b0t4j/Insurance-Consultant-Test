enum NotificationFrequency {
  immediate,
  daily,
  weekly,
}

extension NotificationFrequencyExtension on NotificationFrequency {
  String get displayName {
    switch (this) {
      case NotificationFrequency.immediate:
        return 'Immediate';
      case NotificationFrequency.daily:
        return 'Daily Digest';
      case NotificationFrequency.weekly:
        return 'Weekly Digest';
    }
  }
}

enum FeedPreference {
  all,
  educationOnly,
  nilSportsOnly,
}

extension FeedPreferenceExtension on FeedPreference {
  String get displayName {
    switch (this) {
      case FeedPreference.all:
        return 'All News';
      case FeedPreference.educationOnly:
        return 'Education Only';
      case FeedPreference.nilSportsOnly:
        return 'NIL/Sports Only';
    }
  }
}

class Subscriber {
  final String id;
  final String email;
  final String name;
  final NotificationFrequency frequency;
  final FeedPreference feedPreference;
  final bool highPriorityImmediate;
  final bool isPaused;
  final DateTime createdAt;
  final DateTime? lastDigestSent;

  const Subscriber({
    required this.id,
    required this.email,
    required this.name,
    this.frequency = NotificationFrequency.daily,
    this.feedPreference = FeedPreference.all,
    this.highPriorityImmediate = true,
    this.isPaused = false,
    required this.createdAt,
    this.lastDigestSent,
  });

  Subscriber copyWith({
    String? id,
    String? email,
    String? name,
    NotificationFrequency? frequency,
    FeedPreference? feedPreference,
    bool? highPriorityImmediate,
    bool? isPaused,
    DateTime? createdAt,
    DateTime? lastDigestSent,
  }) {
    return Subscriber(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      feedPreference: feedPreference ?? this.feedPreference,
      highPriorityImmediate: highPriorityImmediate ?? this.highPriorityImmediate,
      isPaused: isPaused ?? this.isPaused,
      createdAt: createdAt ?? this.createdAt,
      lastDigestSent: lastDigestSent ?? this.lastDigestSent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'frequency': frequency.index,
      'feedPreference': feedPreference.index,
      'highPriorityImmediate': highPriorityImmediate,
      'isPaused': isPaused,
      'createdAt': createdAt.toIso8601String(),
      'lastDigestSent': lastDigestSent?.toIso8601String(),
    };
  }

  factory Subscriber.fromJson(Map<String, dynamic> json) {
    return Subscriber(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      frequency: NotificationFrequency.values[json['frequency']],
      feedPreference: FeedPreference.values[json['feedPreference']],
      highPriorityImmediate: json['highPriorityImmediate'],
      isPaused: json['isPaused'],
      createdAt: DateTime.parse(json['createdAt']),
      lastDigestSent: json['lastDigestSent'] != null
          ? DateTime.parse(json['lastDigestSent'])
          : null,
    );
  }
}
