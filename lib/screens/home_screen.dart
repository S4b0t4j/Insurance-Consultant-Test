import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/article.dart';
import '../providers/alert_provider.dart';
import '../providers/news_provider.dart';
import '../providers/theme_provider.dart';
import '../services/pdf_service.dart';
import '../utils/theme.dart';
import '../widgets/alerts_panel.dart';
import '../widgets/filter_panel.dart';
import '../widgets/loading_shimmer.dart';
import '../widgets/news_card.dart';
import '../widgets/news_tabs.dart';
import '../widgets/status_bar.dart';
import '../widgets/subscription_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;
  bool _alertsProcessed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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

    if (articles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No articles to share'),
          backgroundColor: AppColors.mediumPriority,
        ),
      );
      return;
    }

    final dateStr = DateFormat('MMMM d, yyyy').format(DateTime.now());
    final highCount =
        articles.where((a) => a.priority == Priority.high).length;
    final mediumCount =
        articles.where((a) => a.priority == Priority.medium).length;
    final lowCount =
        articles.where((a) => a.priority == Priority.low).length;

    final text = '''
Education News Monitor - $dateStr
Marsh Education Practice

Summary: $highCount High Priority | $mediumCount Medium | $lowCount Low Priority

Top Stories:
${articles.take(5).map((a) => '• ${a.headline}').join('\n')}

View full report with risk analysis in the Education News Monitor app.
''';

    await Share.share(text, subject: 'Education News Report - $dateStr');
  }

  void _showAlertsPanel() {
    showDialog(
      context: context,
      builder: (_) => const AlertsPanel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Education News Monitor',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Marsh Education Practice',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Alerts button with badge
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
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.highPriority,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          // Admin/Settings
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Admin settings coming soon')),
              );
            },
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Admin Settings',
          ),

          // PDF Export
          IconButton(
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF Report',
          ),

          // Share
          IconButton(
            onPressed: _shareReport,
            icon: const Icon(Icons.share),
            tooltip: 'Share Report',
          ),

          // Email Notifications
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const SubscriptionDialog(),
              );
            },
            icon: const Icon(Icons.mail_outline),
            tooltip: 'Email Notifications',
          ),

          // Theme toggle
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return IconButton(
                onPressed: themeProvider.toggleTheme,
                icon: Icon(
                  themeProvider.isDarkMode
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                tooltip: themeProvider.isDarkMode
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
              );
            },
          ),

          // Refresh
          Consumer<NewsProvider>(
            builder: (context, newsProvider, _) {
              return IconButton(
                onPressed: () {
                  newsProvider.refreshArticles();
                  _alertsProcessed = false; // Re-process alerts on refresh
                },
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<NewsProvider>(
        builder: (context, newsProvider, _) {
          // Process alerts when articles are loaded
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
                // Filter panel
                const SliverToBoxAdapter(
                  child: FilterPanel(),
                ),

                // News tabs
                const SliverToBoxAdapter(
                  child: NewsTabs(),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // Status bar
                const SliverToBoxAdapter(
                  child: StatusBar(),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // News list
                if (newsProvider.isLoading)
                  const SliverToBoxAdapter(
                    child: LoadingShimmer(),
                  )
                else if (newsProvider.filteredArticles.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: isDark
                                ? Colors.grey[600]
                                : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No articles match your filters',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: newsProvider.clearAllFilters,
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Clear all filters'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final article = newsProvider.filteredArticles[index];
                        return NewsCard(article: article);
                      },
                      childCount: newsProvider.filteredArticles.length,
                    ),
                  ),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: AnimatedOpacity(
        opacity: _showScrollToTop ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: FloatingActionButton(
          onPressed: _showScrollToTop ? _scrollToTop : null,
          child: const Icon(Icons.keyboard_arrow_up),
        ),
      ),
    );
  }
}
