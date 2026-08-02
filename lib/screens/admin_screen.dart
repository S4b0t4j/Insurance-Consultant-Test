import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/audit_event.dart';
import '../models/user.dart';
import '../providers/ai_provider.dart';
import '../providers/audit_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/discord_provider.dart';
import '../utils/theme.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.people_outline), text: 'Users'),
            Tab(icon: Icon(Icons.smart_toy_outlined), text: 'Claude API'),
            Tab(icon: Icon(Icons.discord), text: 'Discord'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Audit Log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _UsersTab(),
          _ClaudeApiTab(),
          _DiscordTab(),
          _AuditLogTab(),
        ],
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _AddUserDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Authorized Users', style: theme.textTheme.headlineMedium),
                ElevatedButton.icon(
                  onPressed: () => _showAddUserDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add User'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Only invited users can access the Education News Monitor',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ...auth.users.map((user) => _UserCard(user: user)),
          ],
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.read<AuthProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: user.isAdmin
                  ? AppColors.claudeOrange.withValues(alpha: 0.2)
                  : AppColors.persianBlue.withValues(alpha: 0.2),
              child: Icon(
                user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                color: user.isAdmin ? AppColors.claudeOrange : AppColors.persianBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(user.displayName,
                          style: theme.textTheme.titleMedium),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: user.isAdmin
                              ? AppColors.claudeOrange.withValues(alpha: 0.15)
                              : AppColors.lowPriority.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          user.role.name.toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: user.isAdmin
                                ? AppColors.claudeOrange
                                : AppColors.lowPriority,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      if (!user.active) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.paused.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'INACTIVE',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.paused,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(user.email, style: theme.textTheme.bodyMedium),
                  if (user.lastLoginAt != null)
                    Text(
                      'Last login: ${DateFormat.yMMMd().add_jm().format(user.lastLoginAt!)}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (!user.isAdmin)
              Tooltip(
                message: 'Report Studio & Risk Desk access',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.slideshow_outlined, size: 16),
                    Switch(
                      value: user.canUseReportStudio,
                      onChanged: (_) async {
                        final granted =
                            await auth.toggleReportStudioAccess(user.id);
                        if (granted != null && context.mounted) {
                          context.read<AuditProvider>().log(
                                AuditAction.accessGrantChanged,
                                detail:
                                    '${user.email}: Report Studio ${granted ? 'granted' : 'revoked'}',
                              );
                        }
                      },
                    ),
                  ],
                ),
              ),
            IconButton(
              icon: Icon(user.active
                  ? Icons.toggle_on
                  : Icons.toggle_off_outlined),
              color: user.active ? AppColors.lowPriority : AppColors.paused,
              onPressed: () => auth.toggleActive(user.id),
              tooltip: user.active ? 'Deactivate' : 'Activate',
            ),
            if (user.id != auth.currentUser?.id)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.highPriority,
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Remove user?'),
                      content: Text('Remove ${user.displayName} (${user.email})? This cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.highPriority),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await auth.removeUser(user.id);
                  }
                },
                tooltip: 'Remove user',
              ),
          ],
        ),
      ),
    );
  }
}

class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog();

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _role = UserRole.viewer;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final success = await context.read<AuthProvider>().addUser(
          email: _emailController.text,
          displayName: _nameController.text,
          password: _passwordController.text,
          role: _role,
        );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = 'A user with that email already exists';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New User'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Display Name'),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Required';
                  if (!val.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Initial Password'),
                validator: (val) =>
                    val == null || val.length < 6 ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: UserRole.values
                    .map((r) => DropdownMenuItem(
                        value: r, child: Text(r.name.toUpperCase())))
                    .toList(),
                onChanged: (val) => setState(() => _role = val!),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.highPriority)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Add User'),
        ),
      ],
    );
  }
}

class _ClaudeApiTab extends StatefulWidget {
  const _ClaudeApiTab();

  @override
  State<_ClaudeApiTab> createState() => _ClaudeApiTabState();
}

class _ClaudeApiTabState extends State<_ClaudeApiTab> {
  late TextEditingController _controller;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<AIProvider>().apiKey ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<AIProvider>(
      builder: (context, ai, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Claude AI Integration', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Enter your Anthropic API key to enable AI summaries, risk scoring, and Ask AI chat.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.claudeOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.key,
                              color: AppColors.claudeOrange),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('API Key',
                                  style: theme.textTheme.titleMedium),
                              Text(
                                ai.hasApiKey ? 'Configured' : 'Not set',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: ai.hasApiKey
                                      ? AppColors.lowPriority
                                      : AppColors.paused,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'sk-ant-...',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await ai.setApiKey(_controller.text);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('API key saved')),
                                );
                              }
                            },
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: const Text('Save'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: ai.hasApiKey
                              ? () async {
                                  await ai.setApiKey(null);
                                  _controller.clear();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('API key cleared')),
                                    );
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.angelina.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.persianBlue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Demo mode without API key',
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(
                          'AI features run in demo mode with pre-built responses when no API key is configured.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DiscordTab extends StatefulWidget {
  const _DiscordTab();

  @override
  State<_DiscordTab> createState() => _DiscordTabState();
}

