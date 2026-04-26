import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/article.dart';

class NewsFeedSource {
  final String name;
  final String url;
  final NewsCategory defaultCategory;
  final int sourceTier;
  final bool isNilSource;

  const NewsFeedSource({
    required this.name,
    required this.url,
    required this.defaultCategory,
    this.sourceTier = 2,
    this.isNilSource = false,
  });
}

class NewsFeedService {
  static const String _corsProxy = 'https://api.allorigins.win/raw?url=';

  static const List<NewsFeedSource> _educationFeeds = [
    NewsFeedSource(
      name: 'Inside Higher Ed',
      url: 'https://www.insidehighered.com/rss.xml',
      defaultCategory: NewsCategory.higherEducation,
      sourceTier: 1,
    ),
    NewsFeedSource(
      name: 'Education Week',
      url: 'https://www.edweek.org/feed',
      defaultCategory: NewsCategory.federalDoe,
      sourceTier: 1,
    ),
    NewsFeedSource(
      name: 'Chronicle of Higher Ed',
      url: 'https://www.chronicle.com/feed',
      defaultCategory: NewsCategory.higherEducation,
      sourceTier: 1,
    ),
    NewsFeedSource(
      name: 'Google News - Higher Education',
      url: 'https://news.google.com/rss/search?q=higher+education+college+university&hl=en-US&gl=US&ceid=US:en',
      defaultCategory: NewsCategory.higherEducation,
      sourceTier: 2,
    ),
    NewsFeedSource(
      name: 'Google News - Title IX',
      url: 'https://news.google.com/rss/search?q=Title+IX+education&hl=en-US&gl=US&ceid=US:en',
      defaultCategory: NewsCategory.regulatoryCompliance,
      sourceTier: 2,
    ),
    NewsFeedSource(
      name: 'Google News - Department of Education',
      url: 'https://news.google.com/rss/search?q=Department+of+Education+federal&hl=en-US&gl=US&ceid=US:en',
      defaultCategory: NewsCategory.federalDoe,
      sourceTier: 2,
    ),
  ];

  static const List<NewsFeedSource> _nilSportsFeeds = [
    NewsFeedSource(
      name: 'Google News - NIL College Sports',
      url: 'https://news.google.com/rss/search?q=NIL+college+athletes+name+image+likeness&hl=en-US&gl=US&ceid=US:en',
      defaultCategory: NewsCategory.sportsNil,
      sourceTier: 1,
      isNilSource: true,
    ),
    NewsFeedSource(
      name: 'Google News - NCAA',
      url: 'https://news.google.com/rss/search?q=NCAA+college+sports&hl=en-US&gl=US&ceid=US:en',
      defaultCategory: NewsCategory.sportsNil,
      sourceTier: 1,
      isNilSource: true,
    ),
    NewsFeedSource(
      name: 'Google News - Transfer Portal',
      url: 'https://news.google.com/rss/search?q=college+football+transfer+portal&hl=en-US&gl=US&ceid=US:en',
      defaultCategory: NewsCategory.sportsNil,
      sourceTier: 2,
      isNilSource: true,
    ),
    NewsFeedSource(
      name: 'Google News - College Football',
      url: 'https://news.google.com/rss/search?q=college+football+news&hl=en-US&gl=US&ceid=US:en',
      defaultCategory: NewsCategory.sportsNil,
      sourceTier: 2,
      isNilSource: true,
    ),
  ];

  static List<NewsFeedSource> get allFeeds => [..._educationFeeds, ..._nilSportsFeeds];
  static List<NewsFeedSource> get educationFeeds => _educationFeeds;
  static List<NewsFeedSource> get nilSportsFeeds => _nilSportsFeeds;

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

