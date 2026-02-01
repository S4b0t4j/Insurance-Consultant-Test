import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/alert.dart';
import '../models/article.dart';
import '../providers/alert_provider.dart';
import '../utils/theme.dart';

class AlertsPanel extends StatefulWidget {
  const AlertsPanel({super.key});

  @override
  State<AlertsPanel> createState() => _AlertsPanelState();
}

class _AlertsPanelState extends State<AlertsPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isSmall ? size.width * 0.95 : 700,
        height: isSmall ? size.height * 0.9 : 650,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Alert Center',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Consumer<AlertProvider>(
                  builder: (context, provider, _) {
                    if (provider.unreadCount > 0) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.highPriority,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${provider.unreadCount} new',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Active Alerts'),
                Tab(text: 'Rules'),
                Tab(text: 'Deadlines'),
              ],
            ),
            const SizedBox(height: 16),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _ActiveAlertsTab(),
                  _RulesTab(),
                  _DeadlinesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveAlertsTab extends StatelessWidget {
  const _ActiveAlertsTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<AlertProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final alerts = provider.activeAlerts;

        if (alerts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: AppColors.lowPriority.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No active alerts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All systems operating normally',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Actions bar
            Row(
              children: [
                Text(
                  '${alerts.length} active alert${alerts.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: provider.markAllRead,
                  child: const Text('Mark all read'),
                ),
                TextButton(
                  onPressed: () => _confirmClearAll(context, provider),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.highPriority,
                  ),
                  child: const Text('Clear all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: alerts.length,
                itemBuilder: (context, index) {
                  return _AlertCard(alert: alerts[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmClearAll(BuildContext context, AlertProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Alerts?'),
        content: const Text(
          'This will dismiss all active alerts. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.clearAllAlerts();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.highPriority,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final TriggeredAlert alert;

  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final severityColor = alert.rule.severity.color;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          if (!alert.isRead) {
            context.read<AlertProvider>().markAlertRead(alert.id);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: severityColor,
                width: 4,
              ),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          alert.rule.type.icon,
                          size: 14,
                          color: severityColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          alert.rule.severity.displayName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: severityColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!alert.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    alert.timeAgo,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      context.read<AlertProvider>().dismissAlert(alert.id);
                    },
                    icon: const Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                alert.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: alert.isRead ? FontWeight.normal : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Rule: ${alert.rule.name}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              if (alert.relatedArticles.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: [
                    Icon(
                      Icons.article,
                      size: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    Text(
                      '${alert.relatedArticles.length} related article${alert.relatedArticles.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RulesTab extends StatelessWidget {
  const _RulesTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<AlertProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // Add rule button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _showAddRuleDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Rule'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: provider.rules.length,
                itemBuilder: (context, index) {
                  final rule = provider.rules[index];
                  return _RuleCard(rule: rule);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddRuleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _AddRuleDialog(),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final AlertRule rule;

  const _RuleCard({required this.rule});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: rule.severity.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                rule.type.icon,
                color: rule.severity.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rule.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkCardBorder
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          rule.type.displayName,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: rule.severity.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          rule.severity.displayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: rule.severity.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: rule.isEnabled,
              onChanged: (_) {
                context.read<AlertProvider>().toggleRule(rule.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DeadlinesTab extends StatelessWidget {
  const _DeadlinesTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Consumer<AlertProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final overdue = provider.overdueDeadlines;
        final upcoming = provider.upcomingDeadlines;

        if (overdue.isEmpty && upcoming.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_available,
                  size: 64,
                  color: AppColors.lowPriority.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No upcoming deadlines',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          children: [
            if (overdue.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning,
                      size: 18,
                      color: AppColors.highPriority,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Overdue',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.highPriority,
                      ),
                    ),
                  ],
                ),
              ),
              ...overdue.map((d) => _DeadlineCard(
                    deadline: d,
                    dateFormat: dateFormat,
                  )),
              const SizedBox(height: 16),
            ],
            if (upcoming.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Upcoming Deadlines',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...upcoming.map((d) => _DeadlineCard(
                    deadline: d,
                    dateFormat: dateFormat,
                  )),
            ],
          ],
        );
      },
    );
  }
}

class _DeadlineCard extends StatelessWidget {
  final RegulatoryDeadline deadline;
  final DateFormat dateFormat;

  const _DeadlineCard({
    required this.deadline,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final days = deadline.daysUntilDeadline;

    Color statusColor;
    String statusText;
    if (deadline.isOverdue) {
      statusColor = AppColors.highPriority;
      statusText = '${days.abs()} days overdue';
    } else if (deadline.isUrgent) {
      statusColor = AppColors.mediumPriority;
      statusText = '$days days left';
    } else {
      statusColor = AppColors.lowPriority;
      statusText = '$days days left';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    deadline.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              deadline.description,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(deadline.deadline),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                if (deadline.regulatoryBody != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.account_balance,
                    size: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    deadline.regulatoryBody!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
            if (!deadline.isCompleted) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    context.read<AlertProvider>().completeDeadline(deadline.id);
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Mark Complete'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddRuleDialog extends StatefulWidget {
  const _AddRuleDialog();

  @override
  State<_AddRuleDialog> createState() => _AddRuleDialogState();
}

class _AddRuleDialogState extends State<_AddRuleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _keywordsController = TextEditingController();

  AlertRuleType _type = AlertRuleType.keywordMatch;
  AlertSeverity _severity = AlertSeverity.medium;
  int _thresholdCount = 3;
  int _thresholdHours = 24;
  Priority _thresholdPriority = Priority.high;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _keywordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Alert Rule'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Rule Name',
                    hintText: 'e.g., Title IX Monitoring',
                  ),
                  validator: (v) =>
                      v?.isEmpty == true ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What does this rule monitor?',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AlertRuleType>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Rule Type'),
                  items: AlertRuleType.values
                      .where((t) => t != AlertRuleType.regulatoryDeadline)
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.displayName),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _type = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AlertSeverity>(
                  value: _severity,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: AlertSeverity.values
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.displayName),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _severity = v!),
                ),
                const SizedBox(height: 16),
                if (_type == AlertRuleType.keywordMatch) ...[
                  TextFormField(
                    controller: _keywordsController,
                    decoration: const InputDecoration(
                      labelText: 'Keywords (comma-separated)',
                      hintText: 'e.g., Title IX, OCR, investigation',
                    ),
                    maxLines: 2,
                  ),
                ],
                if (_type == AlertRuleType.priorityThreshold) ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _thresholdCount,
                          decoration:
                              const InputDecoration(labelText: 'Count'),
                          items: [2, 3, 4, 5, 10]
                              .map((n) => DropdownMenuItem(
                                    value: n,
                                    child: Text('$n+'),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _thresholdCount = v!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _thresholdHours,
                          decoration:
                              const InputDecoration(labelText: 'Hours'),
                          items: [6, 12, 24, 48, 72]
                              .map((h) => DropdownMenuItem(
                                    value: h,
                                    child: Text('${h}h'),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _thresholdHours = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Priority>(
                    value: _thresholdPriority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: Priority.values
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.name.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _thresholdPriority = v!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Add Rule'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final rule = AlertRule(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _type,
      severity: _severity,
      createdAt: DateTime.now(),
      keywords: _type == AlertRuleType.keywordMatch
          ? _keywordsController.text
              .split(',')
              .map((k) => k.trim())
              .where((k) => k.isNotEmpty)
              .toList()
          : [],
      thresholdCount:
          _type == AlertRuleType.priorityThreshold ? _thresholdCount : null,
      thresholdHours:
          _type == AlertRuleType.priorityThreshold ? _thresholdHours : null,
      thresholdPriority:
          _type == AlertRuleType.priorityThreshold ? _thresholdPriority : null,
    );

    context.read<AlertProvider>().addRule(rule);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alert rule added')),
    );
  }
}
