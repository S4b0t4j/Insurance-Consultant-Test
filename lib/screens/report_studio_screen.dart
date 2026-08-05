import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/report_job.dart';
import '../models/report_source.dart';
import '../models/report_template.dart';
import '../providers/report_studio_provider.dart';
import '../utils/theme.dart';

class ReportStudioScreen extends StatelessWidget {
  const ReportStudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportStudioProvider>(
      builder: (context, studio, _) {
        return Column(
          children: [
            _StepBar(studio: studio),
            if (studio.error != null)
              _Banner(
                text: studio.error!,
                color: AppColors.highPriority,
                onDismiss: () {
                  studio.resetJob();
                },
              ),
            if (!studio.hasApiKey)
              const _Banner(
                text:
                    'No Claude API key configured — generation will fail. An admin can add one under Admin → Claude API.',
                color: AppColors.mediumPriority,
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _stepContent(context, studio),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _stepContent(BuildContext context, ReportStudioProvider studio) {
    switch (studio.step) {
      case 0:
        return _TemplateStep(studio: studio);
      case 1:
        return _SourcesStep(studio: studio);
      case 2:
        return _ConfigureStep(studio: studio);
      case 3:
        return _GenerateStep(studio: studio);
      default:
        return _DownloadStep(studio: studio);
    }
  }
}

// ------------------------------------------------------------------ chrome

class _StepBar extends StatelessWidget {
  final ReportStudioProvider studio;
  const _StepBar({required this.studio});

  static const _labels = [
    'Template',
    'Sources',
    'Configure',
    'Generate & review',
    'Download'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: i <= studio.step ? () => studio.goToStep(i) : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: i == studio.step
                      ? AppColors.darkCobalt
                      : (i < studio.step
                          ? AppColors.darkCobalt.withValues(alpha: 0.12)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: i == studio.step
                          ? Colors.white
                          : AppColors.darkCobalt.withValues(alpha: 0.7),
                      child: Text('${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: i == studio.step
                                ? AppColors.darkCobalt
                                : Colors.white,
                          )),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _labels[i],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: i == studio.step
                            ? Colors.white
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < _labels.length - 1)
              Expanded(
                child: Divider(
                  indent: 6,
                  endIndent: 6,
                  color: theme.dividerColor,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback? onDismiss;
  const _Banner({required this.text, required this.color, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}

Future<(String, Uint8List)?> pickFile(List<String> extensions) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
    withData: true,
  );
  final file = result?.files.firstOrNull;
  final bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  return (file.name, bytes);
}

// ----------------------------------------------------------- step 1: template

class _TemplateStep extends StatelessWidget {
  final ReportStudioProvider studio;
  const _TemplateStep({required this.studio});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final template = studio.template;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upload a formatting template',
            style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'A .pptx or .docx whose look you want to reuse — e.g. a previous edition of the risk report. '
          'The generator keeps its formatting and swaps in new content.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(template == null
                  ? 'Choose .pptx / .docx'
                  : 'Replace template'),
              onPressed: () async {
                final picked = await pickFile(['pptx', 'docx']);
                if (picked != null) {
                  await studio.uploadTemplate(picked.$1, picked.$2);
                }
              },
            ),
            if (template != null) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: studio.clearTemplate,
                child: const Text('Remove'),
              ),
            ],
          ],
        ),
        if (template != null) ...[
          const SizedBox(height: 24),
          _TemplateSummaryCard(template: template),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next: sources'),
            onPressed: () => studio.goToStep(1),
          ),
        ],
      ],
    );
  }
}

class _TemplateSummaryCard extends StatelessWidget {
  final ReportTemplate template;
  const _TemplateSummaryCard({required this.template});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  template.kind == TemplateKind.pptx
                      ? Icons.slideshow
                      : Icons.description,
                  color: AppColors.darkCobalt,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(template.fileName,
                      style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _fact(theme,
                    template.kind == TemplateKind.pptx ? 'Slides' : 'Sections',
                    '${template.slideCount}'),
                _fact(theme, 'Text blocks', '${template.totalTextBlocks}'),
                _fact(theme, 'Heading font', template.theme.headingFont),
                _fact(theme, 'Body font', template.theme.bodyFont),
              ],
            ),
            const SizedBox(height: 16),
            Text('Detected theme colors', style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final hex in template.theme.colors.take(6))
                  Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Color(int.parse('FF$hex', radix: 16)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Tooltip(message: '#$hex', child: const SizedBox()),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fact(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(value,
            style: theme.textTheme.titleLarge
                ?.copyWith(color: AppColors.darkCobalt)),
      ],
    );
  }
}

