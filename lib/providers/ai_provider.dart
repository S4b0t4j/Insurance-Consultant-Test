import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../services/claude_service.dart';

class AIProvider extends ChangeNotifier {
  static const _apiKeyStorage = 'claude_api_key_v1';
  final ClaudeService _service = ClaudeService();

  final List<ClaudeMessage> _chatHistory = [];
  bool _loading = false;
  String? _apiKey;
  List<String> _trendingTopics = [];
  final Map<String, RiskAssessment> _riskCache = {};
  final Map<String, String> _summaryCache = {};

  List<ClaudeMessage> get chatHistory => List.unmodifiable(_chatHistory);
  bool get loading => _loading;
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;
  List<String> get trendingTopics => _trendingTopics;
  String? get apiKey => _apiKey;

  AIProvider() {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_apiKeyStorage);
    _service.setApiKey(_apiKey);
    notifyListeners();
  }

  Future<void> setApiKey(String? key) async {
    _apiKey = key?.trim().isEmpty ?? true ? null : key!.trim();
    _service.setApiKey(_apiKey);
    final prefs = await SharedPreferences.getInstance();
    if (_apiKey == null) {
      await prefs.remove(_apiKeyStorage);
    } else {
      await prefs.setString(_apiKeyStorage, _apiKey!);
    }
    notifyListeners();
  }

  Future<void> sendChatMessage(String message, {List<Article>? context}) async {
    if (message.trim().isEmpty) return;

    _chatHistory.add(ClaudeMessage(role: 'user', content: message));
    _loading = true;
    notifyListeners();

    final systemPrompt =
        'You are an AI insurance risk advisor for the public sector practice. '
        'You help risk professionals understand public sector news, policy and regulatory changes, '
        'and their insurance implications. Be concise, professional, and actionable. '
        'When relevant, mention specific coverage types (D&O, EPLI, cyber, general liability). '
        '${context != null && context.isNotEmpty ? "\n\nRecent articles for context:\n${context.take(10).map((a) => "- ${a.headline}").join("\n")}" : ""}';

    try {
      final response = await _service.chat(
        // Only the recent tail — resending the whole history makes every
        // turn dearer than the last for no quality gain in casual Q&A.
        messages: _chatHistory.length > 12
            ? _chatHistory.sublist(_chatHistory.length - 12)
            : _chatHistory,
        systemPrompt: systemPrompt,
        maxTokens: 1024,
      );
      _chatHistory.add(ClaudeMessage(role: 'assistant', content: response));
    } catch (e) {
      _chatHistory.add(ClaudeMessage(
        role: 'assistant',
        content: 'I encountered an error: ${e.toString()}',
      ));
    }
    _loading = false;
    notifyListeners();
  }

  void clearChat() {
    _chatHistory.clear();
    notifyListeners();
  }

  Future<String> getSummary(Article article) async {
    if (_summaryCache.containsKey(article.id)) {
      return _summaryCache[article.id]!;
    }
    final summary = await _service.summarizeArticle(article);
    _summaryCache[article.id] = summary;
    notifyListeners();
    return summary;
  }

  Future<RiskAssessment> getRiskAssessment(Article article) async {
    if (_riskCache.containsKey(article.id)) {
      return _riskCache[article.id]!;
    }
    final assessment = await _service.assessRisk(article);
    _riskCache[article.id] = assessment;
    notifyListeners();
    return assessment;
  }

  RiskAssessment? cachedRisk(String articleId) => _riskCache[articleId];
  String? cachedSummary(String articleId) => _summaryCache[articleId];

  Future<void> refreshTrends(List<Article> articles) async {
    _trendingTopics = await _service.detectTrends(articles);
    notifyListeners();
  }
}
