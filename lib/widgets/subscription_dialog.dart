import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subscriber.dart';
import '../providers/subscriber_provider.dart';
import '../utils/theme.dart';

class SubscriptionDialog extends StatefulWidget {
  const SubscriptionDialog({super.key});

  @override
  State<SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<SubscriptionDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        width: isSmall ? size.width * 0.95 : 600,
        height: isSmall ? size.height * 0.85 : 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.email_outlined,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Email Notifications',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
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
                Tab(text: 'Add Subscriber'),
                Tab(text: 'Manage Subscribers'),
              ],
            ),
            const SizedBox(height: 16),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _AddSubscriberTab(
                    onSubscribed: () => _tabController.animateTo(1),
                  ),
                  const _ManageSubscribersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSubscriberTab extends StatefulWidget {
  final VoidCallback onSubscribed;

  const _AddSubscriberTab({required this.onSubscribed});

  @override
  State<_AddSubscriberTab> createState() => _AddSubscriberTabState();
}

class _AddSubscriberTabState extends State<_AddSubscriberTab> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  NotificationFrequency _frequency = NotificationFrequency.daily;
  FeedPreference _feedPreference = FeedPreference.all;
  bool _highPriorityImmediate = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await context.read<SubscriberProvider>().addSubscriber(
            email: _emailController.text.trim(),
            name: _nameController.text.trim(),
            frequency: _frequency,
            feedPreference: _feedPreference,
            highPriorityImmediate: _highPriorityImmediate,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscriber added successfully!'),
            backgroundColor: AppColors.lowPriority,
          ),
        );
        _emailController.clear();
        _nameController.clear();
        widget.onSubscribed();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.highPriority,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter subscriber name',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter email address',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an email';
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Frequency
            Text(
              'Notification Frequency',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: NotificationFrequency.values.map((freq) {
                return ChoiceChip(
                  label: Text(freq.displayName),
                  selected: _frequency == freq,
                  onSelected: (_) => setState(() => _frequency = freq),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Feed Preference
            Text(
              'Feed Preference',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FeedPreference.values.map((pref) {
                return ChoiceChip(
                  label: Text(pref.displayName),
                  selected: _feedPreference == pref,
                  onSelected: (_) => setState(() => _feedPreference = pref),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // High Priority Immediate
            SwitchListTile(
              title: const Text('High Priority Immediate'),
              subtitle: const Text(
                'Send urgent news instantly regardless of digest schedule',
              ),
              value: _highPriorityImmediate,
              onChanged: (value) =>
                  setState(() => _highPriorityImmediate = value),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add),
                label: Text(_isLoading ? 'Adding...' : 'Add Subscriber'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageSubscribersTab extends StatelessWidget {
  const _ManageSubscribersTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<SubscriberProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.subscribers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mail_outline,
                  size: 64,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No subscribers yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add subscribers to send email notifications',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: provider.subscribers.length,
          itemBuilder: (context, index) {
            final subscriber = provider.subscribers[index];
            return _SubscriberCard(subscriber: subscriber);
          },
        );
      },
    );
  }
}

class _SubscriberCard extends StatelessWidget {
  final Subscriber subscriber;

  const _SubscriberCard({required this.subscriber});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: subscriber.isPaused
                      ? AppColors.paused.withValues(alpha: 0.2)
                      : AppColors.primaryBlue.withValues(alpha: 0.2),
                  child: Icon(
                    Icons.person,
                    color: subscriber.isPaused
                        ? AppColors.paused
                        : AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscriber.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subscriber.email,
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (subscriber.isPaused)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.paused.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'PAUSED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.paused,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // Settings
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip(
                  icon: Icons.schedule,
                  label: subscriber.frequency.displayName,
                  isDark: isDark,
                ),
                _buildChip(
                  icon: Icons.article,
                  label: subscriber.feedPreference.displayName,
                  isDark: isDark,
                ),
                if (subscriber.highPriorityImmediate)
                  _buildChip(
                    icon: Icons.priority_high,
                    label: 'Urgent Alerts',
                    color: AppColors.highPriority,
                    isDark: isDark,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    context
                        .read<SubscriberProvider>()
                        .togglePause(subscriber.id);
                  },
                  icon: Icon(
                    subscriber.isPaused ? Icons.play_arrow : Icons.pause,
                    size: 18,
                  ),
                  label: Text(subscriber.isPaused ? 'Resume' : 'Pause'),
                ),
                TextButton.icon(
                  onPressed: () => _showDeleteConfirmation(context),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.highPriority,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    Color? color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBorder : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color ?? (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color ?? (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Subscriber?'),
        content: Text(
          'Are you sure you want to remove ${subscriber.name} from the notification list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context
                  .read<SubscriberProvider>()
                  .removeSubscriber(subscriber.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Subscriber removed'),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.highPriority,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