// ----------------------------------------------------------- step 2: sources

class _SourcesStep extends StatelessWidget {
  final ReportStudioProvider studio;
  const _SourcesStep({required this.studio});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allTopics = [...RssTopic.defaults, ...studio.customTopics];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add content sources', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'The new edition is written from these: live news feeds plus any documents or '
          'thought-leadership material you upload (PDF, Word, PowerPoint, text).',
          style: theme.textTheme.bodyMedium,
        ),
        if (studio.importedBrief != null) ...[
          const SizedBox(height: 12),
          Chip(
            avatar: const Icon(Icons.psychology, size: 18),
            label: Text('Risk Desk brief loaded: ${studio.importedBriefLabel}'),
            backgroundColor: AppColors.claudeOrange.withValues(alpha: 0.15),
          ),
        ],
        const SizedBox(height: 20),
        Text('Live news topics', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final topic in allTopics)
              FilterChip(
                label: Text(topic.label),
                selected: studio.selectedTopics.contains(topic),
                onSelected: (_) => studio.toggleTopic(topic),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Custom query'),
              onPressed: () => _addCustomTopic(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Uploaded documents', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        for (final source in studio.sources)
          Card(
            child: ListTile(
              leading: Icon(_iconFor(source.kind)),
              title: Text(source.name),
              subtitle: Text(
                  '${source.kind.name.toUpperCase()} · ${(source.charCount / 1000).toStringAsFixed(1)}k characters extracted'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => studio.removeSource(source),
              ),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('Upload supporting document'),
          onPressed: () async {
            final picked =
                await pickFile(['pdf', 'docx', 'pptx', 'txt', 'md']);
            if (picked != null) {
              await studio.addUploadSource(picked.$1, picked.$2);
            }
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Next: configure'),
          onPressed: () => studio.goToStep(2),
        ),
      ],
    );
  }

  IconData _iconFor(SourceKind kind) {
    switch (kind) {
      case SourceKind.pdf:
        return Icons.picture_as_pdf_outlined;
      case SourceKind.docx:
        return Icons.description_outlined;
      case SourceKind.txt:
        return Icons.notes_outlined;
      case SourceKind.rss:
        return Icons.rss_feed;
    }
  }

  void _addCustomTopic(BuildContext context) {
    final labelCtrl = TextEditingController();
    final queryCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom news topic'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: queryCtrl,
              decoration: const InputDecoration(
                  labelText: 'Google News search query'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (queryCtrl.text.trim().isNotEmpty) {
                studio.addCustomTopic(
                  labelCtrl.text.trim().isEmpty
                      ? queryCtrl.text.trim()
                      : labelCtrl.text.trim(),
                  queryCtrl.text.trim(),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------- step 3: configure

class _ConfigureStep extends StatefulWidget {
  final ReportStudioProvider studio;
  const _ConfigureStep({required this.studio});

  @override
  State<_ConfigureStep> createState() => _ConfigureStepState();
}

class _ConfigureStepState extends State<_ConfigureStep> {
  late final TextEditingController _title;
  late final TextEditingController _date;
  late final TextEditingController _topic;

  ReportStudioProvider get studio => widget.studio;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: studio.config.editionTitle);
    _date = TextEditingController(text: studio.config.editionDate);
    _topic = TextEditingController(text: studio.config.topicFocus);
  }

  @override
  void dispose() {
    _title.dispose();
    _date.dispose();
    _topic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Configure the new edition',
            style: theme.textTheme.headlineMedium),
        const SizedBox(height: 20),
        SegmentedButton<GenerationMode>(
          segments: const [
            ButtonSegment(
              value: GenerationMode.clone,
              icon: Icon(Icons.copy_all),
              label: Text('Clone template formatting'),
            ),
            ButtonSegment(
              value: GenerationMode.rebuild,
              icon: Icon(Icons.auto_awesome_mosaic),
              label: Text('Rebuild from theme'),
            ),
          ],
          selected: {studio.config.mode},
          onSelectionChanged: (s) =>
              setState(() => studio.config.mode = s.first),
        ),
        const SizedBox(height: 8),
        Text(
          studio.config.mode == GenerationMode.clone
              ? 'Keeps your uploaded file pixel-for-pixel (backgrounds, images, charts) and rewrites only the text.'
              : 'Builds a fresh document styled with the template\'s colors and fonts — pick and reorder the slide types below.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 520,
          child: Column(
            children: [
              TextField(
                controller: _title,
                decoration:
                    const InputDecoration(labelText: 'Report title'),
                onChanged: (v) => studio.config.editionTitle = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _date,
                decoration: const InputDecoration(
                    labelText: 'Edition date (e.g. "August 2026 edition")'),
                onChanged: (v) => studio.config.editionDate = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _topic,
                decoration: const InputDecoration(
                    labelText: 'Topic focus (optional)'),
                onChanged: (v) => studio.config.topicFocus = v,
              ),
            ],
          ),
        ),
        if (studio.config.mode == GenerationMode.rebuild) ...[
          const SizedBox(height: 24),
          Text('Slide plan (drag to reorder)',
              style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          SizedBox(
            width: 620,
            child: _ArchetypePicker(studio: studio),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Generate'),
          onPressed: studio.canGenerate
              ? () {
                  studio.goToStep(3);
                  studio.generate();
                }
              : null,
        ),
        if (!studio.canGenerate)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Upload a template (step 1) and add at least one source (step 2) first.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.mediumPriority),
            ),
          ),
      ],
    );
  }
}

