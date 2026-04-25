import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';

class ClaudeMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ClaudeMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toApiFormat() => {
        'role': role,
        'content': content,
      };
}

class RiskAssessment {
  final int score; // 1-10
  final String rationale;
  final int severity;
  final int likelihood;
  final List<String> affectedSectors;
  final String coverageGapNotes;

  RiskAssessment({
    required this.score,
    required this.rationale,
    required this.severity,
    required this.likelihood,
    required this.affectedSectors,
    required this.coverageGapNotes,
  });

  factory RiskAssessment.fromJson(Map<String, dynamic> json) => RiskAssessment(
        score: json['score'] ?? 5,
        rationale: json['rationale'] ?? '',
        severity: json['severity'] ?? 5,
        likelihood: json['likelihood'] ?? 5,
        affectedSectors: List<String>.from(json['affectedSectors'] ?? []),
        coverageGapNotes: json['coverageGapNotes'] ?? '',
      );
}

class ClaudeService {
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-opus-4-7';
  static const String _apiVersion = '2023-06-01';

  String? _apiKey;

  void setApiKey(String? key) {
    _apiKey = key;
  }

  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  Future<String> chat({
    required List<ClaudeMessage> messages,
    String? systemPrompt,
    int maxTokens = 1024,
  }) async {
    if (!hasApiKey) {
      return _demoChatResponse(messages.last.content);
    }

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'content-type': 'application/json',
          'x-api-key': _apiKey!,
          'anthropic-version': _apiVersion,
          'anthropic-dangerous-direct-browser-access': 'true',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': maxTokens,
          if (systemPrompt != null) 'system': systemPrompt,
          'messages': messages.map((m) => m.toApiFormat()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['content'] as List;
        if (content.isNotEmpty) {
          return content.first['text'] as String;
        }
      }
      return 'Unable to reach Claude. Status: ${response.statusCode}';
    } catch (e) {
      return _demoChatResponse(messages.last.content);
    }
  }

  Future<String> summarizeArticle(Article article) async {
    if (!hasApiKey) {
      return _demoSummary(article);
    }

    final systemPrompt =
        'You are a senior insurance risk analyst at Marsh\'s Education Practice. '
        'Generate concise executive summaries (2-3 sentences) focused on insurance and risk implications. '
        'Be precise, professional, and actionable.';

    final userMessage = '''
Article Headline: ${article.headline}
Source: ${article.sourceName}
Category: ${article.primaryCategory.displayName}
Content: ${article.summary}

Generate an executive summary highlighting the key risk implications for educational institutions.''';

    return await chat(
      messages: [ClaudeMessage(role: 'user', content: userMessage)],
      systemPrompt: systemPrompt,
      maxTokens: 300,
    );
  }

  Future<RiskAssessment> assessRisk(Article article) async {
    if (!hasApiKey) {
      return _demoRiskAssessment(article);
    }

    final systemPrompt =
        'You are an insurance risk analyst. Output ONLY valid JSON matching this schema: '
        '{"score": int 1-10, "rationale": string, "severity": int 1-10, "likelihood": int 1-10, '
        '"affectedSectors": [string array], "coverageGapNotes": string}. '
        'Score considers severity, likelihood, sector exposure, and coverage gaps.';

    final userMessage = '''
Headline: ${article.headline}
Summary: ${article.summary}
Category: ${article.primaryCategory.displayName}
Existing Risk Tags: ${article.riskTags.join(', ')}

Assess insurance risk for educational institutions. Return JSON only.''';

    try {
      final response = await chat(
        messages: [ClaudeMessage(role: 'user', content: userMessage)],
        systemPrompt: systemPrompt,
        maxTokens: 500,
      );

      // Extract JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!);
        return RiskAssessment.fromJson(json);
      }
    } catch (_) {}
    return _demoRiskAssessment(article);
  }

  Future<List<String>> detectTrends(List<Article> articles) async {
    if (!hasApiKey || articles.isEmpty) {
      return _demoTrends(articles);
    }

    final systemPrompt =
        'You are a trend analyst. Identify 3-5 emerging trends across articles. '
        'Output as JSON array of short strings, no other text.';

    final articleList = articles
        .take(20)
        .map((a) => '- ${a.headline} (${a.primaryCategory.shortName})')
        .join('\n');

    try {
      final response = await chat(
        messages: [
          ClaudeMessage(
            role: 'user',
            content: 'Articles:\n$articleList\n\nIdentify key trends. JSON array only.',
          )
        ],
        systemPrompt: systemPrompt,
        maxTokens: 400,
      );

      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch != null) {
        final List list = jsonDecode(jsonMatch.group(0)!);
        return list.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return _demoTrends(articles);
  }

  // ============ Demo fallbacks (when no API key) ============

  String _demoChatResponse(String userQuery) {
    final lower = userQuery.toLowerCase();
    if (lower.contains('nil') || lower.contains('athlete')) {
      return 'NIL (Name, Image, Likeness) developments continue to reshape collegiate athletics insurance. '
          'Key risks include: revenue-sharing settlement compliance, employment classification disputes, '
          'and Title IX implications. I recommend reviewing your athletic department\'s D&O coverage and '
          'general liability limits.';
    }
    if (lower.contains('title ix') || lower.contains('compliance')) {
      return 'Title IX compliance remains a high-priority risk area, particularly with recent regulatory changes. '
          'Educational institutions should ensure adequate EPLI coverage and review investigation protocols. '
          'Coverage gaps often emerge around third-party harassment and retaliation claims.';
    }
    if (lower.contains('cyber') || lower.contains('data')) {
      return 'Cyber risk in education is escalating, with K-12 districts and higher ed institutions '
          'as primary targets. Ransomware, FERPA violations, and student PII breaches are top concerns. '
          'Consider dedicated cyber liability policies with breach response coverage.';
    }
    return 'Based on current education news trends, key insurance risks include: regulatory compliance '
        '(Title IX, FERPA), cyber threats targeting student data, NIL-related liability for athletic programs, '
        'and increased D&O exposure for institutional leadership. I can provide deeper analysis on any specific area.';
  }

  String _demoSummary(Article article) {
    return 'AI Summary: ${article.summary} '
        'Key insurance implications include heightened ${article.primaryCategory.displayName.toLowerCase()} exposure '
        'and potential coverage review needs for affected institutions.';
  }

  RiskAssessment _demoRiskAssessment(Article article) {
    final base = article.priority == Priority.high
        ? 8
        : article.priority == Priority.medium
            ? 5
            : 3;
    return RiskAssessment(
      score: base,
      rationale:
          'Risk level reflects ${article.priority.name} priority categorization with focus on ${article.primaryCategory.displayName}.',
      severity: base,
      likelihood: base - 1,
      affectedSectors: [article.primaryCategory.displayName],
      coverageGapNotes:
          'Review existing ${article.primaryCategory.shortName} coverage limits and exclusions.',
    );
  }

  List<String> _demoTrends(List<Article> articles) {
    return [
      'NIL Settlement Implementation',
      'Title IX Regulatory Updates',
      'Cyber Threats in Education',
      'Federal DOE Policy Shifts',
      'Higher Ed Financial Stress',
    ];
  }
}
