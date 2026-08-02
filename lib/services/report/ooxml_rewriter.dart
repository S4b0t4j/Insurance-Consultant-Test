import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../models/report_template.dart';
import 'ooxml_reader.dart';

class OoxmlRewriteException implements Exception {
  final String message;
  OoxmlRewriteException(this.message);
  @override
  String toString() => 'OoxmlRewriteException: $message';
}

/// Clone-mode writer: takes the original template bytes and a map of
/// blockId -> replacement text, rewrites only the XML parts that contain
/// replaced paragraphs and byte-copies every other archive entry untouched.
class OoxmlRewriter {
  /// Returns new document bytes with replacements applied.
  static Uint8List rewrite(
    ReportTemplate template,
    Map<String, String> replacements,
  ) {
    final archive = OoxmlReader.decodeArchive(template.bytes);

    // Which parts need editing, and which blockIds live in each.
    final partsToEdit = <String, Map<String, String>>{};
    for (final slide in template.slides) {
      final slideReplacements = <String, String>{};
      for (final para in slide.allParagraphs) {
        final replacement = replacements[para.blockId];
        if (replacement != null && replacement != para.mergedText) {
          slideReplacements[para.blockId] = replacement;
        }
      }
      if (slideReplacements.isNotEmpty) {
        partsToEdit[slide.partPath] = slideReplacements;
      }
    }

    final rewrittenParts = <String, Uint8List>{};
    partsToEdit.forEach((partPath, slideReplacements) {
      final file = OoxmlReader.findFile(archive, partPath);
      if (file == null) return;
      final original = OoxmlReader.archiveFileText(file);
      final doc = XmlDocument.parse(original);

      final slideIndex = template.slides
          .firstWhere((s) => s.partPath == partPath)
          .index;
      final located = template.kind == TemplateKind.pptx
          ? OoxmlReader.enumeratePptxParagraphs(doc, slideIndex)
          : OoxmlReader.enumerateDocxParagraphs(doc);
      final byId = {for (final lp in located) lp.blockId: lp};

      var applied = 0;
      slideReplacements.forEach((blockId, text) {
        final lp = byId[blockId];
        if (lp == null) return;
        _replaceParagraphText(
            lp.paragraph, text, template.kind == TemplateKind.docx);
        applied++;
      });

      if (applied > 0) {
        rewrittenParts[partPath] =
            Uint8List.fromList(utf8.encode(doc.toXmlString()));
      }
    });

    return repack(archive, rewrittenParts);
  }

  /// Rebuilds the zip: swapped-in edited parts, raw copies of everything
  /// else. `[Content_Types].xml` is kept as the first entry.
  static Uint8List repack(Archive archive, Map<String, Uint8List> edited) {
    final out = Archive();

    void addFile(ArchiveFile f) {
      if (!f.isFile) return;
      final replacement = edited[f.name];
      if (replacement != null) {
        out.addFile(ArchiveFile.bytes(f.name, replacement));
      } else {
        out.addFile(ArchiveFile.bytes(f.name, f.content));
      }
    }

    final contentTypes =
        archive.files.where((f) => f.name == '[Content_Types].xml');
    for (final f in contentTypes) {
      addFile(f);
    }
    for (final f in archive.files) {
      if (f.name == '[Content_Types].xml') continue;
      addFile(f);
    }

    final encoded = ZipEncoder().encode(out);
    return Uint8List.fromList(encoded);
  }

  /// Puts [text] into the paragraph's first run and blanks the remaining
  /// runs, preserving the first run's formatting (rPr).
  static void _replaceParagraphText(
      XmlElement paragraph, String text, bool isDocx) {
    final runTag = isDocx ? 'w:r' : 'a:r';
    final textTag = isDocx ? 'w:t' : 'a:t';

    final runs = paragraph
        .findAllElements(runTag)
        .where((r) =>
            !_isInsideField(r, paragraph) &&
            r.findElements(textTag).isNotEmpty)
        .toList();
    if (runs.isEmpty) return;

    var first = true;
    for (final run in runs) {
      for (final t in run.findElements(textTag)) {
        if (first) {
          t.innerText = text;
          if (isDocx &&
              (text.startsWith(' ') || text.endsWith(' '))) {
            t.setAttribute('xml:space', 'preserve');
          }
          first = false;
        } else {
          t.innerText = '';
        }
      }
    }
  }

  static bool _isInsideField(XmlElement run, XmlElement paragraph) {
    XmlElement? cur = run.parentElement;
    while (cur != null && cur != paragraph) {
      if (cur.qualifiedName == 'a:fld' || cur.qualifiedName == 'w:fldSimple') {
        return true;
      }
      cur = cur.parentElement;
    }
    return false;
  }
}
