import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compliance & Safety Training'),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final contentWidth = maxWidth > 900 ? 900.0 : maxWidth;

          return Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome to your compliance learning hub',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Browse interactive courses, simulations, and quizzes designed to keep your teams safe and certified.',
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              children: [
                                FilledButton.icon(
                                  icon: const Icon(Icons.menu_book),
                                  label: const Text('Explore course catalog'),
                                  onPressed: () => context.go('/catalog'),
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.play_circle),
                                  label: const Text('Resume a course'),
                                  onPressed: () => context.go('/catalog'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'How the platform works',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _HowItWorksSection(
                      icon: Icons.cloud_sync,
                      title: 'Real-time Supabase backend',
                      description:
                          'Courses, modules, and quiz attempts live in Supabase. The Flutter client talks directly to the database and edge functions using your project keys.',
                    ),
                    _HowItWorksSection(
                      icon: Icons.view_module,
                      title: 'Rich learning modules',
                      description:
                          'Each course bundles video lessons, reading material, guided simulations, and scored quizzes. Progress is synced so learners can pick up where they left off.',
                    ),
                    _HowItWorksSection(
                      icon: Icons.analytics,
                      title: 'Automated scoring & certifications',
                      description:
                          'Submitted quizzes are evaluated by a Supabase edge function which returns instant feedback and stores certificate validity periods for administrators.',
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Ready to get started?',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Jump into the catalog to assign training or explore a course to see the learner experience in action.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Go to catalog'),
                        onPressed: () => context.go('/catalog'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
