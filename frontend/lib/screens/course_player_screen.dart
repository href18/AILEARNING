import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/course.dart';
import '../services/course_service.dart';
import '../widgets/quiz_view.dart';
import '../widgets/simulation_view.dart';

class CoursePlayerScreen extends StatefulWidget {
  const CoursePlayerScreen({super.key, required this.course, required this.service});

  final Course course;
  final CourseService service;

  @override
  State<CoursePlayerScreen> createState() => _CoursePlayerScreenState();
}

class _CoursePlayerScreenState extends State<CoursePlayerScreen> {
  int _currentIndex = 0;
  bool _quizSubmitting = false;
  QuizResult? _quizResult;

  @override
  Widget build(BuildContext context) {
    final modules = widget.course.modules;
    final module = modules[_currentIndex];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.translate),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Toggle language via device locale (nb/en).')),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: 350.ms,
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
        child: Padding(
          key: ValueKey(module.id),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(module.title ?? module.type.toUpperCase(), style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Expanded(child: _buildModuleContent(module)),
              const SizedBox(height: 24),
              _buildNavigation(modules),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleContent(CourseModule module) {
    switch (module.type) {
      case 'video':
        return _VideoHero(videoUrl: module.videoUrl);
      case 'article':
        return Markdown(data: module.body ?? '');
      case 'simulation':
        return SimulationView(simulation: module.simulation);
      case 'quiz':
        return QuizView(
          module: module,
          submitting: _quizSubmitting,
          result: _quizResult,
          onSubmit: (answers) async {
            setState(() {
              _quizSubmitting = true;
            });
            try {
              final result = await widget.service.submitQuiz(moduleId: module.id, answers: answers);
              setState(() {
                _quizResult = result;
              });
            } finally {
              setState(() {
                _quizSubmitting = false;
              });
            }
          },
          onReset: () {
            setState(() {
              _quizResult = null;
            });
          },
        );
      default:
        return const Text('Unsupported module type');
    }
  }

  Widget _buildNavigation(List<CourseModule> modules) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton.icon(
          onPressed: _currentIndex == 0
              ? null
              : () => setState(() {
                    _currentIndex--;
                  }),
          icon: const Icon(Icons.chevron_left),
          label: const Text('Previous'),
        ).animate().slideX(begin: -0.2, duration: 250.ms),
        Text('Module ${_currentIndex + 1} of ${modules.length}'),
        ElevatedButton.icon(
          onPressed: _currentIndex == modules.length - 1
              ? null
              : () => setState(() {
                    _currentIndex++;
                  }),
          icon: const Icon(Icons.chevron_right),
          label: const Text('Next'),
        ).animate().slideX(begin: 0.2, duration: 250.ms),
      ],
    );
  }
}

class _VideoHero extends StatelessWidget {
  const _VideoHero({this.videoUrl});

  final String? videoUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [Color(0xff0d47a1), Color(0xff1976d2)]),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.play_circle, color: Colors.white, size: 64),
            SizedBox(height: 12),
            Text('Video placeholder', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack);

    if (videoUrl == null) {
      return placeholder;
    }

    return Column(
      children: [
        placeholder,
        const SizedBox(height: 12),
        SelectableText('Open video: $videoUrl'),
      ],
    );
  }
}
