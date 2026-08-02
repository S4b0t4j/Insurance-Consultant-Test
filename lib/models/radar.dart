import 'report_source.dart';

enum RadarFindingStatus { detected, analyzing, analyzed, dismissed }

enum RadarUrgency { low, medium, high }

/// Configuration for the continuous risk radar. Persisted per browser.
class RadarConfig {
  bool enabled;
  int scanIntervalMinutes;
  List<RssTopic> topics;
  bool autoRunSwarm;
  bool discordAlerts;

  RadarConfig({
    this.enabled = false,
    this.scanIntervalMinutes = 30,
    List<RssTopic>? topics,
    this.autoRunSwarm = false,
    this.discordAlerts = false,
  }) : topics = topics ?? List.of(RssTopic.defaults);

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'scanIntervalMinutes': scanIntervalMinutes,
        'topics': [
          for (final t in topics)
            {'label': t.label, 'query': t.query, 'builtIn': t.builtIn}
        ],
        'autoRunSwarm': autoRunSwarm,
        'discordAlerts': discordAlerts,
      };

  factory RadarConfig.fromJson(Map<String, dynamic> json) => RadarConfig(
        enabled: json['enabled'] ?? false,
        scanIntervalMinutes: json['scanIntervalMinutes'] ?? 30,
        topics: [
          for (final t in (json['topics'] as List? ?? [])
              .whereType<Map<String, dynamic>>())
            RssTopic(
              label: t['label'] ?? '',
              query: t['query'] ?? '',
              builtIn: t['builtIn'] ?? false,
            ),
        ],
        autoRunSwarm: json['autoRunSwarm'] ?? false,
        discordAlerts: json['discordAlerts'] ?? false,
      );
}

/// One emerging risk detected by the radar's triage pass.
class RadarFinding {
  final String id;
  final String title;
  final String rationale;
  final RadarUrgency urgency;
  final List<String> headlines;
  final DateTime detectedAt;
  RadarFindingStatus status;

  /// Serialized EmergingRiskBrief once a swarm run completes for it.
  Map<String, dynamic>? briefJson;

  RadarFinding({
    required this.id,
    required this.title,
    required this.rationale,
    required this.urgency,
    required this.headlines,
    required this.detectedAt,
    this.status = RadarFindingStatus.detected,
    this.briefJson,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'rationale': rationale,
        'urgency': urgency.name,
        'headlines': headlines,
        'detectedAt': detectedAt.toIso8601String(),
        'status': status.name,
        'briefJson': briefJson,
      };

  factory RadarFinding.fromJson(Map<String, dynamic> json) => RadarFinding(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        rationale: json['rationale'] ?? '',
        urgency: RadarUrgency.values.firstWhere(
          (u) => u.name == json['urgency'],
          orElse: () => RadarUrgency.medium,
        ),
        headlines: List<String>.from(json['headlines'] ?? []),
        detectedAt:
            DateTime.tryParse(json['detectedAt'] ?? '') ?? DateTime.now(),
        status: RadarFindingStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => RadarFindingStatus.detected,
        ),
        briefJson: json['briefJson'] is Map<String, dynamic>
            ? json['briefJson'] as Map<String, dynamic>
            : null,
      );
}

/// Fingerprinting for already-seen headlines so scans only triage what is
/// genuinely new. Pure functions — unit tested without network.
class HeadlineFingerprints {
  static const Duration expiry = Duration(days: 30);

  /// Normalized fingerprint: lowercase, alphanumerics+spaces only, squeezed.
  static String fingerprint(String headline) => headline
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Removes fingerprints older than [expiry]. Map is fingerprint -> ISO date.
  static Map<String, String> prune(Map<String, String> seen, DateTime now) {
    final out = <String, String>{};
    seen.forEach((fp, iso) {
      final ts = DateTime.tryParse(iso);
      if (ts != null && now.difference(ts) < expiry) out[fp] = iso;
    });
    return out;
  }

  /// Splits [headlines] into those not yet seen, updating [seen] in place.
  static List<String> filterNew(
      Map<String, String> seen, List<String> headlines, DateTime now) {
    final fresh = <String>[];
    for (final h in headlines) {
      final fp = fingerprint(h);
      if (fp.isEmpty || seen.containsKey(fp)) continue;
      seen[fp] = now.toIso8601String();
      fresh.add(h);
    }
    return fresh;
  }
}
