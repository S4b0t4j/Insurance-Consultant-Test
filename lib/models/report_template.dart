import 'dart:typed_data';

enum TemplateKind { pptx, docx }

/// One paragraph's worth of replaceable text inside a shape or table cell.
class ParagraphInventory {
  /// Stable identifier used in the AI contract, e.g. `s3_sp7_p0` for pptx or
  /// `p12` / `tbl0_r1_c2_p0` for docx.
  final String blockId;
  final int paragraphIndex;

  /// Text of all runs in the paragraph concatenated.
  final String mergedText;

  /// Number of runs the paragraph had (formatting variance indicator).
  final int runCount;

  const ParagraphInventory({
    required this.blockId,
    required this.paragraphIndex,
    required this.mergedText,
    required this.runCount,
  });

  /// Length budget the replacement text should stay within.
  int get charBudget => mergedText.length;

  bool get isMultiRun => runCount > 1;
}

class ShapeInventory {
  final String shapeId;
  final String name;
  final bool isTableCell;

  /// Position/size in EMU when available (pptx only).
  final int? offXEmu, offYEmu, extXEmu, extYEmu;
  final List<ParagraphInventory> paragraphs;

  const ShapeInventory({
    required this.shapeId,
    required this.name,
    this.isTableCell = false,
    this.offXEmu,
    this.offYEmu,
    this.extXEmu,
    this.extYEmu,
    required this.paragraphs,
  });
}

class SlideInventory {
  /// 1-based slide number in presentation order. For docx this is always 1.
  final int index;

  /// Archive path of the slide part, e.g. `ppt/slides/slide4.xml`.
  final String partPath;
  final List<ShapeInventory> shapes;

  const SlideInventory({
    required this.index,
    required this.partPath,
    required this.shapes,
  });

  Iterable<ParagraphInventory> get allParagraphs =>
      shapes.expand((s) => s.paragraphs);

  int get textBlockCount => allParagraphs.length;
}

/// Theme information extracted from a template for rebuild mode.
class ExtractedTheme {
  /// Hex colors without '#', most dominant first.
  final List<String> colors;
  final String headingFont;
  final String bodyFont;
  final int slideWidthEmu;
  final int slideHeightEmu;

  const ExtractedTheme({
    required this.colors,
    required this.headingFont,
    required this.bodyFont,
    this.slideWidthEmu = 12192000,
    this.slideHeightEmu = 6858000,
  });

  String get primary => colors.isNotEmpty ? colors.first : '000F47';
  String get accent1 => colors.length > 1 ? colors[1] : '82BAFF';
  String get accent2 => colors.length > 2 ? colors[2] : 'FFBF00';
}

class ReportTemplate {
  final String fileName;
  final TemplateKind kind;
  final Uint8List bytes;
  final List<SlideInventory> slides;
  final ExtractedTheme theme;
  final DateTime uploadedAt;

  ReportTemplate({
    required this.fileName,
    required this.kind,
    required this.bytes,
    required this.slides,
    required this.theme,
    DateTime? uploadedAt,
  }) : uploadedAt = uploadedAt ?? DateTime.now();

  int get slideCount => slides.length;

  int get totalTextBlocks =>
      slides.fold(0, (sum, s) => sum + s.textBlockCount);
}
