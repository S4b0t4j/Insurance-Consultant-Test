import 'dart:convert';

import '../../models/report_job.dart';
import '../../models/report_source.dart';
import '../../models/report_template.dart';
import 'claude_http.dart';

/// Claude calls behind Report Studio: edition brief digest, clone-mode
/// batch rewrites and rebuild-mode slide planning. Uses structured outputs
/// so responses need no fragile JSON extraction.
class ReportAiService {
  final ClaudeHttp client;

  ReportAiService(this.client);

  static const int _perSourceCharCap = 8000;
  static const int slidesPerBatch = 5;

  /// Call 0: digest all sources into an edition brief. Later calls receive
  /// this digest instead of raw source text — the token-control lever.
  Future<Map<String, dynamic>> editionBrief(
    ReportJobConfig config,
    List<ReportSource> sources,
  ) async {
    final sourceText = StringBuffer();
    for (final s in sources) {
      final text = s.extractedText.length > _perSourceCharCap
          ? s.extractedText.substring(0, _perSourceCharCap)
          : s.extractedText;
      sourceText.writeln('=== SOURCE: ${s.name} (${s.kind.name}) ===');
      sourceText.writeln(text);
      sourceText.writeln();
    }

    final data = await client.send({
      'model': ClaudeHttp.model,
      'max_tokens': 12000,
      'system':
          'You are a senior risk-report editor at a commercial insurance brokerage. '
              'Distill the provided source material into a factual JSON brief for a new '
              'edition of a risk report. Ground every stat, news item and sector impact '
              'in the sources; do not invent figures.',
      'output_config': {
        'effort': 'medium',
        'format': {'type': 'json_schema', 'schema': _briefSchema},
      },
      'messages': [
        {
          'role': 'user',
          'content': 'Report: ${config.editionTitle}\n'
              'Edition date: ${config.editionDate}\n'
              'Topic focus: ${config.topicFocus.isEmpty ? '(broad public-sector risk)' : config.topicFocus}\n\n'
              'Source material:\n$sourceText',
        },
      ],
    });
    return ClaudeHttp.jsonOf(data);
  }

