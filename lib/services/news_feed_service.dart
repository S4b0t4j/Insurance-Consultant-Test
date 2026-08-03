import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/article.dart';

class NewsFeedSource {
  final String name;
  final String url;
  final NewsCategory defaultCategory;
  final int sourceTier;
  final bool isPublicSafetySource;

  const NewsFeedSource({
    required this.name,
    required this.url,
    required this.defaultCategory,
    this.sourceTier = 2,
    this.isPublicSafetySource = false,
  });
}

class NewsFeedService {
  static const String _corsProxy = 'https://api.allorigins.win/raw?url=';

  static const List<NewsFeedSource> _generalFeeds = [
    NewsFeedSource(
      name: 'Government Executive',
      url: 'https://www.govexec.com/rss/all/',
      defaultCategory: NewsCategory.federalPolicy,
      sourceTier: 1,
    ),
    NewsFeedSource(
      name: 'Route Fifty',
      url: 'https://www.route-fifty.com/rss/all/',
      defaultCategory: NewsCategory.stateLocal,
      sourceTier: 1,
    ),
    NewsFeedSource(
      name: 'StateScoop',
      url: 'https://statescoop.com/feed/',
      defaultCategory: NewsCategory.govTech,
      sourceTier: 1,
    ),
    NewsFeedSource(
      name: 'Google News - State & Local Government',
      url: 'https://news.google.com/rss/search?q=state+local+government+policy&hl=en-US&gl=US&ceid=US:en',
      defaultCategory: NewsCategory.stateLocal,
      sourceTier: 2,
    ),
    NewsFeedSource(
      name: 'Google News - Federal Grants & Funding',
      url: 'https://news.google.com/rss/search?q=federal+grant+funding+municipality+county&hl=en-US&gl=US&ceid=US:en',
      defaultCategory: NewsCategory.grantsFunding,
      sourceTier: 2,
    ),
    NewsFeedSource(
      name: 'Google News - Public Sector Compliance',
      url: 'https://news.google.com/rss/search?q=government+regulatory+compliance+audit&hl=en-US&gl=US&ceid=US:en',
      defaultCategory: NewsCategory.regulatoryCompliance,
      sourceTier: 2,
    ),
    NewsFeedSource(
      name: 'Google News - Public Health Agencies',
      url: 'https://news.google.com/rss/search?q=public+health+department+county+state&hl=en-US&gl=US&ceid=US:en',
      defaultCategory: NewsCategory.publicHealth,
      sourceTier: 2,
    ),
    NewsFeedSource(
      name: 'Google News - Public Workforce & Labor',
      url: 'https://news.google.com/rss/search?q=public+sector+union+workforce+pension&hl=en-US&gl=US&ceid=US:en',
      defaultCategory: NewsCategory.workforceLabor,
      sourceTier: 2,
    ),
  ];

  static const List<NewsFeedSource> _publicSafetyFeeds = [
    NewsFeedSource(
      name: 'Google News - Emergency Management',
      url: 'https://news.google.com/rss/search?q=emergency+management+FEMA+disaster+declaration&hl=en-US&gl=US&ceid=US:en',
      defaultCategory: NewsCategory.publicSafety,
      sourceTier: 1,
      isPublicSafetySource: true,
    ),
    NewsFeedSource(
      name: 'Google News - Municipal Cybersecurity',
      url: 'https://news.google.com/rss/search?q=ransomware+city+county+government+cyberattack&hl=en-US&gl=US&ceid=US:en',
      defaultCategory: NewsCategory.publicSafety,
      sourceTier: 1,
      isPublicSafetySource: true,
    ),
    NewsFeedSource(
      name: 'Google News - Police & Fire Liability',
      url: 'https://news.google.com/rss/search?q=police+fire+department+liability+settlement&hl=en-US&gl=US&ceid=US:en',
      defaultCategory: NewsCategory.publicSafety,
      sourceTier: 2,
      isPublicSafetySource: true,
    ),
    NewsFeedSource(
      name: 'Google News - Critical Infrastructure',
      url: 'https://news.google.com/rss/search?q=critical+infrastructure+water+grid+security&hl=en-US&gl=US&ceid=US:en',
      defaultCategory: NewsCategory.publicSafety,
      sourceTier: 2,
      isPublicSafetySource: true,
    ),
  ];