class _ArchetypePicker extends StatelessWidget {
  final ReportStudioProvider studio;
  const _ArchetypePicker({required this.studio});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: true,
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex--;
            final item = studio.rebuildPlanOrder.removeAt(oldIndex);
            studio.rebuildPlanOrder.insert(newIndex, item);
            (context as Element).markNeedsBuild();
          },
          children: [
            for (var i = 0; i < studio.rebuildPlanOrder.length; i++)
              ListTile(
                key: ValueKey('arch_$i'),
                dense: true,
                leading: Text('${i + 1}'),
                title: Text(studio.rebuildPlanOrder[i].label),
                subtitle: Text(studio.rebuildPlanOrder[i].description),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  onPressed: () {
                    studio.rebuildPlanOrder.removeAt(i);
                    (context as Element).markNeedsBuild();
                  },
                ),
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 6,
            children: [
              for (final archetype in SlideArchetype.values)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 14),
                  label: Text(archetype.label),
                  onPressed: () {
                    studio.rebuildPlanOrder.add(archetype);
                    (context as Element).markNeedsBuild();
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------- step 4: generate/review

class _GenerateStep extends StatelessWidget {
  final ReportStudioProvider studio;
  const _GenerateStep({required this.studio});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (studio.status == JobStatus.generating) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Generating…', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 20),
          LinearProgressIndicator(value: studio.progress),
          const SizedBox(height: 12),
          Text(studio.progressLabel),
        ],
      );
    }

    if (studio.status == JobStatus.error) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Generation failed', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(studio.error ?? 'Unknown error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              studio.resetJob();
              studio.goToStep(2);
            },
            child: const Text('Back to configure'),
          ),
        ],
      );
    }

    if (studio.status != JobStatus.reviewing &&
        studio.status != JobStatus.done) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nothing generated yet', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => studio.goToStep(2),
            child: const Text('Go to configure'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Review generated content',
                  style: theme.textTheme.headlineMedium),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Continue to download'),
              onPressed: () => studio.goToStep(4),
            ),
          ],
        ),
        for (final w in studio.warnings)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('⚠ $w',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.mediumPriority)),
          ),
        const SizedBox(height: 16),
        if (studio.config.mode == GenerationMode.clone)
          _CloneReview(studio: studio)
        else
          _RebuildReview(studio: studio),
      ],
    );
  }
}

