import 'package:flutter/foundation.dart';

import '../models/audit_event.dart';
import '../models/report_job.dart';
import '../models/report_source.dart';
import '../models/report_template.dart';
import '../services/report/claude_http.dart';
import '../services/report/docx_builder.dart';
import '../services/report/file_saver.dart' as saver;
import '../services/report/ooxml_reader.dart';
import '../services/report/ooxml_rewriter.dart';
import '../services/report/pptx_builder.dart';
import '../services/report/report_ai_service.dart';
import '../services/report/risk_research_service.dart';
import '../services/report/source_ingest_service.dart';
import 'audit_provider.dart';

/// Orchestrates the Report Studio flow: template upload -> sources ->
/// configure -> generate & review -> download.
class ReportStudioProvider extends ChangeNotifier {
  static const int maxTemplateBytes = 25 * 1024 * 1024;

  final ClaudeHttp _client = ClaudeHttp();
  late final ReportAiService _ai = ReportAiService(_client);
  final SourceIngestService _ingest = SourceIngestService();

  AuditProvider? _audit;

  int step = 0;
  ReportTemplate? template;
  final List<ReportSource> sources = [];
  final Set<RssTopic> selectedTopics = {};
  final List<RssTopic> customTopics = [];
  final ReportJobConfig config = ReportJobConfig();
  List<SlideArchetype> rebuildPlanOrder = [
    SlideArchetype.cover,
    SlideArchetype.agenda,
    SlideArchetype.executiveSummary,
    SlideArchetype.sectionDivider,
    SlideArchetype.keyMetrics,
    SlideArchetype.impactedSectors,
    SlideArchetype.newsUpdates,
    SlideArchetype.sectionDivider,
    SlideArchetype.capabilitiesTable,
    SlideArchetype.contact,
  ];

  JobStatus status = JobStatus.idle;
  String progressLabel = '';
  double progress = 0;
  String? error;
  final List<String> warnings = [];

  /// Clone-mode review state, keyed by blockId.
  final Map<String, BlockReplacement> replacements = {};

  /// Rebuild-mode review state.
  List<PlannedSlide> plannedSlides = [];

  /// Edition brief handed off from Risk Desk (skips needing sources).
  Map<String, dynamic>? importedBrief;
  String? importedBriefLabel;

  void wire({required AuditProvider audit, required String? apiKey}) {
    _audit = audit;
    _client.setApiKey(apiKey);
  }

  bool get hasApiKey => _client.hasApiKey;

  // ------------------------------------------------------------ template

