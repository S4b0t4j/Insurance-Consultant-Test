import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert.dart';
import '../models/audit_event.dart';
import '../models/emerging_risk_brief.dart';
import '../models/radar.dart';
import '../models/report_source.dart';
import '../services/report/claude_http.dart';
import '../services/report/risk_research_service.dart';
import '../services/report/source_ingest_service.dart';
import 'alert_provider.dart';
import 'audit_provider.dart';
import 'discord_provider.dart';
import 'risk_desk_provider.dart';

/// Continuous risk radar: while the dashboard is open, periodically scans
/// the configured news topics, triages genuinely-new headlines with one
/// cheap Claude call, and turns detections into findings + alerts —
/// optionally auto-running the full Risk Desk swarm on each one.
///
/// Browser-tab scoped by design (static app, no backend); detection state
/// persists in SharedPreferences so nothing is re-flagged across sessions.
class RiskRadarProvider extends ChangeNotifier {
  static const _configKey = 'radar_config_v1';
  static const _findingsKey = 'radar_findings_v1';
  static const _seenKey = 'radar_seen_v1';
  static const int maxFindings = 50;

  final ClaudeHttp _client = ClaudeHttp();
  late final RiskResearchService _service = RiskResearchService(_client);
  final SourceIngestService _ingest = SourceIngestService();

  AuditProvider? _audit;
  AlertProvider? _alerts;
  DiscordProvider? _discord;
  RiskDeskProvider? _desk;

  RadarConfig config = RadarConfig();
  final List<RadarFinding> findings = [];
  Map<String, String> _seen = {};

  Timer? _timer;
  bool scanning = false;
  DateTime? lastScanAt;
  String? lastScanSummary;
  String? error;
  bool _loaded = false;

  RiskRadarProvider() {
    _load();
  }

  void wire({
    required AuditProvider audit,
    required String? apiKey,
    AlertProvider? alerts,
    DiscordProvider? discord,
    RiskDeskProvider? desk,
  }) {
    _audit = audit;
    _alerts = alerts;
    _discord = discord;
    _desk = desk;
    _client.setApiKey(apiKey);
  }

  bool get hasApiKey => _client.hasApiKey;

  List<RadarFinding> get activeFindings => findings
      .where((f) => f.status != RadarFindingStatus.dismissed)
      .toList();