class _CloneReview extends StatelessWidget {
  final ReportStudioProvider studio;
  const _CloneReview({required this.studio});

  @override
  Widget build(BuildContext context) {
    final template = studio.template!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final slide in template.slides)
          if (slide.textBlockCount > 0)
            Card(
              margin: const EdgeInsets.only(bottom: 14),
              child: ExpansionTile(
                title: Text(
                    '${template.kind == TemplateKind.pptx ? 'Slide' : 'Section'} ${slide.index} · ${slide.textBlockCount} blocks'),
                subtitle: Text(
                  _slidePreview(slide),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Regenerate'),
                  onPressed: () => studio.regenerateSlide(slide),
                ),
                children: [
                  for (final para in slide.allParagraphs)
                    _BlockEditor(
                      replacement: studio.replacements[para.blockId],
                      onChanged: (v) =>
                          studio.editReplacement(para.blockId, v),
                    ),
                ],
              ),
            ),
      ],
    );
  }

  String _slidePreview(SlideInventory slide) {
    final first = slide.allParagraphs.isEmpty
        ? ''
        : slide.allParagraphs.first.mergedText;
    return first.length > 90 ? '${first.substring(0, 90)}…' : first;
  }
}

class _BlockEditor extends StatelessWidget {
  final BlockReplacement? replacement;
  final ValueChanged<String> onChanged;
  const _BlockEditor({required this.replacement, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = replacement;
    if (r == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Original: ${r.original}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (r.overBudget)
                Chip(
                  label: Text(
                      'over budget (${r.effectiveText.length}/${r.charBudget})'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      AppColors.mediumPriority.withValues(alpha: 0.15),
                ),
            ],
          ),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: r.effectiveText,
            maxLines: null,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: r.isChanged ? null : theme.disabledColor,
            ),
            decoration: const InputDecoration(isDense: true),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _RebuildReview extends StatelessWidget {
  final ReportStudioProvider studio;
  const _RebuildReview({required this.studio});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < studio.plannedSlides.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Slide ${i + 1} · ${studio.plannedSlides[i].archetype.label}',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    _fieldsPreview(studio.plannedSlides[i].fields),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _fieldsPreview(Map<String, dynamic> fields) {
    final buf = StringBuffer();
    fields.forEach((k, v) {
      if (v is String && v.isNotEmpty) {
        buf.writeln('$k: $v');
      } else if (v is List && v.isNotEmpty) {
        buf.writeln('$k: ${v.length} items');
      }
    });
    return buf.isEmpty ? '(empty)' : buf.toString().trim();
  }
}

// ----------------------------------------------------------- step 5: download

class _DownloadStep extends StatelessWidget {
  final ReportStudioProvider studio;
  const _DownloadStep({required this.studio});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isClone = studio.config.mode == GenerationMode.clone;
    final ready = studio.status == JobStatus.reviewing ||
        studio.status == JobStatus.done;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Download', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 12),
        if (!ready)
          const Text('Generate content first (step 4).')
        else ...[
          Text(
            isClone
                ? 'The template file is cloned with your reviewed text swapped in — formatting, images and charts untouched.'
                : 'A fresh document styled from the template theme.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          if (isClone)
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: Text(
                  'Download .${studio.template?.kind == TemplateKind.pptx ? 'pptx' : 'docx'}'),
              onPressed: () => studio.download(),
            )
          else
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.slideshow),
                  label: const Text('Download .pptx'),
                  onPressed: () => studio.downloadRebuildAs(asPptx: true),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.description),
                  label: const Text('Download .docx'),
                  onPressed: () => studio.downloadRebuildAs(asPptx: false),
                ),
              ],
            ),
          if (studio.status == JobStatus.done) ...[
            const SizedBox(height: 20),
            Text('Downloaded. Start another edition?',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                studio.resetJob();
                studio.goToStep(0);
              },
              child: const Text('New run'),
            ),
          ],
        ],
      ],
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
