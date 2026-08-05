import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/news_provider.dart';
import '../utils/theme.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeFormat = DateFormat('h:mm a');

    return Consumer<NewsProvider>(
      builder: (context, newsProvider, _) {
        final isWide = MediaQuery.of(context).size.width > 700;
        final liveIndicator = _buildLiveIndicator(newsProvider);
        final lastUpdated = Text(
          'Last updated: ${timeFormat.format(newsProvider.lastUpdated)}',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        );
        final counts = Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildCountBadge(
              context,
              count: newsProvider.highPriorityCount,
              label: 'High',
              color: AppColors.highPriority,
            ),
            _buildCountBadge(
              context,
              count: newsProvider.mediumPriorityCount,
              label: 'Med',
              color: AppColors.mediumPriority,
            ),
            _buildCountBadge(
              context,
              count: newsProvider.lowPriorityCount,
              label: 'Low',
              color: AppColors.lowPriority,
            ),
            if (newsProvider.breakingNewsCount > 0)
              _buildCountBadge(
                context,
                count: newsProvider.breakingNewsCount,
                label: 'Breaking',
                color: AppColors.breaking,
                isBreaking: true,
              ),
          ],
        );

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            ),
          ),
          child: isWide
              ? Row(
                  children: [
                    liveIndicator,
                    const SizedBox(width: 16),
                    Expanded(child: lastUpdated),
                    counts,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        liveIndicator,
                        const SizedBox(width: 12),
                        Expanded(child: lastUpdated),
                      ],
                    ),
                    const SizedBox(height: 8),
                    counts,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildLiveIndicator(NewsProvider newsProvider) {
    return GestureDetector(
      onTap: newsProvider.toggleAutoUpdate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: newsProvider.isAutoUpdateEnabled
              ? AppColors.live.withValues(alpha: 0.15)
              : AppColors.paused.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: newsProvider.isAutoUpdateEnabled
                ? AppColors.live.withValues(alpha: 0.3)
                : AppColors.paused.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: newsProvider.isAutoUpdateEnabled
                    ? AppColors.live
                    : AppColors.paused,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              newsProvider.isAutoUpdateEnabled ? 'LIVE' : 'PAUSED',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: newsProvider.isAutoUpdateEnabled
                    ? AppColors.live
                    : AppColors.paused,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountBadge(
    BuildContext context, {
    required int count,
    required String label,
    required Color color,
    bool isBreaking = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBreaking)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
