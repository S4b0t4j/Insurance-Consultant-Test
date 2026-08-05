enum GenerationMode { clone, rebuild }

enum JobStatus { idle, generating, reviewing, done, error }

/// The nine slide archetypes learned from a public-entity risk report deck.
enum SlideArchetype {
  cover,
  agenda,
  executiveSummary,
  sectionDivider,
  keyMetrics,
  impactedSectors,
  newsUpdates,
  capabilitiesTable,
  contact,
}

extension SlideArchetypeInfo on SlideArchetype {
  String get label {
    switch (this) {
      case SlideArchetype.cover:
        return 'Cover';
      case SlideArchetype.agenda:
        return 'Agenda';
      case SlideArchetype.executiveSummary:
        return 'Executive summary';
      case SlideArchetype.sectionDivider:
        return 'Section divider';
      case SlideArchetype.keyMetrics:
        return 'Key metrics';
      case SlideArchetype.impactedSectors:
        return 'Impacted sectors';
      case SlideArchetype.newsUpdates:
        return 'News updates';
      case SlideArchetype.capabilitiesTable:
        return 'Capabilities table';
      case SlideArchetype.contact:
        return 'Contact';
    }
  }

  String get description {
    switch (this) {
      case SlideArchetype.cover:
        return 'Title, subtitle and edition date';
      case SlideArchetype.agenda:
        return 'Numbered list of report sections';
      case SlideArchetype.executiveSummary:
        return 'Headline rows summarizing each section';
      case SlideArchetype.sectionDivider:
        return 'Full-bleed divider with section title';
      case SlideArchetype.keyMetrics:
        return 'Stat tiles: big number + caption';
      case SlideArchetype.impactedSectors:
        return 'Sector rows with impact narratives';
      case SlideArchetype.newsUpdates:
        return 'Dated news items with summaries';
      case SlideArchetype.capabilitiesTable:
        return 'Table of service offerings';
      case SlideArchetype.contact:
        return 'Contact block and closing statement';
    }
  }
}

/// A planned slide in rebuild mode: archetype + AI-filled fields.
class PlannedSlide {
  final SlideArchetype archetype;

  /// Field payload; shape depends on archetype (see rebuild contract).
  Map<String, dynamic> fields;

  PlannedSlide({required this.archetype, Map<String, dynamic>? fields})
      : fields = fields ?? {};
}

/// Replacement text for one paragraph block in clone mode.
class BlockReplacement {
  final String blockId;
  final String original;
  String generated;
  String? edited;
  final int charBudget;

  BlockReplacement({
    required this.blockId,
    required this.original,
    required this.generated,
    required this.charBudget,
  });

  String get effectiveText => edited ?? generated;

  bool get overBudget =>
      charBudget > 0 && effectiveText.length > (charBudget * 1.15).ceil() + 4;

  bool get isChanged => effectiveText != original;
}

/// Configuration for one generation run.
class ReportJobConfig {
  GenerationMode mode;
  String editionTitle;
  String editionDate;
  String topicFocus;

  ReportJobConfig({
    this.mode = GenerationMode.clone,
    this.editionTitle = 'Risk Report for Public Entities',
    this.editionDate = '',
    this.topicFocus = '',
  });
}