class _DiscordTabState extends State<_DiscordTab> {
  late TextEditingController _controller;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<DiscordProvider>().webhookUrl ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<DiscordProvider>(
      builder: (context, discord, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Discord Integration', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Send breaking news and high-priority alerts to your Discord channel.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5865F2).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.discord,
                              color: Color(0xFF5865F2)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Webhook URL',
                                  style: theme.textTheme.titleMedium),
                              Text(
                                discord.isConfigured ? 'Configured' : 'Not set',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: discord.isConfigured
                                      ? AppColors.lowPriority
                                      : AppColors.paused,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        labelText: 'https://discord.com/api/webhooks/...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await discord.setWebhookUrl(_controller.text);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Webhook saved')),
                                );
                              }
                            },
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: const Text('Save'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: !discord.isConfigured || _testing
                              ? null
                              : () async {
                                  setState(() => _testing = true);
                                  final ok = await discord.sendTestMessage();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok
                                            ? 'Test message sent successfully'
                                            : 'Failed to send test message'),
                                        backgroundColor: ok
                                            ? AppColors.lowPriority
                                            : AppColors.highPriority,
                                      ),
                                    );
                                  }
                                  if (mounted) setState(() => _testing = false);
                                },
                          icon: _testing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send_outlined, size: 18),
                          label: const Text('Test'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.claudeCream,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How to get a webhook URL',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(
                    '1. Go to your Discord server settings\n'
                    '2. Click "Integrations" > "Webhooks"\n'
                    '3. Create a new webhook and copy its URL\n'
                    '4. Paste the URL above and click Save',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AuditLogTab extends StatefulWidget {
  const _AuditLogTab();

  @override
  State<_AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<_AuditLogTab> {
  AuditAction? _filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<AuditProvider>(
      builder: (context, audit, _) {
        final events = _filter == null
            ? audit.events
            : audit.events.where((e) => e.action == _filter).toList();
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Audit Log',
                      style: theme.textTheme.headlineMedium),
                ),
                DropdownButton<AuditAction?>(
                  value: _filter,
                  hint: const Text('All actions'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All actions')),
                    for (final action in AuditAction.values)
                      DropdownMenuItem(
                          value: action, child: Text(action.label)),
                  ],
                  onChanged: (v) => setState(() => _filter = v),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy JSON'),
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: audit.exportJson()));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Audit log copied to clipboard')),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: const Text('Clear'),
                  onPressed: () => audit.clear(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Advisory client-side log of logins, access grants, uploads, generations and downloads '
              '(last ${AuditProvider.maxEvents} events, this browser only). The authoritative access log '
              'is the hosting layer — see docs/DEPLOYMENT.md.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No events recorded yet.')),
              ),
            for (final event in events)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: Icon(_iconFor(event.action), size: 20),
                  title: Text('${event.action.label} — ${event.userEmail}'),
                  subtitle: Text(event.detail.isEmpty
                      ? DateFormat.yMMMd().add_jms().format(event.timestamp)
                      : '${event.detail}\n${DateFormat.yMMMd().add_jms().format(event.timestamp)}'),
                  isThreeLine: event.detail.isNotEmpty,
                ),
              ),
          ],
        );
      },
    );
  }

  IconData _iconFor(AuditAction action) {
    switch (action) {
      case AuditAction.login:
        return Icons.login;
      case AuditAction.loginFailed:
        return Icons.gpp_bad_outlined;
      case AuditAction.logout:
        return Icons.logout;
      case AuditAction.userAdded:
      case AuditAction.userRemoved:
        return Icons.person_outline;
      case AuditAction.accessGrantChanged:
        return Icons.key_outlined;
      case AuditAction.templateUploaded:
      case AuditAction.sourceAdded:
        return Icons.upload_file_outlined;
      case AuditAction.generationStarted:
      case AuditAction.generationCompleted:
      case AuditAction.generationFailed:
        return Icons.auto_awesome_outlined;
      case AuditAction.reportDownloaded:
        return Icons.download_outlined;
      case AuditAction.riskAnalysisStarted:
      case AuditAction.riskAnalysisCompleted:
      case AuditAction.riskAnalysisFailed:
        return Icons.hub_outlined;
    }
  }
}