  static List<NewsFeedSource> get allFeeds => [..._generalFeeds, ..._publicSafetyFeeds];
  static List<NewsFeedSource> get generalFeeds => _generalFeeds;
  static List<NewsFeedSource> get publicSafetyFeeds => _publicSafetyFeeds;

  Future<List<Article>> fetchAllFeeds() async {
    final allArticles = <Article>[];
    final seenUrls = <String>{};

    for (final feed in allFeeds) {
      try {
        final articles = await fetchFeed(feed);
        for (final article in articles) {
          if (!seenUrls.contains(article.sourceUrl)) {
            seenUrls.add(article.sourceUrl);
            allArticles.add(article);
          }
        }
      } catch (e) {
        print('Error fetching ${feed.name}: $e');
      }
    }

    allArticles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return allArticles;
  }

  Future<List<Article>> fetchGeneralFeeds() async {
    final allArticles = <Article>[];
    final seenUrls = <String>{};

    for (final feed in generalFeeds) {
      try {
        final articles = await fetchFeed(feed);
        for (final article in articles) {
          if (!seenUrls.contains(article.sourceUrl)) {
            seenUrls.add(article.sourceUrl);
            allArticles.add(article);
          }
        }
      } catch (e) {
        print('Error fetching ${feed.name}: $e');
      }
    }

    allArticles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return allArticles;
  }

  Future<List<Article>> fetchPublicSafetyFeeds() async {
    final allArticles = <Article>[];
    final seenUrls = <String>{};

    for (final feed in publicSafetyFeeds) {
      try {
        final articles = await fetchFeed(feed);
        for (final article in articles) {
          if (!seenUrls.contains(article.sourceUrl)) {
            seenUrls.add(article.sourceUrl);
            allArticles.add(article);
          }
        }
      } catch (e) {
        print('Error fetching ${feed.name}: $e');
      }
    }

    allArticles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return allArticles;
  }

