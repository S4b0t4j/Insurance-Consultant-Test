import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../models/report_job.dart';
import '../../models/report_template.dart';
import 'ooxml_parts.dart';

/// Rebuild-mode PowerPoint generator. Renders planned slides from the nine
/// archetypes using the theme extracted from the uploaded template.
/// Text boxes, rectangles, rules and tables only — no images/charts.
class PptxBuilder {
  final ExtractedTheme theme;
  late final int _w;
  late final int _h;
  int _shapeId = 1;

  PptxBuilder(this.theme) {
    _w = theme.slideWidthEmu;
    _h = theme.slideHeightEmu;
  }

  Uint8List build(String title, List<PlannedSlide> plan) {
    final slides = <String>[];
    for (final planned in plan) {
      _shapeId = 1;
      slides.add(_renderSlide(planned));
    }

    final archive = Archive();
    void add(String path, String content) {
      archive.addFile(
          ArchiveFile.bytes(path, Uint8List.fromList(utf8.encode(content))));
    }

    add('[Content_Types].xml', OoxmlParts.contentTypesPptx(slides.length));
    add('_rels/.rels', OoxmlParts.rootRels);
    add('docProps/core.xml', OoxmlParts.corePropsXml(title));
    add('docProps/app.xml', OoxmlParts.appPropsXml);
    add('ppt/presentation.xml',
        OoxmlParts.presentationXml(slides.length, _w, _h));
    add('ppt/_rels/presentation.xml.rels',
        OoxmlParts.presentationRels(slides.length));
    add('ppt/slideMasters/slideMaster1.xml', OoxmlParts.slideMasterXml);
    add('ppt/slideMasters/_rels/slideMaster1.xml.rels',
        OoxmlParts.slideMasterRels);
    add('ppt/slideLayouts/slideLayout1.xml', OoxmlParts.slideLayoutXml);
    add('ppt/slideLayouts/_rels/slideLayout1.xml.rels',
        OoxmlParts.slideLayoutRels);
    add('ppt/theme/theme1.xml', OoxmlParts.themeXml(theme));
    for (var i = 0; i < slides.length; i++) {
      add('ppt/slides/slide${i + 1}.xml', slides[i]);
      add('ppt/slides/_rels/slide${i + 1}.xml.rels', OoxmlParts.slideRels());
    }

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  // ------------------------------------------------------------- geometry

  int x(double frac) => (_w * frac).round();
  int y(double frac) => (_h * frac).round();

  // ------------------------------------------------------------- renderers

  String _renderSlide(PlannedSlide slide) {
    final f = slide.fields;
    String body;
    String? bg;
    switch (slide.archetype) {
      case SlideArchetype.cover:
        bg = theme.primary;
        body = _cover(f);
      case SlideArchetype.agenda:
        body = _agenda(f);
      case SlideArchetype.executiveSummary:
        body = _executiveSummary(f);
      case SlideArchetype.sectionDivider:
        bg = theme.primary;
        body = _sectionDivider(f);
      case SlideArchetype.keyMetrics:
        body = _keyMetrics(f);
      case SlideArchetype.impactedSectors:
        body = _impactedSectors(f);
      case SlideArchetype.newsUpdates:
        body = _newsUpdates(f);
      case SlideArchetype.capabilitiesTable:
        body = _capabilitiesTable(f);
      case SlideArchetype.contact:
        body = _contact(f);
    }
    return _slideXml(body, bg: bg);
  }

  String _cover(Map<String, dynamic> f) {
    final b = StringBuffer();
    b.write(rect(x(0.04), y(0.30), x(0.10), y(0.012), theme.accent2));
    b.write(textBox(x(0.04), y(0.34), x(0.80), y(0.24),
        [TextLine(_s(f['title'], 'Risk Report'), 44, 'FFFFFF', bold: true, heading: true)]));
    b.write(textBox(x(0.04), y(0.60), x(0.70), y(0.10),
        [TextLine(_s(f['subtitle'], ''), 20, theme.accent1)]));
    b.write(textBox(x(0.04), y(0.72), x(0.40), y(0.06),
        [TextLine(_s(f['date'], ''), 16, 'FFFFFF')]));
    return b.toString();
  }

  String _agenda(Map<String, dynamic> f) {
    final items = _list(f['items']);
    final b = StringBuffer();
    b.write(textBox(x(0.04), y(0.05), x(0.60), y(0.12),
        [TextLine('Agenda', 32, theme.primary, bold: true, heading: true)]));
    b.write(rect(x(0.62), 0, x(0.38), _h, theme.primary));
    var yy = 0.24;
    for (var i = 0; i < items.length && i < 10; i++) {
      b.write(textBox(x(0.04), y(yy), x(0.04), y(0.06),
          [TextLine('${i + 1}.', 16, theme.accent2, bold: true)]));
      b.write(textBox(x(0.09), y(yy), x(0.48), y(0.06),
          [TextLine(items[i], 16, '404040')]));
      b.write(rect(x(0.04), y(yy + 0.062), x(0.53), 9525, 'D9D9D9'));
      yy += 0.072;
    }
    return b.toString();
  }

  String _executiveSummary(Map<String, dynamic> f) {
    final rows = _maps(f['rows']);
    final b = StringBuffer();
    b.write(rect(0, 0, x(0.27), _h, theme.primary));
    b.write(textBox(x(0.03), y(0.36), x(0.21), y(0.22),
        [TextLine(_s(f['heading'], 'Executive Summary'), 28, 'FFFFFF', bold: true, heading: true)]));
    var yy = 0.05;
    for (final row in rows.take(6)) {
      b.write(textBox(x(0.30), y(yy), x(0.20), y(0.11),
          [TextLine(_s(row['title'], ''), 15, theme.primary, bold: true)]));
      b.write(textBox(x(0.51), y(yy), x(0.45), y(0.13),
          [TextLine(_s(row['text'], ''), 12, '404040')]));
      yy += 0.155;
    }
    return b.toString();
  }

  String _sectionDivider(Map<String, dynamic> f) {
    final b = StringBuffer();
    b.write(rect(x(0.04), y(0.63), x(0.08), y(0.012), theme.accent2));
    b.write(textBox(x(0.04), y(0.67), x(0.75), y(0.24),
        [TextLine(_s(f['title'], ''), 40, 'FFFFFF', bold: true, heading: true)]));
    return b.toString();
  }

  String _keyMetrics(Map<String, dynamic> f) {
    final stats = _maps(f['stats']);
    final b = StringBuffer();
    b.write(textBox(x(0.04), y(0.04), x(0.75), y(0.08),
        [TextLine(_s(f['heading'], 'Key metrics'), 26, theme.primary, bold: true, heading: true)]));
    b.write(rect(x(0.04), y(0.14), x(0.55), 12700, theme.accent2));
    b.write(rect(x(0.62), 0, x(0.38), _h, theme.primary));
    const cols = 2;
    for (var i = 0; i < stats.length && i < 6; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final xx = 0.04 + col * 0.29;
      final yy = 0.20 + row * 0.26;
      b.write(textBox(x(xx), y(yy), x(0.12), y(0.12),
          [TextLine(_s(stats[i]['value'], ''), 34, theme.accent2, bold: true)]));
      b.write(textBox(x(xx + 0.125), y(yy + 0.012), x(0.155), y(0.18),
          [TextLine(_s(stats[i]['label'], ''), 12, '404040')]));
    }
    return b.toString();
  }

  String _impactedSectors(Map<String, dynamic> f) {
    final rows = _maps(f['rows']);
    final b = StringBuffer();
    b.write(textBox(x(0.04), y(0.04), x(0.92), y(0.07),
        [TextLine(_s(f['heading'], 'Impacted sectors'), 26, theme.primary, bold: true, heading: true)]));
    b.write(textBox(x(0.04), y(0.12), x(0.92), y(0.08),
        [TextLine(_s(f['subheading'], ''), 14, '595959')]));
    var yy = 0.24;
    for (final row in rows.take(4)) {
      b.write(rect(x(0.05), y(yy - 0.015), x(0.90), 9525, 'D9D9D9'));
      b.write(textBox(x(0.05), y(yy + 0.01), x(0.15), y(0.12),
          [TextLine(_s(row['sector'], ''), 14, theme.primary, bold: true)]));
      b.write(textBox(x(0.22), y(yy + 0.01), x(0.73), y(0.16),
          [TextLine(_s(row['impact'], ''), 12, '404040')]));
      yy += 0.185;
    }
    return b.toString();
  }

  String _newsUpdates(Map<String, dynamic> f) {
    final items = _maps(f['items']);
    final b = StringBuffer();
    b.write(textBox(x(0.04), y(0.04), x(0.60), y(0.07),
        [TextLine(_s(f['heading'], 'News updates'), 26, theme.primary, bold: true, heading: true)]));
    b.write(textBox(x(0.04), y(0.13), x(0.50), y(0.06),
        [TextLine(_s(f['category'], ''), 16, theme.accent2, bold: true)]));
    b.write(rect(x(0.74), 0, x(0.26), _h, theme.primary));
    var yy = 0.22;
    for (final item in items.take(3)) {
      final head =
          '${_s(item['date'], '')}: ${_s(item['headline'], '')}'.trim();
      b.write(textBox(x(0.04), y(yy), x(0.66), y(0.07),
          [TextLine(head, 13, theme.primary, bold: true)]));
      b.write(textBox(x(0.04), y(yy + 0.065), x(0.66), y(0.14),
          [TextLine(_s(item['body'], ''), 11, '404040')]));
      b.write(rect(x(0.04), y(yy + 0.215), x(0.66), 9525, 'D9D9D9'));
      yy += 0.245;
    }
    return b.toString();
  }

  String _capabilitiesTable(Map<String, dynamic> f) {
    final rows = _rows(f['rows']);
    final b = StringBuffer();
    b.write(textBox(x(0.04), y(0.04), x(0.92), y(0.07),
        [TextLine(_s(f['heading'], 'Capabilities'), 26, theme.primary, bold: true, heading: true)]));
    b.write(textBox(x(0.04), y(0.12), x(0.92), y(0.06),
        [TextLine(_s(f['subheading'], ''), 14, '595959')]));
    b.write(table(x(0.04), y(0.22), x(0.92), rows));
    return b.toString();
  }

  String _contact(Map<String, dynamic> f) {
    final b = StringBuffer();
    b.write(textBox(x(0.04), y(0.05), x(0.60), y(0.10),
        [TextLine(_s(f['heading'], 'Contact Us'), 30, theme.primary, bold: true, heading: true)]));
    b.write(textBox(x(0.04), y(0.20), x(0.55), y(0.35),
        [TextLine(_s(f['body'], ''), 14, '404040')]));
    b.write(rect(x(0.64), y(0.18), x(0.32), y(0.30), 'F2F2F2'));
    b.write(textBox(x(0.66), y(0.21), x(0.28), y(0.24), [
      TextLine(_s(f['name'], ''), 16, theme.primary, bold: true),
      TextLine(_s(f['title'], ''), 12, '595959'),
      TextLine(_s(f['email'], ''), 12, theme.accent1),
    ]));
    b.write(rect(0, y(0.88), _w, y(0.12), theme.primary));
    b.write(textBox(x(0.04), y(0.90), x(0.90), y(0.08),
        [TextLine(_s(f['closing'], ''), 12, 'FFFFFF')]));
    return b.toString();
  }

  // ------------------------------------------------------------- emitters

  String _slideXml(String shapes, {String? bg}) {
    final bgXml = bg == null
        ? ''
        : '<p:bg><p:bgPr><a:solidFill><a:srgbClr val="$bg"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>';
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">'
        '<p:cSld>$bgXml<p:spTree>'
        '<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
        '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
        '$shapes'
        '</p:spTree></p:cSld>'
        '<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>'
        '</p:sld>';
  }

  /// Multi-paragraph text box.
  String textBox(int px, int py, int cx, int cy, List<TextLine> lines) {
    final id = ++_shapeId;
    final paras = lines.map((l) {
      final font = l.heading ? theme.headingFont : theme.bodyFont;
      return '<a:p><a:r>'
          '<a:rPr lang="en-US" sz="${l.sizePt * 100}"${l.bold ? ' b="1"' : ''} dirty="0">'
          '<a:solidFill><a:srgbClr val="${l.color}"/></a:solidFill>'
          '<a:latin typeface="${OoxmlParts.escapeXml(font)}"/>'
          '</a:rPr>'
          '<a:t>${OoxmlParts.escapeXml(l.text)}</a:t>'
          '</a:r></a:p>';
    }).join();
    return '<p:sp>'
        '<p:nvSpPr><p:cNvPr id="$id" name="TextBox $id"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>'
        '<p:spPr><a:xfrm><a:off x="$px" y="$py"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/></p:spPr>'
        '<p:txBody><a:bodyPr wrap="square"><a:normAutofit/></a:bodyPr><a:lstStyle/>$paras</p:txBody>'
        '</p:sp>';
  }

  /// Solid-fill rectangle (also used as a horizontal rule when cy is tiny).
  String rect(int px, int py, int cx, int cy, String color) {
    final id = ++_shapeId;
    return '<p:sp>'
        '<p:nvSpPr><p:cNvPr id="$id" name="Rect $id"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>'
        '<p:spPr><a:xfrm><a:off x="$px" y="$py"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
        '<a:solidFill><a:srgbClr val="$color"/></a:solidFill><a:ln><a:noFill/></a:ln></p:spPr>'
        '<p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody>'
        '</p:sp>';
  }

  /// Two-column table: first row is a header styled in the primary color.
  String table(int px, int py, int cx, List<List<String>> rows) {
    if (rows.isEmpty) return '';
    final id = ++_shapeId;
    final colCount = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    final colW = (cx / colCount).round();
    final grid = List.generate(colCount, (_) => '<a:gridCol w="$colW"/>').join();

    final trs = StringBuffer();
    for (var r = 0; r < rows.length; r++) {
      final isHeader = r == 0;
      final cells = StringBuffer();
      for (var c = 0; c < colCount; c++) {
        final text = c < rows[r].length ? rows[r][c] : '';
        cells.write('<a:tc><a:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r>'
            '<a:rPr lang="en-US" sz="1200"${isHeader ? ' b="1"' : ''} dirty="0">'
            '<a:solidFill><a:srgbClr val="${isHeader ? 'FFFFFF' : '404040'}"/></a:solidFill>'
            '<a:latin typeface="${OoxmlParts.escapeXml(theme.bodyFont)}"/>'
            '</a:rPr><a:t>${OoxmlParts.escapeXml(text)}</a:t></a:r></a:p></a:txBody>'
            '<a:tcPr marL="91440" marR="91440" marT="45720" marB="45720">'
            '${isHeader ? '<a:solidFill><a:srgbClr val="${theme.primary}"/></a:solidFill>' : (r.isEven ? '<a:solidFill><a:srgbClr val="F2F2F2"/></a:solidFill>' : '')}'
            '</a:tcPr></a:tc>');
      }
      trs.write('<a:tr h="370840">$cells</a:tr>');
    }

    return '<p:graphicFrame>'
        '<p:nvGraphicFramePr><p:cNvPr id="$id" name="Table $id"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>'
        '<p:xfrm><a:off x="$px" y="$py"/><a:ext cx="$cx" cy="${rows.length * 370840}"/></p:xfrm>'
        '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">'
        '<a:tbl><a:tblPr firstRow="1" bandRow="1"/><a:tblGrid>$grid</a:tblGrid>$trs</a:tbl>'
        '</a:graphicData></a:graphic>'
        '</p:graphicFrame>';
  }

  // ------------------------------------------------------------- helpers

  static String _s(dynamic v, String fallback) =>
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

class TextLine {
  final String text;
  final int sizePt;
  final String color;
  final bool bold;
  final bool heading;

  const TextLine(this.text, this.sizePt, this.color,
      {this.bold = false, this.heading = false});
}
