import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../providers/news_provider.dart';
import '../utils/theme.dart';

class FilterPanel extends StatefulWidget {
  const FilterPanel({super.key});

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  final TextEditingController _searchController = TextEditingController();
  bool _isExpanded = false;
  bool _showRiskTypes = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 768;

    return Consumer<NewsProvider>(
      builder: (context, newsProvider, _) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with search
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.filter_list,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Filters',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (newsProvider.hasActiveFilters)
                          TextButton.icon(
                            onPressed: () {
                              newsProvider.clearAllFilters();
                              _searchController.clear();
                            },
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Clear All'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.highPriority,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        IconButton(
                          onPressed: () =>
                              setState(() => _isExpanded = !_isExpanded),
                          icon: Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                          ),
                          tooltip: _isExpanded ? 'Collapse filters' : 'Expand filters',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: newsProvider.setSearchQuery,
                      decoration: InputDecoration(
                        hintText: 'Search headlines, sources, entities...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  newsProvider.setSearchQuery('');
                                },
                                icon: const Icon(Icons.clear),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),

              // Filter sections - collapsed by default
              if (_isExpanded) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildPrioritySection(
                                context,
                                newsProvider,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 2,
                              child: _buildCategorySection(
                                context,
                                newsProvider,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPrioritySection(context, newsProvider),
                            const SizedBox(height: 16),
                            _buildCategorySection(context, newsProvider),
                          ],
                        ),
                ),
                // Risk Types in collapsible section
                _buildRiskTypeCollapsible(context, newsProvider),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrioritySection(BuildContext context, NewsProvider provider) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: Priority.values.map((priority) {
            final isSelected = provider.selectedPriorities.contains(priority);
            Color color;
            String label;
            switch (priority) {
              case Priority.high:
                color = AppColors.highPriority;
                label = 'High';
                break;
              case Priority.medium:
                color = AppColors.mediumPriority;
                label = 'Medium';
                break;
              case Priority.low:
                color = AppColors.lowPriority;
                label = 'Low';
                break;
            }

            return FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => provider.togglePriority(priority),
              backgroundColor: color.withValues(alpha: 0.1),
              selectedColor: color.withValues(alpha: 0.3),
              checkmarkColor: color,
              labelStyle: TextStyle(
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(color: color.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategorySection(BuildContext context, NewsProvider provider) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: NewsCategory.values.map((category) {
            final isSelected = provider.selectedCategories.contains(category);

            return FilterChip(
              label: Text(category.shortName),
              selected: isSelected,
              onSelected: (_) => provider.toggleCategory(category),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRiskTypeCollapsible(BuildContext context, NewsProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final riskTypes = provider.allRiskTypes.toList()..sort();
    final selectedCount = provider.selectedRiskTypes.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkBackground.withValues(alpha: 0.5)
            : AppColors.claudeCream.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showRiskTypes = !_showRiskTypes),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Risk Types',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (selectedCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.claudeOrange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$selectedCount selected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '${riskTypes.length} types',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showRiskTypes
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_showRiskTypes) ...[
            Divider(
              height: 1,
              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: riskTypes.map((riskType) {
                    final isSelected = provider.selectedRiskTypes.contains(riskType);

                    return FilterChip(
                      label: Text(
                        riskType,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: isSelected,
                      onSelected: (_) => provider.toggleRiskType(riskType),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
