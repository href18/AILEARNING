import 'dart:convert';

class Course {
  Course({
    required this.id,
    required this.code,
    required this.title,
    required this.summary,
    required this.durationMinutes,
    required this.certificateValidMonths,
    required this.modules,
  });

  final String id;
  final String code;
  final String title;
  final String summary;
  final int? durationMinutes;
  final int? certificateValidMonths;
  final List<CourseModule> modules;

  factory Course.fromJson(Map<String, dynamic> json) {
    final modulesJson = json['modules'] as List<dynamic>? ?? [];
    return Course(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      durationMinutes: json['durationMinutes'] as int?,
      certificateValidMonths: json['certificateValidMonths'] as int?,
      modules: modulesJson
          .map((m) => CourseModule.fromJson(m as Map<String, dynamic>))
          .toList(),
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

class CourseDraft {
  CourseDraft({
    required this.code,
    this.status = 'published',
    this.durationMinutes,
    this.certificateValidMonths,
    required this.translations,
    required this.modules,
  });

  final String code;
  final String status;
  final int? durationMinutes;
  final int? certificateValidMonths;
  final List<CourseTranslationDraft> translations;
  final List<ModuleDraft> modules;

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'status': status,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (certificateValidMonths != null)
        'certificateValidMonths': certificateValidMonths,
      'translations': translations.map((t) => t.toJson()).toList(),
      'modules': modules.map((m) => m.toJson()).toList(),
    };
  }
}

class CourseTranslationDraft {
  CourseTranslationDraft({
    required this.locale,
    required this.title,
    required this.summary,
  });

  final String locale;
  final String title;
  final String summary;

  Map<String, dynamic> toJson() {
    return {
      'locale': locale,
      'title': title,
      'summary': summary,
    };
  }
}

class ModuleDraft {
  ModuleDraft({
    required this.type,
    required this.position,
    required this.translations,
    this.durationSeconds,
    this.quiz,
  });

  final String type;
  final int position;
  final int? durationSeconds;
  final List<ModuleTranslationDraft> translations;
  final QuizDraft? quiz;

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'position': position,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      'translations': translations.map((t) => t.toJson()).toList(),
      if (quiz != null) 'quiz': quiz!.toJson(),
    };
  }
}

class ModuleTranslationDraft {
  ModuleTranslationDraft({
    required this.locale,
    required this.title,
    this.body,
    this.videoUrl,
    this.simulation,
  });

  final String locale;
  final String title;
  final String? body;
  final String? videoUrl;
  final Map<String, dynamic>? simulation;

  Map<String, dynamic> toJson() {
    return {
      'locale': locale,
      'title': title,
      if (body != null) 'body': body,
      if (videoUrl != null) 'videoUrl': videoUrl,
      if (simulation != null) 'simulation': simulation,
    };
  }
}

class QuizDraft {
  QuizDraft({
    this.passingScore = 80,
    required this.questions,
  });

  final int passingScore;
  final List<QuizQuestionDraft> questions;

  Map<String, dynamic> toJson() {
    return {
      'passingScore': passingScore,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}

class QuizQuestionDraft {
  QuizQuestionDraft({
    required this.body,
    this.type = 'single',
    this.explanation,
    required this.options,
  });

  final String body;
  final String type;
  final String? explanation;
  final List<QuizOptionDraft> options;

  Map<String, dynamic> toJson() {
    return {
      'body': body,
      'type': type,
      if (explanation != null) 'explanation': explanation,
      'options': options.map((o) => o.toJson()).toList(),
    };
  }
}

class QuizOptionDraft {
  QuizOptionDraft({
    required this.body,
    this.isCorrect = false,
  });

  final String body;
  final bool isCorrect;

  Map<String, dynamic> toJson() {
    return {
      'body': body,
      'isCorrect': isCorrect,
    };
  }
}
