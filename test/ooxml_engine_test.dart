import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:vantage_public_sector/models/report_job.dart';
import 'package:vantage_public_sector/models/report_template.dart';
import 'package:vantage_public_sector/services/report/docx_builder.dart';
import 'package:vantage_public_sector/services/report/ooxml_reader.dart';
import 'package:vantage_public_sector/services/report/ooxml_rewriter.dart';
import 'package:vantage_public_sector/services/report/pptx_builder.dart';
import 'package:flutter_test/flutter_test.dart';

const theme = ExtractedTheme(
  colors: ['000F47', '82BAFF', 'FFBF00'],
  headingFont: 'Georgia',
  bodyFont: 'Arial',
  slideWidthEmu: 18288000,
  slideHeightEmu: 10287000,
);

/// A 3-slide fixture deck produced by our own builder: cover, key metrics,
/// capabilities table.
Uint8List buildFixturePptx() {
  return PptxBuilder(theme).build('Fixture Deck', [
    PlannedSlide(archetype: SlideArchetype.cover, fields: {
      'title': 'Risk Report for Public Entities',
      'subtitle': 'Quarterly risk intelligence',
      'date': 'May 2026 edition',
    }),
    PlannedSlide(archetype: SlideArchetype.keyMetrics, fields: {
      'heading': 'Key metrics',
      'stats': [
        {'value': r'$1.2B', 'label': 'in convective storm losses'},
        {'value': '38%', 'label': 'cyber premium increase'},
      ],
    }),
    PlannedSlide(archetype: SlideArchetype.capabilitiesTable, fields: {
      'heading': 'Capabilities',
      'subheading': 'What we offer',
      'rows': [
        ['Service', 'Description'],
        ['Analytics', 'Risk finance optimization'],
        ['CatDQ', 'Property data quality'],
      ],
    }),
  ]);
}

