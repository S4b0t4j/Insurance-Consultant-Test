import 'package:flutter/material.dart';
import 'article.dart';

/// Types of alert rules that can be configured
enum AlertRuleType {
  priorityThreshold,   // X+ high-priority articles in Y hours
  keywordMatch,        // Custom keyword detected
  categorySpike,       // Unusual activity in a category
  breakingNews,        // Any breaking news
  regulatoryDeadline,  // Upcoming compliance deadline
  institutionMention,  // Specific institution mentioned
  conferenceMention,   // Specific conference mentioned
}

extension AlertRuleTypeExtension on AlertRuleType {
  String get displayName {
    switch (this) {
      case AlertRuleType.priorityThreshold:
        return 'Priority Threshold';
      case AlertRuleType.keywordMatch:
        return 'Keyword Match';
      case AlertRuleType.categorySpike:
        return 'Category Spike';
      case AlertRuleType.breakingNews:
        return 'Breaking News';
      case AlertRuleType.regulatoryDeadline:
        return 'Regulatory Deadline';
      case AlertRuleType.institutionMention:
        return 'Institution Mention';
      case AlertRuleType.conferenceMention:
        return 'Conference Mention';
    }
  }

  IconData get icon {
    switch (this) {
      case AlertRuleType.priorityThreshold:
        return Icons.trending_up;
      case AlertRuleType.keywordMatch:
        return Icons.search;
      case AlertRuleType.categorySpike:
        return Icons.show_chart;
      case AlertRuleType.breakingNews:
        return Icons.flash_on;
      case AlertRuleType.regulatoryDeadline:
        return Icons.event;
      case AlertRuleType.institutionMention:
        return Icons.school;
      case AlertRuleType.conferenceMention:
        return Icons.sports_football;
    }
  }
}

/// Severity level for triggered alerts
enum AlertSeverity {
  critical,  // Immediate action required
  high,      // Urgent attention needed
  medium,    // Monitor closely
  low,       // Informational
}

extension AlertSeverityExtension on AlertSeverity {
  String get displayName {
    switch (this) {
      case AlertSeverity.critical:
        return 'Critical';
      case AlertSeverity.high:
        return 'High';
      case AlertSeverity.medium:
        return 'Medium';
      case AlertSeverity.low:
        return 'Low';
    }
  }

  Color get color {
    switch (this) {
      case AlertSeverity.critical:
        return const Color(0xFF7F1D1D); // Dark red
      case AlertSeverity.high:
        return const Color(0xFFDC2626); // Red
      case AlertSeverity.medium:
        return const Color(0xFFF59E0B); // Orange
      case AlertSeverity.low:
        return const Color(0xFF16A34A); // Green
    }
  }
}

/// Configuration for an alert rule
class AlertRule {
  final String id;
  final String name;
  final String description;
  final AlertRuleType type;
  final AlertSeverity severity;
  final bool isEnabled;
  final DateTime createdAt;

  // Threshold settings (for priorityThreshold type)
  final int? thresholdCount;
  final int? thresholdHours;
  final Priority? thresholdPriority;

  // Keyword settings (for keywordMatch type)
  final List<String> keywords;
  final bool keywordCaseSensitive;

  // Category settings (for categorySpike type)
  final NewsCategory? targetCategory;
  final int? spikeThreshold;

  // Institution/Conference settings
  final List<String> watchedInstitutions;
  final List<String> watchedConferences;

  // Deadline settings (for regulatoryDeadline type)
  final DateTime? deadlineDate;
  final int? reminderDaysBefore;

  const AlertRule({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.severity = AlertSeverity.medium,
    this.isEnabled = true,
    required this.createdAt,
    this.thresholdCount,
    this.thresholdHours,
    this.thresholdPriority,
    this.keywords = const [],
    this.keywordCaseSensitive = false,
    this.targetCategory,
    this.spikeThreshold,
    this.watchedInstitutions = const [],
    this.watchedConferences = const [],
    this.deadlineDate,
    this.reminderDaysBefore,
  });

