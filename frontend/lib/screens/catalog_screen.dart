import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/course.dart';
import '../services/course_service.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.courseService});

  final CourseService courseService;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late Future<List<Course>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.courseService.fetchCourses(locale: Intl.getCurrentLocale());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compliance & Safety Catalog'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'My page',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go('/me'),
          ),
        ],
      ),
      body: FutureBuilder<List<Course>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load courses: ${snapshot.error}'),
              ),
            );
          }

          final courses = snapshot.data ?? [];
          if (courses.isEmpty) {
            return const Center(child: Text('No courses published yet.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.8,
            ),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return _CourseCard(course: course)
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .move(begin: const Offset(0, 16), duration: 350.ms);
            },
          );
        },
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/course/${course.id}', extra: course),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(course.code, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(course.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  course.summary,
                  style: theme.textTheme.bodyLarge,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  if (course.durationMinutes != null)
                    Chip(
                      avatar: const Icon(Icons.timer, size: 16),
                      label: Text('${course.durationMinutes} min'),
                    ),
                  if (course.certificateValidMonths != null)
                    Chip(
                      avatar: const Icon(Icons.verified, size: 16),
                      label: Text('Certificate ${course.certificateValidMonths} mth'),
                    ),
                  Chip(
                    avatar: const Icon(Icons.layers, size: 16),
                    label: Text('${course.modules.length} modules'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
