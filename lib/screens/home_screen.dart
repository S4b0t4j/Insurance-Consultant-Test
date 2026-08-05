import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/article.dart';
import '../providers/alert_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/discord_provider.dart';
import '../providers/layout_provider.dart';
import '../providers/news_provider.dart';
import '../providers/theme_provider.dart';
import '../services/pdf_service.dart';
import '../utils/theme.dart';
import '../widgets/alerts_panel.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/vantage_view.dart';
import '../widgets/filter_panel.dart';
import '../widgets/grid_layout.dart';
import '../widgets/layout_switcher.dart';
import '../widgets/list_layout.dart';
import '../widgets/loading_shimmer.dart';
import '../widgets/news_tabs.dart';
import '../widgets/newspaper_layout.dart';
import '../widgets/onboarding_tour.dart';
import '../widgets/status_bar.dart';
import '../widgets/trending_section.dart';
import 'admin_screen.dart';
import 'ask_ai_screen.dart';
import 'report_studio_screen.dart';
import 'risk_desk_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Below this width the sidebar moves into a Drawer instead of sitting
/// inline — matches FilterPanel's existing isWide breakpoint so the app
/// doesn't grow a second, different notion of "mobile".
const double _mobileBreakpoint = 768;

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;
  bool _alertsProcessed = false;
  bool _onboardingChecked = false;
  AppSection _section = AppSection.dashboard;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnboarding());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollController.offset > 200;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  Future<void> _checkOnboarding() async {
    if (_onboardingChecked) return;
    _onboardingChecked = true;
    final auth = context.read<AuthProvider>();
    final seen = await auth.hasSeenOnboarding();
    if (!seen && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const OnboardingTour(),
      );
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  void _processAlerts(List<Article> articles) {
    if (!_alertsProcessed && articles.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<AlertProvider>().processArticles(articles);
          // Send breaking news to Discord if configured
          final discord = context.read<DiscordProvider>();
          if (discord.isConfigured) {
            for (final article in articles.take(5).where((a) =>
                a.isBreaking || a.priority == Priority.high)) {
              discord.sendArticleAlert(article);
            }
          }
          _alertsProcessed = true;
        }
      });
    }
  }

  Future<void> _exportPdf() async {
    final newsProvider = context.read<NewsProvider>();
    final articles = newsProvider.filteredArticles;
    if (articles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No articles to export'),
          backgroundColor: AppColors.mediumPriority,
        ),
      );
      return;
    }
    try {
      await PdfService.generateAndPrintReport(articles);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: AppColors.highPriority,
          ),
        );
      }
    }
  }

  Future<void> _shareReport() async {
    final newsProvider = context.read<NewsProvider>();
    final articles = newsProvider.filteredArticles;
    if (articles.isEmpty) return;

    final dateStr = DateFormat('MMMM d, yyyy').format(DateTime.now());
    final highCount =
        articles.where((a) => a.priority == Priority.high).length;
    final mediumCount =
        articles.where((a) => a.priority == Priority.medium).length;
    final lowCount =
        articles.where((a) => a.priority == Priority.low).length;

    final text = '''
VANTAGE Public Sector - $dateStr
VANTAGE Public Sector

Summary: $highCount High Priority | $mediumCount Medium | $lowCount Low Priority

Top Stories:
${articles.take(5).map((a) => '• ${a.headline}').join('\n')}

View full report with risk analysis in the VANTAGE Public Sector app.
''';
    await Share.share(text, subject: 'Public Sector Risk Report - $dateStr');
  }

  void _showAlertsPanel() {
    showDialog(context: context, builder: (_) => const AlertsPanel());
  }

  Widget _buildSectionContent() {
    switch (_section) {
      case AppSection.dashboard:
        return _buildDashboard();
      case AppSection.vantageMap:
        return const VantageView();
      case AppSection.askAi:
        return const AskAiScreen();
      case AppSection.riskDesk:
        return _guarded(RiskDeskScreen(
          onBuildReport: () =>
              setState(() => _section = AppSection.reportStudio),
        ));
      case AppSection.reportStudio:
        return _guarded(const ReportStudioScreen());
      case AppSection.alerts:
        return const AlertsPanel(inline: true);
      case AppSection.admin:
        return const AdminScreen();
    }
  }

  /// Access can be revoked mid-session; both gated sections re-check here.
  Widget _guarded(Widget child) {
    final auth = context.watch<AuthProvider>();
    if (!auth.canUseReportStudio) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 12),
            Text('No access',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
                'Ask an administrator to grant you Report Studio access.'),
          ],
        ),
      );
    }
    return child;
  }

  Widget _buildDashboard() {
    return Consumer2<NewsProvider, LayoutProvider>(
      builder: (context, newsProvider, layoutProvider, _) {
        if (!newsProvider.isLoading) {
          _processAlerts(newsProvider.articles);
        }
        return RefreshIndicator(
          onRefresh: () async {
            await newsProvider.refreshArticles();
            _alertsProcessed = false;
          },
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Trending section (only when articles loaded)
              if (!newsProvider.isLoading && newsProvider.articles.isNotEmpty)
                const SliverToBoxAdapter(child: TrendingSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // Filter panel
              const SliverToBoxAdapter(child: FilterPanel()),
              const SliverToBoxAdapter(child: NewsTabs()),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              const SliverToBoxAdapter(child: StatusBar()),

              // Layout switcher row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: const [LayoutSwitcher()],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // Article display by layout
              if (newsProvider.isLoading)
                const SliverToBoxAdapter(child: LoadingShimmer())
              else if (newsProvider.filteredArticles.isEmpty)
                _buildEmptyState()
              else
                SliverToBoxAdapter(
                  child: _buildArticleView(
                    newsProvider.filteredArticles,
                    layoutProvider,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArticleView(List<Article> articles, LayoutProvider layout) {
    switch (layout.layout) {
      case ViewLayout.grid:
        return GridLayout(articles: articles);
      case ViewLayout.newspaper:
        return NewspaperLayout(articles: articles);
      case ViewLayout.list:
        return ListLayout(articles: articles);
    }
  }

  SliverFillRemaining _buildEmptyState() {
    final theme = Theme.of(context);
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No articles match your filters',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: context.read<NewsProvider>().clearAllFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear all filters'),
            ),
          ],
        ),
      ),
    );
  }

  String _sectionTitle() {
    switch (_section) {
      case AppSection.dashboard:
        return 'VANTAGE Public Sector';
      case AppSection.vantageMap:
        return 'Entity Map';
      case AppSection.askAi:
        return 'Ask AI';
      case AppSection.riskDesk:
        return 'Risk Desk';
      case AppSection.reportStudio:
        return 'Report Studio';
      case AppSection.alerts:
        return 'Alerts';
      case AppSection.admin:
        return 'Admin Settings';
    }
  }

  void _selectSection(AppSection s) {
    setState(() => _section = s);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < _mobileBreakpoint;
    return Scaffold(
      key: _scaffoldKey,
      drawer: isMobile
          ? Drawer(
              child: AppSidebar(
                currentSection: _section,
                onSectionChange: (s) {
                  Navigator.of(context).pop();
                  _selectSection(s);
                },
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            AppSidebar(
              currentSection: _section,
              onSectionChange: _selectSection,
            ),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isMobile: isMobile),
                Expanded(child: _buildSectionContent()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _section == AppSection.dashboard
          ? AnimatedOpacity(
              opacity: _showScrollToTop ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: FloatingActionButton(
                onPressed: _showScrollToTop ? _scrollToTop : null,
                child: const Icon(Icons.keyboard_arrow_up),
              ),
            )
          : null,
    );
  }

  Widget _buildTopBar({required bool isMobile}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
          if (isMobile)
            IconButton(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sectionTitle(),
                  style: theme.textTheme.headlineLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_section == AppSection.dashboard)
                  Text(
                    'Real-time news intelligence · ${DateFormat.yMMMMd().format(DateTime.now())}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (_section == AppSection.dashboard) ...[
            // Alerts
            Consumer<AlertProvider>(
              builder: (context, alertProvider, _) {
                final unreadCount = alertProvider.unreadCount;
                return Stack(
                  children: [
                    IconButton(
                      onPressed: _showAlertsPanel,
                      icon: const Icon(Icons.notifications_outlined),
                      tooltip: 'Alerts',
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.highPriority,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                              minWidth: 16, minHeight: 16),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
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
                );
              },
            ),
            IconButton(
              onPressed: _exportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export PDF',
            ),
            IconButton(
              onPressed: _shareReport,
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share Report',
            ),
            Consumer<NewsProvider>(
              builder: (context, newsProvider, _) {
                return IconButton(
                  onPressed: () {
                    newsProvider.refreshArticles();
                    _alertsProcessed = false;
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                );
              },
            ),
          ],
          const SizedBox(width: 8),
          Container(width: 1, height: 24, color: theme.dividerColor),
          const SizedBox(width: 8),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return IconButton(
                onPressed: themeProvider.toggleTheme,
                icon: Icon(
                  themeProvider.isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
                tooltip: themeProvider.isDarkMode
                    ? 'Light mode'
                    : 'Dark mode',
              );
            },
          ),
        ],
      ),
    );
  }
}
