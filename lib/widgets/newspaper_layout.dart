import 'package:flutter/material.dart';
import '../models/article.dart';
import '../utils/theme.dart';
import 'article_detail_modal.dart';

class NewspaperLayout extends StatelessWidget {
  final List<Article> articles;
  const NewspaperLayout({super.key, required this.articles});

  Color _priorityColor(Priority p) {
    switch (p) {
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
    if (articles.isEmpty) return const SizedBox();
    final theme = Theme.of(context);
    final featured = articles.first;
    final secondaries = articles.skip(1).take(2).toList();
    final remaining = articles.skip(3).toList();
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Newspaper masthead
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  width: 3,
                ),
                bottom: BorderSide(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'THE MARSH EDUCATION GAZETTE',
                  style: theme.textTheme.displaySmall?.copyWith(
                    letterSpacing: 2,
                    fontSize: 28,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Insurance Risk Intelligence · ${DateTime.now().toString().split(' ').first}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Featured article
          _FeaturedNewspaperArticle(
            article: featured,
            priorityColor: _priorityColor(featured.priority),
          ),
          const SizedBox(height: 24),
          // Two-column secondaries
          if (secondaries.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 700) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < secondaries.length; i++) ...[
                        Expanded(
                          child: _NewspaperColumnArticle(
                            article: secondaries[i],
                            priorityColor:
                                _priorityColor(secondaries[i].priority),
                          ),
                        ),
                        if (i < secondaries.length - 1) ...[
                          const SizedBox(width: 16),
                          Container(
                            width: 1,
                            height: 200,
                            color: theme.dividerColor,
                          ),
                          const SizedBox(width: 16),
                        ],
                      ]
                    ],
                  );
                } else {
                  return Column(
                    children: secondaries
                        .map((a) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _NewspaperColumnArticle(
                                article: a,
                                priorityColor: _priorityColor(a.priority),
                              ),
                            ))
                        .toList(),
                  );
                }
              },
            ),
          const SizedBox(height: 32),
          // Remaining: 3-column grid
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 1200
                  ? 3
                  : constraints.maxWidth > 700
                      ? 2
                      : 1;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: remaining.map((a) {
                  final width = (constraints.maxWidth - 16 * (cols - 1)) / cols;
                  return SizedBox(
                    width: width,
                    child: _SmallNewspaperArticle(
                      article: a,
                      priorityColor: _priorityColor(a.priority),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeaturedNewspaperArticle extends StatelessWidget {
  final Article article;
  final Color priorityColor;
  const _FeaturedNewspaperArticle({
    required this.article,
    required this.priorityColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => ArticleDetailModal.show(context, article),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'FEATURED · ${article.priority.name.toUpperCase()}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${article.primaryCategory.displayName.toUpperCase()} · ${article.timeAgo}',
                style: theme.textTheme.bodySmall?.copyWith(letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            article.headline,
            style: theme.textTheme.displayLarge?.copyWith(
              height: 1.1,
              fontSize: 44,
            ),
          ),
          const SizedBox(height: 12),
          // Pull quote
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: AppColors.claudeOrange,
                  width: 4,
                ),
              ),
            ),
            child: Text(
              article.summary,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                fontSize: 18,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'BY ${article.sourceName.toUpperCase()}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewspaperColumnArticle extends StatelessWidget {
  final Article article;
  final Color priorityColor;
  const _NewspaperColumnArticle({
    required this.article,
    required this.priorityColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => ArticleDetailModal.show(context, article),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: priorityColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${article.primaryCategory.shortName.toUpperCase()} · ${article.timeAgo}',
                style: theme.textTheme.bodySmall?.copyWith(letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            article.headline,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontSize: 22,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            article.summary,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            article.sourceName.toUpperCase(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallNewspaperArticle extends StatelessWidget {
  final Article article;
  final Color priorityColor;
  const _SmallNewspaperArticle({
    required this.article,
    required this.priorityColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => ArticleDetailModal.show(context, article),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 2,
            color: priorityColor,
          ),
          const SizedBox(height: 8),
          Text(
            '${article.primaryCategory.shortName.toUpperCase()} · ${article.timeAgo}',
            style: theme.textTheme.bodySmall?.copyWith(
              letterSpacing: 1,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            article.headline,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'Fraunces',
              height: 1.3,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            article.summary,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
