import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/layout_provider.dart';
import '../utils/theme.dart';

class LayoutSwitcher extends StatelessWidget {
  const LayoutSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Consumer<LayoutProvider>(
      builder: (context, layout, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // View layout toggle
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBackground
                    : AppColors.claudeCream,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToggleButton(
                    icon: Icons.grid_view_rounded,
                    tooltip: 'Grid view',
                    selected: layout.layout == ViewLayout.grid,
                    onTap: () => layout.setLayout(ViewLayout.grid),
                  ),
                  _ToggleButton(
                    icon: Icons.article_outlined,
                    tooltip: 'Newspaper view',
                    selected: layout.layout == ViewLayout.newspaper,
                    onTap: () => layout.setLayout(ViewLayout.newspaper),
                  ),
                  _ToggleButton(
                    icon: Icons.view_list_rounded,
                    tooltip: 'List view',
                    selected: layout.layout == ViewLayout.list,
                    onTap: () => layout.setLayout(ViewLayout.list),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Density toggle (only for grid)
            if (layout.layout == ViewLayout.grid)
              PopupMenuButton<CardDensity>(
                tooltip: 'Card density',
                onSelected: layout.setDensity,
                itemBuilder: (_) => CardDensity.values
                    .map((d) => PopupMenuItem(
                          value: d,
                          child: Row(
                            children: [
                              Icon(
                                d == layout.density
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                size: 16,
                                color: d == layout.density
                                    ? AppColors.darkCobalt
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(d.name[0].toUpperCase() + d.name.substring(1)),
                            ],
                          ),
                        ))
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBackground
                        : AppColors.claudeCream,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.density_medium, size: 16),
                      const SizedBox(width: 6),
                      Text(layout.density.name[0].toUpperCase() +
                          layout.density.name.substring(1)),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? theme.colorScheme.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      )
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 18,
              color: selected
                  ? AppColors.darkCobalt
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