  Future<List<Article>> fetchEducationFeeds() async {
    final allArticles = <Article>[];
    final seenUrls = <String>{};

    for (final feed in educationFeeds) {
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

  Future<List<Article>> fetchNilSportsFeeds() async {
    final allArticles = <Article>[];
    final seenUrls = <String>{};

    for (final feed in nilSportsFeeds) {
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
      institutionsAffected: _extractInstitutions(title, cleanDescription),
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

    if (text.contains('nil') || text.contains('name, image') ||
        text.contains('name image likeness') || text.contains('collective')) {
      return NewsCategory.sportsNil;
    }
    if (text.contains('transfer portal') || text.contains('ncaa') ||
        text.contains('college football') || text.contains('college basketball')) {
      return NewsCategory.sportsNil;
    }
    if (text.contains('title ix') || text.contains('title 9') ||
        text.contains('discrimination')) {
      return NewsCategory.regulatoryCompliance;
    }
    if (text.contains('department of education') || text.contains('doe') ||
        text.contains('federal') || text.contains('betsy devos') ||
        text.contains('secretary of education')) {
      return NewsCategory.federalDoe;
    }
    if (text.contains('fafsa') || text.contains('financial aid') ||
        text.contains('student loan') || text.contains('pell grant')) {
      return NewsCategory.financialAid;
    }
    if (text.contains('edtech') || text.contains('online learning') ||
        text.contains('digital learning') || text.contains('ai in education')) {
      return NewsCategory.edTech;
    }
    if (text.contains('faculty') || text.contains('professor') ||
        text.contains('union') || text.contains('labor')) {
      return NewsCategory.workforceLabor;
    }
    if (text.contains('health') || text.contains('mental health') ||
        text.contains('campus safety')) {
      return NewsCategory.healthcareEducation;
    }

    return source.defaultCategory;
  }

  List<NewsCategory> _getAdditionalCategories(String title, String description, NewsFeedSource source) {
    final categories = <NewsCategory>[];
    final text = '$title $description'.toLowerCase();

    if (text.contains('compliance') || text.contains('regulation')) {
      categories.add(NewsCategory.regulatoryCompliance);
    }
    if (text.contains('university') || text.contains('college') ||
        text.contains('campus')) {
      categories.add(NewsCategory.higherEducation);
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
    if (text.contains('nlrb') || text.contains('title ix') ||
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
      'NIL Compliance': ['nil', 'name image likeness', 'collective'],
      'Title IX': ['title ix', 'discrimination', 'gender'],
      'Labor Relations': ['union', 'nlrb', 'employee', 'worker'],
      'Reputational Risk': ['scandal', 'investigation', 'misconduct'],
      'Policy Change': ['new regulation', 'amendment', 'reform'],
      'Contract Risk': ['contract', 'deal', 'agreement'],
      'Revenue Sharing': ['revenue sharing', 'compensation', 'payment'],
    };

    for (final entry in riskKeywords.entries) {
      if (entry.value.any((keyword) => text.contains(keyword))) {
        tags.add(entry.key);
      }
    }

    return tags.take(4).toList();
  }

  List<String> _extractEntities(String title, String description) {
    final entities = <String>[];
    final text = '$title $description';

    final knownEntities = [
      'NCAA', 'NLRB', 'Department of Education', 'DOE', 'OCR',
      'Supreme Court', 'Congress', 'Title IX', 'FAFSA',
      'Big Ten', 'SEC', 'ACC', 'Big 12', 'Pac-12', 'Ivy League',
    ];

    for (final entity in knownEntities) {
      if (text.contains(entity)) {
        entities.add(entity);
      }
    }

    final universityPattern = RegExp(r'(University of \w+|\w+ University|\w+ College)');
    for (final match in universityPattern.allMatches(text)) {
      entities.add(match.group(0)!);
    }

    return entities.take(5).toList();
  }

  List<String> _extractInstitutions(String title, String description) {
    final institutions = <String>[];
    final text = '$title $description';

    final universityPattern = RegExp(r'(University of \w+|\w+ University|\w+ College|[A-Z]{2,4} (?:State|Tech))');
    for (final match in universityPattern.allMatches(text)) {
      institutions.add(match.group(0)!);
    }

    return institutions.take(3).toList();
  }

  String _determineScope(String title, String description) {
    final text = '$title $description'.toLowerCase();

    if (text.contains('nationwide') || text.contains('national') ||
        text.contains('federal') || text.contains('all states')) {
      return 'National';
    }
    if (text.contains('conference') || text.contains('regional')) {
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

    if (text.contains('nil') || category == NewsCategory.sportsNil) {
      return 'NIL-related development requires monitoring for compliance implications, '
             'contract structure risks, and potential impacts on athletic program budgets.';
    }
    if (text.contains('title ix') || text.contains('discrimination')) {
      return 'Title IX developments may require policy reviews, training updates, and '
             'assessment of institutional compliance procedures. Monitor for enforcement guidance.';
    }
    if (text.contains('lawsuit') || text.contains('settlement')) {
      return 'Legal developments may set precedents affecting institutional liability exposure. '
             'Review current coverage and risk mitigation strategies.';
    }
    if (text.contains('federal') || text.contains('department of education')) {
      return 'Federal policy changes may impact compliance requirements, funding eligibility, '
             'or institutional obligations. Track implementation timelines.';
    }

    return 'Monitor this development for potential impacts on institutional operations, '
           'compliance requirements, or risk exposure. Assess relevance to client portfolio.';
  }

  String? _identifyOpportunity(String title, String description, NewsCategory category) {
    final text = '$title $description'.toLowerCase();

    if (text.contains('nil') || category == NewsCategory.sportsNil) {
      return 'Opportunity to develop NIL-specific coverage products or consulting services '
             'for institutions and collectives navigating the evolving landscape.';
    }
    if (text.contains('compliance') || text.contains('regulation')) {
      return 'Potential for compliance consulting engagement to help institutions '
             'navigate new requirements and mitigate regulatory risk.';
    }
    if (text.contains('cybersecurity') || text.contains('data')) {
      return 'Cyber insurance and risk assessment services opportunity for institutions '
             'addressing data protection requirements.';
    }

    return null;
  }
}
