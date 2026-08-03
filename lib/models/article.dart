enum Priority { high, medium, low }

enum NewsCategory {
  federalPolicy,
  stateLocal,
  publicSafety,
  publicHealth,
  regulatoryCompliance,
  grantsFunding,
  govTech,
  workforceLabor,
}

extension NewsCategoryExtension on NewsCategory {
  String get displayName {
    switch (this) {
      case NewsCategory.federalPolicy:
        return 'Federal Policy';
      case NewsCategory.stateLocal:
        return 'State & Local';
      case NewsCategory.publicSafety:
        return 'Public Safety';
      case NewsCategory.publicHealth:
        return 'Public Health';
      case NewsCategory.regulatoryCompliance:
        return 'Regulatory/Compliance';
      case NewsCategory.grantsFunding:
        return 'Grants & Funding';
      case NewsCategory.govTech:
        return 'GovTech';
      case NewsCategory.workforceLabor:
        return 'Workforce/Labor';
    }
  }

  String get shortName {
    switch (this) {
      case NewsCategory.federalPolicy:
        return 'Federal';
      case NewsCategory.stateLocal:
        return 'State/Local';
      case NewsCategory.publicSafety:
        return 'Safety';
      case NewsCategory.publicHealth:
        return 'Health';
      case NewsCategory.regulatoryCompliance:
        return 'Regulatory';
      case NewsCategory.grantsFunding:
        return 'Grants';
      case NewsCategory.govTech:
        return 'GovTech';
      case NewsCategory.workforceLabor:
        return 'Workforce';
    }
  }
}

class Article {
  final String id;
  final String headline;
  final String summary;
  final String sourceName;
  final String sourceUrl;
  final DateTime publishedAt;
  final NewsCategory primaryCategory;
  final List<NewsCategory> additionalCategories;
  final Priority priority;
  final List<String> riskTags;
  final String riskAnalysis;
  final String? businessOpportunity;
  final String? actionRequired;
  final List<String> keyEntities;
  final List<String> entitiesAffected;
  final List<String> jurisdictionsAffected;
  final String geographicScope;
  final int sourceTier;
  final bool isBreaking;

  // AI-generated insights (optional, populated via Claude API)
  final String? aiSummary;
  final int? aiRiskScore; // 1-10
  final String? aiRiskRationale;
  final List<String> aiTrendTags;

  const Article({
    required this.id,
    required this.headline,
    required this.summary,
    required this.sourceName,
    required this.sourceUrl,
    required this.publishedAt,
    required this.primaryCategory,
    this.additionalCategories = const [],
    required this.priority,
    this.riskTags = const [],
    required this.riskAnalysis,
    this.businessOpportunity,
    this.actionRequired,
    this.keyEntities = const [],
    this.entitiesAffected = const [],
    this.jurisdictionsAffected = const [],
    this.geographicScope = 'National',
    this.sourceTier = 2,
    this.isBreaking = false,
    this.aiSummary,
    this.aiRiskScore,
    this.aiRiskRationale,
    this.aiTrendTags = const [],
  });

  /// Guaranteed-working URL: Google News search for the article headline.
  /// Always returns real, current articles even when sourceUrl is stale.
  String get searchUrl {
    final query = Uri.encodeComponent(headline);
    return 'https://www.google.com/search?q=$query&tbm=nws';
  }

  Article copyWith({
    String? aiSummary,
    int? aiRiskScore,
    String? aiRiskRationale,
    List<String>? aiTrendTags,
  }) {
    return Article(
      id: id,
      headline: headline,
      summary: summary,
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      publishedAt: publishedAt,
      primaryCategory: primaryCategory,
      additionalCategories: additionalCategories,
      priority: priority,
      riskTags: riskTags,
      riskAnalysis: riskAnalysis,
      businessOpportunity: businessOpportunity,
      actionRequired: actionRequired,
      keyEntities: keyEntities,
      entitiesAffected: entitiesAffected,
      jurisdictionsAffected: jurisdictionsAffected,
      geographicScope: geographicScope,
      sourceTier: sourceTier,
      isBreaking: isBreaking,
      aiSummary: aiSummary ?? this.aiSummary,
      aiRiskScore: aiRiskScore ?? this.aiRiskScore,
      aiRiskRationale: aiRiskRationale ?? this.aiRiskRationale,
      aiTrendTags: aiTrendTags ?? this.aiTrendTags,
    );
  }

  /// Public-safety stories get their own dashboard tab, so they are also
  /// excluded from the general feed to keep the two views disjoint.
  bool get isPublicSafety =>
      primaryCategory == NewsCategory.publicSafety ||
      additionalCategories.contains(NewsCategory.publicSafety);

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(publishedAt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${(diff.inDays / 7).floor()}w ago';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'headline': headline,
      'summary': summary,
      'sourceName': sourceName,
      'sourceUrl': sourceUrl,
      'publishedAt': publishedAt.toIso8601String(),
      'primaryCategory': primaryCategory.index,
      'additionalCategories': additionalCategories.map((c) => c.index).toList(),
      'priority': priority.index,
      'riskTags': riskTags,
      'riskAnalysis': riskAnalysis,
      'businessOpportunity': businessOpportunity,
      'actionRequired': actionRequired,
      'keyEntities': keyEntities,
      'entitiesAffected': entitiesAffected,
      'jurisdictionsAffected': jurisdictionsAffected,
      'geographicScope': geographicScope,
      'sourceTier': sourceTier,
      'isBreaking': isBreaking,
    };
  }

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'],
      headline: json['headline'],
      summary: json['summary'],
      sourceName: json['sourceName'],
      sourceUrl: json['sourceUrl'],
      publishedAt: DateTime.parse(json['publishedAt']),
      primaryCategory: NewsCategory.values[json['primaryCategory']],
      additionalCategories: (json['additionalCategories'] as List)
          .map((i) => NewsCategory.values[i as int])
          .toList(),
      priority: Priority.values[json['priority']],
      riskTags: List<String>.from(json['riskTags']),
      riskAnalysis: json['riskAnalysis'],
      businessOpportunity: json['businessOpportunity'],
      actionRequired: json['actionRequired'],
      keyEntities: List<String>.from(json['keyEntities']),
      entitiesAffected: List<String>.from(json['entitiesAffected']),
      jurisdictionsAffected: List<String>.from(json['jurisdictionsAffected']),
      geographicScope: json['geographicScope'],
      sourceTier: json['sourceTier'],
      isBreaking: json['isBreaking'],
    );
  }
}
