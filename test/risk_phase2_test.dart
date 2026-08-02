import 'package:education_news_monitor/models/emerging_risk_brief.dart';
import 'package:education_news_monitor/models/radar.dart';
import 'package:education_news_monitor/models/report_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmergingRiskBrief JSON round-trip', () {
    test('toJson -> fromJson preserves all fields', () {
      final brief = EmergingRiskBrief(
        topic: 'Helium shortage',
        summary: 'Qatar force majeure removed 30% of supply.',
        velocity: 'Fast-moving; 2-3 quarter horizon.',
        lines: const [
          LineOfBusinessImpact(
            line: 'Property',
            exposure: 'Business interruption for MRI-dependent hospitals.',
            underwritingConsiderations: 'Ask about helium contracts.',
            severity: 'high',
          ),
        ],
        coverageGaps: const ['Contingent BI sublimits'],
        marketOutlook: 'Capacity tightening.',
        recommendedActions: const ['Review supply contracts'],
        stats: const [
          BriefStat(value: '~30%', label: 'global supply at risk', source: 'EIA'),
        ],
        newsItems: const [
          BriefNewsItem(
              date: '2026-02-10',
              headline: 'QatarEnergy halts LNG',
              summary: 'Force majeure declared.'),
        ],
        citations: [const BriefCitation(title: 'Reuters', url: 'https://r.example')],
      );

      final restored =
          EmergingRiskBrief.fromJson('Helium shortage', brief.toJson());
      expect(restored.summary, brief.summary);
      expect(restored.velocity, brief.velocity);
      expect(restored.lines.single.line, 'Property');
      expect(restored.lines.single.severity, 'high');
      expect(restored.coverageGaps, brief.coverageGaps);
      expect(restored.marketOutlook, brief.marketOutlook);
      expect(restored.recommendedActions, brief.recommendedActions);
      expect(restored.stats.single.value, '~30%');
      expect(restored.newsItems.single.headline, 'QatarEnergy halts LNG');
      expect(restored.citations.single.url, 'https://r.example');
    });
  });

  group('Radar models JSON round-trip', () {
    test('RadarConfig', () {
      final config = RadarConfig(
        enabled: true,
        scanIntervalMinutes: 15,
        topics: [const RssTopic(label: 'Cyber', query: 'cyber risk', builtIn: false)],
        autoRunSwarm: true,
        discordAlerts: true,
      );
      final restored = RadarConfig.fromJson(config.toJson());
      expect(restored.enabled, true);
      expect(restored.scanIntervalMinutes, 15);
      expect(restored.topics.single.query, 'cyber risk');
      expect(restored.autoRunSwarm, true);
      expect(restored.discordAlerts, true);
    });

    test('RadarFinding with attached brief', () {
      final finding = RadarFinding(
        id: 'rf_1',
        title: 'PFAS wave',
        rationale: 'Litigation expanding into new industries.',
        urgency: RadarUrgency.high,
        headlines: const ['[Reuters] PFAS suits filed'],
        detectedAt: DateTime(2026, 8, 1, 12),
        status: RadarFindingStatus.analyzed,
        briefJson: {'summary': 's', 'velocity': 'v'},
      );
      final restored = RadarFinding.fromJson(finding.toJson());
      expect(restored.id, 'rf_1');
      expect(restored.urgency, RadarUrgency.high);
      expect(restored.status, RadarFindingStatus.analyzed);
      expect(restored.detectedAt, DateTime(2026, 8, 1, 12));
      expect(restored.briefJson?['summary'], 's');
    });
  });

  group('HeadlineFingerprints', () {
    test('fingerprint normalizes punctuation, case and whitespace', () {
      expect(
        HeadlineFingerprints.fingerprint('  PFAS Suits — Filed!  '),
        HeadlineFingerprints.fingerprint('pfas suits filed'),
      );
    });

    test('filterNew returns only unseen headlines and records them', () {
      final seen = <String, String>{};
      final now = DateTime(2026, 8, 2);
      final first = HeadlineFingerprints.filterNew(
          seen, ['Storm losses mount', 'Cyber attack hits city'], now);
      expect(first.length, 2);

      final second = HeadlineFingerprints.filterNew(
          seen, ['Storm Losses Mount!', 'New helium shortage'], now);
      expect(second, ['New helium shortage']);
      expect(seen.length, 3);
    });

    test('prune drops fingerprints older than 30 days', () {
      final now = DateTime(2026, 8, 2);
      final seen = {
        'old headline': now
            .subtract(const Duration(days: 31))
            .toIso8601String(),
        'recent headline':
            now.subtract(const Duration(days: 5)).toIso8601String(),
      };
      final pruned = HeadlineFingerprints.prune(seen, now);
      expect(pruned.keys, ['recent headline']);
    });
  });
}