  // ------------------------------------------------------------ persistence

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final rawConfig = prefs.getString(_configKey);
      if (rawConfig != null) {
        config = RadarConfig.fromJson(jsonDecode(rawConfig));
      }
      final rawFindings = prefs.getString(_findingsKey);
      if (rawFindings != null) {
        findings.addAll((jsonDecode(rawFindings) as List)
            .whereType<Map<String, dynamic>>()
            .map(RadarFinding.fromJson));
      }
      final rawSeen = prefs.getString(_seenKey);
      if (rawSeen != null) {
        _seen = Map<String, String>.from(jsonDecode(rawSeen));
        _seen = HeadlineFingerprints.prune(_seen, DateTime.now());
      }
    } catch (_) {
      // Corrupt state: start fresh.
    }
    _loaded = true;
    if (config.enabled) _startTimer();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
    await prefs.setString(_findingsKey,
        jsonEncode(findings.map((f) => f.toJson()).toList()));
    await prefs.setString(_seenKey, jsonEncode(_seen));
  }

  // ------------------------------------------------------------ config

  Future<void> setEnabled(bool enabled) async {
    config.enabled = enabled;
    if (enabled) {
      _startTimer();
      // First scan right away so the user sees it working.
      unawaited(scanNow());
    } else {
      _timer?.cancel();
      _timer = null;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setInterval(int minutes) async {
    config.scanIntervalMinutes = minutes;
    if (config.enabled) _startTimer();
    await _persist();
    notifyListeners();
  }

  Future<void> setAutoRun(bool value) async {
    config.autoRunSwarm = value;
    await _persist();
    notifyListeners();
  }

  Future<void> setDiscordAlerts(bool value) async {
    config.discordAlerts = value;
    await _persist();
    notifyListeners();
  }

  Future<void> toggleTopic(RssTopic topic) async {
    final existing =
        config.topics.indexWhere((t) => t.query == topic.query);
    if (existing >= 0) {
      config.topics.removeAt(existing);
    } else {
      config.topics.add(topic);
    }
    await _persist();
    notifyListeners();
  }

  bool topicSelected(RssTopic topic) =>
      config.topics.any((t) => t.query == topic.query);

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(minutes: config.scanIntervalMinutes),
      (_) => scanNow(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ scanning

  Future<void> scanNow() async {
    if (scanning || !_loaded) return;
    scanning = true;
    error = null;
    notifyListeners();

    try {
      // 1. Fetch all configured topics; collect headlines.
      final headlines = <String>[];
      var feedsOk = 0;
      for (final topic in config.topics) {
        try {
          final items = await _ingest.fetchTopic(topic, maxItems: 15);
          feedsOk++;
          headlines.addAll(items.map((n) => '[${n.source}] ${n.title}'));
        } catch (_) {
          // Individual feed failures are non-fatal.
        }
      }
      if (feedsOk == 0 && config.topics.isNotEmpty) {
        throw SourceIngestException('All radar feeds failed this scan.');
      }

      // 2. Only triage what we haven't seen before.
      _seen = HeadlineFingerprints.prune(_seen, DateTime.now());
      final fresh =
          HeadlineFingerprints.filterNew(_seen, headlines, DateTime.now());

      var detections = 0;
      if (fresh.isNotEmpty) {
        final known = activeFindings.map((f) => f.title).toList();
        final risks = await _service.triage(fresh, known);
        for (final risk in risks) {
          detections++;
          final finding = RadarFinding(
            id: 'rf_${DateTime.now().microsecondsSinceEpoch}_$detections',
            title: risk['title'] ?? 'Emerging risk',
            rationale: risk['rationale'] ?? '',
            urgency: RadarUrgency.values.firstWhere(
              (u) => u.name == risk['urgency'],
              orElse: () => RadarUrgency.medium,
            ),
            headlines: List<String>.from(risk['headlines'] ?? []),
            detectedAt: DateTime.now(),
          );
          findings.insert(0, finding);
          _audit?.log(AuditAction.radarRiskDetected,
              detail: '${finding.title} (${finding.urgency.name})');
          _alerts?.addExternalAlert(
            title: 'Radar: ${finding.title}',
            message: finding.rationale,
            severity: switch (finding.urgency) {
              RadarUrgency.high => AlertSeverity.high,
              RadarUrgency.medium => AlertSeverity.medium,
              RadarUrgency.low => AlertSeverity.low,
            },
          );
          if (config.discordAlerts && _discord != null) {
            unawaited(_discord!.sendRadarAlert(
                finding.title, finding.rationale, finding.urgency.name));
          }
        }
        while (findings.length > maxFindings) {
          findings.removeLast();
        }
      }

      lastScanAt = DateTime.now();
      lastScanSummary =
          '${config.topics.length} topics, ${fresh.length} new headlines, '
          '$detections detection${detections == 1 ? '' : 's'}';
      _audit?.log(AuditAction.radarScanCompleted, detail: lastScanSummary!);
      await _persist();

      // 3. Optionally auto-run the swarm on the newest detection.
      if (config.autoRunSwarm && detections > 0) {
        final next = findings.firstWhere(
            (f) => f.status == RadarFindingStatus.detected,
            orElse: () => findings.first);
        unawaited(analyzeFinding(next));
      }
    } on ReportAiException catch (e) {
      error = 'Radar triage failed: ${e.message}';
    } catch (e) {
      error = 'Radar scan failed: $e';
    }

    scanning = false;
    notifyListeners();
  }

  /// Runs the full Risk Desk swarm for a finding and stores the brief on it.
  Future<void> analyzeFinding(RadarFinding finding) async {
    final desk = _desk;
    if (desk == null || desk.running) return;
    finding.status = RadarFindingStatus.analyzing;
    notifyListeners();

    await desk.run(finding.title, finding.rationale);
    final brief = desk.brief;
    if (brief != null) {
      finding.briefJson = brief.toJson();
      finding.status = RadarFindingStatus.analyzed;
    } else {
      finding.status = RadarFindingStatus.detected;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> dismissFinding(RadarFinding finding) async {
    finding.status = RadarFindingStatus.dismissed;
    await _persist();
    notifyListeners();
  }

  /// Rehydrates a stored brief for viewing.
  EmergingRiskBrief? briefOf(RadarFinding finding) {
    final json = finding.briefJson;
    if (json == null) return null;
    return EmergingRiskBrief.fromJson(finding.title, json);
  }
}
