import 'package:common/api/supabase_client.dart';
import 'package:common/models/course.dart';
import 'package:common/models/course_completion.dart';
import 'package:common/models/lesson.dart';
import 'package:common/models/module.dart';
import 'package:common/models/module_completion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'learning_providers.dart';

class CourseLearningScreen extends ConsumerStatefulWidget {
  const CourseLearningScreen({super.key});

  @override
  ConsumerState<CourseLearningScreen> createState() => _CourseLearningScreenState();
}

class _CourseLearningScreenState extends ConsumerState<CourseLearningScreen> {
  String? _selectedCourseId;

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(enrolledCoursesProvider);
    final courseCompletion = ref.watch(courseCompletionProvider).maybeWhen(
          data: (data) => data,
          orElse: () => const <String, CourseCompletion>{},
        );

    return SafeArea(
      child: coursesAsync.when(
        data: (courses) {
          if (courses.isEmpty) {
            return const Center(child: Text('Purchase a course to begin learning.'));
          }

          final selectedCourse = _selectedCourseId != null
              ? courses.firstWhere(
                  (course) => course.id == _selectedCourseId,
                  orElse: () => courses.first,
                )
              : courses.first;

          _selectedCourseId = selectedCourse.id;

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  children: [
                    SizedBox(
                      width: 320,
                      child: _CourseList(
                        courses: courses,
                        courseCompletion: courseCompletion,
                        onSelect: (course) {
                          setState(() {
                            _selectedCourseId = course.id;
                          });
                        },
                        selectedId: selectedCourse.id,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: CourseDetailView(courseId: selectedCourse.id),
                    ),
                  ],
                );
              }

              return _CourseList(
                courses: courses,
                courseCompletion: courseCompletion,
                selectedId: selectedCourse.id,
                onSelect: (course) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CourseDetailPage(course: course),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load courses: $error')),
      ),
    );
  }
}

class _CourseList extends StatelessWidget {
  const _CourseList({
    required this.courses,
    required this.courseCompletion,
    required this.onSelect,
    required this.selectedId,
  });

  final List<Course> courses;
  final Map<String, CourseCompletion> courseCompletion;
  final void Function(Course) onSelect;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final course = courses[index];
        final completion = courseCompletion[course.id];
        final progress = completion == null
            ? 0.0
            : (completion.isCompleted ? 1.0 : 0.5);
        final subtitle = completion == null
            ? 'Not started'
            : (completion.isCompleted ? 'Completed' : 'In progress');
        return ListTile(
          selected: selectedId == course.id,
          title: Text(course.title),
          subtitle: Text(subtitle),
          trailing: SizedBox(
            width: 120,
            child: LinearProgressIndicator(value: progress),
          ),
          onTap: () => onSelect(course),
        );
      },
      separatorBuilder: (_, __) => const Divider(),
      itemCount: courses.length,
    );
  }
}

class CourseDetailPage extends StatelessWidget {
  const CourseDetailPage({required this.course, super.key});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(course.title)),
      body: CourseDetailView(courseId: course.id),
    );
  }
}

class CourseDetailView extends ConsumerWidget {
  const CourseDetailView({required this.courseId, super.key});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(courseContentProvider(courseId));
    final moduleCompletion = ref.watch(moduleCompletionProvider).maybeWhen(
          data: (data) => data,
          orElse: () => const <String, ModuleCompletion>{},
        );

    return contentAsync.when(
      data: (data) {
        final modules = data.modules;
        final moduleStatus = _calculateModuleStatus(modules, moduleCompletion);
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: modules.length,
          itemBuilder: (context, index) {
            final moduleData = modules[index];
            final status = moduleStatus[moduleData.module.id]!;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ExpansionTile(
                initiallyExpanded: index == 0,
                title: Text(moduleData.module.title),
                subtitle: Text(status.locked
                    ? 'Locked'
                    : status.completed
                        ? 'Completed'
                        : 'In progress'),
                children: [
                  for (final lesson in moduleData.lessons)
                    ListTile(
                      title: Text(lesson.title),
                      subtitle: lesson.contentUrl != null
                          ? Text(lesson.contentUrl!)
                          : const Text('No content URL'),
                      trailing: FilledButton(
                        onPressed: status.locked
                            ? null
                            : () => _completeLesson(context, ref, lesson, courseId),
                        child: const Text('Mark Complete'),
                      ),
                      onTap: lesson.contentUrl == null
                          ? null
                          : () async {
                              final uri = Uri.parse(lesson.contentUrl!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                    ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Failed to load course: $error')),
    );
  }

  Map<String, ModuleCompletionInfo> _calculateModuleStatus(
    List<ModuleWithLessons> modules,
    Map<String, ModuleCompletion> moduleCompletion,
  ) {
    final status = <String, ModuleCompletionInfo>{};
    var prevRequiredIncomplete = false;
    for (final module in modules) {
      final completion = moduleCompletion[module.module.id];
      final completed = completion?.isCompleted ?? false;
      final locked = prevRequiredIncomplete;
      status[module.module.id] = ModuleCompletionInfo(
        completed: completed,
        locked: locked,
      );
      if (module.module.required && !completed) {
        prevRequiredIncomplete = true;
      }
    }
    return status;
  }

  Future<void> _completeLesson(
      BuildContext context, WidgetRef ref, Lesson lesson, String courseId) async {
    try {
      await SupabaseManager.client.rpc('complete_lesson', params: {
        'p_lesson_id': lesson.id,
      });
      ref.invalidate(moduleCompletionProvider);
      ref.invalidate(courseCompletionProvider);
      ref.invalidate(courseContentProvider(courseId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked ${lesson.title} as complete')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete lesson: $error')),
        );
      }
    }
  }
}

class ModuleCompletionInfo {
  const ModuleCompletionInfo({required this.completed, required this.locked});

  final bool completed;
  final bool locked;
}
