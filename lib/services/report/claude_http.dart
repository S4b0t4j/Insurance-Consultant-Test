import 'dart:convert';

import 'package:http/http.dart' as http;

class ReportAiException implements Exception {
  final int? statusCode;
  final String message;
  ReportAiException(this.message, {this.statusCode});
  @override
  String toString() =>
      'ReportAiException${statusCode != null ? ' ($statusCode)' : ''}: $message';
}

/// Thin raw-HTTP Claude Messages API client for Report Studio and Risk Desk.
/// Unlike the legacy ClaudeService, errors are propagated — never masked
/// with demo content.
class ClaudeHttp {
  static const String apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String model = 'claude-opus-5';
  static const String _apiVersion = '2023-06-01';

  String? _apiKey;

  void setApiKey(String? key) => _apiKey = key;

  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// POSTs a Messages API request body; retries once on 429/5xx/529.
  /// Returns the decoded response JSON.
  Future<Map<String, dynamic>> send(Map<String, dynamic> body) async {
    if (!hasApiKey) {
      throw ReportAiException(
          'No Claude API key configured. Ask an admin to add one under Admin → Claude API.');
    }

    http.Response response;
    for (var attempt = 0;; attempt++) {
      try {
        response = await http
            .post(
              Uri.parse(apiUrl),
              headers: {
                'content-type': 'application/json',
                'x-api-key': _apiKey!,
                'anthropic-version': _apiVersion,
                'anthropic-dangerous-direct-browser-access': 'true',
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(minutes: 6));
      } catch (e) {
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        throw ReportAiException('Network error calling Claude: $e');
      }

      if (response.statusCode == 200) break;
      final retryable = response.statusCode == 429 ||
          response.statusCode >= 500;
      if (retryable && attempt == 0) {
        await Future.delayed(const Duration(seconds: 5));
        continue;
      }
      String detail = response.body;
      try {
        detail = jsonDecode(response.body)['error']?['message'] ?? detail;
      } catch (_) {}
      throw ReportAiException(detail, statusCode: response.statusCode);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['stop_reason'] == 'refusal') {
      throw ReportAiException(
          'Claude declined this request (safety refusal). Adjust the topic or sources and try again.');
    }
    return data;
  }

  /// Concatenated text of all text blocks in a response.
  static String textOf(Map<String, dynamic> data) {
    final content = (data['content'] as List?) ?? [];
    return content
        .whereType<Map<String, dynamic>>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String? ?? '')
        .join();
  }

  /// Parses the JSON produced by a structured-output request.
  static Map<String, dynamic> jsonOf(Map<String, dynamic> data) {
    final text = textOf(data);
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      throw ReportAiException(
          'Claude returned malformed JSON despite structured output: $e');
    }
  }

  /// Web-search citations attached to text blocks: list of {title, url}.
  static List<Map<String, String>> citationsOf(Map<String, dynamic> data) {
    final out = <Map<String, String>>[];
    final seen = <String>{};
    final content = (data['content'] as List?) ?? [];
    for (final block in content.whereType<Map<String, dynamic>>()) {
      final citations = (block['citations'] as List?) ?? [];
      for (final c in citations.whereType<Map<String, dynamic>>()) {
        final url = c['url'] as String? ?? '';
        if (url.isEmpty || seen.contains(url)) continue;
        seen.add(url);
        out.add({'title': c['title'] as String? ?? url, 'url': url});
      }
    }
    return out;
  }
}
