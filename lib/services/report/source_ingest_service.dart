import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../../models/report_source.dart';
import 'file_saver.dart' as saver;
import 'ooxml_reader.dart';

class SourceIngestException implements Exception {
  final String message;
  SourceIngestException(this.message);
  @override
  String toString() => 'SourceIngestException: $message';
}

/// Extracts text from uploaded supporting documents and pulls live news
/// items from Google News RSS topics (via CORS proxies, matching the
/// pattern proven in NewsFeedService).
class SourceIngestService {
  static const List<String> _corsProxies = [
    'https://api.allorigins.win/raw?url=',
    'https://corsproxy.io/?url=',
  ];

  /// Text extraction dispatch by file extension.
  Future<ReportSource> extractFromUpload(String name, Uint8List bytes) async {
    final lower = name.toLowerCase();
    if (lower.endsWith('.txt') || lower.endsWith('.md')) {
      return ReportSource(
        name: name,
        kind: SourceKind.txt,
        extractedText: utf8.decode(bytes, allowMalformed: true),
      );
    }
    if (lower.endsWith('.docx')) {
      final template = OoxmlReader.parse(name, bytes);
      final text = template.slides
          .expand((s) => s.allParagraphs)
          .map((p) => p.mergedText)
          .join('\n');
      return ReportSource(
          name: name, kind: SourceKind.docx, extractedText: text);
    }
    if (lower.endsWith('.pptx')) {
      final template = OoxmlReader.parse(name, bytes);
      final text = template.slides
          .map((s) =>
              'Slide ${s.index}:\n${s.allParagraphs.map((p) => p.mergedText).join('\n')}')
          .join('\n\n');
      return ReportSource(
          name: name, kind: SourceKind.docx, extractedText: text);
    }
    if (lower.endsWith('.pdf')) {
      final text = await saver.extractPdfText(bytes);
      if (text.trim().isEmpty) {
        throw SourceIngestException(
            '"$name" has no extractable text layer (scanned/image-only PDF).');
      }
      return ReportSource(
          name: name, kind: SourceKind.pdf, extractedText: text);
    }
    throw SourceIngestException(
        'Unsupported source type for "$name". Upload .pdf, .docx, .pptx, .txt or .md.');
  }

  /// Fetches an RSS topic and returns parsed items, trying each CORS proxy
  /// in turn.
  Future<List<RssNewsItem>> fetchTopic(RssTopic topic,
      {int maxItems = 12}) async {
    Object? lastError;
    for (final proxy in _corsProxies) {
      try {
        final url =
            Uri.parse('$proxy${Uri.encodeComponent(topic.feedUrl)}');
        final response =
            await http.get(url).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          lastError = 'HTTP ${response.statusCode}';
          continue;
        }
        return _parseRss(response.body, maxItems);
      } catch (e) {
        lastError = e;
      }
    }
    throw SourceIngestException(
        'Could not fetch "${topic.label}" feed: $lastError');
  }

  List<RssNewsItem> _parseRss(String body, int maxItems) {
    final doc = XmlDocument.parse(body);
    final items = <RssNewsItem>[];
    for (final item in doc.findAllElements('item')) {
      if (items.length >= maxItems) break;
      final title = item.findElements('title').firstOrNull?.innerText ?? '';
      if (title.trim().isEmpty) continue;
      final description =
          item.findElements('description').firstOrNull?.innerText ?? '';
      final source = item.findElements('source').firstOrNull?.innerText ?? '';
      final link = item.findElements('link').firstOrNull?.innerText ?? '';
      final pubDate =
          item.findElements('pubDate').firstOrNull?.innerText ?? '';
      items.add(RssNewsItem(
        title: _cleanHtml(title),
        snippet: _cleanHtml(description),
        source: source.isEmpty ? 'Google News' : source,
        link: link,
        published: _parseRfc822(pubDate),
      ));
    }
    return items;
  }

  /// Converts fetched news items into a ReportSource the AI can digest.
  static ReportSource toSource(RssTopic topic, List<RssNewsItem> items) {
    final buf = StringBuffer('Live news for topic "${topic.label}" '
        '(query: ${topic.query}), fetched ${DateTime.now().toIso8601String()}:\n');
    for (final n in items) {
      final date = n.published != null
          ? '${n.published!.year}-${n.published!.month.toString().padLeft(2, '0')}-${n.published!.day.toString().padLeft(2, '0')}'
          : '';
      buf.writeln('- [$date] [${n.source}] ${n.title}');
      if (n.snippet.isNotEmpty && n.snippet != n.title) {
        buf.writeln('  ${n.snippet}');
      }
    }
    return ReportSource(
      name: 'News: ${topic.label}',
      kind: SourceKind.rss,
      extractedText: buf.toString(),
    );
  }

  String _cleanHtml(String input) => input
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();

  static const _months = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };

  DateTime? _parseRfc822(String input) {
    final m = RegExp(r'(\d{1,2}) (\w{3}) (\d{4})').firstMatch(input);
    if (m == null) return null;
    final month = _months[m.group(2)];
    if (month == null) return null;
    return DateTime(
        int.parse(m.group(3)!), month, int.parse(m.group(1)!));
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
