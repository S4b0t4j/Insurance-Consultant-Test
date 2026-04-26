import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/article.dart';
import '../providers/ai_provider.dart';
import '../services/claude_service.dart';
import '../utils/theme.dart';

class ArticleDetailModal extends StatefulWidget {
  final Article article;
  const ArticleDetailModal({super.key, required this.article});

  static Future<void> show(BuildContext context, Article article) {
    return showDialog(
      context: context,
      builder: (_) => ArticleDetailModal(article: article),
    );
  }

  @override
  State<ArticleDetailModal> createState() => _ArticleDetailModalState();
}

class _ArticleDetailModalState extends State<ArticleDetailModal> {
  String? _summary;
  RiskAssessment? _risk;
  bool _loadingSummary = false;
  bool _loadingRisk = false;

  Future<void> _generateSummary() async {
    setState(() => _loadingSummary = true);
    final ai = context.read<AIProvider>();
    final summary = await ai.getSummary(widget.article);
    if (mounted) setState(() {
      _summary = summary;
      _loadingSummary = false;
    });
  }

  Future<void> _assessRisk() async {
    setState(() => _loadingRisk = true);
    final ai = context.read<AIProvider>();
    final risk = await ai.getRiskAssessment(widget.article);
    if (mounted) setState(() {
      _risk = risk;
      _loadingRisk = false;
    });
  }

  Color _priorityColor() {
    switch (widget.article.priority) {
      case Priority.high:
        return AppColors.highPriority;
      case Priority.medium:
        return AppColors.mediumPriority;
      case Priority.low:
        return AppColors.lowPriority;
    }
  }

  Color _riskColor(int score) {
    if (score >= 8) return AppColors.highPriority;
    if (score >= 5) return AppColors.mediumPriority;
    return AppColors.lowPriority;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final article = widget.article;
    final size = MediaQuery.of(context).size;
    final ai = context.watch<AIProvider>();
    _summary ??= ai.cachedSummary(article.id);
    _risk ??= ai.cachedRisk(article.id);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? AppColors.darkCardBorder
                        : AppColors.lightCardBorder,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _priorityColor().withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      article.priority.name.toUpperCase(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _priorityColor(),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (article.isBreaking) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.breaking,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.bolt, size: 12, color: Colors.white),
                          SizedBox(width: 3),
                          Text('BREAKING',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      article.primaryCategory.displayName,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(article.headline, style: theme.textTheme.displaySmall),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.business,
                            size: 14,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text(article.sourceName,
                            style: theme.textTheme.bodyMedium),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time,
                            size: 14,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat.yMMMd().add_jm().format(article.publishedAt),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Summary', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(article.summary, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 24),
                    // AI Summary section
                    _AiSection(
                      title: 'AI Executive Summary',
                      icon: Icons.auto_awesome,
                      action: _summary == null && !_loadingSummary
                          ? TextButton.icon(
                              onPressed: _generateSummary,
                              icon: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text('Generate'),
                            )
                          : null,
                      child: _loadingSummary
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: LinearProgressIndicator(),
                            )
                          : _summary != null
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.claudeCream,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(_summary!,
                                      style: theme.textTheme.bodyMedium),
                                )
                              : const SizedBox(),
                    ),
                    const SizedBox(height: 16),
                    // Risk score section
                    _AiSection(
                      title: 'AI Risk Assessment',
                      icon: Icons.warning_amber_outlined,
                      action: _risk == null && !_loadingRisk
                          ? TextButton.icon(
                              onPressed: _assessRisk,
                              icon: const Icon(Icons.analytics_outlined, size: 16),
                              label: const Text('Assess'),
                            )
                          : null,
                      child: _loadingRisk
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: LinearProgressIndicator(),
                            )
                          : _risk != null
                              ? _RiskCard(risk: _risk!, getColor: _riskColor)
                              : const SizedBox(),
                    ),
                    const SizedBox(height: 24),
                    // Risk Analysis (existing)
                    if (article.riskAnalysis.isNotEmpty) ...[
                      Text('Insurance Risk Analysis',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(article.riskAnalysis,
                          style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 16),
                    ],
                    // Risk tags
                    if (article.riskTags.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: article.riskTags
                            .map((t) => Chip(
                                  label: Text(t),
                                  backgroundColor:
                                      AppColors.angelina.withValues(alpha: 0.4),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (article.actionRequired != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.claudeOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.claudeOrange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.flag,
                                color: AppColors.claudeOrange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Action Required',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                              color: AppColors.claudeOrange)),
                                  const SizedBox(height: 4),
                                  Text(article.actionRequired!,
                                      style: theme.textTheme.bodyMedium),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Footer actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppColors.darkCardBorder
                        : AppColors.lightCardBorder,
                  ),
                ),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Close'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        launchUrl(
                          Uri.parse(article.searchUrl),
                          mode: LaunchMode.externalApplication,
                          webOnlyWindowName: '_blank',
                        );
                      },
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Find Articles'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? action;
  final Widget child;

  const _AiSection({
    required this.title,
    required this.icon,
    this.action,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.claudeOrange),
            const SizedBox(width: 8),
            Text(title, style: theme.textTheme.titleLarge),
            const Spacer(),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _RiskCard extends StatelessWidget {
  final RiskAssessment risk;
  final Color Function(int) getColor;
  const _RiskCard({required this.risk, required this.getColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = getColor(risk.score);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${risk.score}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          )),
                      const Text('/10',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Risk Score', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    _MetricBar(
                      label: 'Severity',
                      value: risk.severity,
                      color: color,
                    ),
                    const SizedBox(height: 4),
                    _MetricBar(
                      label: 'Likelihood',
                      value: risk.likelihood,
                      color: color,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(risk.rationale, style: theme.textTheme.bodyMedium),
          if (risk.affectedSectors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: risk.affectedSectors
                  .map((s) => Chip(
                        label: Text(s),
                        labelStyle: const TextStyle(fontSize: 11),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
          if (risk.coverageGapNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Coverage notes: ${risk.coverageGapNotes}',
                style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _MetricBar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: theme.textTheme.bodySmall)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 10,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
            width: 24,
            child: Text('$value',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.end)),
      ],
    );
  }
}
