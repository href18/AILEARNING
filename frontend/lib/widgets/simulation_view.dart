import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

    return Column(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: 350.ms,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xff4caf50), Color(0xff009688)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Step ${_index + 1}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Text(
                  step['title']?.toString() ?? '',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ).animate().slideY(begin: -0.15, duration: 300.ms).fadeIn(),
                const SizedBox(height: 16),
                Text(
                  step['description']?.toString() ?? '',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
                ).animate().fadeIn(duration: 500.ms),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: _index == 0
                  ? null
                  : () => setState(() {
                        _index--;
                      }),
              icon: const Icon(Icons.chevron_left),
              label: const Text('Back'),
            ),
            DotsIndicator(current: _index, total: steps.length),
            OutlinedButton.icon(
              onPressed: _index == steps.length - 1
                  ? null
                  : () => setState(() {
                        _index++;
                      }),
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next'),
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
              color: i == current ? Theme.of(context).colorScheme.primary : Colors.white24,
            ),
          ),
      ],
    );
  }
}
