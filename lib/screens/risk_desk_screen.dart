import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/emerging_risk_brief.dart';
import '../providers/report_studio_provider.dart';
import '../providers/risk_desk_provider.dart';
import '../utils/theme.dart';
import 'report_studio_screen.dart' show pickFile;

/// Risk Desk: type one emerging risk, get a practitioner-grade brief from a
/// staged swarm of research + specialist agents.
class RiskDeskScreen extends StatefulWidget {
  final VoidCallback? onBuildReport;
  const RiskDeskScreen({super.key, this.onBuildReport});

  @override
  State<RiskDeskScreen> createState() => _RiskDeskScreenState();
}

class _RiskDeskScreenState extends State<RiskDeskScreen> {
  final _topicCtrl = TextEditingController();
  final _focusCtrl = TextEditingController();

  static const _examples = [
    'Helium supply shortage',
    'PFAS litigation expansion',
    'Convective storm clustering',
    'AI liability for professional services',
    'Grid instability from data-center demand',
  ];

  @override
  void dispose() {
    _topicCtrl.dispose();
    _focusCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<RiskDeskProvider>(
      builder: (context, desk, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Describe an emerging risk',
                  style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'A research swarm investigates it with live web data, then underwriter, '
                'broker and risk-manager specialists assess the commercial insurance '
                'implications — the way a CPCU, CIC or ARM would.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: _topicCtrl,
                          enabled: !desk.running,
                          decoration: const InputDecoration(
                            labelText: 'Emerging risk',
                            hintText:
                                'e.g. "Helium supply shortage" or "PFAS litigation"',
                          ),
                          onSubmitted: (_) => _run(desk),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _focusCtrl,
                          enabled: !desk.running,
                          decoration: const InputDecoration(
                            labelText:
                                'Optional focus (segment, lines of business…)',
                            hintText: 'e.g. public entities; property & cyber',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        icon: desk.running
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.hub),
                        label: Text(
                            desk.running ? 'Swarm running…' : 'Run analysis'),
                        onPressed: desk.running ? null : () => _run(desk),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.attach_file, size: 16),
                        label: Text(desk.uploads.isEmpty
                            ? 'Attach material'
                            : '${desk.uploads.length} attached'),
                        onPressed: desk.running
                            ? null
                            : () async {
                                final picked = await pickFile(
                                    ['pdf', 'docx', 'pptx', 'txt', 'md']);
                                if (picked != null) {
                                  await desk.addUpload(picked.$1, picked.$2);
                                }
                              },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final example in _examples)
                    ActionChip(
                      label: Text(example),
                      onPressed: desk.running
                          ? null
                          : () =>
                              setState(() => _topicCtrl.text = example),
                    ),
                ],
              ),
              for (final upload in desk.uploads)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.attachment, size: 16),
                  title: Text(upload.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => desk.removeUpload(upload),
                  ),
                ),
              if (desk.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(desk.error!,
                      style:
                          const TextStyle(color: AppColors.highPriority)),
                ),
              if (desk.webSearchDegraded)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Live web search wasn\'t available for this API key — analysis used feeds and uploads only.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.mediumPriority),
                  ),
                ),
              if (desk.stages.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Agent swarm', style: theme.textTheme.titleLarge),
                const SizedBox(height: 10),
                _SwarmBoard(stages: desk.stages),
              ],
              if (desk.brief != null) ...[
                const SizedBox(height: 28),
                _BriefView(
                  brief: desk.brief!,
                  onBuildReport: () {
                    final payload = desk.editionBrief;
                    if (payload == null) return;
                    context
                        .read<ReportStudioProvider>()
                        .importBrief(payload, desk.brief!.topic);
                    widget.onBuildReport?.call();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _run(RiskDeskProvider desk) {
    if (_topicCtrl.text.trim().isEmpty) return;
    desk.run(_topicCtrl.text, _focusCtrl.text);
  }
}

class _SwarmBoard extends StatelessWidget {
  final List<SwarmStage> stages;
  const _SwarmBoard({required this.stages});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final stage in stages)
          Container(
            width: 300,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: switch (stage.status) {
                  SwarmStageStatus.running => AppColors.claudeOrange,
                  SwarmStageStatus.done => AppColors.lowPriority,
                  SwarmStageStatus.failed => AppColors.highPriority,
                  _ => theme.dividerColor,
                },
              ),
            ),
            child: Row(
              children: [
                switch (stage.status) {
                  SwarmStageStatus.pending => Icon(Icons.schedule,
                      size: 18, color: theme.disabledColor),
                  SwarmStageStatus.running => const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SwarmStageStatus.done => const Icon(Icons.check_circle,
                      size: 18, color: AppColors.lowPriority),
                  SwarmStageStatus.failed => const Icon(Icons.error,
                      size: 18, color: AppColors.highPriority),
                  SwarmStageStatus.skipped =>
                    Icon(Icons.remove, size: 18, color: theme.disabledColor),
                },
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stage.label,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if (stage.note.isNotEmpty)
                        Text(stage.note,
                            style: theme.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BriefView extends StatelessWidget {
  final EmergingRiskBrief brief;
  final VoidCallback onBuildReport;
  const _BriefView({required this.brief, required this.onBuildReport});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Emerging Risk Brief: ${brief.topic}',
                      style: theme.textTheme.headlineMedium),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.slideshow),
                  label: const Text('Build report from this'),
                  onPressed: onBuildReport,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(brief.summary, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            _section(theme, 'Velocity & timeline', brief.velocity),
            if (brief.stats.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  for (final stat in brief.stats.take(6))
                    SizedBox(
                      width: 220,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stat.value,
                              style: theme.textTheme.displaySmall?.copyWith(
                                  color: AppColors.claudeOrange)),
                          Text(stat.label,
                              style: theme.textTheme.bodySmall),
                          if (stat.source.isNotEmpty)
                            Text(stat.source,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: theme.disabledColor)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Text('Lines of business', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final line in brief.lines)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(line.line,
                              style: theme.textTheme.titleLarge),
                        ),
                        Chip(
                          label: Text(line.severity.toUpperCase()),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: switch (line.severity) {
                            'high' =>
                              AppColors.highPriority.withValues(alpha: 0.15),
                            'medium' => AppColors.mediumPriority
                                .withValues(alpha: 0.15),
                            _ =>
                              AppColors.lowPriority.withValues(alpha: 0.15),
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(line.exposure),
                    const SizedBox(height: 6),
                    Text('Underwriting: ${line.underwritingConsiderations}',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            _listSection(theme, 'Coverage gaps', brief.coverageGaps),
            _section(theme, 'Market outlook', brief.marketOutlook),
            _listSection(
                theme, 'Recommended actions', brief.recommendedActions),
            if (brief.newsItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Recent developments', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              for (final n in brief.newsItems.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• ${n.date}: ${n.headline} — ${n.summary}'),
                ),
            ],
            if (brief.citations.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Sources', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              for (final citation in brief.citations.take(12))
                Text('• ${citation.title} — ${citation.url}',
                    style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String title, String body) {
    if (body.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }

  Widget _listSection(ThemeData theme, String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          for (final item in items) Text('• $item'),
        ],
      ),
    );
  }
}
