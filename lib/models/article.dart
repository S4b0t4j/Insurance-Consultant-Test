enum Priority { high, medium, low }

enum NewsCategory {
  federalDoe,
  higherEducation,
  sportsNil,
  healthcareEducation,
  regulatoryCompliance,
  financialAid,
  edTech,
  workforceLabor,
}

extension NewsCategoryExtension on NewsCategory {
  String get displayName {
    switch (this) {
      case NewsCategory.federalDoe:
        return 'Federal/DOE';
      case NewsCategory.higherEducation:
        return 'Higher Education';
      case NewsCategory.sportsNil:
        return 'Sports & NIL';
      case NewsCategory.healthcareEducation:
        return 'Healthcare in Education';
      case NewsCategory.regulatoryCompliance:
        return 'Regulatory/Compliance';
      case NewsCategory.financialAid:
        return 'Financial Aid';
      case NewsCategory.edTech:
        return 'EdTech';
      case NewsCategory.workforceLabor:
        return 'Workforce/Labor';
    }
  }

  String get shortName {
    switch (this) {
      case NewsCategory.federalDoe:
        return 'DOE';
      case NewsCategory.higherEducation:
        return 'Higher Ed';
      case NewsCategory.sportsNil:
        return 'NIL/Sports';
      case NewsCategory.healthcareEducation:
        return 'Healthcare';
      case NewsCategory.regulatoryCompliance:
        return 'Regulatory';
      case NewsCategory.financialAid:
        return 'Financial Aid';
      case NewsCategory.edTech:
        return 'EdTech';
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
  final List<String> institutionsAffected;
  final List<String> conferencesAffected;
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
    this.institutionsAffected = const [],
    this.conferencesAffected = const [],
    this.geographicScope = 'National',
    this.sourceTier = 2,
    this.isBreaking = false,
    this.aiSummary,
    this.aiRiskScore,
    this.aiRiskRationale,
    this.aiTrendTags = const [],
  });

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
      institutionsAffected: institutionsAffected,
      conferencesAffected: conferencesAffected,
      geographicScope: geographicScope,
      sourceTier: sourceTier,
      isBreaking: isBreaking,
      aiSummary: aiSummary ?? this.aiSummary,
      aiRiskScore: aiRiskScore ?? this.aiRiskScore,
      aiRiskRationale: aiRiskRationale ?? this.aiRiskRationale,
      aiTrendTags: aiTrendTags ?? this.aiTrendTags,
    );
  }

  bool get isNilSports =>
      primaryCategory == NewsCategory.sportsNil ||
      additionalCategories.contains(NewsCategory.sportsNil);

  bool get isEducationOnly =>
      !isNilSports &&
      primaryCategory != NewsCategory.sportsNil;

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
      'institutionsAffected': institutionsAffected,
      'conferencesAffected': conferencesAffected,
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
      institutionsAffected: List<String>.from(json['institutionsAffected']),
      conferencesAffected: List<String>.from(json['conferencesAffected']),
      geographicScope: json['geographicScope'],
      sourceTier: json['sourceTier'],
      isBreaking: json['isBreaking'],
    );
  }
}
