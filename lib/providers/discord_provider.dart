import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../services/discord_service.dart';

class DiscordProvider extends ChangeNotifier {
  final DiscordService _service = DiscordService();
  bool _initialized = false;

  DiscordProvider() {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _service.loadConfig();
    _initialized = true;
    notifyListeners();
  }

  bool get initialized => _initialized;
  bool get isConfigured => _service.isConfigured;
  String? get webhookUrl => _service.webhookUrl;

  Future<void> setWebhookUrl(String? url) async {
    await _service.setWebhookUrl(url);
    notifyListeners();
  }

  Future<bool> sendArticleAlert(Article article) {
    return _service.sendArticleAlert(article);
  }

  Future<bool> sendRadarAlert(String title, String message, String urgency) {
    return _service.sendRadarAlert(title, message, urgency);
  }

  Future<bool> sendTestMessage() {
    return _service.sendTestMessage();
  }
}