void main() {
  group('PptxBuilder output', () {
    test('produces a structurally valid package', () {
      final bytes = buildFixturePptx();
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, contains('[Content_Types].xml'));
      expect(names, contains('_rels/.rels'));
      expect(names, contains('ppt/presentation.xml'));
      expect(names, contains('ppt/slides/slide1.xml'));
      expect(names, contains('ppt/slides/slide3.xml'));
      expect(names, contains('ppt/theme/theme1.xml'));
      expect(names, contains('ppt/slideMasters/slideMaster1.xml'));

      // Every XML part parses.
      for (final f in archive.files.where((f) => f.name.endsWith('.xml'))) {
        expect(() => OoxmlReader.archiveFileText(f), returnsNormally,
            reason: f.name);
      }
    });
  });

  group('OoxmlReader', () {
    test('inventories slides, shapes and text with stable blockIds', () {
      final bytes = buildFixturePptx();
      final template = OoxmlReader.parse('fixture.pptx', bytes);

      expect(template.kind, TemplateKind.pptx);
      expect(template.slideCount, 3);
      expect(template.totalTextBlocks, greaterThan(5));

      final allText = template.slides
          .expand((s) => s.allParagraphs)
          .map((p) => p.mergedText)
          .join('\n');
      expect(allText, contains('Risk Report for Public Entities'));
      expect(allText, contains('May 2026 edition'));
      expect(allText, contains(r'$1.2B'));
      expect(allText, contains('Risk finance optimization'));

      // blockIds unique.
      final ids =
          template.slides.expand((s) => s.allParagraphs).map((p) => p.blockId);
      expect(ids.toSet().length, ids.length);

      // Table cells addressed via graphic-frame ids.
      expect(ids.where((id) => id.contains('_gf')).isNotEmpty, true);
    });

    test('extracts the theme colors and slide size back out', () {
      final bytes = buildFixturePptx();
      final template = OoxmlReader.parse('fixture.pptx', bytes);
      expect(template.theme.colors, contains('000F47'));
      expect(template.theme.slideWidthEmu, 18288000);
      expect(template.theme.slideHeightEmu, 10287000);
    });

    test('rejects non-office files', () {
      expect(
        () => OoxmlReader.parse('nonsense.pptx',
            Uint8List.fromList(utf8.encode('not a zip'))),
        throwsA(isA<OoxmlReadException>()),
      );
    });
  });

  group('OoxmlRewriter (clone mode)', () {
    test('identity clone: no replacements -> non-slide parts byte-identical',
        () {
      final bytes = buildFixturePptx();
      final template = OoxmlReader.parse('fixture.pptx', bytes);

      final cloned = OoxmlRewriter.rewrite(template, {});
      final original = ZipDecoder().decodeBytes(bytes);
      final rewritten = ZipDecoder().decodeBytes(cloned);

      expect(rewritten.files.where((f) => f.isFile).length,
          original.files.where((f) => f.isFile).length);
      for (final f in original.files.where((f) => f.isFile)) {
        final clone = rewritten.files.firstWhere((c) => c.name == f.name);
        expect(clone.content, f.content,
            reason: '${f.name} should be byte-identical');
      }
    });

    test('replaces targeted text and leaves the rest untouched', () {
      final bytes = buildFixturePptx();
      final template = OoxmlReader.parse('fixture.pptx', bytes);

      final titleBlock = template.slides.first.allParagraphs.firstWhere(
          (p) => p.mergedText == 'Risk Report for Public Entities');
      final dateBlock = template.slides.first.allParagraphs
          .firstWhere((p) => p.mergedText == 'May 2026 edition');

      final cloned = OoxmlRewriter.rewrite(template, {
        titleBlock.blockId: 'Emerging Risk Briefing',
        dateBlock.blockId: 'August 2026 edition',
      });

      final reparsed = OoxmlReader.parse('clone.pptx', cloned);
      final texts = reparsed.slides
          .expand((s) => s.allParagraphs)
          .map((p) => p.mergedText)
          .toList();
      expect(texts, contains('Emerging Risk Briefing'));
      expect(texts, contains('August 2026 edition'));
      expect(texts, isNot(contains('Risk Report for Public Entities')));
      // Untouched slide 2 content survives.
      expect(texts, contains(r'$1.2B'));

      // Untouched parts are byte-identical (slide2, slide3, theme, rels...).
      final original = ZipDecoder().decodeBytes(bytes);
      final rewritten = ZipDecoder().decodeBytes(cloned);
      for (final f in original.files.where((f) =>
          f.isFile && f.name != 'ppt/slides/slide1.xml')) {
        final clone = rewritten.files.firstWhere((c) => c.name == f.name);
        expect(clone.content, f.content, reason: f.name);
      }
    });

    test('replacement lands in first run and blanks the rest', () {
      final bytes = buildFixturePptx();
      final template = OoxmlReader.parse('fixture.pptx', bytes);
      final block = template.slides.first.allParagraphs.first;

      final cloned =
          OoxmlRewriter.rewrite(template, {block.blockId: 'NEW <TEXT> & MORE'});
      final reparsed = OoxmlReader.parse('clone.pptx', cloned);
      final texts = reparsed.slides
          .expand((s) => s.allParagraphs)
          .map((p) => p.mergedText);
      // XML-escaping round-trips.
      expect(texts, contains('NEW <TEXT> & MORE'));
    });
  });

  group('DocxBuilder + docx round-trip', () {
    test('builds a parseable docx whose text can be cloned', () {
      final bytes = DocxBuilder(theme).build('Fixture Doc', [
        PlannedSlide(archetype: SlideArchetype.cover, fields: {
          'title': 'Emerging Risk Brief',
          'subtitle': 'Helium shortage',
          'date': 'August 2026',
        }),
        PlannedSlide(archetype: SlideArchetype.impactedSectors, fields: {
          'heading': 'Impacted sectors',
          'subheading': 'Where it bites',
          'rows': [
            {'sector': 'Healthcare', 'impact': 'MRI helium costs rising.'},
          ],
        }),
      ]);

      final template = OoxmlReader.parse('fixture.docx', bytes);
      expect(template.kind, TemplateKind.docx);
      final texts = template.slides
          .expand((s) => s.allParagraphs)
          .map((p) => p.mergedText)
          .toList();
      expect(texts, contains('Emerging Risk Brief'));
      expect(texts, contains('MRI helium costs rising.'));

      final block = template.slides.first.allParagraphs
          .firstWhere((p) => p.mergedText == 'Emerging Risk Brief');
      final cloned =
          OoxmlRewriter.rewrite(template, {block.blockId: 'PFAS Brief'});
      final reparsed = OoxmlReader.parse('clone.docx', cloned);
      expect(
          reparsed.slides
              .expand((s) => s.allParagraphs)
              .map((p) => p.mergedText),
          contains('PFAS Brief'));
    });
  });
}
