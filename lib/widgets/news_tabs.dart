import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/news_provider.dart';
import '../utils/theme.dart';

class NewsTabs extends StatelessWidget {
  const NewsTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<NewsProvider>(
      builder: (context, newsProvider, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _buildTab(
                context,
                label: 'All News',
                icon: Icons.article,
                count: newsProvider.allNewsCount,
                isSelected: newsProvider.currentTab == NewsFeedTab.all,
                onTap: () => newsProvider.setCurrentTab(NewsFeedTab.all),
                color: AppColors.primaryBlue,
              ),
              _buildTab(
                context,
                label: 'General',
                icon: Icons.school,
                count: newsProvider.generalCount,
                isSelected: newsProvider.currentTab == NewsFeedTab.general,
                onTap: () => newsProvider.setCurrentTab(NewsFeedTab.general),
                color: AppColors.accentTeal,
              ),
              _buildTab(
                context,
                label: 'Public Safety',
                icon: Icons.sports_football,
                count: newsProvider.publicSafetyCount,
                isSelected: newsProvider.currentTab == NewsFeedTab.publicSafety,
                onTap: () => newsProvider.setCurrentTab(NewsFeedTab.publicSafety),
                color: AppColors.mediumPriority,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTab(
    BuildContext context, {
    required String label,
    required IconData icon,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.2 : 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? color
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? color
                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.2)
                      : (isDark ? AppColors.darkCardBorder : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? color
                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
