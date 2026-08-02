import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../models/report_job.dart';
import '../../models/report_template.dart';
import 'ooxml_parts.dart';

/// Rebuild-mode Word generator: renders the same planned slides as a themed
/// report document (title page, headings, body text, tables).
class DocxBuilder {
  final ExtractedTheme theme;

  DocxBuilder(this.theme);

  Uint8List build(String title, List<PlannedSlide> plan) {
    final body = StringBuffer();
    for (final slide in plan) {
      _renderSection(body, slide);
    }

    final document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>$body'
        '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/>'
        '<w:pgMar w:top="1080" w:right="1080" w:bottom="1080" w:left="1080"/></w:sectPr>'
        '</w:body></w:document>';

    final archive = Archive();
    void add(String path, String content) {
      archive.addFile(
          ArchiveFile.bytes(path, Uint8List.fromList(utf8.encode(content))));
    }

    add('[Content_Types].xml', OoxmlParts.contentTypesDocx);
    add('_rels/.rels', OoxmlParts.rootRelsDocx);
    add('docProps/core.xml', OoxmlParts.corePropsXml(title));
    add('docProps/app.xml', OoxmlParts.appPropsXml);
    add('word/document.xml', document);
    add('word/_rels/document.xml.rels', OoxmlParts.documentRels);
    add('word/styles.xml', OoxmlParts.stylesXml(theme));

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  void _renderSection(StringBuffer b, PlannedSlide slide) {
    final f = slide.fields;
    switch (slide.archetype) {
      case SlideArchetype.cover:
        b.write(_styled('Title', _s(f['title'])));
        b.write(_para(_s(f['subtitle']), size: 28, color: theme.accent1));
        b.write(_para(_s(f['date']), size: 24, color: '595959'));
        b.write(_pageBreak());
      case SlideArchetype.agenda:
        b.write(_styled('Heading1', 'Contents'));
        final items = _list(f['items']);
        for (var i = 0; i < items.length; i++) {
          b.write(_para('${i + 1}.  ${items[i]}'));
        }
      case SlideArchetype.executiveSummary:
        b.write(_styled('Heading1', _s(f['heading'], 'Executive Summary')));
        for (final row in _maps(f['rows'])) {
          b.write(_styled('Heading2', _s(row['title'])));
          b.write(_para(_s(row['text'])));
        }
      case SlideArchetype.sectionDivider:
        b.write(_pageBreak());
        b.write(_styled('Heading1', _s(f['title'])));
      case SlideArchetype.keyMetrics:
        b.write(_styled('Heading2', _s(f['heading'], 'Key metrics')));
        for (final s in _maps(f['stats'])) {
          b.write(_para('${_s(s['value'])} — ${_s(s['label'])}',
              bold: true, color: theme.primary));
        }
      case SlideArchetype.impactedSectors:
        b.write(_styled('Heading2', _s(f['heading'], 'Impacted sectors')));
        b.write(_para(_s(f['subheading']), color: '595959'));
        for (final row in _maps(f['rows'])) {
          b.write(_para(_s(row['sector']), bold: true, color: theme.primary));
          b.write(_para(_s(row['impact'])));
        }
      case SlideArchetype.newsUpdates:
        b.write(_styled('Heading2', _s(f['heading'], 'News updates')));
        b.write(_para(_s(f['category']), bold: true, color: theme.accent1));
        for (final item in _maps(f['items'])) {
          b.write(_para('${_s(item['date'])}: ${_s(item['headline'])}',
              bold: true));
          b.write(_para(_s(item['body'])));
        }
      case SlideArchetype.capabilitiesTable:
        b.write(_styled('Heading2', _s(f['heading'], 'Capabilities')));
        b.write(_table(_rows(f['rows'])));
      case SlideArchetype.contact:
        b.write(_styled('Heading1', _s(f['heading'], 'Contact')));
        b.write(_para(_s(f['body'])));
        b.write(_para(_s(f['name']), bold: true));
        b.write(_para(_s(f['title'])));
        b.write(_para(_s(f['email']), color: theme.accent1));
        b.write(_para(_s(f['closing']), color: '595959'));
    }
  }

  String _styled(String styleId, String text) {
    if (text.isEmpty) return '';
    return '<w:p><w:pPr><w:pStyle w:val="$styleId"/></w:pPr>'
        '<w:r><w:t xml:space="preserve">${OoxmlParts.escapeXml(text)}</w:t></w:r></w:p>';
  }

  String _para(String text,
      {bool bold = false, int size = 22, String color = '333333'}) {
    if (text.isEmpty) return '';
    return '<w:p><w:r><w:rPr>'
        '${bold ? '<w:b/>' : ''}'
        '<w:color w:val="$color"/><w:sz w:val="$size"/>'
        '</w:rPr><w:t xml:space="preserve">${OoxmlParts.escapeXml(text)}</w:t></w:r></w:p>';
  }

  String _pageBreak() => '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';

  String _table(List<List<String>> rows) {
    if (rows.isEmpty) return '';
    final colCount = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    final b = StringBuffer('<w:tbl><w:tblPr>'
        '<w:tblW w:w="0" w:type="auto"/>'
        '<w:tblBorders>'
        '<w:top w:val="single" w:sz="4" w:color="D9D9D9"/>'
        '<w:bottom w:val="single" w:sz="4" w:color="D9D9D9"/>'
        '<w:insideH w:val="single" w:sz="4" w:color="D9D9D9"/>'
        '</w:tblBorders></w:tblPr>');
    for (var r = 0; r < rows.length; r++) {
      final isHeader = r == 0;
      b.write('<w:tr>');
      for (var c = 0; c < colCount; c++) {
        final text = c < rows[r].length ? rows[r][c] : '';
        b.write('<w:tc><w:tcPr>'
            '${isHeader ? '<w:shd w:val="clear" w:fill="${theme.primary}"/>' : ''}'
            '</w:tcPr>'
            '<w:p><w:r><w:rPr>'
            '${isHeader ? '<w:b/><w:color w:val="FFFFFF"/>' : '<w:color w:val="404040"/>'}'
            '<w:sz w:val="20"/></w:rPr>'
            '<w:t xml:space="preserve">${OoxmlParts.escapeXml(text)}</w:t></w:r></w:p></w:tc>');
      }
      b.write('</w:tr>');
    }
    b.write('</w:tbl>');
    return b.toString();
  }

  static String _s(dynamic v, [String fallback = '']) =>
      (v is String && v.trim().isNotEmpty) ? v : fallback;

  static List<String> _list(dynamic v) =>
      v is List ? v.whereType<String>().toList() : const [];

  static List<Map<String, dynamic>> _maps(dynamic v) =>
      v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

  static List<List<String>> _rows(dynamic v) {
    if (v is! List) return const [];
    return v
        .whereType<List>()
        .map((r) => r.map((c) => c.toString()).toList())
        .toList();
  }
}
