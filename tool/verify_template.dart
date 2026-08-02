// Verification harness for the Report Studio OOXML engine: parses a real
// .pptx/.docx template, writes an identity clone and a sample-replacement
// clone so they can be opened in PowerPoint/Word to confirm no repair prompt.
//
// Usage: dart run tool/verify_template.dart <template.pptx> <output-dir>
import 'dart:io';
import 'dart:typed_data';

import 'package:education_news_monitor/services/report/ooxml_reader.dart';
import 'package:education_news_monitor/services/report/ooxml_rewriter.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
        'Usage: dart run tool/verify_template.dart <template.pptx|docx> <output-dir>');
    exit(64);
  }
  final inPath = args[0];
  final outDir = args[1];
  final bytes = Uint8List.fromList(File(inPath).readAsBytesSync());

  final sw = Stopwatch()..start();
  final template = OoxmlReader.parse(inPath.split('/').last, bytes);
  print('Parsed in ${sw.elapsedMilliseconds}ms: '
      '${template.slideCount} slides, ${template.totalTextBlocks} text blocks');
  print('Theme colors: ${template.theme.colors}');
  print('Fonts: heading=${template.theme.headingFont} body=${template.theme.bodyFont}');
  print('Slide size: ${template.theme.slideWidthEmu} x ${template.theme.slideHeightEmu}');

  for (final s in template.slides.take(3)) {
    final first = s.allParagraphs.take(2).map((p) =>
        '${p.blockId}:"${p.mergedText.substring(0, p.mergedText.length.clamp(0, 40))}"');
    print('  slide ${s.index} (${s.textBlockCount} blocks): ${first.join(' | ')}');
  }

  // Identity clone.
  sw.reset();
  final identity = OoxmlRewriter.rewrite(template, {});
  print('Identity clone in ${sw.elapsedMilliseconds}ms, '
      '${identity.length} bytes (original ${bytes.length})');
  File('$outDir/identity_clone.pptx').writeAsBytesSync(identity);

  // Real replacement clone: retitle the edition + first few text blocks.
  final replacements = <String, String>{};
  for (final s in template.slides) {
    for (final p in s.allParagraphs) {
      if (p.mergedText.contains('May 2026 edition')) {
        replacements[p.blockId] = 'August 2026 edition';
      }
      if (p.mergedText == 'Key metrics') {
        replacements[p.blockId] = 'Quarter highlights';
      }
    }
  }
  print('Applying ${replacements.length} replacements…');
  sw.reset();
  final modified = OoxmlRewriter.rewrite(template, replacements);
  print('Modified clone in ${sw.elapsedMilliseconds}ms');
  File('$outDir/modified_clone.pptx').writeAsBytesSync(modified);

  // Re-parse both clones to prove they're still valid.
  final id2 = OoxmlReader.parse('id.pptx', identity);
  final mod2 = OoxmlReader.parse('mod.pptx', modified);
  print('Reparsed identity: ${id2.slideCount} slides, ${id2.totalTextBlocks} blocks');
  print('Reparsed modified: ${mod2.slideCount} slides, ${mod2.totalTextBlocks} blocks');
  final modTexts =
      mod2.slides.expand((s) => s.allParagraphs).map((p) => p.mergedText).toSet();
  print('Edition date swapped: ${modTexts.contains('August 2026 edition')}');
  print('Old date gone: ${!modTexts.contains('May 2026 edition')}');
  print('"Key metrics" -> "Quarter highlights": ${modTexts.contains('Quarter highlights')}');
}
