import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/emerging_risk_brief.dart';
import '../models/radar.dart';
import '../models/report_source.dart';
import '../providers/report_studio_provider.dart';
import '../providers/risk_desk_provider.dart';
import '../providers/risk_radar_provider.dart';
import '../services/report/risk_research_service.dart';
import '../utils/theme.dart';
import 'report_studio_screen.dart' show pickFile;

/// Risk Desk: on-demand emerging-risk analysis (Analyze) plus a continuous
/// scanning radar (Radar).
class RiskDeskScreen extends StatelessWidget {
  final VoidCallback? onBuildReport;
  const RiskDeskScreen({super.key, this.onBuildReport});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.hub_outlined), text: 'Analyze'),
                Tab(icon: Icon(Icons.radar_outlined), text: 'Radar'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _AnalyzeTab(onBuildReport: onBuildReport),
                const _RadarTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================= Analyze

class _AnalyzeTab extends StatefulWidget {
  final VoidCallback? onBuildReport;
  const _AnalyzeTab({this.onBuildReport});

  @override
  State<_AnalyzeTab> createState() => _AnalyzeTabState();
}

class _AnalyzeTabState extends State<_AnalyzeTab>
    with AutomaticKeepAliveClientMixin {
  final _topicCtrl = TextEditingController();
  final _focusCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

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
    super.build(context);
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
                'A research swarm investigates it with live web data, then your chosen '
                'specialist lenses assess the commercial insurance implications — the '
                'way a CPCU, CIC, ARM, AIC or actuary would.',
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
              const SizedBox(height: 14),
              // Depth + lens controls.
              Wrap(
                spacing: 16,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<ResearchDepth>(
                    segments: [
                      for (final d in ResearchDepth.values)
                        ButtonSegment(value: d, label: Text(d.label)),
                    ],
                    selected: {desk.depth},
                    onSelectionChanged: desk.running
                        ? null
                        : (s) => desk.setDepth(s.first),
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final lens
                          in RiskResearchService.lensPrompts.keys)
                        FilterChip(
                          label: Text(lens),
                          selected: desk.selectedLenses.contains(lens),
                          onSelected: desk.running
                              ? null
                              : (_) => desk.toggleLens(lens),
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
                SwarmBoard(stages: desk.stages),
              ],
              if (desk.brief != null) ...[
                const SizedBox(height: 28),
                BriefView(
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
                const SizedBox(height: 16),
                _BriefChat(desk: desk),
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

/// Follow-up Q&A thread under a finished brief.
class _BriefChat extends StatefulWidget {
  final RiskDeskProvider desk;
  const _BriefChat({required this.desk});

  @override
  State<_BriefChat> createState() => _BriefChatState();
}

class _BriefChatState extends State<_BriefChat> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final q = _ctrl.text.trim();
    if (q.isEmpty || widget.desk.chatLoading) return;
    _ctrl.clear();
    widget.desk.askFollowUp(q);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desk = widget.desk;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ask a follow-up', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'e.g. "How would this hit a mid-size public hospital\'s program?" or '
              '"What submission questions should an underwriter add?"',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final turn in desk.briefChat)
              Align(
                alignment: turn.role == 'user'
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 640),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: turn.role == 'user'
                        ? AppColors.darkCobalt.withValues(alpha: 0.08)
                        : theme.colorScheme.surface,
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(turn.text),
                ),
              ),
            if (desk.chatLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    enabled: !desk.chatLoading,
                    decoration: const InputDecoration(
                        hintText: 'Ask about this brief…', isDense: true),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: desk.chatLoading ? null : _send,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================= Radar

class _RadarTab extends StatelessWidget {
  const _RadarTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer2<RiskRadarProvider, RiskDeskProvider>(
      builder: (context, radar, desk, _) {
        final config = radar.config;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Continuous risk radar',
                        style: theme.textTheme.headlineMedium),
                  ),
                  Switch(
                    value: config.enabled,
                    onChanged: (v) => radar.setEnabled(v),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Scans the selected news topics on an interval, triages genuinely new '
                'headlines with a low-cost AI pass, and raises findings/alerts for '
                'emerging risks worth practitioner analysis. Runs while this dashboard '
                'tab is open; detection history persists between sessions.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 15, label: Text('15 min')),
                      ButtonSegment(value: 30, label: Text('30 min')),
                      ButtonSegment(value: 60, label: Text('60 min')),
                    ],
                    selected: {config.scanIntervalMinutes},
                    onSelectionChanged: (s) => radar.setInterval(s.first),
                  ),
                  FilterChip(
                    avatar: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Auto-run analysis on detection'),
                    selected: config.autoRunSwarm,
                    onSelected: (v) => radar.setAutoRun(v),
                  ),
                  FilterChip(
                    avatar: const Icon(Icons.discord, size: 16),
                    label: const Text('Discord alerts'),
                    selected: config.discordAlerts,
                    onSelected: (v) => radar.setDiscordAlerts(v),
                  ),
                  OutlinedButton.icon(
                    icon: radar.scanning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.radar, size: 16),
                    label:
                        Text(radar.scanning ? 'Scanning…' : 'Scan now'),
                    onPressed: radar.scanning ? null : () => radar.scanNow(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Monitored topics', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final topic in RssTopic.defaults)
                    FilterChip(
                      label: Text(topic.label),
                      selected: radar.topicSelected(topic),
                      onSelected: (_) => radar.toggleTopic(topic),
                    ),
                ],
              ),
              if (radar.lastScanAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Last scan ${DateFormat.yMMMd().add_jm().format(radar.lastScanAt!)} — ${radar.lastScanSummary}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (radar.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(radar.error!,
                      style:
                          const TextStyle(color: AppColors.highPriority)),
                ),
              const SizedBox(height: 24),
              Text('Findings', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              if (radar.activeFindings.isEmpty)
                Text(
                  'Nothing detected yet. Findings appear here when a scan spots an '
                  'emerging risk worth analyzing.',
                  style: theme.textTheme.bodyMedium,
                ),
              for (final finding in radar.activeFindings)
                _FindingCard(finding: finding, radar: radar, desk: desk),
            ],
          ),
        );
      },
    );
  }
}

