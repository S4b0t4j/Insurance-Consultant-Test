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

  // Per-stage output caps and context char-caps. Sized so every call stays
  // under ClaudeHttp.perCallBudgetUsd at its own model's rates — worked
  // numbers in test/cost_budget_test.dart, which fails if these drift out
  // of budget. research() and synthesize() run on ClaudeHttp.deepModel
  // (Sonnet 5); everything else runs on ClaudeHttp.model (Haiku).
  static const int planMaxTokens = 2000;
  static const int researchMaxTokens = 3000;
  static const int researchContextCharCap = 6000;
  static const int lensMaxTokens = 2500;
  static const int lensResearchCharCap = 10000;
  // Lower than research's 3000 despite being the "main" output: Sonnet's
  // output price ($15/MTok standard) means max_tokens is the dominant cost
  // term, and 6000 alone would clear perCallBudgetUsd with no room left for
  // input. The pooled research/lens context below is left at full size —
  // more grounding material matters more to synthesis quality than a
  // longer written brief.
  static const int synthesizeMaxTokens = 5000;
  static const int synthesizeSectionCharCap = 8000;
  static const int followUpMaxTokens = 1500;
  static const int followUpBriefCharCap = 8000;
  static const int followUpResearchCharCap = 8000;
  static const int followUpHistoryTurns = 6;
  static const int triageMaxTokens = 2000;
  static const int triageMaxHeadlines = 30;
  static const int triageMaxKnownRisks = 50;

  /// Stage 1: decompose the emerging risk into research angles (count per
  /// [depth]).
  Future<List<ResearchAngle>> plan(String topic, String focus,
      {ResearchDepth depth = ResearchDepth.standard}) async {
    final data = await client.send({
      'model': ClaudeHttp.model,
      'max_tokens': planMaxTokens,
      'system':
          'You are a research director at a commercial insurance brokerage planning '
              'an emerging-risk investigation. ${depth.angleInstruction} The angles '
              'must be distinct and non-overlapping, together covering: current facts '
              'and timeline, affected industries/entities, loss and claim potential, '
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
    ResearchDepth depth = ResearchDepth.standard,
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
    // Per-upload cap above bounds one file; this bounds the total when
    // several are attached — upload count is user-controlled, not ours.
    final boundedContext =
        ClaudeHttp.truncate(context.toString(), researchContextCharCap);

    final baseMessages = [
      {
        'role': 'user',
        'content': 'Emerging risk under investigation: $topic\n'
            'Your research angle: ${angle.title}\n'
            'Research question: ${angle.question}\n\n'
            '${boundedContext.isEmpty ? '' : 'Supporting context:\n$boundedContext\n'}'
            'Research this thoroughly using web search for current, real-world '
            'information. Report concrete facts, figures, dates and named entities. '
            'End with a FINDINGS section of bullet points.',
      },
    ];

    Map<String, dynamic> body(bool withSearch) => {
          // Sonnet 5: research quality is what a brief is actually judged
          // on, and this is the one stage whose `effort` setting couldn't
          // do anything on Haiku (stripped as unsupported).
          'model': ClaudeHttp.deepModel,
          'max_tokens': researchMaxTokens,
          'system':
              'You are a research analyst investigating an emerging risk for a '
                  'commercial insurance audience. Prioritize recent, verifiable facts '
                  'with sources. Be concrete: numbers, dates, named companies/agencies.',
          'output_config': {'effort': depth.researchEffort},
          if (withSearch)
            'tools': [
              {
                'type': ClaudeHttp.webSearchTypeFor(ClaudeHttp.deepModel),
                'name': 'web_search',
                'max_uses': depth.searchUses,
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
    'Claims':
        'Analyze through a claims professional\'s lens (AIC mindset): which policy '
            'wordings and coverage triggers will be tested, likely claim and litigation '
            'scenarios, defense-cost and coverage-dispute exposure, notice/reporting '
            'pitfalls for insureds, early reserving signals, and claim-handling '
            'preparations carriers and TPAs should make now.',
    'Actuarial':
        'Analyze through an actuarial/pricing lens: expected frequency and severity '
            'trends, availability and credibility of data to rate this exposure, rate '
            'adequacy of current pricing, accumulation and PML modeling considerations, '
            'reinsurance and retro market signals, and what to watch in loss '
            'development over the next 4-8 quarters.',
  };

  /// The three default lenses (the two extra are opt-in for deeper runs).
  static const List<String> defaultLenses = [
    'Underwriter',
    'Broker',
    'Risk manager'
  ];

  /// Stage 3: one specialist lens over the pooled research.
  Future<String> lens(String topic, String lensName, String pooledResearch,
      {ResearchDepth depth = ResearchDepth.standard}) async {
    final boundedResearch =
        ClaudeHttp.truncate(pooledResearch, lensResearchCharCap);
    final data = await client.send({
      'model': ClaudeHttp.model,
      'max_tokens': lensMaxTokens,
      'system':
          'You are a credentialed commercial insurance practitioner producing expert '
              'analysis of an emerging risk. ${lensPrompts[lensName] ?? ''} '
              'Base the analysis strictly on the research provided. Be specific to '
              'lines of business and quantify where the research allows.',
      'output_config': {'effort': depth.lensEffort},
      'messages': [
        {
          'role': 'user',
          'content':
              'Emerging risk: $topic\n\nPooled research findings:\n$boundedResearch',
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
    // Unbounded joins: up to 6 research angles and 5 lenses feed in here.
    // Cap each pooled section rather than the per-piece text above, so this
    // stays bounded regardless of how many angles/lenses a run used.
    final researchText = ClaudeHttp.truncate(
        research
            .map((r) => '=== ${r.angle.title} ===\n${r.findings}')
            .join('\n\n'),
        synthesizeSectionCharCap);
    final lensText = ClaudeHttp.truncate(
        lensAnalyses.entries
            .map((e) => '=== ${e.key} analysis ===\n${e.value}')
            .join('\n\n'),
        synthesizeSectionCharCap);

    final data = await client.send({
      // Sonnet 5: this is the call the whole brief is judged on.
      'model': ClaudeHttp.deepModel,
      'max_tokens': synthesizeMaxTokens,
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

  /// Follow-up Q&A on a finished brief: plain-text answer grounded in the
  /// brief (and the pooled research when still in memory).
  Future<String> followUp({
    required String topic,
    required Map<String, dynamic> briefJson,
    String pooledResearch = '',
    List<({String role, String text})> history = const [],
    required String question,
  }) async {
    final context = StringBuffer('EMERGING RISK BRIEF (JSON):\n')
      ..writeln(ClaudeHttp.truncate(briefJson.toString(), followUpBriefCharCap));
    if (pooledResearch.isNotEmpty) {
      context.writeln(
          '\nUNDERLYING RESEARCH:\n${ClaudeHttp.truncate(pooledResearch, followUpResearchCharCap)}');
    }

    // Every turn resends the whole chat — cap it or a long Q&A thread
    // grows this call's cost without bound.
    final boundedHistory = history.length > followUpHistoryTurns
        ? history.sublist(history.length - followUpHistoryTurns)
        : history;
    final messages = <Map<String, dynamic>>[
      for (final turn in boundedHistory)
        {'role': turn.role, 'content': turn.text},
      {'role': 'user', 'content': question},
    ];

    final data = await client.send({
      'model': ClaudeHttp.model,
      'max_tokens': followUpMaxTokens,
      'system':
          'You are a senior commercial insurance practitioner (CPCU) answering '
              'follow-up questions about an emerging-risk brief on "$topic". Ground '
              'answers in the brief and research below; where they are silent, say so '
              'and reason carefully from standard insurance practice, flagging the '
              'inference. Be concise and practical.\n\n$context',
      'output_config': {'effort': 'medium'},
      'messages': messages,
    });
    return ClaudeHttp.textOf(data);
  }

  /// Radar triage: given fresh headlines and the risks already being tracked,
  /// identify genuinely new emerging risks worth a full analysis. One cheap
  /// low-effort call per scan.
  Future<List<Map<String, dynamic>>> triage(
    List<String> newHeadlines,
    List<String> knownRiskTitles,
  ) async {
    if (newHeadlines.isEmpty) return const [];
    // knownRiskTitles accumulates for the app's whole lifetime; without a
    // cap this call's cost creeps up the longer the radar has been running.
    final boundedHeadlines = newHeadlines.length > triageMaxHeadlines
        ? newHeadlines.sublist(0, triageMaxHeadlines)
        : newHeadlines;
    final boundedKnown = knownRiskTitles.length > triageMaxKnownRisks
        ? knownRiskTitles.sublist(
            knownRiskTitles.length - triageMaxKnownRisks)
        : knownRiskTitles;
    final data = await client.send({
      // Triage runs on a timer (default every 30 min) whenever the app is
      // open, so it is the cost floor of the whole app: cheap model, small
      // cap. Uses the shared constant so it tracks whatever the rest of the
      // pipeline is set to.
      'model': ClaudeHttp.model,
      'max_tokens': triageMaxTokens,
      'system':
          'You are a risk-intelligence triage analyst at a commercial insurance '
              'brokerage. From the fresh headlines, identify EMERGING RISKS that '
              'warrant practitioner analysis: developing situations with plausible '
              'commercial insurance implications (new loss drivers, litigation waves, '
              'supply shocks, regulatory shifts, catastrophe patterns). Ignore '
              'routine news, one-off incidents with no systemic angle, and anything '
              'matching a risk already being tracked. Return an empty list when '
              'nothing qualifies — most scans should find nothing.',
      'output_config': {
        'effort': 'low',
        'format': {
          'type': 'json_schema',
          'schema': {
            'type': 'object',
            'properties': {
              'emergingRisks': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'title': {'type': 'string'},
                    'rationale': {'type': 'string'},
                    'urgency': {
                      'type': 'string',
                      'enum': ['low', 'medium', 'high'],
                    },
                    'headlines': {
                      'type': 'array',
                      'items': {'type': 'string'},
                    },
                  },
                  'required': ['title', 'rationale', 'urgency', 'headlines'],
                  'additionalProperties': false,
                },
              },
            },
            'required': ['emergingRisks'],
            'additionalProperties': false,
          },
        },
      },
      'messages': [
        {
          'role': 'user',
          'content': 'Risks already being tracked (do NOT re-report these '
              'or close variants):\n'
              '${boundedKnown.isEmpty ? '(none)' : boundedKnown.map((t) => '- $t').join('\n')}\n\n'
              'Fresh headlines since the last scan:\n'
              '${boundedHeadlines.map((h) => '- $h').join('\n')}',
        },
      ],
    });
    final parsed = ClaudeHttp.jsonOf(data);
    return (parsed['emergingRisks'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

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
