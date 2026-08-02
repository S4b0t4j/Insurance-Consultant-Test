import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert.dart';
import '../models/article.dart';
import '../services/crypto_service.dart';

/// Provider for managing alert rules, triggered alerts, and regulatory deadlines
class AlertProvider with ChangeNotifier {
  static const String _rulesKey = 'encrypted_alert_rules_v1';
  static const String _alertsKey = 'encrypted_triggered_alerts_v1';
  static const String _deadlinesKey = 'encrypted_deadlines_v1';

  List<AlertRule> _rules = [];
  List<TriggeredAlert> _triggeredAlerts = [];
  List<RegulatoryDeadline> _deadlines = [];
  bool _isLoading = true;
  CryptoService? _cryptoService;

  // Track article IDs that have already triggered alerts to avoid duplicates
  final Set<String> _processedArticleIds = {};

  AlertProvider() {
    _initializeAndLoad();
  }

  // Getters
  List<AlertRule> get rules => _rules;
  List<AlertRule> get enabledRules => _rules.where((r) => r.isEnabled).toList();
  List<TriggeredAlert> get triggeredAlerts => _triggeredAlerts;
  List<TriggeredAlert> get unreadAlerts =>
      _triggeredAlerts.where((a) => !a.isRead && !a.isDismissed).toList();
  List<TriggeredAlert> get activeAlerts =>
      _triggeredAlerts.where((a) => !a.isDismissed).toList();
  List<RegulatoryDeadline> get deadlines => _deadlines;
  List<RegulatoryDeadline> get upcomingDeadlines =>
      _deadlines.where((d) => !d.isCompleted && d.daysUntilDeadline >= 0).toList()
        ..sort((a, b) => a.deadline.compareTo(b.deadline));
  List<RegulatoryDeadline> get overdueDeadlines =>
      _deadlines.where((d) => !d.isCompleted && d.isOverdue).toList();
  bool get isLoading => _isLoading;
  int get unreadCount => unreadAlerts.length;

