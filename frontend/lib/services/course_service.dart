import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/assignment.dart';
import '../models/course.dart';

class CourseService {
  CourseService(this.client);

  final SupabaseClient client;

  Future<List<Course>> fetchCourses({String locale = 'nb'}) async {
    final response = await client
        .from('courses')
        .select(
            'id, code, status, duration_minutes, certificate_valid_months, course_i18n!inner(locale, title, summary), modules(id, type, position, duration_seconds, module_i18n!inner(locale, title, body_md, video_url, simulation_json), quiz:quizzes(id, passing_score, questions:quiz_questions(id, body, type, explanation, options:quiz_options(id, body, is_correct))))')
        .eq('status', 'published')
        .eq('course_i18n.locale', locale)
        .order('code');

    final courses = (response as List<dynamic>)
        .map((dynamic item) => _mapCourse(item as Map<String, dynamic>))
        .toList();
    return courses;
  }

  Future<QuizResult> submitQuiz({required String moduleId, required Map<String, List<String>> answers}) async {
    final response = await client.functions.invoke(
      'api',
      body: {
        'path': '/quiz',
        'module_id': moduleId,
        'answers': answers,
      },
      headers: {
        'x-edge-path': '/quiz',
      },
    );

    if (response.error != null) {
      throw response.error!;
    }

    final data = response.data as Map<String, dynamic>;
    return QuizResult(
      score: data['score'] as int? ?? 0,
      passed: data['passed'] as bool? ?? false,
      details: (data['details'] as List<dynamic>? ?? [])
          .map((dynamic item) => QuizResultDetail.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<Assignment>> fetchAssignmentsForUser({required String userId, String locale = 'nb'}) async {
    final response = await client.functions.invoke(
      'api',
      body: {
        'path': '/me/assignments',
        'user_id': userId,
        'locale': locale,
      },
      headers: {
        'x-edge-path': '/me/assignments',
      },
    );

    if (response.error != null) {
      throw response.error!;
    }

    final payload = response.data as Map<String, dynamic>? ?? {};
    final assignments = (payload['assignments'] as List<dynamic>? ?? [])
        .map((dynamic item) => Assignment.fromJson(item as Map<String, dynamic>))
        .toList();
    return assignments;
  }

  Course _mapCourse(Map<String, dynamic> row) {
    final localeData = (row['course_i18n'] as List<dynamic>?)?.firstOrNull as Map<String, dynamic>?;
    final modules = (row['modules'] as List<dynamic>? ?? [])
        .map((dynamic module) => _mapModule(module as Map<String, dynamic>))
        .sortedBy((module) => module.position)
        .toList();

    return Course(
      id: row['id'] as String,
      code: row['code'] as String,
      title: localeData?['title'] as String? ?? '',
      summary: localeData?['summary'] as String? ?? '',
      durationMinutes: row['duration_minutes'] as int?,
      certificateValidMonths: row['certificate_valid_months'] as int?,
      modules: modules,
    );
  }

  CourseModule _mapModule(Map<String, dynamic> row) {
    final localeData = (row['module_i18n'] as List<dynamic>?)?.firstOrNull as Map<String, dynamic>?;
    Map<String, dynamic>? simulation;
    final rawSimulation = localeData?['simulation_json'];
    if (rawSimulation is Map<String, dynamic>) {
      simulation = rawSimulation;
    } else if (rawSimulation is String) {
      simulation = jsonDecode(rawSimulation) as Map<String, dynamic>;
    }

    Quiz? quiz;
    final quizData = row['quiz'];
    if (quizData is Map<String, dynamic>) {
      quiz = Quiz(
        id: quizData['id'] as String,
        passingScore: quizData['passing_score'] as int? ?? 0,
        questions: (quizData['questions'] as List<dynamic>? ?? [])
            .map((dynamic q) => QuizQuestion(
                  id: (q as Map<String, dynamic>)['id'] as String,
                  body: q['body'] as String? ?? '',
                  type: q['type'] as String? ?? 'single',
                  explanation: q['explanation'] as String?,
                  options: (q['options'] as List<dynamic>? ?? [])
                      .map((dynamic option) => QuizOption(
                            id: (option as Map<String, dynamic>)['id'] as String,
                            body: option['body'] as String? ?? '',
                            isCorrect: option['is_correct'] as bool? ?? false,
                          ))
                      .toList(),
                ))
            .toList(),
      );
    }

    return CourseModule(
      id: row['id'] as String,
      type: row['type'] as String,
      position: row['position'] as int,
      title: localeData?['title'] as String?,
      body: localeData?['body_md'] as String?,
      videoUrl: localeData?['video_url'] as String?,
      simulation: simulation,
      quiz: quiz,
      durationSeconds: row['duration_seconds'] as int?,
    );
  }
}

class QuizResult {
  QuizResult({
    required this.score,
    required this.passed,
    required this.details,
  });

  final int score;
  final bool passed;
  final List<QuizResultDetail> details;
}

class QuizResultDetail {
  QuizResultDetail({
    required this.questionId,
    required this.isCorrect,
    required this.explanation,
    required this.correctOptionIds,
  });

  final String questionId;
  final bool isCorrect;
  final String? explanation;
  final List<String> correctOptionIds;

  factory QuizResultDetail.fromJson(Map<String, dynamic> json) {
    return QuizResultDetail(
      questionId: json['questionId'] as String,
      isCorrect: json['isCorrect'] as bool? ?? false,
      explanation: json['explanation'] as String?,
      correctOptionIds: (json['correctOptionIds'] as List<dynamic>? ?? [])
          .map((dynamic id) => id.toString())
          .toList(),
    );
  }
}