class _FindingCard extends StatelessWidget {
  final RadarFinding finding;
  final RiskRadarProvider radar;
  final RiskDeskProvider desk;
  const _FindingCard(
      {required this.finding, required this.radar, required this.desk});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(finding.urgency.name.toUpperCase()),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: switch (finding.urgency) {
                    RadarUrgency.high =>
                      AppColors.highPriority.withValues(alpha: 0.15),
                    RadarUrgency.medium =>
                      AppColors.mediumPriority.withValues(alpha: 0.15),
                    RadarUrgency.low =>
                      AppColors.lowPriority.withValues(alpha: 0.15),
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child:
                      Text(finding.title, style: theme.textTheme.titleLarge),
                ),
                Text(
                  DateFormat.MMMd().add_jm().format(finding.detectedAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(finding.rationale),
            if (finding.headlines.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final h in finding.headlines.take(3))
                Text('• $h', style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (finding.status == RadarFindingStatus.analyzing)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (finding.briefJson == null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.hub, size: 16),
                    label: const Text('Run analysis'),
                    onPressed:
                        desk.running ? null : () => radar.analyzeFinding(finding),
                  )
                else
                  ElevatedButton.icon(
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('View brief'),
                    onPressed: () => _showBrief(context),
                  ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => radar.dismissFinding(finding),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBrief(BuildContext context) {
    final brief = radar.briefOf(finding);
    if (brief == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: BriefView(
              brief: brief,
              onBuildReport: () {
                Navigator.pop(ctx);
                ctx
                    .read<ReportStudioProvider>()
                    .importBrief(
                        RiskResearchService.briefToEditionBrief(brief),
                        brief.topic);
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================ shared views

class SwarmBoard extends StatelessWidget {
  final List<SwarmStage> stages;
  const SwarmBoard({super.key, required this.stages});

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

class BriefView extends StatelessWidget {
  final EmergingRiskBrief brief;
  final VoidCallback onBuildReport;
  const BriefView(
      {super.key, required this.brief, required this.onBuildReport});

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