  static const Map<String, dynamic> _briefSchema = {
    'type': 'object',
    'properties': {
      'editionTheme': {'type': 'string'},
      'keyThemes': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'stats': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'value': {'type': 'string'},
            'label': {'type': 'string'},
            'source': {'type': 'string'},
          },
          'required': ['value', 'label', 'source'],
          'additionalProperties': false,
        },
      },
      'newsItems': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'date': {'type': 'string'},
            'headline': {'type': 'string'},
            'summary': {'type': 'string'},
            'category': {'type': 'string'},
          },
          'required': ['date', 'headline', 'summary', 'category'],
          'additionalProperties': false,
        },
      },
      'sectorImpacts': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'sector': {'type': 'string'},
            'impact': {'type': 'string'},
          },
          'required': ['sector', 'impact'],
          'additionalProperties': false,
        },
      },
    },
    'required': [
      'editionTheme',
      'keyThemes',
      'stats',
      'newsItems',
      'sectorImpacts'
    ],
    'additionalProperties': false,
  };

  /// Clone mode: rewrite one batch of slides. Returns blockId -> new text.
  /// Missing ids are left for the caller to fall back to original text.
  Future<Map<String, String>> cloneBatch(
    ReportJobConfig config,
    Map<String, dynamic> brief,
    List<SlideInventory> batch,
  ) async {
    final slidesPayload = batch
        .map((slide) => {
              'slide': slide.index,
              'blocks': slide.allParagraphs
                  .map((p) => {
                        'id': p.blockId,
                        'original': p.mergedText,
                        'maxChars': p.charBudget,
                      })
                  .toList(),
            })
        .toList();

    final data = await client.send({
      'model': ClaudeHttp.model,
      'max_tokens': 16000,
      'system':
          'You rewrite the text of an existing report template to produce a new edition. '
              'For each block, write replacement text grounded ONLY in the edition brief. '
              'Hard rules: '
              '(1) each replacement must be at most maxChars characters — never exceed it by more than 10%; '
              '(2) preserve the block\'s role: a stat stays a short stat, a heading stays a heading, a date stays a date, a label stays a label; '
              '(3) if a block is boilerplate (page numbers, legal footers, company names, URLs, contact info), return it unchanged; '
              '(4) use the edition title/date provided where the original shows an edition title/date; '
              '(5) return every block id you were given, exactly once, in the replacements array.',
      'output_config': {
        'effort': 'medium',
        'format': {'type': 'json_schema', 'schema': _replacementsSchema},
      },
      'messages': [
        {
          'role': 'user',
          'content': _json({
            'edition': {
              'title': config.editionTitle,
              'date': config.editionDate,
              'topic': config.topicFocus,
            },
            'brief': brief,
            'slides': slidesPayload,
          }),
        },
      ],
    });

    final parsed = ClaudeHttp.jsonOf(data);
    final result = <String, String>{};
    for (final r in (parsed['replacements'] as List? ?? [])
        .whereType<Map<String, dynamic>>()) {
      final id = r['id'] as String?;
      final text = r['text'] as String?;
      if (id != null && text != null) result[id] = text;
    }
    return result;
  }

  static const Map<String, dynamic> _replacementsSchema = {
    'type': 'object',
    'properties': {
      'replacements': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'text': {'type': 'string'},
          },
          'required': ['id', 'text'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['replacements'],
    'additionalProperties': false,
  };

  /// Rebuild mode: produce a slide plan from the brief.
  Future<List<PlannedSlide>> rebuildPlan(
    ReportJobConfig config,
    Map<String, dynamic> brief,
    List<SlideArchetype> requestedOrder,
  ) async {
    final data = await client.send({
      'model': ClaudeHttp.model,
      'max_tokens': 16000,
      'system':
          'You are composing a risk-report slide deck from an edition brief. '
              'Produce one slides[] entry per requested archetype, in the requested order, '
              'filling each archetype\'s fields from the brief. Keep text tight: headings under 80 chars, '
              'stat values under 10 chars, narratives 1-3 sentences. Ground everything in the brief.',
      'output_config': {
        'effort': 'medium',
        'format': {'type': 'json_schema', 'schema': _planSchema},
      },
      'messages': [
        {
          'role': 'user',
          'content': _json({
            'edition': {
              'title': config.editionTitle,
              'date': config.editionDate,
              'topic': config.topicFocus,
            },
            'requestedArchetypes':
                requestedOrder.map((a) => a.name).toList(),
            'archetypeFields': _archetypeFieldGuide,
            'brief': brief,
          }),
        },
      ],
    });

    final parsed = ClaudeHttp.jsonOf(data);
    final result = <PlannedSlide>[];
    final slides = (parsed['slides'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    for (var i = 0; i < requestedOrder.length; i++) {
      Map<String, dynamic> fields = {};
      if (i < slides.length) {
        final produced = slides[i];
        fields = (produced['fields'] as Map<String, dynamic>?) ?? {};
      }
      result.add(PlannedSlide(archetype: requestedOrder[i], fields: fields));
    }
    return result;
  }

  static const Map<String, String> _archetypeFieldGuide = {
    'cover': '{title, subtitle, date}',
    'agenda': '{items: [string] (max 10)}',
    'executiveSummary': '{heading, rows: [{title, text}] (max 6)}',
    'sectionDivider': '{title}',
    'keyMetrics': '{heading, stats: [{value, label}] (max 6)}',
    'impactedSectors': '{heading, subheading, rows: [{sector, impact}] (max 4)}',
    'newsUpdates': '{heading, category, items: [{date, headline, body}] (max 3)}',
    'capabilitiesTable':
        '{heading, subheading, rows: [[name, description]] (first row is header, max 5 rows)}',
    'contact': '{heading, body, name, title, email, closing}',
  };

  static const Map<String, dynamic> _planSchema = {
    'type': 'object',
    'properties': {
      'slides': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'archetype': {'type': 'string'},
            'fields': {'type': 'object'},
          },
          'required': ['archetype', 'fields'],
        },
      },
    },
    'required': ['slides'],
  };

  static String _json(Object o) => jsonEncode(o);
}
