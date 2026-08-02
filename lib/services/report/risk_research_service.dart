import '../../models/emerging_risk_brief.dart';
import '../../models/report_source.dart';
import 'claude_http.dart';

/// One research angle produced by the planner.
class ResearchAngle {
  final String title;
  final String question;

  const ResearchAngle({required this.title, required this.question});
}

/// Result of one researcher agent.
class ResearchFindings {
  final ResearchAngle angle;
  final String findings;
  final List<Map<String, String>> citations;
  final bool usedWebSearch;

  const ResearchFindings({
    required this.angle,
    required this.findings,
    required this.citations,
    required this.usedWebSearch,
  });
}

/// The Risk Desk agent swarm: planner -> parallel researchers (with live
/// web search) -> three practitioner lenses -> synthesizer. Each stage is a
/// separate Claude call so the provider can drive progress UI and retry
/// stages independently.
class RiskResearchService {
  final ClaudeHttp client;

  RiskResearchService(this.client);

  /// Stage 1: decompose the emerging risk into 3-5 research angles.
  Future<List<ResearchAngle>> plan(String topic, String focus) async {
    final data = await client.send({
      'model': ClaudeHttp.model,
      'max_tokens': 6000,
      'system':
          'You are a research director at a commercial insurance brokerage planning '
              'an emerging-risk investigation. Decompose the topic into 3-5 distinct, '
              'non-overlapping research angles that together cover: current facts and '
              'timeline, affected industries/entities, loss and claim potential, '
              'regulatory/legal developments, and market response.',
      'output_config': {
        'effort': 'low',
        'format': {
          'type': 'json_schema',
          'schema': {
            'type': 'object',
            'properties': {
              'angles': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'title': {'type': 'string'},
                    'question': {'type': 'string'},
                  },
                  'required': ['title', 'question'],
                  'additionalProperties': false,
                },
              },
            },
            'required': ['angles'],
            'additionalProperties': false,
          },
        },
      },
      'messages': [
        {
          'role': 'user',
          'content': 'Emerging risk: $topic\n'
              '${focus.isEmpty ? '' : 'Focus: $focus\n'}'
              'Produce the research plan.',
        },
      ],
    });
    final parsed = ClaudeHttp.jsonOf(data);
    return (parsed['angles'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((a) => ResearchAngle(
              title: a['title'] ?? 'Angle',
              question: a['question'] ?? '',
            ))
        .toList();
  }

  /// Stage 2: one researcher, grounded in live web search plus any RSS/news
  /// items and uploaded material. Falls back to context-only research when
  /// web search is unavailable for the org.
  Future<ResearchFindings> research(
    String topic,
    ResearchAngle angle, {
    List<RssNewsItem> newsItems = const [],
    List<ReportSource> uploads = const [],
  }) async {
    final context = StringBuffer();
    if (newsItems.isNotEmpty) {
      context.writeln('Recent headlines from monitored feeds:');
      for (final n in newsItems.take(15)) {
        context.writeln('- [${n.source}] ${n.title}');
      }
    }
    for (final u in uploads) {
      final text = u.extractedText.length > 4000
          ? u.extractedText.substring(0, 4000)
          : u.extractedText;
      context.writeln('\n=== Uploaded material: ${u.name} ===\n$text');
    }

    final baseMessages = [
      {
        'role': 'user',
        'content': 'Emerging risk under investigation: $topic\n'
            'Your research angle: ${angle.title}\n'
            'Research question: ${angle.question}\n\n'
            '${context.isEmpty ? '' : 'Supporting context:\n$context\n'}'
            'Research this thoroughly using web search for current, real-world '
            'information. Report concrete facts, figures, dates and named entities. '
            'End with a FINDINGS section of bullet points.',
      },
    ];

    Map<String, dynamic> body(bool withSearch) => {
          'model': ClaudeHttp.model,
          'max_tokens': 8000,
          'system':
              'You are a research analyst investigating an emerging risk for a '
                  'commercial insurance audience. Prioritize recent, verifiable facts '
                  'with sources. Be concrete: numbers, dates, named companies/agencies.',
          'output_config': {'effort': 'medium'},
          if (withSearch)
            'tools': [
              {
                'type': 'web_search_20260209',
                'name': 'web_search',
                'max_uses': 4,
              },
            ],
          'messages': List.of(baseMessages),
        };

    Map<String, dynamic> data;
    var usedSearch = true;
    try {
      data = await _sendResumingPauses(body(true));
    } on ReportAiException catch (e) {
      // Web search not enabled for this org (or tool rejected): degrade to
      // context-only research so the swarm still completes.
      if (e.statusCode == 400) {
        usedSearch = false;
        data = await client.send(body(false));
      } else {
        rethrow;
      }
    }

    return ResearchFindings(
      angle: angle,
      findings: ClaudeHttp.textOf(data),
      citations: ClaudeHttp.citationsOf(data),
      usedWebSearch: usedSearch,
    );
  }

  /// Server-tool loops can stop with `pause_turn`; resume by re-sending the
  /// conversation with the paused assistant content appended.
  Future<Map<String, dynamic>> _sendResumingPauses(
      Map<String, dynamic> body) async {
    var data = await client.send(body);
    var continuations = 0;
    while (data['stop_reason'] == 'pause_turn' && continuations < 3) {
      continuations++;
      final messages =
          List<Map<String, dynamic>>.from(body['messages'] as List);
      messages.add({'role': 'assistant', 'content': data['content']});
      data = await client.send({...body, 'messages': messages});
    }
    return data;
  }

  static const Map<String, String> lensPrompts = {
    'Underwriter':
        'Analyze through an underwriter\'s lens (CPCU/AU mindset): risk appetite '
            'implications, key exposure drivers and rating factors, aggregation and '
            'accumulation concerns, policy language and exclusions likely to be '
            'tightened, information underwriters will start requiring on submissions.',
    'Broker':
        'Analyze through a broker\'s lens (CIC mindset): placement strategy, current '
            'market capacity and which markets are pulling back, program structure '
            'recommendations (layers, retentions, captives/alternative risk transfer), '
            'how to present affected clients to markets, renewal negotiation points.',
    'Risk manager':
        'Analyze through a risk manager\'s lens (ARM mindset): loss control and '
            'mitigation measures, business continuity implications, total cost of risk '
            'impact, claims scenarios to pre-plan, contractual risk transfer, and '
            'board-level talking points.',
  };

  /// Stage 3: one specialist lens over the pooled research.
  Future<String> lens(
      String topic, String lensName, String pooledResearch) async {
    final data = await client.send({
      'model': ClaudeHttp.model,
      'max_tokens': 6000,
      'system':
          'You are a credentialed commercial insurance practitioner producing expert '
              'analysis of an emerging risk. ${lensPrompts[lensName] ?? ''} '
              'Base the analysis strictly on the research provided. Be specific to '
              'lines of business and quantify where the research allows.',
      'output_config': {'effort': 'high'},
      'messages': [
        {
          'role': 'user',
          'content':
              'Emerging risk: $topic\n\nPooled research findings:\n$pooledResearch',
        },
      ],
    });
    return ClaudeHttp.textOf(data);
  }

  /// Stage 4: synthesize everything into the structured brief.
  Future<EmergingRiskBrief> synthesize(
    String topic,
    String focus,
    List<ResearchFindings> research,
    Map<String, String> lensAnalyses,
  ) async {
    final researchText = research
        .map((r) => '=== ${r.angle.title} ===\n${r.findings}')
        .join('\n\n');
    final lensText = lensAnalyses.entries
        .map((e) => '=== ${e.key} analysis ===\n${e.value}')
        .join('\n\n');

    final data = await client.send({
      'model': ClaudeHttp.model,
      'max_tokens': 16000,
      'system':
          'You are the practice leader synthesizing an emerging-risk briefing for '
              'commercial insurance professionals. Merge the research and the three '
              'specialist analyses into one coherent brief. Every claim must trace to '
              'the provided material. Write for an audience of underwriters, brokers '
              'and risk managers.',
      'output_config': {
        'effort': 'high',
        'format': {'type': 'json_schema', 'schema': _briefSchema},
      },
      'messages': [
        {
          'role': 'user',
          'content': 'Emerging risk: $topic\n'
              '${focus.isEmpty ? '' : 'Focus: $focus\n'}\n'
              'RESEARCH:\n$researchText\n\nSPECIALIST ANALYSES:\n$lensText',
        },
      ],
    });

    final parsed = ClaudeHttp.jsonOf(data);
    final brief = EmergingRiskBrief.fromJson(topic, parsed);

    // Attach citations gathered by the researchers.
    final seen = <String>{};
    for (final r in research) {
      for (final c in r.citations) {
        final url = c['url'] ?? '';
        if (url.isEmpty || !seen.add(url)) continue;
        brief.citations.add(BriefCitation(title: c['title'] ?? url, url: url));
      }
    }
    return brief;
  }

  static const Map<String, dynamic> _briefSchema = {
    'type': 'object',
    'properties': {
      'summary': {'type': 'string'},
      'velocity': {
        'type': 'string',
        'description':
            'How fast this risk is developing and the expected timeline.',
      },
      'linesOfBusiness': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'line': {'type': 'string'},
            'exposure': {'type': 'string'},
            'underwritingConsiderations': {'type': 'string'},
            'severity': {
              'type': 'string',
              'enum': ['low', 'medium', 'high'],
            },
          },
          'required': [
            'line',
            'exposure',
            'underwritingConsiderations',
            'severity'
          ],
          'additionalProperties': false,
        },
      },
      'coverageGaps': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'marketOutlook': {'type': 'string'},
      'recommendedActions': {
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
          },
          'required': ['date', 'headline', 'summary'],
          'additionalProperties': false,
        },
      },
    },
    'required': [
      'summary',
      'velocity',
      'linesOfBusiness',
      'coverageGaps',
      'marketOutlook',
      'recommendedActions',
      'stats',
      'newsItems'
    ],
    'additionalProperties': false,
  };

  /// Converts a finished brief into the Report Studio edition-brief shape so
  /// "Build report from this" can feed the template pipeline directly.
  static Map<String, dynamic> briefToEditionBrief(EmergingRiskBrief brief) {
    return {
      'editionTheme': '${brief.topic}: ${brief.summary}',
      'keyThemes': [
        brief.velocity,
        ...brief.coverageGaps.take(3),
        brief.marketOutlook,
      ].where((s) => s.isNotEmpty).toList(),
      'stats': brief.stats
          .map((s) => {'value': s.value, 'label': s.label, 'source': s.source})
          .toList(),
      'newsItems': brief.newsItems
          .map((n) => {
                'date': n.date,
                'headline': n.headline,
                'summary': n.summary,
                'category': brief.topic,
              })
          .toList(),
      'sectorImpacts': brief.lines
          .map((l) => {
                'sector': l.line,
                'impact':
                    '${l.exposure} Underwriting: ${l.underwritingConsiderations}',
              })
          .toList(),
    };
  }
}