  Future<List<Article>> fetchFeed(NewsFeedSource source) async {
    final articles = <Article>[];

    try {
      final encodedUrl = Uri.encodeComponent(source.url);
      final response = await http.get(
        Uri.parse('$_corsProxy$encodedUrl'),
        headers: {'Accept': 'application/rss+xml, application/xml, text/xml'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final document = XmlDocument.parse(response.body);
      final items = document.findAllElements('item');

      int index = 0;
      for (final item in items.take(15)) {
        try {
          final article = _parseRssItem(item, source, index);
          if (article != null) {
            articles.add(article);
            index++;
          }
        } catch (e) {
          print('Error parsing item: $e');
        }
      }
    } catch (e) {
      print('Error fetching feed ${source.name}: $e');
      rethrow;
    }

    return articles;
  }

  Article? _parseRssItem(XmlElement item, NewsFeedSource source, int index) {
    final title = item.findElements('title').firstOrNull?.innerText.trim();
    final link = item.findElements('link').firstOrNull?.innerText.trim();
    final description = item.findElements('description').firstOrNull?.innerText.trim();
    final pubDateStr = item.findElements('pubDate').firstOrNull?.innerText.trim();

    if (title == null || title.isEmpty) return null;

    final cleanDescription = _cleanHtml(description ?? '');
    final pubDate = _parseDate(pubDateStr) ?? DateTime.now();
    final extractedSource = _extractSourceName(item, source.name);

    final category = _categorizeArticle(title, cleanDescription, source);
    final priority = _determinePriority(title, cleanDescription, pubDate);
    final riskTags = _extractRiskTags(title, cleanDescription);
    final keyEntities = _extractEntities(title, cleanDescription);
    final isBreaking = _isBreakingNews(title, pubDate);

    return Article(
      id: '${source.name.hashCode}_${link.hashCode}_$index',
      headline: title,
      summary: cleanDescription.isNotEmpty
          ? cleanDescription
          : 'Read the full article for more details.',
      sourceName: extractedSource,
      sourceUrl: link ?? '',
      publishedAt: pubDate,
      primaryCategory: category,
      additionalCategories: _getAdditionalCategories(title, cleanDescription, source),
      priority: priority,
      riskTags: riskTags,
      riskAnalysis: _generateRiskAnalysis(title, cleanDescription, category),
      businessOpportunity: _identifyOpportunity(title, cleanDescription, category),
      keyEntities: keyEntities,
      entitiesAffected: _extractEntities(title, cleanDescription),
      jurisdictionsAffected: _extractJurisdictions(title, cleanDescription),
      geographicScope: _determineScope(title, cleanDescription),
      sourceTier: source.sourceTier,
      isBreaking: isBreaking,
    );
  }

  String _cleanHtml(String html) {
    var text = html;
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > 500) {
      text = '${text.substring(0, 497)}...';
    }
    return text;
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null) return null;

    try {
      return DateTime.parse(dateStr);
    } catch (_) {}

    final rfc822Pattern = RegExp(
      r'(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})',
    );
    final match = rfc822Pattern.firstMatch(dateStr);
    if (match != null) {
      final months = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
        'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
      };
      final day = int.parse(match.group(1)!);
      final month = months[match.group(2)] ?? 1;
      final year = int.parse(match.group(3)!);
      final hour = int.parse(match.group(4)!);
      final minute = int.parse(match.group(5)!);
      final second = int.parse(match.group(6)!);
      return DateTime.utc(year, month, day, hour, minute, second);
    }