  AlertRule copyWith({
    String? id,
    String? name,
    String? description,
    AlertRuleType? type,
    AlertSeverity? severity,
    bool? isEnabled,
    DateTime? createdAt,
    int? thresholdCount,
    int? thresholdHours,
    Priority? thresholdPriority,
    List<String>? keywords,
    bool? keywordCaseSensitive,
    NewsCategory? targetCategory,
    int? spikeThreshold,
    List<String>? watchedInstitutions,
    List<String>? watchedConferences,
    DateTime? deadlineDate,
    int? reminderDaysBefore,
  }) {
    return AlertRule(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      thresholdCount: thresholdCount ?? this.thresholdCount,
      thresholdHours: thresholdHours ?? this.thresholdHours,
      thresholdPriority: thresholdPriority ?? this.thresholdPriority,
      keywords: keywords ?? this.keywords,
      keywordCaseSensitive: keywordCaseSensitive ?? this.keywordCaseSensitive,
      targetCategory: targetCategory ?? this.targetCategory,
      spikeThreshold: spikeThreshold ?? this.spikeThreshold,
      watchedInstitutions: watchedInstitutions ?? this.watchedInstitutions,
      watchedConferences: watchedConferences ?? this.watchedConferences,
      deadlineDate: deadlineDate ?? this.deadlineDate,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.index,
      'severity': severity.index,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
      'thresholdCount': thresholdCount,
      'thresholdHours': thresholdHours,
      'thresholdPriority': thresholdPriority?.index,
      'keywords': keywords,
      'keywordCaseSensitive': keywordCaseSensitive,
      'targetCategory': targetCategory?.index,
      'spikeThreshold': spikeThreshold,
      'watchedInstitutions': watchedInstitutions,
      'watchedConferences': watchedConferences,
      'deadlineDate': deadlineDate?.toIso8601String(),
      'reminderDaysBefore': reminderDaysBefore,
    };
  }

  factory AlertRule.fromJson(Map<String, dynamic> json) {
    return AlertRule(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: AlertRuleType.values[json['type']],
      severity: AlertSeverity.values[json['severity']],
      isEnabled: json['isEnabled'],
      createdAt: DateTime.parse(json['createdAt']),
      thresholdCount: json['thresholdCount'],
      thresholdHours: json['thresholdHours'],
      thresholdPriority: json['thresholdPriority'] != null
          ? Priority.values[json['thresholdPriority']]
          : null,
      keywords: List<String>.from(json['keywords'] ?? []),
      keywordCaseSensitive: json['keywordCaseSensitive'] ?? false,
      targetCategory: json['targetCategory'] != null
          ? NewsCategory.values[json['targetCategory']]
          : null,
      spikeThreshold: json['spikeThreshold'],
      watchedInstitutions: List<String>.from(json['watchedInstitutions'] ?? []),
      watchedConferences: List<String>.from(json['watchedConferences'] ?? []),
      deadlineDate: json['deadlineDate'] != null
          ? DateTime.parse(json['deadlineDate'])
          : null,
      reminderDaysBefore: json['reminderDaysBefore'],
    );
  }
}

/// A triggered alert instance
class TriggeredAlert {
  final String id;
  final AlertRule rule;
  final DateTime triggeredAt;
  final String message;
  final List<Article> relatedArticles;
  final bool isRead;
  final bool isDismissed;

  const TriggeredAlert({
    required this.id,
    required this.rule,
    required this.triggeredAt,
    required this.message,
    this.relatedArticles = const [],
    this.isRead = false,
    this.isDismissed = false,
  });

  TriggeredAlert copyWith({
    String? id,
    AlertRule? rule,
    DateTime? triggeredAt,
    String? message,
    List<Article>? relatedArticles,
    bool? isRead,
    bool? isDismissed,
  }) {
    return TriggeredAlert(
      id: id ?? this.id,
      rule: rule ?? this.rule,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      message: message ?? this.message,
      relatedArticles: relatedArticles ?? this.relatedArticles,
      isRead: isRead ?? this.isRead,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(triggeredAt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rule': rule.toJson(),
      'triggeredAt': triggeredAt.toIso8601String(),
      'message': message,
      'relatedArticleIds': relatedArticles.map((a) => a.id).toList(),
      'isRead': isRead,
      'isDismissed': isDismissed,
    };
  }
}

/// Regulatory deadline entry
class RegulatoryDeadline {
  final String id;
  final String title;
  final String description;
  final DateTime deadline;
  final String? regulatoryBody;
  final List<String> affectedInstitutionTypes;
  final String? complianceUrl;
  final bool isCompleted;

  const RegulatoryDeadline({
    required this.id,
    required this.title,
    required this.description,
    required this.deadline,
    this.regulatoryBody,
    this.affectedInstitutionTypes = const [],
    this.complianceUrl,
    this.isCompleted = false,
  });

  int get daysUntilDeadline {
    return deadline.difference(DateTime.now()).inDays;
  }

  bool get isOverdue => daysUntilDeadline < 0;
  bool get isUrgent => daysUntilDeadline <= 7 && daysUntilDeadline >= 0;
  bool get isUpcoming => daysUntilDeadline <= 30 && daysUntilDeadline > 7;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'deadline': deadline.toIso8601String(),
      'regulatoryBody': regulatoryBody,
      'affectedInstitutionTypes': affectedInstitutionTypes,
      'complianceUrl': complianceUrl,
      'isCompleted': isCompleted,
    };
  }

  factory RegulatoryDeadline.fromJson(Map<String, dynamic> json) {
    return RegulatoryDeadline(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      deadline: DateTime.parse(json['deadline']),
      regulatoryBody: json['regulatoryBody'],
      affectedInstitutionTypes:
          List<String>.from(json['affectedInstitutionTypes'] ?? []),
      complianceUrl: json['complianceUrl'],
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}
