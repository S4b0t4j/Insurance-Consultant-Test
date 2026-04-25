import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/article.dart';
import '../providers/news_provider.dart';
import '../utils/theme.dart';
import 'article_detail_modal.dart';

class TrendingSection extends StatelessWidget {
  const TrendingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<NewsProvider>(
      builder: (context, news, _) {
        if (news.articles.isEmpty) return const SizedBox();
        final top3 = _getTop3(news.articles);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.claudeOrange, Color(0xFFE0997B)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.trending_up,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text('Trending Now', style: theme.textTheme.headlineMedium),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.claudeOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('AI-CURATED',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.claudeOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              for (int i = 0; i < top3.length; i++) ...[
                                _TrendingCard(article: top3[i], rank: i + 1),
                                if (i < top3.length - 1) const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: _TrendChart(articles: news.articles),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        for (int i = 0; i < top3.length; i++) ...[
                          _TrendingCard(article: top3[i], rank: i + 1),
                          if (i < top3.length - 1) const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 12),
                        _TrendChart(articles: news.articles),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  List<Article> _getTop3(List<Article> articles) {
    final sorted = [...articles];
    sorted.sort((a, b) {
      // Sort by priority (high first), then breaking, then date
      final priorityDiff = a.priority.index.compareTo(b.priority.index);
      if (priorityDiff != 0) return priorityDiff;
      if (a.isBreaking != b.isBreaking) return a.isBreaking ? -1 : 1;
      return b.publishedAt.compareTo(a.publishedAt);
    });
    return sorted.take(3).toList();
  }
}

class _TrendingCard extends StatelessWidget {
  final Article article;
  final int rank;
  const _TrendingCard({required this.article, required this.rank});

  Color _priorityColor() {
    switch (article.priority) {
      case Priority.high:
        return AppColors.highPriority;
      case Priority.medium:
        return AppColors.mediumPriority;
      case Priority.low:
        return AppColors.lowPriority;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => ArticleDetailModal.show(context, article),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.darkCardBorder
                  : AppColors.lightCardBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: rank == 1
                        ? [AppColors.claudeOrange, const Color(0xFFE0997B)]
                        : [AppColors.persianBlue, AppColors.fluorescentTeal],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      )),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _priorityColor().withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(article.priority.name.toUpperCase(),
                              style: TextStyle(
                                color: _priorityColor(),
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                              )),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${article.primaryCategory.shortName} · ${article.timeAgo}',
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article.headline,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<Article> articles;
  const _TrendChart({required this.articles});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Count articles per category
    final Map<NewsCategory, int> counts = {};
    for (final cat in NewsCategory.values) {
      counts[cat] = 0;
    }
    for (final article in articles) {
      counts[article.primaryCategory] = (counts[article.primaryCategory] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = entries.take(5).toList();

    return Container(
      height: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkCardBorder
              : AppColors.lightCardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Topics by Volume', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: top5.isEmpty
                    ? 10
                    : (top5.first.value + 2).toDouble(),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 2,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < top5.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              top5[idx].key.shortName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 9,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (int i = 0; i < top5.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: top5[i].value.toDouble(),
                          color: i == 0
                              ? AppColors.claudeOrange
                              : AppColors.persianBlue,
                          width: 18,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
