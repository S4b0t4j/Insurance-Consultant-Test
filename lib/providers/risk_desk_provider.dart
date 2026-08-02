import 'package:flutter/foundation.dart';

import '../models/audit_event.dart';
import '../models/emerging_risk_brief.dart';
import '../models/report_source.dart';
import '../services/report/claude_http.dart';
import '../services/report/risk_research_service.dart';
import '../services/report/source_ingest_service.dart';
import 'audit_provider.dart';

/// Drives the Risk Desk agent swarm and exposes per-stage progress for the
/// swarm board UI.
class RiskDeskProvider extends ChangeNotifier {
  final ClaudeHttp _client = ClaudeHttp();
  late final RiskResearchService _service = RiskResearchService(_client);
  final SourceIngestService _ingest = SourceIngestService();

  AuditProvider? _audit;

  bool running = false;
  String? error;
  String topic = '';
  String focus = '';
  final List<ReportSource> uploads = [];
  final List<SwarmStage> stages = [];
  EmergingRiskBrief? brief;
  bool webSearchDegraded = false;

  static const int _maxConcurrentResearchers = 3;

  void wire({required AuditProvider audit, required String? apiKey}) {
    _audit = audit;
    _client.setApiKey(apiKey);
  }

  bool get hasApiKey => _client.hasApiKey;

  Future<void> addUpload(String fileName, Uint8List bytes) async {
    error = null;
    try {
      uploads.add(await _ingest.extractFromUpload(fileName, bytes));
    } on SourceIngestException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Could not read "$fileName": $e';
    }
    notifyListeners();
  }

  void removeUpload(ReportSource source) {
    uploads.remove(source);
    notifyListeners();
  }

  Future<void> run(String riskTopic, String riskFocus) async {
    if (running) return;
    topic = riskTopic.trim();
    focus = riskFocus.trim();
    if (topic.isEmpty) return;

    running = true;
    error = null;
    brief = null;
    webSearchDegraded = false;
    stages.clear();
    _audit?.log(AuditAction.riskAnalysisStarted, detail: topic);

    final planStage = SwarmStage(id: 'plan', label: 'Planner: decompose the risk');
    stages.add(planStage);
    notifyListeners();

    try {
      // Stage 0: cheap grounding — pull one topical news feed.
      final newsItems = <RssNewsItem>[];
      try {
        final feedTopic = RssTopic(label: topic, query: topic, builtIn: false);
        newsItems.addAll(await _ingest.fetchTopic(feedTopic, maxItems: 10));
      } catch (_) {
        // Non-fatal: researchers still have web search.
      }

      // Stage 1: planner.
      planStage.status = SwarmStageStatus.running;
      notifyListeners();
      final angles = await _service.plan(topic, focus);
      if (angles.isEmpty) {
        throw ReportAiException('Planner produced no research angles.');
      }
      planStage.status = SwarmStageStatus.done;
      planStage.note = '${angles.length} research angles';

      // Stage 2: researchers (bounded concurrency).
      final researchStages = {
        for (final a in angles)
          a.title: SwarmStage(id: 'research_${a.title}', label: 'Researcher: ${a.title}'),
      };
      stages.addAll(researchStages.values);
      notifyListeners();

      final findings = <ResearchFindings>[];
      for (var i = 0; i < angles.length; i += _maxConcurrentResearchers) {
        final chunk = angles.skip(i).take(_maxConcurrentResearchers).toList();
        for (final a in chunk) {
          researchStages[a.title]!.status = SwarmStageStatus.running;
        }
        notifyListeners();
        final results = await Future.wait(chunk.map((a) async {
          try {
            final r = await _service.research(topic, a,
                newsItems: newsItems, uploads: uploads);
            researchStages[a.title]!.status = SwarmStageStatus.done;
            if (!r.usedWebSearch) {
              webSearchDegraded = true;
              researchStages[a.title]!.note = 'no live web search';
            } else {
              researchStages[a.title]!.note =
                  '${r.citations.length} sources cited';
            }
            return r;
          } catch (e) {
            researchStages[a.title]!.status = SwarmStageStatus.failed;
            researchStages[a.title]!.note = '$e';
            return null;
          } finally {
            notifyListeners();
          }
        }));
        findings.addAll(results.whereType<ResearchFindings>());
      }
      if (findings.isEmpty) {
        throw ReportAiException('All researcher agents failed.');
      }

      final pooled = findings
          .map((r) => '=== ${r.angle.title} ===\n${r.findings}')
          .join('\n\n');

      // Stage 3: specialist lenses in parallel.
      final lensStages = {
        for (final name in RiskResearchService.lensPrompts.keys)
          name: SwarmStage(
              id: 'lens_$name',
              label: '$name lens',
              status: SwarmStageStatus.running),
      };
      stages.addAll(lensStages.values);
      notifyListeners();

      final lensAnalyses = <String, String>{};
      await Future.wait(RiskResearchService.lensPrompts.keys.map((name) async {
        try {
          lensAnalyses[name] = await _service.lens(topic, name, pooled);
          lensStages[name]!.status = SwarmStageStatus.done;
        } catch (e) {
          lensStages[name]!.status = SwarmStageStatus.failed;
          lensStages[name]!.note = '$e';
        }
        notifyListeners();
      }));
      if (lensAnalyses.isEmpty) {
        throw ReportAiException('All specialist lens agents failed.');
      }

      // Stage 4: synthesis.
      final synthStage = SwarmStage(
          id: 'synth',
          label: 'Synthesizer: emerging-risk brief',
          status: SwarmStageStatus.running);
      stages.add(synthStage);
      notifyListeners();

      brief = await _service.synthesize(topic, focus, findings, lensAnalyses);
      synthStage.status = SwarmStageStatus.done;
      _audit?.log(AuditAction.riskAnalysisCompleted,
          detail:
              '$topic (${brief!.lines.length} lines of business, ${brief!.citations.length} citations)');
    } on ReportAiException catch (e) {
      error = e.message;
      for (final s in stages) {
        if (s.status == SwarmStageStatus.running) {
          s.status = SwarmStageStatus.failed;
        }
      }
      _audit?.log(AuditAction.riskAnalysisFailed, detail: '$topic: ${e.message}');
    } catch (e) {
      error = 'Analysis failed: $e';
      _audit?.log(AuditAction.riskAnalysisFailed, detail: '$topic: $e');
    }

    running = false;
    notifyListeners();
  }

  /// Edition-brief payload for the Report Studio handoff.
  Map<String, dynamic>? get editionBrief =>
      brief == null ? null : RiskResearchService.briefToEditionBrief(brief!);

  void reset() {
    stages.clear();
    brief = null;
    error = null;
    running = false;
    notifyListeners();
  }
}
