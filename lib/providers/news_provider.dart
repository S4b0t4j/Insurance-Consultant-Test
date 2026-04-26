import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../data/sample_articles.dart';

enum NewsFeedTab { all, education, nilSports }

class NewsProvider with ChangeNotifier {
  List<Article> _articles = [];
  NewsFeedTab _currentTab = NewsFeedTab.all;
  String _searchQuery = '';
  Set<Priority> _selectedPriorities = {};
  Set<NewsCategory> _selectedCategories = {};
  Set<String> _selectedRiskTypes = {};
  bool _isLoading = true;
  bool _isAutoUpdateEnabled = true;
  DateTime _lastUpdated = DateTime.now();
  Timer? _refreshTimer;

  NewsProvider() {
    _initializeData();
    _startAutoRefresh();
  }

  // Getters
  List<Article> get articles => _articles;
  NewsFeedTab get currentTab => _currentTab;
  String get searchQuery => _searchQuery;
  Set<Priority> get selectedPriorities => _selectedPriorities;
  Set<NewsCategory> get selectedCategories => _selectedCategories;
  Set<String> get selectedRiskTypes => _selectedRiskTypes;
  bool get isLoading => _isLoading;
  bool get isAutoUpdateEnabled => _isAutoUpdateEnabled;
  DateTime get lastUpdated => _lastUpdated;

  List<Article> get filteredArticles {
    var filtered = _articles.where((article) {
      // Tab filter
      switch (_currentTab) {
        case NewsFeedTab.education:
          if (article.isNilSports) return false;
          break;
        case NewsFeedTab.nilSports:
          if (!article.isNilSports) return false;
          break;
        case NewsFeedTab.all:
          break;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesHeadline = article.headline.toLowerCase().contains(query);
        final matchesSummary = article.summary.toLowerCase().contains(query);
        final matchesSource = article.sourceName.toLowerCase().contains(query);
        final matchesEntities = article.keyEntities.any(
          (e) => e.toLowerCase().contains(query),
        );
        if (!matchesHeadline && !matchesSummary && !matchesSource && !matchesEntities) {
          return false;
        }
      }

      // Priority filter
      if (_selectedPriorities.isNotEmpty &&
          !_selectedPriorities.contains(article.priority)) {
        return false;
      }

      // Category filter
      if (_selectedCategories.isNotEmpty) {
        final articleCategories = {
          article.primaryCategory,
          ...article.additionalCategories,
        };
        if (!_selectedCategories.any((c) => articleCategories.contains(c))) {
          return false;
        }
      }

      // Risk type filter
      if (_selectedRiskTypes.isNotEmpty &&
          !article.riskTags.any((t) => _selectedRiskTypes.contains(t))) {
        return false;
      }

      return true;
    }).toList();

    // Sort by date (newest first) and priority
    filtered.sort((a, b) {
      // Breaking news first
      if (a.isBreaking != b.isBreaking) {
        return a.isBreaking ? -1 : 1;
      }
      // Then by priority
      if (a.priority != b.priority) {
        return a.priority.index.compareTo(b.priority.index);
      }
      // Then by date
      return b.publishedAt.compareTo(a.publishedAt);
    });

    return filtered;
  }

  int get allNewsCount => _articles.length;

  int get educationCount =>
      _articles.where((a) => !a.isNilSports).length;

  int get nilSportsCount =>
      _articles.where((a) => a.isNilSports).length;

  int get highPriorityCount =>
      filteredArticles.where((a) => a.priority == Priority.high).length;

  int get mediumPriorityCount =>
      filteredArticles.where((a) => a.priority == Priority.medium).length;

  int get lowPriorityCount =>
      filteredArticles.where((a) => a.priority == Priority.low).length;

  int get breakingNewsCount =>
      filteredArticles.where((a) => a.isBreaking).length;

  Set<String> get allRiskTypes {
    final types = <String>{};
    for (final article in _articles) {
      types.addAll(article.riskTags);
    }
    return types;
  }

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedPriorities.isNotEmpty ||
      _selectedCategories.isNotEmpty ||
      _selectedRiskTypes.isNotEmpty;

  void _initializeData() {
    _isLoading = true;
    notifyListeners();

    // Simulate network delay
    Future.delayed(const Duration(milliseconds: 800), () {
      _articles = List.from(sampleArticles);
      _isLoading = false;
      _lastUpdated = DateTime.now();
      notifyListeners();
    });
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    // Tick every 30 seconds to update timeAgo displays and refresh data
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isAutoUpdateEnabled) {
        // Notify listeners so timeAgo recomputes; also refresh lastUpdated
        _lastUpdated = DateTime.now();
        notifyListeners();
      }
    });
  }

  void setCurrentTab(NewsFeedTab tab) {
    _currentTab = tab;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void togglePriority(Priority priority) {
    if (_selectedPriorities.contains(priority)) {
      _selectedPriorities.remove(priority);
    } else {
      _selectedPriorities.add(priority);
    }
    notifyListeners();
  }

  void toggleCategory(NewsCategory category) {
    if (_selectedCategories.contains(category)) {
      _selectedCategories.remove(category);
    } else {
      _selectedCategories.add(category);
    }
    notifyListeners();
  }

  void toggleRiskType(String riskType) {
    if (_selectedRiskTypes.contains(riskType)) {
      _selectedRiskTypes.remove(riskType);
    } else {
      _selectedRiskTypes.add(riskType);
    }
    notifyListeners();
  }

  void clearAllFilters() {
    _searchQuery = '';
    _selectedPriorities.clear();
    _selectedCategories.clear();
    _selectedRiskTypes.clear();
    notifyListeners();
  }

  void toggleAutoUpdate() {
    _isAutoUpdateEnabled = !_isAutoUpdateEnabled;
    notifyListeners();
  }

  Future<void> refreshArticles() async {
    _lastUpdated = DateTime.now();
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
