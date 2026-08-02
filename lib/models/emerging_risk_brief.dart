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
