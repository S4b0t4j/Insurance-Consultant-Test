enum SourceKind { docx, txt, pdf, rss }

/// A piece of supporting material fed to the AI: an uploaded document or a
/// batch of live news items from an RSS topic.
class ReportSource {
  final String name;
  final SourceKind kind;
  final String extractedText;
  final DateTime addedAt;

  ReportSource({
    required this.name,
    required this.kind,
    required this.extractedText,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  int get charCount => extractedText.length;
}

/// A Google News RSS query used to pull live headlines for a topic.
class RssTopic {
  final String label;
  final String query;
  final bool builtIn;

  const RssTopic({required this.label, required this.query, this.builtIn = true});

  String get feedUrl =>
      'https://news.google.com/rss/search?q=${Uri.encodeComponent(query)}&hl=en-US&gl=US&ceid=US:en';

  static const List<RssTopic> defaults = [
    RssTopic(label: 'Public entity risk', query: 'public sector risk management insurance'),
    RssTopic(label: 'Cyber threats', query: 'cyberattack ransomware government schools hospital'),
    RssTopic(label: 'Geopolitical', query: 'geopolitical risk supply chain disruption'),
    RssTopic(label: 'Economy & budgets', query: 'federal budget deficit inflation public agencies'),
    RssTopic(label: 'Catastrophe & property', query: 'catastrophe property insurance losses storm'),
    RssTopic(label: 'Insurance market', query: 'commercial insurance market renewal rates capacity'),
  ];
}

/// One news item parsed from an RSS feed.
class RssNewsItem {
  final String title;
  final String snippet;
  final String source;
  final String link;
  final DateTime? published;

  const RssNewsItem({
    required this.title,
    required this.snippet,
    required this.source,
    required this.link,
    this.published,
  });
}
