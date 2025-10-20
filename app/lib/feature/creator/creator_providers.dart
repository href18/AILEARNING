import 'package:common/api/supabase_client.dart';
import 'package:common/models/course.dart';
import 'package:common/models/lesson.dart';
import 'package:common/models/module.dart';
import 'package:common/models/module_completion.dart';
import 'package:common/models/webhook_endpoint.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

final creatorCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  final userId = auth.profile?.id;
  if (userId == null) {
    return const [];
  }
  final response = await SupabaseManager.client
      .from('courses')
      .select()
      .eq('creator_id', userId)
      .order('created_at', ascending: false);
  return (response as List<dynamic>)
      .map((json) => Course.fromJson(json as Map<String, dynamic>))
      .toList();
});

final creatorCourseContentProvider = FutureProvider.family<List<ModuleWithLessons>, String>((ref, courseId) async {
  final response = await SupabaseManager.client
      .from('modules')
      .select('*, lessons(*)')
      .eq('course_id', courseId)
      .order('order_index');
  final modules = <ModuleWithLessons>[];
  for (final raw in response as List<dynamic>) {
    final map = raw as Map<String, dynamic>;
    final module = Module.fromJson(map);
    final lessons = (map['lessons'] as List<dynamic>? ?? [])
        .map((lesson) => Lesson.fromJson(lesson as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    modules.add(ModuleWithLessons(module: module, lessons: lessons));
  }
  modules.sort((a, b) => a.module.orderIndex.compareTo(b.module.orderIndex));
  return modules;
});

class ModuleWithLessons {
  ModuleWithLessons({required this.module, required this.lessons});
  final Module module;
  final List<Lesson> lessons;
}

class ModuleAnalytics {
  ModuleAnalytics({
    required this.module,
    required this.completionRate,
    this.averageScore,
  });

  final Module module;
  final double completionRate;
  final double? averageScore;
}

class CourseAnalytics {
  CourseAnalytics({
    required this.courseId,
    required this.studentCount,
    required this.modules,
    this.lastActivity,
  });

  final String courseId;
  final int studentCount;
  final List<ModuleAnalytics> modules;
  final DateTime? lastActivity;
}

final courseAnalyticsProvider =
    FutureProvider.family<CourseAnalytics, String>((ref, courseId) async {
  final moduleResponse = await SupabaseManager.client
      .from('modules')
      .select()
      .eq('course_id', courseId)
      .order('order_index');
  final modules = (moduleResponse as List<dynamic>)
      .map((json) => Module.fromJson(json as Map<String, dynamic>))
      .toList();

  final enrollmentResponse = await SupabaseManager.client
      .from('enrollments')
      .select()
      .eq('course_id', courseId);
  final studentCount = (enrollmentResponse as List<dynamic>).length;

  final moduleIds = modules.map((m) => m.id).toList();
  List<dynamic> completionsRaw = [];
  if (moduleIds.isNotEmpty) {
    completionsRaw = await SupabaseManager.client
        .from('module_completion')
        .select()
        .inFilter('module_id', moduleIds);
  }
  final completions = completionsRaw
      .map((json) => ModuleCompletion.fromJson(json as Map<String, dynamic>))
      .toList();

  final moduleAnalytics = <ModuleAnalytics>[];
  for (final module in modules) {
    final moduleCompletions = completions.where((c) => c.moduleId == module.id);
    final completedCount = moduleCompletions.where((c) => c.isCompleted).length;
    final avgScoreEntries = moduleCompletions
        .map((c) => c.avgScore)
        .where((score) => score != null)
        .cast<int>()
        .toList();
    final completionRate = studentCount == 0
        ? 0.0
        : completedCount / studentCount;
    final avgScore = avgScoreEntries.isEmpty
        ? null
        : avgScoreEntries.reduce((a, b) => a + b) / avgScoreEntries.length;
    moduleAnalytics.add(ModuleAnalytics(
      module: module,
      completionRate: completionRate,
      averageScore: avgScore,
    ));
  }

  DateTime? lastActivity;
  if (moduleIds.isNotEmpty) {
    final lessonsResponse = await SupabaseManager.client
        .from('lessons')
        .select('id')
        .inFilter('module_id', moduleIds);
    final lessonIds = (lessonsResponse as List<dynamic>)
        .map((json) => (json as Map<String, dynamic>)['id'] as String)
        .toList();
    if (lessonIds.isNotEmpty) {
      final progressResponse = await SupabaseManager.client
          .from('progress')
          .select('updated_at')
          .inFilter('lesson_id', lessonIds)
          .order('updated_at', ascending: false)
          .limit(1);
      if (progressResponse is List<dynamic> && progressResponse.isNotEmpty) {
        final updated = (progressResponse.first as Map<String, dynamic>)['updated_at'] as String;
        lastActivity = DateTime.tryParse(updated);
      }
    }
  }

  return CourseAnalytics(
    courseId: courseId,
    studentCount: studentCount,
    modules: moduleAnalytics,
    lastActivity: lastActivity,
  );
});

final webhookEndpointsProvider = FutureProvider<List<WebhookEndpoint>>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  final userId = auth.profile?.id;
  if (userId == null) {
    return const [];
  }
  final response = await SupabaseManager.client
      .from('webhook_endpoints')
      .select()
      .eq('owner_id', userId)
      .order('created_at', ascending: false);
  return (response as List<dynamic>)
      .map((json) => WebhookEndpoint.fromJson(json as Map<String, dynamic>))
      .toList();
});