  Future<void> _initializeAndLoad() async {
    _isLoading = true;
    notifyListeners();

    try {
      _cryptoService = await CryptoService.getInstance();
      await Future.wait([
        _loadRules(),
        _loadTriggeredAlerts(),
        _loadDeadlines(),
      ]);
      _initializeDefaultRules();
      _initializeSampleDeadlines();
    } catch (e) {
      debugPrint('Error initializing alert provider: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedData = prefs.getString(_rulesKey);
      if (encryptedData != null && encryptedData.isNotEmpty) {
        final decryptedJson = _cryptoService!.decrypt(encryptedData);
        final List<dynamic> jsonList = jsonDecode(decryptedJson);
        _rules = jsonList
            .map((json) => AlertRule.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading alert rules: $e');
    }
  }

  Future<void> _loadTriggeredAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedData = prefs.getString(_alertsKey);
      if (encryptedData != null && encryptedData.isNotEmpty) {
        final decryptedJson = _cryptoService!.decrypt(encryptedData);
        final List<dynamic> jsonList = jsonDecode(decryptedJson);
        // Note: We store minimal alert data, articles are re-linked on load
        _triggeredAlerts = jsonList.map((json) {
          final rule = AlertRule.fromJson(json['rule'] as Map<String, dynamic>);
          return TriggeredAlert(
            id: json['id'],
            rule: rule,
            triggeredAt: DateTime.parse(json['triggeredAt']),
            message: json['message'],
            isRead: json['isRead'] ?? false,
            isDismissed: json['isDismissed'] ?? false,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error loading triggered alerts: $e');
    }
  }

  Future<void> _loadDeadlines() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedData = prefs.getString(_deadlinesKey);
      if (encryptedData != null && encryptedData.isNotEmpty) {
        final decryptedJson = _cryptoService!.decrypt(encryptedData);
        final List<dynamic> jsonList = jsonDecode(decryptedJson);
        _deadlines = jsonList
            .map((json) =>
                RegulatoryDeadline.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading deadlines: $e');
    }
  }

  void _initializeDefaultRules() {
    if (_rules.isEmpty) {
      _rules = [
        AlertRule(
          id: 'default_high_priority',
          name: 'High Priority Surge',
          description: 'Alert when 3+ high priority articles appear within 24 hours',
          type: AlertRuleType.priorityThreshold,
          severity: AlertSeverity.high,
          thresholdCount: 3,
          thresholdHours: 24,
          thresholdPriority: Priority.high,
          createdAt: DateTime.now(),
        ),
        AlertRule(
          id: 'default_breaking',
          name: 'Breaking News Alert',
          description: 'Immediate alert for any breaking news',
          type: AlertRuleType.breakingNews,
          severity: AlertSeverity.critical,
          createdAt: DateTime.now(),
        ),
        AlertRule(
          id: 'default_title_ix',
          name: 'Title IX Keywords',
          description: 'Monitor for Title IX related news',
          type: AlertRuleType.keywordMatch,
          severity: AlertSeverity.high,
          keywords: ['Title IX', 'OCR investigation', 'sexual misconduct', 'gender equity'],
          createdAt: DateTime.now(),
        ),
        AlertRule(
          id: 'default_nil',
          name: 'NIL Compliance',
          description: 'Monitor for NIL compliance and regulation changes',
          type: AlertRuleType.keywordMatch,
          severity: AlertSeverity.medium,
          keywords: ['NIL violation', 'NIL regulation', 'NIL compliance', 'collective'],
          createdAt: DateTime.now(),
        ),
        AlertRule(
          id: 'default_accreditation',
          name: 'Accreditation Risk',
          description: 'Alert on accreditation-related news',
          type: AlertRuleType.keywordMatch,
          severity: AlertSeverity.critical,
          keywords: ['accreditation', 'probation', 'loss of accreditation', 'HLC', 'SACSCOC'],
          createdAt: DateTime.now(),
        ),
        AlertRule(
          id: 'default_doe_category',
          name: 'DOE Activity Spike',
          description: 'Alert when Federal/DOE category sees unusual activity',
          type: AlertRuleType.categorySpike,
          severity: AlertSeverity.high,
          targetCategory: NewsCategory.federalDoe,
          spikeThreshold: 5,
          createdAt: DateTime.now(),
        ),
      ];
      _saveRules();
    }
  }

  void _initializeSampleDeadlines() {
    if (_deadlines.isEmpty) {
      final now = DateTime.now();
      _deadlines = [
        RegulatoryDeadline(
          id: 'dl_1',
          title: 'Title IX Final Rule Implementation',
          description: 'New Title IX regulations take effect. All institutions must have updated policies and procedures in place.',
          deadline: DateTime(2026, 8, 1),
          regulatoryBody: 'Department of Education',
          affectedInstitutionTypes: ['All Title IV institutions'],
          complianceUrl: 'https://www.ed.gov/title-ix',
        ),
        RegulatoryDeadline(
          id: 'dl_2',
          title: 'IPEDS Fall Enrollment Survey',
          description: 'Annual submission of fall enrollment data to IPEDS.',
          deadline: DateTime(now.year, 10, 15),
          regulatoryBody: 'NCES / Department of Education',
          affectedInstitutionTypes: ['All Title IV institutions'],
        ),
        RegulatoryDeadline(
          id: 'dl_3',
          title: 'NCAA NIL Disclosure Deadline',
          description: 'All NIL arrangements must be disclosed per new NCAA requirements.',
          deadline: DateTime(2026, 7, 1),
          regulatoryBody: 'NCAA',
          affectedInstitutionTypes: ['NCAA Division I', 'NCAA Division II', 'NCAA Division III'],
        ),
        RegulatoryDeadline(
          id: 'dl_4',
          title: 'Clery Act Annual Security Report',
          description: 'Publish and distribute annual security report to campus community.',
          deadline: DateTime(now.year, 10, 1),
          regulatoryBody: 'Department of Education',
          affectedInstitutionTypes: ['All Title IV institutions'],
        ),
        RegulatoryDeadline(
          id: 'dl_5',
          title: 'FERPA Annual Notification',
          description: 'Annual notification to students of FERPA rights.',
          deadline: DateTime(now.year, 9, 1),
          regulatoryBody: 'Department of Education',
          affectedInstitutionTypes: ['All educational institutions'],
        ),
      ];
      _saveDeadlines();
    }
  }

  Future<void> _saveRules() async {
    if (_cryptoService == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _rules.map((r) => r.toJson()).toList();
      final encrypted = _cryptoService!.encrypt(jsonEncode(jsonList));
      await prefs.setString(_rulesKey, encrypted);
    } catch (e) {
      debugPrint('Error saving rules: $e');
    }
  }

  Future<void> _saveTriggeredAlerts() async {
    if (_cryptoService == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _triggeredAlerts.map((a) => a.toJson()).toList();
      final encrypted = _cryptoService!.encrypt(jsonEncode(jsonList));
      await prefs.setString(_alertsKey, encrypted);
    } catch (e) {
      debugPrint('Error saving triggered alerts: $e');
    }
  }

  Future<void> _saveDeadlines() async {
    if (_cryptoService == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _deadlines.map((d) => d.toJson()).toList();
      final encrypted = _cryptoService!.encrypt(jsonEncode(jsonList));
      await prefs.setString(_deadlinesKey, encrypted);
    } catch (e) {
      debugPrint('Error saving deadlines: $e');
    }
  }

  /// Process articles and check against all enabled rules
  void processArticles(List<Article> articles) {
    for (final rule in enabledRules) {
      switch (rule.type) {
        case AlertRuleType.priorityThreshold:
          _checkPriorityThreshold(rule, articles);
          break;
        case AlertRuleType.keywordMatch:
          _checkKeywordMatch(rule, articles);
          break;
        case AlertRuleType.breakingNews:
          _checkBreakingNews(rule, articles);
          break;
        case AlertRuleType.categorySpike:
          _checkCategorySpike(rule, articles);
          break;
        case AlertRuleType.institutionMention:
          _checkInstitutionMention(rule, articles);
          break;
        case AlertRuleType.conferenceMention:
          _checkConferenceMention(rule, articles);
          break;
        case AlertRuleType.regulatoryDeadline:
          // Handled separately
          break;
      }
    }
    _checkDeadlineAlerts();
  }

  void _checkPriorityThreshold(AlertRule rule, List<Article> articles) {
    if (rule.thresholdCount == null ||
        rule.thresholdHours == null ||
        rule.thresholdPriority == null) return;

    final cutoff = DateTime.now().subtract(Duration(hours: rule.thresholdHours!));
    final matchingArticles = articles.where((a) =>
        a.priority == rule.thresholdPriority &&
        a.publishedAt.isAfter(cutoff)).toList();

    if (matchingArticles.length >= rule.thresholdCount!) {
      final alertId = '${rule.id}_${DateTime.now().millisecondsSinceEpoch}';
      if (!_hasRecentAlert(rule.id, const Duration(hours: 4))) {
        _triggerAlert(
          TriggeredAlert(
            id: alertId,
            rule: rule,
            triggeredAt: DateTime.now(),
            message:
                '${matchingArticles.length} ${rule.thresholdPriority!.name} priority articles in the last ${rule.thresholdHours} hours',
            relatedArticles: matchingArticles,
          ),
        );
      }
    }
  }

  void _checkKeywordMatch(AlertRule rule, List<Article> articles) {
    if (rule.keywords.isEmpty) return;

    for (final article in articles) {
      if (_processedArticleIds.contains('${rule.id}_${article.id}')) continue;

      final textToSearch = rule.keywordCaseSensitive
          ? '${article.headline} ${article.summary}'
          : '${article.headline} ${article.summary}'.toLowerCase();

      for (final keyword in rule.keywords) {
        final searchKeyword =
            rule.keywordCaseSensitive ? keyword : keyword.toLowerCase();

        if (textToSearch.contains(searchKeyword)) {
          _processedArticleIds.add('${rule.id}_${article.id}');
          _triggerAlert(
            TriggeredAlert(
              id: '${rule.id}_${article.id}',
              rule: rule,
              triggeredAt: DateTime.now(),
              message: 'Keyword "$keyword" found in: ${article.headline}',
              relatedArticles: [article],
            ),
          );
          break;
        }
      }
    }
  }

  void _checkBreakingNews(AlertRule rule, List<Article> articles) {
    for (final article in articles) {
      if (article.isBreaking &&
          !_processedArticleIds.contains('${rule.id}_${article.id}')) {
        _processedArticleIds.add('${rule.id}_${article.id}');
        _triggerAlert(
          TriggeredAlert(
            id: '${rule.id}_${article.id}',
            rule: rule,
            triggeredAt: DateTime.now(),
            message: 'BREAKING: ${article.headline}',
            relatedArticles: [article],
          ),
        );
      }
    }
  }

  void _checkCategorySpike(AlertRule rule, List<Article> articles) {
    if (rule.targetCategory == null || rule.spikeThreshold == null) return;

    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final categoryArticles = articles.where((a) =>
        a.primaryCategory == rule.targetCategory &&
        a.publishedAt.isAfter(cutoff)).toList();

    if (categoryArticles.length >= rule.spikeThreshold!) {
      if (!_hasRecentAlert(rule.id, const Duration(hours: 12))) {
        _triggerAlert(
          TriggeredAlert(
            id: '${rule.id}_${DateTime.now().millisecondsSinceEpoch}',
            rule: rule,
            triggeredAt: DateTime.now(),
            message:
                'Spike detected: ${categoryArticles.length} ${rule.targetCategory!.displayName} articles in 24 hours',
            relatedArticles: categoryArticles,
          ),
        );
      }
    }
  }

  void _checkInstitutionMention(AlertRule rule, List<Article> articles) {
    if (rule.watchedInstitutions.isEmpty) return;

    for (final article in articles) {
      if (_processedArticleIds.contains('${rule.id}_${article.id}')) continue;

      for (final institution in rule.watchedInstitutions) {
        if (article.institutionsAffected
            .any((i) => i.toLowerCase().contains(institution.toLowerCase()))) {
          _processedArticleIds.add('${rule.id}_${article.id}');
          _triggerAlert(
            TriggeredAlert(
              id: '${rule.id}_${article.id}',
              rule: rule,
              triggeredAt: DateTime.now(),
              message: '$institution mentioned: ${article.headline}',
              relatedArticles: [article],
            ),
          );
          break;
        }
      }
    }
  }

  void _checkConferenceMention(AlertRule rule, List<Article> articles) {
    if (rule.watchedConferences.isEmpty) return;

    for (final article in articles) {
      if (_processedArticleIds.contains('${rule.id}_${article.id}')) continue;

      for (final conference in rule.watchedConferences) {
        if (article.conferencesAffected
            .any((c) => c.toLowerCase().contains(conference.toLowerCase()))) {
          _processedArticleIds.add('${rule.id}_${article.id}');
          _triggerAlert(
            TriggeredAlert(
              id: '${rule.id}_${article.id}',
              rule: rule,
              triggeredAt: DateTime.now(),
              message: '$conference mentioned: ${article.headline}',
              relatedArticles: [article],
            ),
          );
          break;
        }
      }
    }
  }

  void _checkDeadlineAlerts() {
    for (final deadline in upcomingDeadlines) {
      final days = deadline.daysUntilDeadline;
      final alertId = 'deadline_${deadline.id}_$days';

      // Alert at 30 days, 14 days, 7 days, 3 days, 1 day
      if ((days == 30 || days == 14 || days == 7 || days == 3 || days == 1) &&
          !_triggeredAlerts.any((a) => a.id == alertId)) {
        final urgency = days <= 3 ? 'URGENT' : days <= 7 ? 'Upcoming' : 'Reminder';
        final severity = days <= 3
            ? AlertSeverity.critical
            : days <= 7
                ? AlertSeverity.high
                : AlertSeverity.medium;

        _triggerAlert(
          TriggeredAlert(
            id: alertId,
            rule: AlertRule(
              id: 'deadline_rule',
              name: 'Regulatory Deadline',
              description: deadline.description,
              type: AlertRuleType.regulatoryDeadline,
              severity: severity,
              createdAt: DateTime.now(),
            ),
            triggeredAt: DateTime.now(),
            message: '$urgency: ${deadline.title} - $days days remaining',
          ),
        );
      }
    }
  }

  bool _hasRecentAlert(String ruleId, Duration window) {
    final cutoff = DateTime.now().subtract(window);
    return _triggeredAlerts.any((a) =>
        a.rule.id == ruleId &&
        a.triggeredAt.isAfter(cutoff) &&
        !a.isDismissed);
  }

  void _triggerAlert(TriggeredAlert alert) {
    _triggeredAlerts.insert(0, alert);
    _saveTriggeredAlerts();
    notifyListeners();
  }

  /// Lets other features (e.g. the Risk Radar) surface alerts through the
  /// standard alerts panel without owning an AlertRule.
  void addExternalAlert({
    required String title,
    required String message,
    AlertSeverity severity = AlertSeverity.medium,
  }) {
    final now = DateTime.now();
    _triggerAlert(TriggeredAlert(
      id: 'ext_${now.microsecondsSinceEpoch}',
      rule: AlertRule(
        id: 'external',
        name: title,
        description: 'External alert',
        type: AlertRuleType.keywordMatch,
        severity: severity,
        createdAt: now,
      ),
      triggeredAt: now,
      message: message,
    ));
  }

  // CRUD Operations for Rules
  Future<void> addRule(AlertRule rule) async {
    _rules.add(rule);
    await _saveRules();
    notifyListeners();
  }

  Future<void> updateRule(AlertRule rule) async {
    final index = _rules.indexWhere((r) => r.id == rule.id);
    if (index != -1) {
      _rules[index] = rule;
      await _saveRules();
      notifyListeners();
    }
  }

  Future<void> deleteRule(String id) async {
    _rules.removeWhere((r) => r.id == id);
    await _saveRules();
    notifyListeners();
  }

  Future<void> toggleRule(String id) async {
    final index = _rules.indexWhere((r) => r.id == id);
    if (index != -1) {
      _rules[index] = _rules[index].copyWith(isEnabled: !_rules[index].isEnabled);
      await _saveRules();
      notifyListeners();
    }
  }

  // Alert Management
  Future<void> markAlertRead(String id) async {
    final index = _triggeredAlerts.indexWhere((a) => a.id == id);
    if (index != -1) {
      _triggeredAlerts[index] = _triggeredAlerts[index].copyWith(isRead: true);
      await _saveTriggeredAlerts();
      notifyListeners();
    }
  }

  Future<void> dismissAlert(String id) async {
    final index = _triggeredAlerts.indexWhere((a) => a.id == id);
    if (index != -1) {
      _triggeredAlerts[index] = _triggeredAlerts[index].copyWith(isDismissed: true);
      await _saveTriggeredAlerts();
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    _triggeredAlerts = _triggeredAlerts
        .map((a) => a.copyWith(isRead: true))
        .toList();
    await _saveTriggeredAlerts();
    notifyListeners();
  }

  Future<void> clearAllAlerts() async {
    _triggeredAlerts.clear();
    _processedArticleIds.clear();
    await _saveTriggeredAlerts();
    notifyListeners();
  }

  // Deadline Management
  Future<void> addDeadline(RegulatoryDeadline deadline) async {
    _deadlines.add(deadline);
    await _saveDeadlines();
    notifyListeners();
  }

  Future<void> completeDeadline(String id) async {
    final index = _deadlines.indexWhere((d) => d.id == id);
    if (index != -1) {
      _deadlines[index] = RegulatoryDeadline(
        id: _deadlines[index].id,
        title: _deadlines[index].title,
        description: _deadlines[index].description,
        deadline: _deadlines[index].deadline,
        regulatoryBody: _deadlines[index].regulatoryBody,
        affectedInstitutionTypes: _deadlines[index].affectedInstitutionTypes,
        complianceUrl: _deadlines[index].complianceUrl,
        isCompleted: true,
      );
      await _saveDeadlines();
      notifyListeners();
    }
  }

  Future<void> deleteDeadline(String id) async {
    _deadlines.removeWhere((d) => d.id == id);
    await _saveDeadlines();
    notifyListeners();
  }
}
