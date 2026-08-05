import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../models/report_template.dart';

/// A paragraph located inside a parsed OOXML part, addressable by blockId.
/// Shared by the reader (inventory) and rewriter (replacement) so both
/// enumerate paragraphs identically.
class LocatedParagraph {
  final String blockId;
  final XmlElement paragraph;
  final String shapeId;
  final String shapeName;
  final bool isTableCell;
  final int? offX, offY, extX, extY;

  LocatedParagraph({
    required this.blockId,
    required this.paragraph,
    required this.shapeId,
    required this.shapeName,
    this.isTableCell = false,
    this.offX,
    this.offY,
    this.extX,
    this.extY,
  });
}

class OoxmlReadException implements Exception {
  final String message;
  OoxmlReadException(this.message);
  @override
  String toString() => 'OoxmlReadException: $message';
}

class OoxmlReader {
  /// Parses an uploaded .pptx or .docx into a [ReportTemplate].
  static ReportTemplate parse(String fileName, Uint8List bytes) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pptx')) {
      return _parsePptx(fileName, bytes);
    } else if (lower.endsWith('.docx')) {
      return _parseDocx(fileName, bytes);
    }
    throw OoxmlReadException(
        'Unsupported template type. Upload a .pptx or .docx file.');
  }

  static Archive decodeArchive(Uint8List bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw OoxmlReadException('Could not read file as an Office document: $e');
    }
  }

  static String archiveFileText(ArchiveFile file) =>
      utf8.decode(file.content, allowMalformed: true);

  static ArchiveFile? findFile(Archive archive, String path) {
    for (final f in archive.files) {
      if (f.name == path) return f;
    }
    return null;
  }

  // ---------------------------------------------------------------- pptx

  static ReportTemplate _parsePptx(String fileName, Uint8List bytes) {
    final archive = decodeArchive(bytes);
    final slidePaths = orderedSlidePaths(archive);
    if (slidePaths.isEmpty) {
      throw OoxmlReadException('No slides found in presentation.');
    }

    final slides = <SlideInventory>[];
    for (var i = 0; i < slidePaths.length; i++) {
      final part = findFile(archive, slidePaths[i]);
      if (part == null) continue;
      final doc = XmlDocument.parse(archiveFileText(part));
      final located = enumeratePptxParagraphs(doc, i + 1);
      slides.add(_toInventory(i + 1, slidePaths[i], located));
    }

    final size = _slideSize(archive);
    final theme = extractPptxTheme(archive, size);

    return ReportTemplate(
      fileName: fileName,
      kind: TemplateKind.pptx,
      bytes: bytes,
      slides: slides,
      theme: theme,
    );
  }

  /// Slide part paths in presentation order, resolved via presentation.xml
  /// relationship ids.
  static List<String> orderedSlidePaths(Archive archive) {
    final presFile = findFile(archive, 'ppt/presentation.xml');
    final relsFile = findFile(archive, 'ppt/_rels/presentation.xml.rels');
    if (presFile == null || relsFile == null) {
      // Fall back to natural sort of slide files.
      final paths = archive.files
          .map((f) => f.name)
          .where((n) =>
              n.startsWith('ppt/slides/slide') && n.endsWith('.xml'))
          .toList();
      paths.sort((a, b) => _slideNum(a).compareTo(_slideNum(b)));
      return paths;
    }

    final rels = XmlDocument.parse(archiveFileText(relsFile));
    final relMap = <String, String>{};
    for (final rel in rels.findAllElements('Relationship')) {
      final id = rel.getAttribute('Id');
      final target = rel.getAttribute('Target');
      final type = rel.getAttribute('Type') ?? '';
      if (id != null && target != null && type.endsWith('/slide')) {
        var t = target;
        if (t.startsWith('/')) {
          t = t.substring(1);
        } else {
          t = 'ppt/$t';
        }
        relMap[id] = t.replaceAll('slides/../', '');
      }
    }

    final pres = XmlDocument.parse(archiveFileText(presFile));
    final ordered = <String>[];
    for (final sldId in pres.findAllElements('p:sldId')) {
      final rId = sldId.getAttribute('r:id');
      final path = relMap[rId];
      if (path != null) ordered.add(path);
    }
    return ordered.isNotEmpty ? ordered : relMap.values.toList();
  }

  static int _slideNum(String path) {
    final m = RegExp(r'slide(\d+)\.xml$').firstMatch(path);
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  static (int, int) _slideSize(Archive archive) {
    final presFile = findFile(archive, 'ppt/presentation.xml');
    if (presFile != null) {
      final pres = XmlDocument.parse(archiveFileText(presFile));
      final sldSz = pres.findAllElements('p:sldSz').firstOrNull;
      if (sldSz != null) {
        final cx = int.tryParse(sldSz.getAttribute('cx') ?? '');
        final cy = int.tryParse(sldSz.getAttribute('cy') ?? '');
        if (cx != null && cy != null) return (cx, cy);
      }
    }
    return (12192000, 6858000);
  }

  /// Deterministic paragraph enumeration for one slide document. Walks
  /// every `p:sp` (including inside groups) and every table cell in
  /// `p:graphicFrame`s, skipping empty paragraphs and slide-number fields.
  static List<LocatedParagraph> enumeratePptxParagraphs(
      XmlDocument slideDoc, int slideIndex) {
    final result = <LocatedParagraph>[];

    for (final sp in slideDoc.findAllElements('p:sp')) {
      final cNvPr = sp.findAllElements('p:cNvPr').firstOrNull;
      final shapeId = cNvPr?.getAttribute('id') ?? '0';
      final shapeName = cNvPr?.getAttribute('name') ?? '';
      final xfrm = sp.findAllElements('a:xfrm').firstOrNull;
      final off = xfrm?.findElements('a:off').firstOrNull;
      final ext = xfrm?.findElements('a:ext').firstOrNull;

      final txBody = sp.findAllElements('p:txBody').firstOrNull;
      if (txBody == null) continue;

      var pIdx = 0;
      for (final para in txBody.findElements('a:p')) {
        final text = paragraphText(para);
        final blockId = 's${slideIndex}_sp${shapeId}_p$pIdx';
        pIdx++;
        if (text.trim().isEmpty) continue;
        if (para.findAllElements('a:fld').isNotEmpty) continue;
        result.add(LocatedParagraph(
          blockId: blockId,
          paragraph: para,
          shapeId: shapeId,
          shapeName: shapeName,
          offX: int.tryParse(off?.getAttribute('x') ?? ''),
          offY: int.tryParse(off?.getAttribute('y') ?? ''),
          extX: int.tryParse(ext?.getAttribute('cx') ?? ''),
          extY: int.tryParse(ext?.getAttribute('cy') ?? ''),
        ));
      }
    }

    // Tables inside graphic frames.
    for (final frame in slideDoc.findAllElements('p:graphicFrame')) {
      final cNvPr = frame.findAllElements('p:cNvPr').firstOrNull;
      final frameId = cNvPr?.getAttribute('id') ?? '0';
      var rIdx = 0;
      for (final tr in frame.findAllElements('a:tr')) {
        var cIdx = 0;
        for (final tc in tr.findElements('a:tc')) {
          var pIdx = 0;
          for (final para in tc.findAllElements('a:p')) {
            final text = paragraphText(para);
            final blockId =
                's${slideIndex}_gf${frameId}_r${rIdx}_c${cIdx}_p$pIdx';
            pIdx++;
            if (text.trim().isEmpty) continue;
            result.add(LocatedParagraph(
              blockId: blockId,
              paragraph: para,
              shapeId: 'gf$frameId',
              shapeName: 'Table $frameId',
              isTableCell: true,
            ));
          }
          cIdx++;
        }
        rIdx++;
      }
    }

    return result;
  }

  /// Concatenated run text of a paragraph (a:p for pptx, w:p for docx).
  static String paragraphText(XmlElement para) {
    final buf = StringBuffer();
    for (final t in para.findAllElements('a:t')) {
      // Skip run text that lives inside a field (slide numbers etc.).
      if (_hasAncestor(t, 'a:fld', stopAt: para)) continue;
      buf.write(t.innerText);
    }
    for (final t in para.findAllElements('w:t')) {
      buf.write(t.innerText);
    }
    return buf.toString();
  }

  static bool _hasAncestor(XmlElement node, String name,
      {required XmlElement stopAt}) {
    XmlElement? cur = node.parentElement;
    while (cur != null && cur != stopAt) {
      if (cur.qualifiedName == name) return true;
      cur = cur.parentElement;
    }
    return false;
  }

  static SlideInventory _toInventory(
      int index, String partPath, List<LocatedParagraph> located) {
    final byShape = <String, List<LocatedParagraph>>{};
    for (final lp in located) {
      byShape.putIfAbsent(lp.shapeId, () => []).add(lp);
    }
    final shapes = <ShapeInventory>[];
    byShape.forEach((shapeId, paras) {
      final first = paras.first;
      shapes.add(ShapeInventory(
        shapeId: shapeId,
        name: first.shapeName,
        isTableCell: first.isTableCell,
        offXEmu: first.offX,
        offYEmu: first.offY,
        extXEmu: first.extX,
        extYEmu: first.extY,
        paragraphs: [
          for (var i = 0; i < paras.length; i++)
            ParagraphInventory(
              blockId: paras[i].blockId,
              paragraphIndex: i,
              mergedText: paragraphText(paras[i].paragraph),
              runCount: paras[i]
                  .paragraph
                  .findAllElements('a:r')
                  .length
                  .clamp(0, 999),
            ),
        ],
      ));
    });
    return SlideInventory(index: index, partPath: partPath, shapes: shapes);
  }

  // ---------------------------------------------------------------- theme

  /// Extracts dominant colors and fonts: theme1.xml scheme plus a frequency
  /// count of literal srgbClr values across slide parts (captures brand
  /// colors applied directly to shapes/runs).
  static ExtractedTheme extractPptxTheme(Archive archive, (int, int) size) {
    final counts = <String, int>{};
    final fontCounts = <String, int>{};
    final colorRe = RegExp(r'srgbClr val="([0-9A-Fa-f]{6})"');
    final fontRe = RegExp(r'typeface="([^"]+)"');

    for (final f in archive.files) {
      if (!f.name.startsWith('ppt/slides/slide') || !f.name.endsWith('.xml')) {
        continue;
      }
      final xml = archiveFileText(f);
      for (final m in colorRe.allMatches(xml)) {
        final hex = m.group(1)!.toUpperCase();
        counts[hex] = (counts[hex] ?? 0) + 1;
      }
      for (final m in fontRe.allMatches(xml)) {
        final font = m.group(1)!;
        if (font.startsWith('+')) continue;
        fontCounts[font] = (fontCounts[font] ?? 0) + 1;
      }
    }

    // Fold in the declared theme scheme at low weight.
    final themeFile = findFile(archive, 'ppt/theme/theme1.xml');
    String headingFont = 'Arial', bodyFont = 'Arial';
    if (themeFile != null) {
      final themeXml = archiveFileText(themeFile);
      for (final m in colorRe.allMatches(themeXml)) {
        final hex = m.group(1)!.toUpperCase();
        counts[hex] = (counts[hex] ?? 0) + 1;
      }
      final doc = XmlDocument.parse(themeXml);
      final major = doc.findAllElements('a:majorFont').firstOrNull;
      final minor = doc.findAllElements('a:minorFont').firstOrNull;
      headingFont = major
              ?.findElements('a:latin')
              .firstOrNull
              ?.getAttribute('typeface') ??
          'Arial';
      bodyFont = minor
              ?.findElements('a:latin')
              .firstOrNull
              ?.getAttribute('typeface') ??
          'Arial';
    }
    if (fontCounts.isNotEmpty) {
      final sorted = fontCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      bodyFont = sorted.first.key.replaceAll(RegExp(r' (Bold|Italics?)$'), '');
      if (sorted.length > 1) {
        headingFont =
            sorted[1].key.replaceAll(RegExp(r' (Bold|Italics?)$'), '');
      } else {
        headingFont = bodyFont;
      }
    }

    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final colors = ranked
        .map((e) => e.key)
        .where((c) => c != 'FFFFFF' && c != '000000')
        .take(6)
        .toList();
    if (colors.isEmpty) colors.addAll(['000F47', '82BAFF', 'FFBF00']);

    return ExtractedTheme(
      colors: colors,
      headingFont: headingFont,
      bodyFont: bodyFont,
      slideWidthEmu: size.$1,
      slideHeightEmu: size.$2,
    );
  }

  // ---------------------------------------------------------------- docx

  static ReportTemplate _parseDocx(String fileName, Uint8List bytes) {
    final archive = decodeArchive(bytes);
    final docFile = findFile(archive, 'word/document.xml');
    if (docFile == null) {
      throw OoxmlReadException('word/document.xml not found in document.');
    }
    final doc = XmlDocument.parse(archiveFileText(docFile));
    final located = enumerateDocxParagraphs(doc);

    final shapes = <ShapeInventory>[
      ShapeInventory(
        shapeId: 'body',
        name: 'Document body',
        paragraphs: [
          for (var i = 0; i < located.length; i++)
            ParagraphInventory(
              blockId: located[i].blockId,
              paragraphIndex: i,
              mergedText: paragraphText(located[i].paragraph),
              runCount: located[i].paragraph.findAllElements('w:r').length,
            ),
        ],
      ),
    ];

    return ReportTemplate(
      fileName: fileName,
      kind: TemplateKind.docx,
      bytes: bytes,
      slides: [
        SlideInventory(
            index: 1, partPath: 'word/document.xml', shapes: shapes),
      ],
      theme: extractDocxTheme(archive),
    );
  }

  /// All w:p elements in document order (body and table paragraphs alike),
  /// ids `p0..pN` — skipping empty paragraphs.
  static List<LocatedParagraph> enumerateDocxParagraphs(XmlDocument doc) {
    final result = <LocatedParagraph>[];
    var idx = 0;
    for (final para in doc.findAllElements('w:p')) {
      final blockId = 'p$idx';
      idx++;
      final text = paragraphText(para);
      if (text.trim().isEmpty) continue;
      result.add(LocatedParagraph(
        blockId: blockId,
        paragraph: para,
        shapeId: 'body',
        shapeName: 'Document body',
      ));
    }
    return result;
  }

  static ExtractedTheme extractDocxTheme(Archive archive) {
    final counts = <String, int>{};
    final colorRe = RegExp(r'w:val="([0-9A-Fa-f]{6})"');
    final docFile = findFile(archive, 'word/document.xml');
    final stylesFile = findFile(archive, 'word/styles.xml');
    for (final f in [docFile, stylesFile]) {
      if (f == null) continue;
      for (final m in colorRe.allMatches(archiveFileText(f))) {
        final hex = m.group(1)!.toUpperCase();
        if (hex == 'FFFFFF' || hex == '000000') continue;
        counts[hex] = (counts[hex] ?? 0) + 1;
      }
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final colors = ranked.map((e) => e.key).take(6).toList();
    if (colors.isEmpty) colors.addAll(['000F47', '82BAFF', 'FFBF00']);

    String headingFont = 'Georgia', bodyFont = 'Arial';
    if (stylesFile != null) {
      final fonts = RegExp(r'w:ascii="([^"]+)"')
          .allMatches(archiveFileText(stylesFile))
          .map((m) => m.group(1)!)
          .toList();
      if (fonts.isNotEmpty) bodyFont = fonts.first;
    }
    return ExtractedTheme(
        colors: colors, headingFont: headingFont, bodyFont: bodyFont);
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
