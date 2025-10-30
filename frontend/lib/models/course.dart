import 'dart:convert';

class Course {
  Course({
    required this.id,
    required this.code,
    required this.title,
    required this.summary,
    required this.durationMinutes,
    required this.certificateValidMonths,
    required this.level,
    required this.language,
    required this.updatedAtText,
    required this.learnersCount,
    required this.rating,
    required this.reviewCount,
    required this.author,
    required this.outcomes,
    required this.prerequisites,
    required this.captions,
    required this.resources,
    this.coverImageUrl,
    required this.modules,
  });

  final String id;
  final String code;
  final String title;
  final String summary;
  final int? durationMinutes;
  final int? certificateValidMonths;
  final String level;
  final String language;
  final String updatedAtText;
  final int learnersCount;
  final double rating;
  final int reviewCount;
  final CourseAuthor author;
  final List<String> outcomes;
  final List<String> prerequisites;
  final List<String> captions;
  final List<CourseResource> resources;
  final String? coverImageUrl;
  final List<CourseModule> modules;

  factory Course.fromJson(Map<String, dynamic> json) {
    final modulesJson = json['modules'] as List<dynamic>? ?? [];
    final resourcesJson = json['resources'] as List<dynamic>? ?? [];
    return Course(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      durationMinutes: json['durationMinutes'] as int?,
      certificateValidMonths: json['certificateValidMonths'] as int?,
      level: json['level'] as String? ?? 'Beginner',
      language: json['language'] as String? ?? 'English',
      updatedAtText: json['updatedAtText'] as String? ?? '',
      learnersCount: json['learnersCount'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      author: CourseAuthor.fromJson(
        json['author'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      outcomes: (json['outcomes'] as List<dynamic>? ?? [])
          .map((dynamic value) => value.toString())
          .toList(),
      prerequisites: (json['prerequisites'] as List<dynamic>? ?? [])
          .map((dynamic value) => value.toString())
          .toList(),
      captions: (json['captions'] as List<dynamic>? ?? [])
          .map((dynamic value) => value.toString())
          .toList(),
      resources: resourcesJson
          .map((dynamic value) =>
              CourseResource.fromJson(value as Map<String, dynamic>))
          .toList(),
      coverImageUrl: json['coverImageUrl'] as String?,
      modules: modulesJson
          .map((m) => CourseModule.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CourseAuthor {
  CourseAuthor({
    required this.name,
    required this.title,
    required this.bio,
  });

  final String name;
  final String? title;
  final String? bio;

  factory CourseAuthor.fromJson(Map<String, dynamic> json) {
    return CourseAuthor(
      name: json['name'] as String? ?? '',
      title: json['title'] as String?,
      bio: json['bio'] as String?,
    );
  }
}

class CourseResource {
  CourseResource({
    required this.label,
    required this.url,
    required this.type,
  });

  final String label;
  final String url;
  final String type;

  factory CourseResource.fromJson(Map<String, dynamic> json) {
    return CourseResource(
      label: json['label'] as String? ?? '',
      url: json['url'] as String? ?? '',
      type: json['type'] as String? ?? 'link',
    );
  }
}

class CourseModule {
  CourseModule({
    required this.id,
    required this.type,
    required this.position,
    required this.title,
    this.body,
    this.videoUrl,
    this.simulation,
    this.quiz,
    this.durationSeconds,
  });

  final String id;
  final String type;
  final int position;
  final String? title;
  final String? body;
  final String? videoUrl;
  final Map<String, dynamic>? simulation;
  final Quiz? quiz;
  final int? durationSeconds;

  factory CourseModule.fromJson(Map<String, dynamic> json) {
    final simulationJson = json['simulation'];
    Map<String, dynamic>? simulation;
    if (simulationJson is String) {
      simulation = jsonDecode(simulationJson) as Map<String, dynamic>;
    } else if (simulationJson is Map<String, dynamic>) {
      simulation = simulationJson;
    }

    return CourseModule(
      id: json['id'] as String,
      type: json['type'] as String,
      position: json['position'] as int,
      title: json['title'] as String?,
      body: json['body'] as String?,
      videoUrl: json['videoUrl'] as String?,
      simulation: simulation,
      quiz: json['quiz'] == null
          ? null
          : Quiz.fromJson(json['quiz'] as Map<String, dynamic>),
      durationSeconds: json['durationSeconds'] as int?,
    );
  }
}

class Quiz {
  Quiz({
    required this.id,
    required this.passingScore,
    required this.questions,
  });

  final String id;
  final int passingScore;
  final List<QuizQuestion> questions;

  factory Quiz.fromJson(Map<String, dynamic> json) {
    final questions = json['questions'] as List<dynamic>? ?? [];
    return Quiz(
      id: json['id'] as String,
      passingScore: json['passingScore'] as int,
      questions: questions
          .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}

class QuizQuestion {
  QuizQuestion({
    required this.id,
    required this.body,
    required this.type,
    required this.explanation,
    required this.options,
  });

  final String id;
  final String body;
  final String type;
  final String? explanation;
  final List<QuizOption> options;

  bool get isMultiple => type == 'multi';

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final options = json['options'] as List<dynamic>? ?? [];
    return QuizQuestion(
      id: json['id'] as String,
      body: json['body'] as String,
      type: json['type'] as String,
      explanation: json['explanation'] as String?,
      options: options
          .map((o) => QuizOption.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }
}

class QuizOption {
  QuizOption({
    required this.id,
    required this.body,
    required this.isCorrect,
  });

  final String id;
  final String body;
  final bool isCorrect;

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      id: json['id'] as String,
      body: json['body'] as String,
      isCorrect: json['isCorrect'] as bool? ?? false,
    );
  }
}
