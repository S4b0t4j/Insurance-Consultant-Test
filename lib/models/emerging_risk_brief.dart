/// How much research the swarm does per run. Drives planner angle count,
/// web-search budget and per-call effort.
enum ResearchDepth { quick, standard, deep }

extension ResearchDepthInfo on ResearchDepth {
  String get label {
    switch (this) {
      case ResearchDepth.quick:
        return 'Quick scan';
      case ResearchDepth.standard:
        return 'Standard';
      case ResearchDepth.deep:
        return 'Deep dive';
    }
  }

  String get angleInstruction {
    switch (this) {
      case ResearchDepth.quick:
        return 'Decompose the topic into exactly 2-3 research angles.';
      case ResearchDepth.standard:
        return 'Decompose the topic into 3-5 research angles.';
      case ResearchDepth.deep:
        return 'Decompose the topic into 5-6 research angles.';
    }
  }

  int get searchUses {
    switch (this) {
      case ResearchDepth.quick:
        return 2;
      case ResearchDepth.standard:
        return 4;
      case ResearchDepth.deep:
        return 6;
    }
  }

  String get researchEffort {
    switch (this) {
      case ResearchDepth.quick:
        return 'low';
      case ResearchDepth.standard:
        return 'medium';
      case ResearchDepth.deep:
        return 'high';
    }
  }

  String get lensEffort {
    switch (this) {
      case ResearchDepth.quick:
        return 'medium';
      case ResearchDepth.standard:
        return 'high';
      case ResearchDepth.deep:
        return 'high';
    }
  }
}

/// Structured output of the Risk Desk agent swarm: a practitioner-grade
/// analysis of an emerging risk's commercial insurance implications.
class EmergingRiskBrief {
  final String topic;
  final String summary;
  final String velocity;
  final List<LineOfBusinessImpact> lines;
  final List<String> coverageGaps;
  final String marketOutlook;
  final List<String> recommendedActions;
  final List<BriefStat> stats;
  final List<BriefNewsItem> newsItems;
  final List<BriefCitation> citations;
  final DateTime generatedAt;

  EmergingRiskBrief({
    required this.topic,
    required this.summary,
    required this.velocity,
    required this.lines,
    required this.coverageGaps,
    required this.marketOutlook,
    required this.recommendedActions,
    required this.stats,
    required this.newsItems,
    required this.citations,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  /// Serialization used for radar persistence and the follow-up chat
  /// context. Round-trips with [EmergingRiskBrief.fromJson] (citations are
  /// carried in an extra key that fromJson also reads).
  Map<String, dynamic> toJson() => {
        'summary': summary,
        'velocity': velocity,
        'linesOfBusiness': [
          for (final l in lines)
            {
              'line': l.line,
              'exposure': l.exposure,
              'underwritingConsiderations': l.underwritingConsiderations,
              'severity': l.severity,
            }
        ],
        'coverageGaps': coverageGaps,
        'marketOutlook': marketOutlook,
        'recommendedActions': recommendedActions,
        'stats': [
          for (final s in stats)
            {'value': s.value, 'label': s.label, 'source': s.source}
        ],
        'newsItems': [
          for (final n in newsItems)
            {'date': n.date, 'headline': n.headline, 'summary': n.summary}
        ],
        'citations': [
          for (final c in citations) {'title': c.title, 'url': c.url}
        ],
      };

  factory EmergingRiskBrief.fromJson(String topic, Map<String, dynamic> json) {
    List<T> mapList<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((json[key] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(f)
            .toList();
    return EmergingRiskBrief(
      topic: topic,
      summary: json['summary'] ?? '',
      velocity: json['velocity'] ?? '',
      lines: mapList('linesOfBusiness', LineOfBusinessImpact.fromJson),
      coverageGaps: List<String>.from(json['coverageGaps'] ?? []),
      marketOutlook: json['marketOutlook'] ?? '',
      recommendedActions: List<String>.from(json['recommendedActions'] ?? []),
      stats: mapList('stats', BriefStat.fromJson),
      newsItems: mapList('newsItems', BriefNewsItem.fromJson),
      citations: mapList('citations', BriefCitation.fromJson),
    );
  }
}

class LineOfBusinessImpact {
  final String line;
  final String exposure;
  final String underwritingConsiderations;
  final String severity;

  const LineOfBusinessImpact({
    required this.line,
    required this.exposure,
    required this.underwritingConsiderations,
    required this.severity,
  });

  factory LineOfBusinessImpact.fromJson(Map<String, dynamic> json) =>
      LineOfBusinessImpact(
        line: json['line'] ?? '',
        exposure: json['exposure'] ?? '',
        underwritingConsiderations: json['underwritingConsiderations'] ?? '',
        severity: json['severity'] ?? 'medium',
      );
}

class BriefStat {
  final String value;
  final String label;
  final String source;

  const BriefStat({required this.value, required this.label, this.source = ''});

  factory BriefStat.fromJson(Map<String, dynamic> json) => BriefStat(
        value: json['value'] ?? '',
        label: json['label'] ?? '',
        source: json['source'] ?? '',
      );
}

class BriefNewsItem {
  final String date;
  final String headline;
  final String summary;

  const BriefNewsItem({
    required this.date,
    required this.headline,
    required this.summary,
  });

  factory BriefNewsItem.fromJson(Map<String, dynamic> json) => BriefNewsItem(
        date: json['date'] ?? '',
        headline: json['headline'] ?? '',
        summary: json['summary'] ?? '',
      );
}

class BriefCitation {
  final String title;
  final String url;

  const BriefCitation({required this.title, required this.url});

  factory BriefCitation.fromJson(Map<String, dynamic> json) => BriefCitation(
        title: json['title'] ?? '',
        url: json['url'] ?? '',
      );
}

/// Progress states for the swarm UI.
enum SwarmStageStatus { pending, running, done, failed, skipped }

class SwarmStage {
  final String id;
  final String label;
  SwarmStageStatus status;
  String note;

  SwarmStage({
    required this.id,
    required this.label,
    this.status = SwarmStageStatus.pending,
    this.note = '',
  });
}