    return null;
  }

  String _extractSourceName(XmlElement item, String defaultSource) {
    final source = item.findElements('source').firstOrNull?.innerText.trim();
    if (source != null && source.isNotEmpty) return source;

    final dcCreator = item.findElements('dc:creator').firstOrNull?.innerText.trim();
    if (dcCreator != null && dcCreator.isNotEmpty) return dcCreator;

    return defaultSource;
  }

  NewsCategory _categorizeArticle(String title, String description, NewsFeedSource source) {
    final text = '$title $description'.toLowerCase();

    if (text.contains('ransomware') || text.contains('cyberattack') ||
        text.contains('data breach') || text.contains('critical infrastructure')) {
      return NewsCategory.publicSafety;
    }
    if (text.contains('emergency management') || text.contains('fema') ||
        text.contains('disaster declaration') || text.contains('first responder') ||
        text.contains('police department') || text.contains('fire department')) {
      return NewsCategory.publicSafety;
    }
    if (text.contains('audit') || text.contains('compliance') ||
        text.contains('open records') || text.contains('procurement rule')) {
      return NewsCategory.regulatoryCompliance;
    }
    if (text.contains('congress') || text.contains('white house') ||
        text.contains('federal agency') || text.contains('executive order')) {
      return NewsCategory.federalPolicy;
    }
    if (text.contains('grant') || text.contains('appropriation') ||
        text.contains('bond measure') || text.contains('budget shortfall')) {
      return NewsCategory.grantsFunding;
    }
    if (text.contains('govtech') || text.contains('digital services') ||
        text.contains('legacy system') || text.contains('cloud migration')) {
      return NewsCategory.govTech;
    }
    if (text.contains('union') || text.contains('collective bargaining') ||
        text.contains('pension') || text.contains('public employee')) {
      return NewsCategory.workforceLabor;
    }
    if (text.contains('public health') || text.contains('health department') ||
        text.contains('outbreak')) {
      return NewsCategory.publicHealth;
    }
    if (text.contains('city council') || text.contains('county board') ||
        text.contains('governor') || text.contains('state legislature') ||
        text.contains('municipal')) {
      return NewsCategory.stateLocal;
    }

    return source.defaultCategory;
  }

  List<NewsCategory> _getAdditionalCategories(String title, String description, NewsFeedSource source) {
    final categories = <NewsCategory>[];
    final text = '$title $description'.toLowerCase();

    if (text.contains('compliance') || text.contains('regulation')) {
      categories.add(NewsCategory.regulatoryCompliance);
    }
    if (text.contains('city') || text.contains('county') ||
        text.contains('state agency') || text.contains('municipal')) {
      categories.add(NewsCategory.stateLocal);
    }
    if (text.contains('employee') || text.contains('worker') ||
        text.contains('nlrb')) {
      categories.add(NewsCategory.workforceLabor);
    }

    return categories.take(2).toList();
  }

  Priority _determinePriority(String title, String description, DateTime pubDate) {
    final text = '$title $description'.toLowerCase();
    final hoursSincePublished = DateTime.now().difference(pubDate).inHours;

    if (text.contains('breaking') || text.contains('urgent') ||
        text.contains('just in') || text.contains('alert')) {
      return Priority.high;
    }
    if (text.contains('settlement') || text.contains('lawsuit') ||
        text.contains('ruling') || text.contains('supreme court') ||
        text.contains('billion') || text.contains('million')) {
      return Priority.high;
    }
    if (text.contains('consent decree') || text.contains('federal monitor') ||
        text.contains('investigation') || text.contains('scandal')) {
      return Priority.high;
    }
    if (hoursSincePublished < 6) {
      return Priority.high;
    }
    if (hoursSincePublished < 24) {
      return Priority.medium;
    }

    return Priority.low;
  }

  List<String> _extractRiskTags(String title, String description) {
    final tags = <String>[];
    final text = '$title $description'.toLowerCase();

    final riskKeywords = {
      'Compliance Risk': ['compliance', 'regulation', 'policy', 'rule'],
      'Legal Liability': ['lawsuit', 'litigation', 'court', 'legal'],
      'Financial Risk': ['budget', 'funding', 'revenue', 'cost'],
      'Cyber Risk': ['ransomware', 'cyberattack', 'data breach', 'phishing'],
      'Civil Rights': ['discrimination', 'civil rights', 'consent decree'],
      'Labor Relations': ['union', 'collective bargaining', 'pension', 'employee'],
      'Reputational Risk': ['scandal', 'investigation', 'misconduct'],
      'Policy Change': ['new regulation', 'amendment', 'reform'],
      'Contract Risk': ['contract', 'deal', 'agreement'],
      'Procurement Risk': ['procurement', 'bid protest', 'sole source'],
      'Infrastructure Risk': ['bridge', 'water system', 'power grid', 'transit'],
    };

    for (final entry in riskKeywords.entries) {
      if (entry.value.any((keyword) => text.contains(keyword))) {
        tags.add(entry.key);
      }
    }

    return tags.take(4).toList();
  }

  /// Named bodies mentioned in the story — agencies, regulators, courts.
  List<String> _extractEntities(String title, String description) {
    final entities = <String>[];
    final text = '$title $description';

    const knownEntities = [
      'FEMA', 'GSA', 'DHS', 'CISA', 'HUD', 'DOT', 'EPA', 'GAO', 'OMB',
      'CMS', 'CDC', 'HHS', 'DOJ', 'NIST', 'Supreme Court', 'Congress',
      'Federal Reserve', 'Treasury', 'National Guard',
    ];

    for (final entity in knownEntities) {
      if (text.contains(entity)) entities.add(entity);
    }

    // "City of Austin", "Cook County", "Texas Department of ...", agencies.
    final bodyPattern = RegExp(
      r'(City of \w+|County of \w+|\w+ County|\w+ Department of [\w ]{3,30}|'
      r'\w+ Municipal \w+|State of \w+)',
    );
    for (final match in bodyPattern.allMatches(text)) {
      entities.add(match.group(0)!.trim());
    }

    return entities.toSet().take(5).toList();
  }

  /// Where the story applies — states, counties, cities.
  List<String> _extractJurisdictions(String title, String description) {
    final text = '$title $description';
    final jurisdictions = <String>[];

    final pattern = RegExp(
      r'(City of \w+|\w+ County|State of \w+|\w+ Metro(?:politan)? Area)',
    );
    for (final match in pattern.allMatches(text)) {
      jurisdictions.add(match.group(0)!.trim());
    }

    return jurisdictions.toSet().take(3).toList();
  }

  String _determineScope(String title, String description) {
    final text = '$title $description'.toLowerCase();

    if (text.contains('nationwide') || text.contains('national') ||
        text.contains('federal') || text.contains('all states')) {
      return 'National';
    }
    if (text.contains('county') || text.contains('regional') ||
        text.contains('metro') || text.contains('statewide')) {
      return 'Regional';
    }

    return 'National';
  }

  bool _isBreakingNews(String title, DateTime pubDate) {
    final hoursSincePublished = DateTime.now().difference(pubDate).inHours;
    final titleLower = title.toLowerCase();

    return (hoursSincePublished < 3 &&
            (titleLower.contains('breaking') ||
             titleLower.contains('just in') ||
             titleLower.contains('alert'))) ||
           hoursSincePublished < 1;
  }

  String _generateRiskAnalysis(String title, String description, NewsCategory category) {
    final text = '$title $description'.toLowerCase();

    if (text.contains('ransomware') || text.contains('cyberattack') ||
        text.contains('data breach')) {
      return 'Cyber incident affecting a public entity. Review network segmentation, '
             'incident response readiness and cyber coverage limits across comparable '
             'agencies in the portfolio.';
    }
    if (category == NewsCategory.publicSafety) {
      return 'Public safety development with potential liability and continuity of '
             'operations exposure. Assess emergency response obligations and mutual aid '
             'agreements.';
    }
    if (text.contains('lawsuit') || text.contains('settlement') ||
        text.contains('consent decree')) {
      return 'Legal development may set precedent affecting public entity liability. '
             'Review current coverage, sovereign immunity posture and reserves.';
    }
    if (text.contains('grant') || text.contains('appropriation') ||
        text.contains('budget')) {
      return 'Funding change may affect programme continuity and compliance obligations '
             'attached to the award. Track eligibility and reporting deadlines.';
    }
    if (category == NewsCategory.federalPolicy) {
      return 'Federal policy change may alter compliance requirements or funding '
             'eligibility for state and local recipients. Track implementation timelines.';
    }

    return 'Monitor for impacts on agency operations, compliance obligations or risk '
           'exposure. Assess relevance to the entity portfolio.';
  }

  String? _identifyOpportunity(String title, String description, NewsCategory category) {
    final text = '$title $description'.toLowerCase();

    if (text.contains('ransomware') || text.contains('cyberattack') ||
        text.contains('data breach')) {
      return 'Cyber risk assessment and coverage review for agencies with comparable '
             'infrastructure and threat exposure.';
    }
    if (text.contains('compliance') || text.contains('audit') ||
        text.contains('regulation')) {
      return 'Compliance advisory engagement to help agencies meet new requirements '
             'and reduce audit findings.';
    }
    if (text.contains('grant') || text.contains('appropriation')) {
      return 'Grant compliance and programme risk support for recipients managing new '
             'award conditions.';
    }
    if (category == NewsCategory.publicSafety) {
      return 'Emergency preparedness and continuity of operations consulting for '
             'agencies reassessing response capability.';
    }

    return null;
  }
}