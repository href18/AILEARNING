import 'package:common/api/supabase_client.dart';
import 'package:common/models/course.dart';
import 'package:common/models/course_completion.dart';
import 'package:common/models/enrollment.dart';
import 'package:common/models/lesson.dart';
import 'package:common/models/module.dart';
import 'package:common/models/module_completion.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

final enrollmentsProvider = FutureProvider<List<Enrollment>>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  final userId = auth.profile?.id;
  if (userId == null) {
    return const [];
  }
  final response = await SupabaseManager.client
      .from('enrollments')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false);
  return (response as List<dynamic>)
      .map((json) => Enrollment.fromJson(json as Map<String, dynamic>))
      .toList();
});

final enrolledCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final enrollments = await ref.watch(enrollmentsProvider.future);
  if (enrollments.isEmpty) {
    return const [];
  }
  final ids = enrollments.map((e) => e.courseId).toList();
  final response = await SupabaseManager.client
      .from('courses')
      .select()
      .inFilter('id', ids)
      .order('title');
  return (response as List<dynamic>)
      .map((json) => Course.fromJson(json as Map<String, dynamic>))
      .toList();
});

final courseCompletionProvider = FutureProvider<Map<String, CourseCompletion>>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  final userId = auth.profile?.id;
  if (userId == null) {
    return const {};
  }
  final response = await SupabaseManager.client
      .from('course_completion')
      .select()
      .eq('user_id', userId);
  final entries = (response as List<dynamic>)
      .map((json) => CourseCompletion.fromJson(json as Map<String, dynamic>));
  return {for (final completion in entries) completion.courseId: completion};
});

final moduleCompletionProvider = FutureProvider<Map<String, ModuleCompletion>>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  final userId = auth.profile?.id;
  if (userId == null) {
    return const {};
  }
  final response = await SupabaseManager.client
      .from('module_completion')
      .select()
      .eq('user_id', userId);
  final entries = (response as List<dynamic>)
      .map((json) => ModuleCompletion.fromJson(json as Map<String, dynamic>));
  return {for (final completion in entries) completion.moduleId: completion};
});

class CourseContentData {
  CourseContentData({
    required this.course,
    required this.modules,
  });

  final Course course;
  final List<ModuleWithLessons> modules;
}

class ModuleWithLessons {
  ModuleWithLessons({
    required this.module,
    required this.lessons,
  });

  final Module module;
  final List<Lesson> lessons;
}

final courseContentProvider =
    FutureProvider.family<CourseContentData, String>((ref, courseId) async {
  final courseResponse = await SupabaseManager.client
      .from('courses')
      .select()
      .eq('id', courseId)
      .maybeSingle();
  if (courseResponse == null) {
    throw StateError('Course not found');
  }

  final moduleResponse = await SupabaseManager.client
      .from('modules')
      .select('*, lessons(*)')
      .eq('course_id', courseId)
      .order('order_index');

  final course = Course.fromJson(courseResponse as Map<String, dynamic>);
  final modules = <ModuleWithLessons>[];

  for (final raw in moduleResponse as List<dynamic>) {
    final map = raw as Map<String, dynamic>;
    final module = Module.fromJson(map);
    final lessonsRaw = (map['lessons'] as List<dynamic>? ?? []);
    final lessons = lessonsRaw
        .map((lessonJson) => Lesson.fromJson(lessonJson as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    modules.add(ModuleWithLessons(module: module, lessons: lessons));
  }

  modules.sort((a, b) => a.module.orderIndex.compareTo(b.module.orderIndex));

  return CourseContentData(course: course, modules: modules);
});
