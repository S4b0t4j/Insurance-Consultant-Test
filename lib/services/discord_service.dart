import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';

class DiscordService {
  static const _webhookKey = 'discord_webhook_url_v1';
  String? _webhookUrl;

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _webhookUrl = prefs.getString(_webhookKey);
  }

  Future<void> setWebhookUrl(String? url) async {
    _webhookUrl = url?.trim().isEmpty ?? true ? null : url!.trim();
    final prefs = await SharedPreferences.getInstance();
    if (_webhookUrl == null) {
      await prefs.remove(_webhookKey);
    } else {
      await prefs.setString(_webhookKey, _webhookUrl!);
    }
  }

  String? get webhookUrl => _webhookUrl;
  bool get isConfigured => _webhookUrl != null && _webhookUrl!.isNotEmpty;

  Future<bool> sendArticleAlert(Article article) async {
    if (!isConfigured) return false;
    try {
      final color = article.priority == Priority.high
          ? 0xDC2626
          : article.priority == Priority.medium
              ? 0xF59E0B
              : 0x16A34A;

      final payload = {
        'username': 'Marsh Education News Monitor',
        'embeds': [
          {
            'title': article.headline,
            'description': article.summary,
            'url': article.sourceUrl,
            'color': color,
            'fields': [
              {
                'name': 'Priority',
                'value': article.priority.name.toUpperCase(),
                'inline': true,
              },
              {
                'name': 'Category',
                'value': article.primaryCategory.displayName,
                'inline': true,
              },
              {
                'name': 'Source',
                'value': article.sourceName,
                'inline': true,
              },
            ],
            'timestamp': article.publishedAt.toIso8601String(),
            'footer': {'text': 'Marsh Education Practice'},
          }
        ],
      };

      final response = await http.post(
        Uri.parse(_webhookUrl!),
        headers: {'content-type': 'application/json'},
        body: jsonEncode(payload),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Radar detection alert: simple embed with title + rationale.
  Future<bool> sendRadarAlert(
      String title, String message, String urgency) async {
    if (!isConfigured) return false;
    try {
      final color = urgency == 'high'
          ? 0xDC2626
          : urgency == 'medium'
              ? 0xF59E0B
              : 0x16A34A;
      final response = await http.post(
        Uri.parse(_webhookUrl!),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'username': 'Risk Radar',
          'embeds': [
            {
              'title': 'Emerging risk detected: $title',
              'description': message,
              'color': color,
              'fields': [
                {
                  'name': 'Urgency',
                  'value': urgency.toUpperCase(),
                  'inline': true,
                },
              ],
              'timestamp': DateTime.now().toIso8601String(),
              'footer': {'text': 'Risk Desk — Radar'},
            }
          ],
        }),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<bool> sendTestMessage() async {
    if (!isConfigured) return false;
    try {
      final response = await http.post(
        Uri.parse(_webhookUrl!),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'username': 'Marsh Education News Monitor',
          'content':
              'Test message from Education News Monitor. Discord integration is working.',
        }),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
