import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/alert_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/layout_provider.dart';
import '../utils/theme.dart';

enum AppSection { dashboard, askAi, riskDesk, reportStudio, alerts, admin }

class AppSidebar extends StatelessWidget {
  final AppSection currentSection;
  final ValueChanged<AppSection> onSectionChange;

  const AppSidebar({
    super.key,
    required this.currentSection,
    required this.onSectionChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Consumer3<LayoutProvider, AuthProvider, AlertProvider>(
      builder: (context, layout, auth, alerts, _) {
        final collapsed = layout.sidebarCollapsed;
        final width = collapsed ? 72.0 : 240.0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: width,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              right: BorderSide(
                color: isDark
                    ? AppColors.darkCardBorder
                    : AppColors.lightCardBorder,
              ),
            ),
          ),
          child: Column(
            children: [
              // Logo + collapse toggle
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 12, 20),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.darkCobalt, AppColors.persianBlue],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.school_rounded,
                          color: Colors.white, size: 22),
                    ),
                    if (!collapsed) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Marsh',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            Text('Education Practice',
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _NavItem(
                      icon: Icons.dashboard_outlined,
                      activeIcon: Icons.dashboard,
                      label: 'Dashboard',
                      collapsed: collapsed,
                      selected: currentSection == AppSection.dashboard,
                      onTap: () => onSectionChange(AppSection.dashboard),
                    ),
                    _NavItem(
                      icon: Icons.auto_awesome_outlined,
                      activeIcon: Icons.auto_awesome,
                      label: 'Ask AI',
                      collapsed: collapsed,
                      selected: currentSection == AppSection.askAi,
                      onTap: () => onSectionChange(AppSection.askAi),
                      accentColor: AppColors.claudeOrange,
                    ),
                    if (auth.canUseReportStudio) ...[
                      _NavItem(
                        icon: Icons.hub_outlined,
                        activeIcon: Icons.hub,
                        label: 'Risk Desk',
                        collapsed: collapsed,
                        selected: currentSection == AppSection.riskDesk,
                        onTap: () => onSectionChange(AppSection.riskDesk),
                        accentColor: AppColors.claudeOrange,
                      ),
                      _NavItem(
                        icon: Icons.slideshow_outlined,
                        activeIcon: Icons.slideshow,
                        label: 'Report Studio',
                        collapsed: collapsed,
                        selected: currentSection == AppSection.reportStudio,
                        onTap: () => onSectionChange(AppSection.reportStudio),
                        accentColor: AppColors.persianBlue,
                      ),
                    ],
                    _NavItem(
                      icon: Icons.notifications_outlined,
                      activeIcon: Icons.notifications,
                      label: 'Alerts',
                      badge: alerts.unreadCount > 0 ? alerts.unreadCount : null,
                      collapsed: collapsed,
                      selected: currentSection == AppSection.alerts,
                      onTap: () => onSectionChange(AppSection.alerts),
                    ),
                    if (auth.isAdmin)
                      _NavItem(
                        icon: Icons.admin_panel_settings_outlined,
                        activeIcon: Icons.admin_panel_settings,
                        label: 'Admin',
                        collapsed: collapsed,
                        selected: currentSection == AppSection.admin,
                        onTap: () => onSectionChange(AppSection.admin),
                      ),
                  ],
                ),
              ),
              // User section
              if (auth.currentUser != null) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            AppColors.persianBlue.withValues(alpha: 0.2),
                        child: Text(
                          auth.currentUser!.displayName
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.persianBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!collapsed) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                auth.currentUser!.displayName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                auth.currentUser!.role.name.toUpperCase(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, size: 18),
                          onPressed: () => auth.logout(),
                          tooltip: 'Logout',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              // Collapse toggle
              Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: Icon(collapsed
                      ? Icons.chevron_right
                      : Icons.chevron_left),
                  onPressed: layout.toggleSidebar,
                  tooltip: collapsed ? 'Expand' : 'Collapse',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;
  final Color? accentColor;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.collapsed,
    required this.selected,
    required this.onTap,
    this.badge,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? AppColors.darkCobalt;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.1) : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      selected ? activeIcon : icon,
                      size: 20,
                      color: selected
                          ? color
                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    if (badge != null && badge! > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.highPriority,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            badge! > 9 ? '9+' : '$badge',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? color
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
