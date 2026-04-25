import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';

class OnboardingTour extends StatefulWidget {
  const OnboardingTour({super.key});

  @override
  State<OnboardingTour> createState() => _OnboardingTourState();
}

class _OnboardingTourState extends State<OnboardingTour> {
  int _step = 0;

  final List<_TourStep> _steps = const [
    _TourStep(
      icon: Icons.dashboard_rounded,
      title: 'Real-time News Dashboard',
      description:
          'Stay informed on education, NIL, and regulatory news that impacts insurance risk for your clients. AI-curated and prioritized for you.',
      color: AppColors.darkCobalt,
    ),
    _TourStep(
      icon: Icons.auto_awesome_rounded,
      title: 'Ask AI for Insights',
      description:
          'Powered by Claude, our AI assistant can summarize articles, assess risk, and answer questions about insurance implications.',
      color: AppColors.claudeOrange,
    ),
    _TourStep(
      icon: Icons.notifications_active_rounded,
      title: 'Smart Alerts',
      description:
          'Get notified about breaking news, regulatory deadlines, and high-priority risks. Configure rules to monitor what matters most.',
      color: AppColors.fluorescentTeal,
    ),
    _TourStep(
      icon: Icons.view_module_rounded,
      title: 'Three Views, Your Choice',
      description:
          'Switch between Grid, Newspaper, and List views anytime. Adjust card density to match your workflow.',
      color: AppColors.persianBlue,
    ),
  ];

  Future<void> _finish() async {
    await context.read<AuthProvider>().markOnboardingComplete();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _steps[_step];
    final size = MediaQuery.of(context).size;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: size.width > 600 ? 480 : double.infinity,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Progress indicator
            Row(
              children: List.generate(_steps.length, (i) {
                final active = i <= _step;
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: active ? step.color : theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [step.color, step.color.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(step.icon, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            Text(step.title,
                style: theme.textTheme.displaySmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(step.description,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Back'),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  flex: _step == 0 ? 1 : 1,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_step < _steps.length - 1) {
                        setState(() => _step++);
                      } else {
                        _finish();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: step.color,
                    ),
                    child: Text(
                        _step < _steps.length - 1 ? 'Next' : 'Get started'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _finish,
              child: const Text('Skip tour'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TourStep {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  const _TourStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
