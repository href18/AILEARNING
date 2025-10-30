import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:compliance_training_app/localization/app_localizations.dart';

class SimulationView extends StatefulWidget {
  const SimulationView({super.key, this.simulation});

  final Map<String, dynamic>? simulation;

  @override
  State<SimulationView> createState() => _SimulationViewState();
}

class _SimulationViewState extends State<SimulationView> with SingleTickerProviderStateMixin {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final steps = (widget.simulation?['steps'] as List<dynamic>? ?? [])
        .map((dynamic step) => step as Map<String, dynamic>)
        .toList();

    if (steps.isEmpty) {
      return const Center(child: Text('No simulation steps configured.'));
    }

    final step = steps[_index];
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: 350.ms,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.85),
                  theme.colorScheme.secondary.withValues(alpha: 0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const Icon(Icons.auto_fix_high, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      l10n.translate('course_simulation_title'),
                      style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.translate(
                    'course_simulation_step',
                    params: {
                      'current': '${_index + 1}',
                      'total': '${steps.length}',
                    },
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Text(
                  step['title']?.toString() ?? '',
                  style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
                ).animate().slideY(begin: -0.1, duration: 300.ms).fadeIn(),
                const SizedBox(height: 18),
                Text(
                  step['description']?.toString() ?? '',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    height: 1.5,
                  ),
                ).animate().fadeIn(duration: 400.ms),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _index == 0
                  ? null
                  : () => setState(() {
                        _index--;
                      }),
              icon: const Icon(Icons.chevron_left),
              label: Text(l10n.translate('course_simulation_back')),
            ),
            const Spacer(),
            DotsIndicator(current: _index, total: steps.length),
            const Spacer(),
            FilledButton.icon(
              onPressed: _index == steps.length - 1
                  ? null
                  : () => setState(() {
                        _index++;
                      }),
              icon: const Icon(Icons.chevron_right),
              label: Text(l10n.translate('course_simulation_next')),
            ),
          ],
        ),
      ],
    );
  }
}

class DotsIndicator extends StatelessWidget {
  const DotsIndicator({super.key, required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: 250.ms,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 14 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: i == current
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }
}