  Future<void> uploadTemplate(String fileName, Uint8List bytes) async {
    error = null;
    if (fileName.toLowerCase().endsWith('.pdf')) {
      error =
          'PDFs can\'t be used as formatting templates — upload them in the Sources step instead. Templates must be .pptx or .docx.';
      notifyListeners();
      return;
    }
    if (bytes.length > maxTemplateBytes) {
      error = 'Template is too large (max 25 MB).';
      notifyListeners();
      return;
    }
    try {
      template = OoxmlReader.parse(fileName, bytes);
      replacements.clear();
      status = JobStatus.idle;
      _audit?.log(AuditAction.templateUploaded,
          detail:
              '$fileName (${(bytes.length / 1024).round()} KB, ${template!.slideCount} slides, ${template!.totalTextBlocks} text blocks)');
    } on OoxmlReadException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Could not parse template: $e';
    }
    notifyListeners();
  }

  void clearTemplate() {
    template = null;
    replacements.clear();
    notifyListeners();
  }

  // ------------------------------------------------------------ sources

  Future<void> addUploadSource(String fileName, Uint8List bytes) async {
    error = null;
    try {
      final source = await _ingest.extractFromUpload(fileName, bytes);
      sources.add(source);
      _audit?.log(AuditAction.sourceAdded,
          detail: '$fileName (${source.charCount} chars extracted)');
    } on SourceIngestException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Could not read "$fileName": $e';
    }
    notifyListeners();
  }

  void removeSource(ReportSource source) {
    sources.remove(source);
    notifyListeners();
  }

  void toggleTopic(RssTopic topic) {
    if (!selectedTopics.remove(topic)) selectedTopics.add(topic);
    notifyListeners();
  }

  void addCustomTopic(String label, String query) {
    final topic = RssTopic(label: label, query: query, builtIn: false);
    customTopics.add(topic);
    selectedTopics.add(topic);
    notifyListeners();
  }

  void importBrief(Map<String, dynamic> brief, String label) {
    importedBrief = brief;
    importedBriefLabel = label;
    config.topicFocus = label;
    step = 2;
    notifyListeners();
  }

  // ------------------------------------------------------------ generate

  bool get canGenerate =>
      template != null &&
      (sources.isNotEmpty ||
          selectedTopics.isNotEmpty ||
          importedBrief != null);

  Future<void> generate() async {
    if (template == null) return;
    error = null;
    warnings.clear();
    status = JobStatus.generating;
    progress = 0;
    _audit?.log(AuditAction.generationStarted,
        detail:
            '${config.mode.name} mode, ${template!.fileName}, edition "${config.editionTitle}"');
    notifyListeners();

    try {
      // 1. Pull selected live feeds into sources.
      final effectiveSources = List<ReportSource>.from(sources);
      var topicIdx = 0;
      for (final topic in selectedTopics) {
        topicIdx++;
        _setProgress(
            'Fetching news: ${topic.label} ($topicIdx/${selectedTopics.length})',
            0.05 * topicIdx / selectedTopics.length);
        try {
          final items = await _ingest.fetchTopic(topic);
          if (items.isNotEmpty) {
            effectiveSources
                .add(SourceIngestService.toSource(topic, items));
          }
        } catch (e) {
          warnings.add('Feed "${topic.label}" unavailable — skipped. ($e)');
        }
      }

      // 2. Edition brief (reuse an imported Risk Desk brief when present).
      Map<String, dynamic> brief;
      if (importedBrief != null) {
        brief = importedBrief!;
        _setProgress('Using Risk Desk brief: $importedBriefLabel', 0.15);
      } else {
        if (effectiveSources.isEmpty) {
          throw ReportAiException(
              'No usable sources: uploads/feeds all failed.');
        }
        _setProgress('Digesting sources into edition brief…', 0.10);
        brief = await _ai.editionBrief(config, effectiveSources);
      }

      if (config.mode == GenerationMode.clone) {
        await _generateClone(brief);
      } else {
        await _generateRebuild(brief);
      }

      status = JobStatus.reviewing;
      _setProgress('Review the generated content', 1.0);
      _audit?.log(AuditAction.generationCompleted,
          detail: '${config.mode.name} mode, ${template!.fileName}');
    } on ReportAiException catch (e) {
      error = e.message;
      status = JobStatus.error;
      _audit?.log(AuditAction.generationFailed, detail: e.message);
    } catch (e) {
      error = 'Generation failed: $e';
      status = JobStatus.error;
      _audit?.log(AuditAction.generationFailed, detail: '$e');
    }
    notifyListeners();
  }

  Future<void> _generateClone(Map<String, dynamic> brief) async {
    final slides = template!.slides;
    replacements.clear();

    final batches = <List<SlideInventory>>[];
    for (var i = 0; i < slides.length; i += ReportAiService.slidesPerBatch) {
      batches.add(slides.sublist(
          i,
          (i + ReportAiService.slidesPerBatch).clamp(0, slides.length)));
    }

    for (var b = 0; b < batches.length; b++) {
      _setProgress('Writing content: batch ${b + 1} of ${batches.length}…',
          0.15 + 0.8 * (b / batches.length));
      Map<String, String> batchResult;
      try {
        batchResult = await _ai.cloneBatch(config, brief, batches[b]);
      } on ReportAiException catch (e) {
        warnings.add(
            'Batch ${b + 1} failed (${e.message}) — those slides keep their original text.');
        batchResult = {};
      }
      for (final slide in batches[b]) {
        for (final para in slide.allParagraphs) {
          final generated = batchResult[para.blockId];
          if (generated == null && batchResult.isNotEmpty) {
            warnings.add(
                'Block ${para.blockId} missing from AI response — original kept.');
          }
          replacements[para.blockId] = BlockReplacement(
            blockId: para.blockId,
            original: para.mergedText,
            generated: generated ?? para.mergedText,
            charBudget: para.charBudget,
          );
        }
      }
      notifyListeners();
    }
  }

  Future<void> _generateRebuild(Map<String, dynamic> brief) async {
    _setProgress('Planning slides from brief…', 0.3);
    plannedSlides = await _ai.rebuildPlan(config, brief, rebuildPlanOrder);
  }

  /// Re-runs generation for a single slide's blocks (clone mode).
  Future<void> regenerateSlide(SlideInventory slide) async {
    if (template == null) return;
    final brief = importedBrief;
    if (brief == null && replacements.isEmpty) return;
    try {
      final batchResult = await _ai.cloneBatch(
          config, brief ?? {}, [slide]);
      for (final para in slide.allParagraphs) {
        final generated = batchResult[para.blockId];
        if (generated != null) {
          replacements[para.blockId] = BlockReplacement(
            blockId: para.blockId,
            original: para.mergedText,
            generated: generated,
            charBudget: para.charBudget,
          );
        }
      }
    } on ReportAiException catch (e) {
      error = e.message;
    }
    notifyListeners();
  }

  void editReplacement(String blockId, String text) {
    final r = replacements[blockId];
    if (r == null) return;
    r.edited = text;
    notifyListeners();
  }

  // ------------------------------------------------------------ download

  Future<void> download() async {
    if (template == null) return;
    try {
      Uint8List bytes;
      String name;
      final base = config.editionTitle
          .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '')
          .trim()
          .replaceAll(' ', '_');
      if (config.mode == GenerationMode.clone) {
        final texts = {
          for (final r in replacements.values)
            if (r.isChanged) r.blockId: r.effectiveText,
        };
        bytes = OoxmlRewriter.rewrite(template!, texts);
        final ext = template!.kind == TemplateKind.pptx ? 'pptx' : 'docx';
        name = '$base.$ext';
        await saver.saveFile(name, bytes,
            template!.kind == TemplateKind.pptx ? saver.pptxMime : saver.docxMime);
      } else {
        if (template!.kind == TemplateKind.pptx) {
          bytes = PptxBuilder(template!.theme)
              .build(config.editionTitle, plannedSlides);
          name = '$base.pptx';
          await saver.saveFile(name, bytes, saver.pptxMime);
        } else {
          bytes = DocxBuilder(template!.theme)
              .build(config.editionTitle, plannedSlides);
          name = '$base.docx';
          await saver.saveFile(name, bytes, saver.docxMime);
        }
      }
      status = JobStatus.done;
      _audit?.log(AuditAction.reportDownloaded, detail: name);
    } catch (e) {
      error = 'Download failed: $e';
    }
    notifyListeners();
  }

  /// Rebuild-mode export helper that lets the user pick the output format
  /// regardless of the template kind.
  Future<void> downloadRebuildAs({required bool asPptx}) async {
    if (template == null || plannedSlides.isEmpty) return;
    try {
      final base = config.editionTitle
          .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '')
          .trim()
          .replaceAll(' ', '_');
      if (asPptx) {
        final bytes = PptxBuilder(template!.theme)
            .build(config.editionTitle, plannedSlides);
        await saver.saveFile('$base.pptx', bytes, saver.pptxMime);
        _audit?.log(AuditAction.reportDownloaded, detail: '$base.pptx');
      } else {
        final bytes = DocxBuilder(template!.theme)
            .build(config.editionTitle, plannedSlides);
        await saver.saveFile('$base.docx', bytes, saver.docxMime);
        _audit?.log(AuditAction.reportDownloaded, detail: '$base.docx');
      }
      status = JobStatus.done;
    } catch (e) {
      error = 'Download failed: $e';
    }
    notifyListeners();
  }

  // ------------------------------------------------------------ misc

  void goToStep(int s) {
    step = s;
    notifyListeners();
  }

  void _setProgress(String label, double value) {
    progressLabel = label;
    progress = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void resetJob() {
    status = JobStatus.idle;
    replacements.clear();
    plannedSlides = [];
    error = null;
    warnings.clear();
    progress = 0;
    notifyListeners();
  }

  /// Exposed for Risk Desk handoff.
  static Map<String, dynamic> briefFromRiskDesk(dynamic brief) =>
      RiskResearchService.briefToEditionBrief(brief);
}
