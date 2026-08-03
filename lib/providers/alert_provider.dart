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
          id: 'default_cyber',
          name: 'Municipal Cyber Incident',
          description: 'Monitor for ransomware and breaches against public entities',
          type: AlertRuleType.keywordMatch,
          severity: AlertSeverity.critical,
          keywords: ['ransomware', 'cyberattack', 'data breach', 'systems offline'],
          createdAt: DateTime.now(),
        ),
        AlertRule(
          id: 'default_officials_liability',
          name: 'Public Officials Liability',
          description: 'Monitor for claims and suits against governing bodies',
          type: AlertRuleType.keywordMatch,
          severity: AlertSeverity.high,
          keywords: ['public officials liability', 'consent decree', 'civil rights suit', 'indemnification'],
          createdAt: DateTime.now(),
        ),
        AlertRule(
          id: 'default_fiscal_distress',
          name: 'Fiscal Distress',
          description: 'Alert on budget and credit deterioration at public entities',
          type: AlertRuleType.keywordMatch,
          severity: AlertSeverity.critical,
          keywords: ['budget shortfall', 'credit downgrade', 'state takeover', 'insolvency'],
          createdAt: DateTime.now(),
        ),
        AlertRule(
          id: 'default_federal_category',
          name: 'Federal Policy Activity Spike',
          description: 'Alert when Federal Policy sees unusual activity',
          type: AlertRuleType.categorySpike,
          severity: AlertSeverity.high,
          targetCategory: NewsCategory.federalPolicy,
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
          title: 'Single Audit Submission (2 CFR 200)',
          description: 'Entities expending \$1M or more in federal awards must submit the Single Audit reporting package to the Federal Audit Clearinghouse.',
          deadline: DateTime(now.year, 9, 30),
          regulatoryBody: 'Office of Management and Budget',
          affectedEntityTypes: ['All federal award recipients'],
          complianceUrl: 'https://www.whitehouse.gov/omb/management/office-federal-financial-management/',
        ),
        RegulatoryDeadline(
          id: 'dl_2',
          title: 'Annual Comprehensive Financial Report',
          description: 'Publication of the ACFR for the prior fiscal year under GASB reporting standards.',
          deadline: DateTime(now.year, 12, 31),
          regulatoryBody: 'Governmental Accounting Standards Board',
          affectedEntityTypes: ['State and local governments'],
        ),
        RegulatoryDeadline(
          id: 'dl_3',
          title: 'CISA Incident Reporting (CIRCIA)',
          description: 'Covered entities must report substantial cyber incidents within 72 hours and ransom payments within 24 hours.',
          deadline: DateTime(now.year, 10, 1),
          regulatoryBody: 'Cybersecurity and Infrastructure Security Agency',
          affectedEntityTypes: ['Critical infrastructure entities'],
          complianceUrl: 'https://www.cisa.gov/circia',
        ),
        RegulatoryDeadline(
          id: 'dl_4',
          title: 'Emergency Operations Plan Review',
          description: 'Annual review and certification of the jurisdiction emergency operations plan.',
          deadline: DateTime(now.year, 7, 1),
          regulatoryBody: 'Federal Emergency Management Agency',
          affectedEntityTypes: ['Counties and municipalities'],
        ),
        RegulatoryDeadline(
          id: 'dl_5',
          title: 'Public Records Retention Certification',
          description: 'Annual certification that records retention and open-records procedures meet state requirements.',
          deadline: DateTime(now.year, 6, 30),
          regulatoryBody: 'State Records Administration',
          affectedEntityTypes: ['All public agencies'],
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
        case AlertRuleType.entityMention:
          _checkEntityMention(rule, articles);
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

  void _checkEntityMention(AlertRule rule, List<Article> articles) {
    if (rule.watchedEntities.isEmpty) return;

    for (final article in articles) {
      if (_processedArticleIds.contains('${rule.id}_${article.id}')) continue;

      for (final entity in rule.watchedEntities) {
        if (article.entitiesAffected
            .any((i) => i.toLowerCase().contains(entity.toLowerCase()))) {
          _processedArticleIds.add('${rule.id}_${article.id}');
          _triggerAlert(
            TriggeredAlert(
              id: '${rule.id}_${article.id}',
              rule: rule,
              triggeredAt: DateTime.now(),
              message: '\$entity mentioned: \${article.headline}',
              relatedArticles: [article],
            ),
          );
          break;
        }
      }
    }
  }

  void _checkConferenceMention(AlertRule rule, List<Article> articles) {
    if (rule.watchedJurisdictions.isEmpty) return;

    for (final article in articles) {
      if (_processedArticleIds.contains('${rule.id}_${article.id}')) continue;

      for (final conference in rule.watchedJurisdictions) {
        if (article.jurisdictionsAffected
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
        affectedEntityTypes: _deadlines[index].affectedEntityTypes,
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
