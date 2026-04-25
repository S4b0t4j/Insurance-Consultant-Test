import 'package:flutter/material.dart';
import '../models/article.dart';
import '../utils/theme.dart';
import 'article_detail_modal.dart';

class ListLayout extends StatelessWidget {
  final List<Article> articles;
  const ListLayout({super.key, required this.articles});

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: isDark
              ? AppColors.darkCardBorder
              : AppColors.lightCardBorder,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBackground
                  : AppColors.claudeCream,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.cardRadius),
                topRight: Radius.circular(AppTheme.cardRadius),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                    flex: 1,
                    child: Text('PRIORITY',
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700, letterSpacing: 1))),
                Expanded(
                    flex: 5,
                    child: Text('HEADLINE',
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700, letterSpacing: 1))),
                Expanded(
                    flex: 2,
                    child: Text('CATEGORY',
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700, letterSpacing: 1))),
                Expanded(
                    flex: 2,
                    child: Text('SOURCE',
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700, letterSpacing: 1))),
                Expanded(
                    flex: 1,
                    child: Text('TIME',
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700, letterSpacing: 1))),
              ],
            ),
          ),
          for (int i = 0; i < articles.length; i++)
            _ListRow(
              article: articles[i],
              priorityColor: _priorityColor(articles[i].priority),
              isLast: i == articles.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  final Article article;
  final Color priorityColor;
  final bool isLast;
  const _ListRow({
    required this.article,
    required this.priorityColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => ArticleDetailModal.show(context, article),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isLast ? Colors.transparent : theme.dividerColor,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: priorityColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(article.priority.name.toUpperCase(),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: priorityColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11)),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  if (article.isBreaking) ...[
                    const Icon(Icons.bolt,
                        size: 14, color: AppColors.breaking),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      article.headline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(article.primaryCategory.shortName,
                  style: theme.textTheme.bodySmall),
            ),
            Expanded(
              flex: 2,
              child: Text(article.sourceName,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 1,
              child: Text(article.timeAgo,
                  style: theme.textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}
