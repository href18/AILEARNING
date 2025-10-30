import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:compliance_training_app/models/course.dart';

class CourseService {
  CourseService();

  SharedPreferences? _prefs;
  bool _initialized = false;
  final Map<String, ValueNotifier<Set<String>>> _progressNotifiers = {};

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _prefs = await SharedPreferences.getInstance();
    for (final template in _courseTemplates) {
      final saved =
          _prefs?.getStringList(_progressKey(template.id)) ?? <String>[];
      _progressNotifiers[template.id] = ValueNotifier(saved.toSet());
    }
    _initialized = true;
  }

  Future<List<Course>> fetchCourses({String locale = 'nb'}) async {
    await _ensureInitialized();
    await Future.delayed(const Duration(milliseconds: 150));
    final normalizedLocale = _normalizeLocale(locale);
    final language = normalizedLocale == 'en' ? 'en' : 'nb';
    return _courseTemplates
        .map((template) => template.build(language))
        .toList();
  }

  Future<DashboardSnapshot> loadDashboardSnapshot(
      {String locale = 'nb'}) async {
    final courses = await fetchCourses(locale: locale);
    final totalModules =
        courses.fold<int>(0, (sum, course) => sum + course.modules.length);
    final totalLearners =
        courses.fold<int>(0, (sum, course) => sum + course.learnersCount);
    final completedModules = courses.fold<int>(0, (sum, course) {
      final completed = _progressNotifiers[course.id]?.value.length ?? 0;
      return sum + completed;
    });

    final avgCompletion = totalModules == 0
        ? 0.0
        : (completedModules / totalModules).clamp(0.0, 1.0);

    final coursePerformance = courses.map((course) {
      final completed = _progressNotifiers[course.id]?.value.length ?? 0;
      final completionRate = course.modules.isEmpty
          ? 0.0
          : (completed / course.modules.length).clamp(0.0, 1.0);
      return CoursePerformance(
        courseId: course.id,
        courseTitle: course.title,
        learners: course.learnersCount,
        completionRate: completionRate,
        modules: course.modules.length,
      );
    }).toList()
      ..sort((a, b) => b.completionRate.compareTo(a.completionRate));

    final weeklyLaunches = _generateWeeklyLaunches(coursePerformance);
    final certificateAlerts = _mockCertificateAlerts(courses);
    final estimatedActiveLearners = totalLearners == 0
        ? 0
        : math.max(6, (totalLearners * (0.35 + avgCompletion * 0.45)).round());

    return DashboardSnapshot(
      totalCourses: courses.length,
      modulesInCatalog: totalModules,
      totalLearners: totalLearners,
      activeLearners: math.min(totalLearners, estimatedActiveLearners),
      averageCompletion: avgCompletion,
      coursePerformance: coursePerformance,
      weeklyLaunches: weeklyLaunches,
      certificateAlerts: certificateAlerts,
    );
  }

  Future<Course?> loadCourseById(String id, {String locale = 'nb'}) async {
    final courses = await fetchCourses(locale: locale);
    for (final course in courses) {
      if (course.id == id) {
        return course;
      }
    }
    return null;
  }

  ValueListenable<Set<String>> watchProgress(String courseId) {
    _ensureProgressNotifier(courseId);
    return _progressNotifiers[courseId]!;
  }

  bool isModuleCompleted(String courseId, String moduleId) {
    final notifier = _progressNotifiers[courseId];
    if (notifier == null) {
      return false;
    }
    return notifier.value.contains(moduleId);
  }

  Future<void> markModuleComplete(String courseId, String moduleId) async {
    await _ensureInitialized();
    final notifier = _ensureProgressNotifier(courseId);
    if (notifier.value.contains(moduleId)) {
      return;
    }
    final updated = {...notifier.value, moduleId};
    notifier.value = updated;
    await _prefs?.setStringList(_progressKey(courseId), updated.toList());
  }

  bool isModuleUnlocked(
    String courseId,
    List<CourseModule> modules,
    int moduleIndex,
    Set<String> completed,
  ) {
    if (moduleIndex <= 0) {
      return true;
    }
    final previousId = modules[moduleIndex - 1].id;
    return completed.contains(previousId);
  }

  Future<QuizResult> submitQuiz({
    required String moduleId,
    required Map<String, List<String>> answers,
  }) async {
    final template = _moduleTemplatesById[moduleId];
    if (template == null || template.quiz == null) {
      throw ArgumentError('Quiz module not found: $moduleId');
    }

    final quiz = template.quiz!;
    if (quiz.questions.isEmpty) {
      return QuizResult(score: 0, passed: false, details: const []);
    }

    var correctCount = 0;
    final details = <QuizResultDetail>[];
    for (final question in quiz.questions) {
      final submitted = (answers[question.id] ?? []).toSet();
      final correctOptionIds = question.options
          .where((option) => option.isCorrect)
          .map((option) => option.id)
          .toSet();

      final isCorrect = submitted.isNotEmpty &&
          submitted.length == correctOptionIds.length &&
          correctOptionIds.containsAll(submitted);

      if (isCorrect) {
        correctCount++;
      }

      details.add(
        QuizResultDetail(
          questionId: question.id,
          isCorrect: isCorrect,
          explanation: question.explanation,
          correctOptionIds: correctOptionIds.toList(),
        ),
      );
    }

    final score =
        ((correctCount / quiz.questions.length) * 100).round().clamp(0, 100);
    final passed = score >= quiz.passingScore;

    if (passed) {
      final courseId = _moduleToCourseId[moduleId];
      if (courseId != null) {
        unawaited(markModuleComplete(courseId, moduleId));
      }
    }

    return QuizResult(score: score, passed: passed, details: details);
  }

  List<CourseModule> modulesForCourse(String courseId, String locale) {
    final template = _courseTemplates.firstWhere(
      (c) => c.id == courseId,
      orElse: () {
        throw ArgumentError('Unknown course: $courseId');
      },
    );
    final language = _normalizeLocale(locale) == 'en' ? 'en' : 'nb';
    return template.build(language).modules;
  }

  Future<void> resetProgress(String courseId) async {
    await _ensureInitialized();
    final notifier = _ensureProgressNotifier(courseId);
    notifier.value = <String>{};
    await _prefs?.remove(_progressKey(courseId));
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    await init();
  }

  ValueNotifier<Set<String>> _ensureProgressNotifier(String courseId) {
    return _progressNotifiers.putIfAbsent(
      courseId,
      () {
        final saved =
            _prefs?.getStringList(_progressKey(courseId)) ?? <String>[];
        return ValueNotifier(saved.toSet());
      },
    );
  }

  String _normalizeLocale(String locale) {
    if (locale.isEmpty) {
      return 'nb';
    }
    final languageCode = locale.split('_').first.split('-').first;
    return languageCode == 'en' ? 'en' : 'nb';
  }

  String _progressKey(String courseId) => 'progress_$courseId';
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

class DashboardSnapshot {
  DashboardSnapshot({
    required this.totalCourses,
    required this.modulesInCatalog,
    required this.totalLearners,
    required this.activeLearners,
    required this.averageCompletion,
    required this.coursePerformance,
    required this.weeklyLaunches,
    required this.certificateAlerts,
  });

  final int totalCourses;
  final int modulesInCatalog;
  final int totalLearners;
  final int activeLearners;
  final double averageCompletion;
  final List<CoursePerformance> coursePerformance;
  final List<int> weeklyLaunches;
  final List<CertificateAlert> certificateAlerts;
}

class CoursePerformance {
  CoursePerformance({
    required this.courseId,
    required this.courseTitle,
    required this.learners,
    required this.completionRate,
    required this.modules,
  });

  final String courseId;
  final String courseTitle;
  final int learners;
  final double completionRate;
  final int modules;
}

class CertificateAlert {
  CertificateAlert({
    required this.courseId,
    required this.courseTitle,
    required this.learners,
    required this.expiryDate,
  });

  final String courseId;
  final String courseTitle;
  final int learners;
  final DateTime expiryDate;
}

final List<_CourseTemplate> _courseTemplates = [
  _CourseTemplate(
    id: 'course_fse_101',
    code: 'FSE-101',
    durationMinutes: 60,
    certificateValidMonths: 24,
    localizedTitle: {
      'nb': 'FSE Grunnkurs',
      'en': 'FSE Safety Basics',
    },
    localizedSummary: {
      'nb':
          'Grunnleggende sikkerhetsopplæring for arbeid nær elektriske anlegg.',
      'en': 'Mandatory electrical safety awareness training for contractors.',
    },
    localizedLevel: {
      'nb': 'Nybegynner',
      'en': 'Beginner',
    },
    localizedLanguageLabel: {
      'nb': 'Engelsk',
      'en': 'English',
    },
    localizedUpdatedAtText: {
      'nb': 'Oppdatert mars 2025',
      'en': 'Updated Mar 2025',
    },
    learnersCount: 40200,
    rating: 4.7,
    reviewCount: 3400,
    author: _AuthorTemplate(
      name: 'Dr. Jane Doe',
      localizedTitle: {
        'nb': 'Fagseksjonsleder, strøm & sikkerhet',
        'en': 'Lead Instructor, Electrical Safety',
      },
      localizedBio: {
        'nb':
            'Dr. Jane Doe har 15 års erfaring med elektrisk sikkerhet i industrien, og leder opplæringsprogrammer for energiselskaper i Norden.',
        'en':
            'Dr. Jane Doe brings 15 years of electrical safety leadership, coaching utility teams across the Nordics on compliance and field execution.',
      },
    ),
    localizedOutcomes: {
      'nb': [
        'Identifisere de fem grunnprinsippene i FSE og anvende dem i arbeidet.',
        'Utføre risikovurderinger og dokumentere kontrolltiltak før jobbstart.',
        'Håndtere beredskap ved elektriske hendelser og kommunisere i teamet.',
      ],
      'en': [
        'Recognise the five core FSE principles and apply them on the job.',
        'Run structured risk assessments and document controls before work.',
        'Respond to electrical incidents with confidence and team alignment.',
      ],
    },
    localizedPrerequisites: {
      'nb': [
        'Grunnleggende HMS-kompetanse.',
        'Tilgang til bedriftens FSE-prosedyrer.',
      ],
      'en': [
        'General workplace HSE knowledge.',
        'Access to your company’s FSE procedures.',
      ],
    },
    localizedCaptions: {
      'nb': ['Engelsk', 'Spansk', 'Fransk'],
      'en': ['English', 'Spanish', 'French'],
    },
    resources: [
      _ResourceTemplate(
        localizedLabel: {
          'nb': 'Syllabus (PDF)',
          'en': 'Syllabus (PDF)',
        },
        url: 'https://example.com/resources/fse-syllabus.pdf',
        type: 'pdf',
      ),
      _ResourceTemplate(
        localizedLabel: {
          'nb': 'Datasett for øvelser',
          'en': 'Exercise datasets',
        },
        url: 'https://example.com/resources/fse-datasets.zip',
        type: 'link',
      ),
    ],
    coverImageUrl:
        'https://images.unsplash.com/photo-1520607162513-77705c0f0d4a?auto=format&fit=crop&w=1400&q=80',
    modules: [
      _ModuleTemplate(
        id: 'fse_intro_video',
        type: 'video',
        position: 1,
        durationSeconds: 300,
        localizedTitle: {
          'nb': 'Introduksjonsvideo',
          'en': 'Introduction Video',
        },
        videoUrl: 'https://player.vimeo.com/video/76979871?h=8272103f6e',
      ),
      _ModuleTemplate(
        id: 'fse_principles_article',
        type: 'article',
        position: 2,
        durationSeconds: 420,
        localizedTitle: {
          'nb': 'Fem livsviktige prinsipper',
          'en': 'Five lifesaving principles',
        },
        localizedBody: {
          'nb':
              'Fem prinsipper danner grunnmuren i FSE-arbeidet.\n\n1. Hold avstand – vurder spenningssatte deler.\n2. Bryt strømmen – verifiser frakobling.\n3. Bruk godkjent verneutstyr – kontroller før bruk.\n4. Lås og merk – følg LOTO-rutiner.\n5. Rapporter avvik – bygg læringskultur.',
          'en':
              'Five simple rules keep electrical work safe.\n\n1. Maintain distance – identify live parts.\n2. De-energise – verify isolation.\n3. Wear certified PPE – inspect before every task.\n4. Lockout/tagout – log every intervention.\n5. Report deviations – capture incidents and near misses.',
        },
      ),
      _ModuleTemplate(
        id: 'fse_risk_assessment',
        type: 'article',
        position: 3,
        durationSeconds: 360,
        localizedTitle: {
          'nb': 'Risikovurdering steg for steg',
          'en': 'Step-by-step risk assessment',
        },
        localizedBody: {
          'nb':
              'Lær å identifisere farer i felt og dokumenter kontroller før arbeid startes. Inkluderer sjekkliste for spenningsløse arbeidsoperasjoner.',
          'en':
              'Learn to identify field hazards and document controls before work starts. Includes a checklist for de-energised operations.',
        },
      ),
      _ModuleTemplate(
        id: 'fse_scenario_simulation',
        type: 'simulation',
        position: 4,
        durationSeconds: 240,
        localizedTitle: {
          'nb': 'Scenario: Førstehjelp ved støt',
          'en': 'Scenario: First aid after shock',
        },
        simulation: {
          'steps': [
            {
              'title': 'Assess',
              'description':
                  'Sikre området, bryt strømmen og vurder egen sikkerhet.',
            },
            {
              'title': 'Alert',
              'description':
                  'Varsle 113, oppgi adresse og informer om strømskade.',
            },
            {
              'title': 'Aid',
              'description':
                  'Start HLR hvis nødvendig og klargjør hjertestarter.',
            },
            {
              'title': 'Follow-up',
              'description': 'Dokumenter hendelsen og hold debrief med teamet.',
            },
          ],
        },
      ),
      _ModuleTemplate(
        id: 'fse_live_work_guidelines',
        type: 'article',
        position: 5,
        durationSeconds: 420,
        localizedTitle: {
          'nb': 'Arbeid nær spenningsførende anlegg',
          'en': 'Working near live installations',
        },
        localizedBody: {
          'nb':
              'Dekker ESA-krav, minstehøyder og bruk av observatør. Inneholder tabell for sikkerhetsavstander.',
          'en':
              'Covers ESA requirements, minimum approach distances and the role of a safety observer. Includes a quick-reference distance table.',
        },
      ),
      _ModuleTemplate(
        id: 'fse_quiz',
        type: 'quiz',
        position: 6,
        durationSeconds: 600,
        localizedTitle: {
          'nb': 'Quiz: FSE grunnkurs',
          'en': 'Quiz: FSE fundamentals',
        },
        quiz: Quiz(
          id: 'quiz_fse',
          passingScore: 80,
          questions: [
            QuizQuestion(
              id: 'quiz_q1',
              body: 'Hva er første steg før arbeid på spenningssatte anlegg?',
              type: 'single',
              explanation:
                  'Arbeid skal aldri startes før spenning er bekreftet frakoblet.',
              options: [
                QuizOption(
                  id: 'quiz_q1_a1',
                  body: 'Verifisere frakobling og spenningsløs tilstand.',
                  isCorrect: true,
                ),
                QuizOption(
                  id: 'quiz_q1_a2',
                  body: 'Finne nærmeste nødutgang.',
                  isCorrect: false,
                ),
                QuizOption(
                  id: 'quiz_q1_a3',
                  body: 'Måle isolasjonsmotstand.',
                  isCorrect: false,
                ),
              ],
            ),
            QuizQuestion(
              id: 'quiz_q2',
              body: 'Hvilket verneutstyr er minimum ved arbeid i tavlerom?',
              type: 'multi',
              explanation:
                  'Hansker og ansiktsskjerm reduserer risiko for lysbueskade.',
              options: [
                QuizOption(
                  id: 'quiz_q2_a1',
                  body: 'Lysbuegodkjent visir',
                  isCorrect: true,
                ),
                QuizOption(
                  id: 'quiz_q2_a2',
                  body: 'Isolerende hansker',
                  isCorrect: true,
                ),
                QuizOption(
                  id: 'quiz_q2_a3',
                  body: 'Vernesko uten tåvern',
                  isCorrect: false,
                ),
              ],
            ),
            QuizQuestion(
              id: 'quiz_q3',
              body: 'Hvor ofte bør FSE-kompetanse fornyes internt i bedriften?',
              type: 'single',
              explanation: 'Årlige oppfriskninger er anbefalt praksis.',
              options: [
                QuizOption(
                  id: 'quiz_q3_a1',
                  body: 'Hvert år',
                  isCorrect: true,
                ),
                QuizOption(
                  id: 'quiz_q3_a2',
                  body: 'Annen hvert år',
                  isCorrect: false,
                ),
                QuizOption(
                  id: 'quiz_q3_a3',
                  body: 'Kun ved nyansettelser',
                  isCorrect: false,
                ),
              ],
            ),
          ],
        ),
      ),
      _ModuleTemplate(
        id: 'fse_reflection_journal',
        type: 'article',
        position: 7,
        durationSeconds: 300,
        localizedTitle: {
          'nb': 'Refleksjon og tiltak',
          'en': 'Reflection and next steps',
        },
        localizedBody: {
          'nb':
              'Oppsummer læringspunkter og planlegg tiltak for eget team. Inkluderer forslag til toolbox-møter.',
          'en':
              'Summarise learning points and plan actions for your team. Includes suggestions for toolbox talks.',
        },
      ),
    ],
  ),
  _CourseTemplate(
    id: 'course_hotwork_201',
    code: 'VARM-201',
    durationMinutes: 40,
    certificateValidMonths: 12,
    localizedTitle: {
      'nb': 'Varme arbeider - praksis',
      'en': 'Hot work fundamentals',
    },
    localizedSummary: {
      'nb':
          'Trygg utførelse av varme arbeider med fokus på forebygging og dokumentasjon.',
      'en':
          'Perform hot work safely with an emphasis on prevention and documentation.',
    },
    localizedLevel: {
      'nb': 'Mellomnivå',
      'en': 'Intermediate',
    },
    localizedLanguageLabel: {
      'nb': 'Engelsk',
      'en': 'English',
    },
    localizedUpdatedAtText: {
      'nb': 'Oppdatert januar 2025',
      'en': 'Updated Jan 2025',
    },
    learnersCount: 21500,
    rating: 4.6,
    reviewCount: 1890,
    author: _AuthorTemplate(
      name: 'Samuel Lee',
      localizedTitle: {
        'nb': 'Senior HMS-rådgiver',
        'en': 'Senior HSE Advisor',
      },
      localizedBio: {
        'nb':
            'Samuel har sertifisert over 8 000 arbeidere i varme arbeider og står bak flere bransjestandarder for forebygging.',
        'en':
            'Samuel has certified 8,000+ technicians in hot work and co-authored industry standards on fire prevention.',
      },
    ),
    localizedOutcomes: {
      'nb': [
        'Planlegge varme arbeider med riktig risikostyring og dokumentasjon.',
        'Velge og kontrollere slokkeutstyr før, under og etter arbeid.',
        'Implementere ettersynsrutiner og logging av målinger.',
      ],
      'en': [
        'Plan hot work with the right risk controls and permits.',
        'Select and verify extinguishing gear before, during, and after tasks.',
        'Implement post-work inspections and measurement logs.',
      ],
    },
    localizedPrerequisites: {
      'nb': [
        'Gyldig grunnleggende HMS-kurs.',
        'Kjennskap til lokale brannrutiner.',
      ],
      'en': [
        'Valid basic HSE course.',
        'Familiarity with local fire procedures.',
      ],
    },
    localizedCaptions: {
      'nb': ['Engelsk', 'Norsk'],
      'en': ['English', 'Norwegian'],
    },
    resources: [
      _ResourceTemplate(
        localizedLabel: {
          'nb': 'Permit-mal (DOCX)',
          'en': 'Permit template (DOCX)',
        },
        url: 'https://example.com/resources/hotwork-permit.docx',
        type: 'doc',
      ),
      _ResourceTemplate(
        localizedLabel: {
          'nb': 'Sjekkliste for slokkemidler',
          'en': 'Extinguishing checklist',
        },
        url: 'https://example.com/resources/hotwork-checklist.pdf',
        type: 'pdf',
      ),
    ],
    coverImageUrl:
        'https://images.unsplash.com/photo-1518002171953-d2a32874c4ec?auto=format&fit=crop&w=1400&q=80',
    modules: [
      _ModuleTemplate(
        id: 'hot_intro_article',
        type: 'article',
        position: 1,
        durationSeconds: 240,
        localizedTitle: {
          'nb': 'Sertifiseringskrav og ansvarsroller',
          'en': 'Certification requirements and roles',
        },
        localizedBody: {
          'nb':
              'Entreprenør, tilsynsansvarlig og utførende må samarbeide før arbeid startes. Bruk sjekkliste og slokkemidler.',
          'en':
              'Contractor, supervisor and operator must align before work starts. Use the checklist and ensure extinguishing equipment.',
        },
      ),
      _ModuleTemplate(
        id: 'hot_site_setup',
        type: 'article',
        position: 2,
        durationSeconds: 300,
        localizedTitle: {
          'nb': 'Rigging av arbeidssted',
          'en': 'Preparing the work site',
        },
        localizedBody: {
          'nb':
              'Slik planlegger du sperringer, avstand og ventilasjon før arbeidet tennes.',
          'en':
              'How to plan barriers, clearance and ventilation before the work begins.',
        },
      ),
      _ModuleTemplate(
        id: 'hot_video',
        type: 'video',
        position: 3,
        durationSeconds: 420,
        localizedTitle: {
          'nb': 'Video: Kontroll før gnist',
          'en': 'Video: Control before sparks',
        },
        videoUrl: 'https://samplelib.com/lib/preview/mp4/sample-5s.mp4',
      ),
      _ModuleTemplate(
        id: 'hot_permit_simulation',
        type: 'simulation',
        position: 4,
        durationSeconds: 300,
        localizedTitle: {
          'nb': 'Permit-simulering',
          'en': 'Permit walk-through',
        },
        simulation: {
          'steps': [
            {
              'title': 'Sjekk området',
              'description':
                  'Fjern brennbar last og verifiser overflate-temperatur.',
            },
            {
              'title': 'Fullfør sjekklisten',
              'description':
                  'Signer permitten og bekreft slokkeutstyr på plass.',
            },
            {
              'title': 'Overvåk gnister',
              'description': 'Hold vakt og logg temperaturmålinger underveis.',
            },
            {
              'title': 'Ettersyn',
              'description':
                  'Overvåk området i minimum 60 minutter og dokumenter kontroll.',
            },
          ],
        },
      ),
      _ModuleTemplate(
        id: 'hot_quiz',
        type: 'quiz',
        position: 5,
        durationSeconds: 480,
        localizedTitle: {
          'nb': 'Quiz: Slokking og beredskap',
          'en': 'Quiz: Extinguishing readiness',
        },
        quiz: Quiz(
          id: 'quiz_hotwork',
          passingScore: 70,
          questions: [
            QuizQuestion(
              id: 'hot_q1',
              body:
                  'Hvor lenge skal området overvåkes etter avsluttet varmt arbeid?',
              type: 'single',
              explanation:
                  'Minimum en time overvåking er bransjestandard for å fange etterslukking.',
              options: [
                QuizOption(
                  id: 'hot_q1_a1',
                  body: '30 minutter',
                  isCorrect: false,
                ),
                QuizOption(
                  id: 'hot_q1_a2',
                  body: '60 minutter',
                  isCorrect: true,
                ),
                QuizOption(
                  id: 'hot_q1_a3',
                  body: 'Til lunsjpausen',
                  isCorrect: false,
                ),
              ],
            ),
            QuizQuestion(
              id: 'hot_q2',
              body: 'Hvilke to tiltak er minimum før varmearbeid starter?',
              type: 'multi',
              explanation:
                  'Du må fjerne brennbart materiale og sikre godkjent slokkeutstyr.',
              options: [
                QuizOption(
                  id: 'hot_q2_a1',
                  body: 'Fjerne brennbart materiale',
                  isCorrect: true,
                ),
                QuizOption(
                  id: 'hot_q2_a2',
                  body: 'Varsle brannvesenet',
                  isCorrect: false,
                ),
                QuizOption(
                  id: 'hot_q2_a3',
                  body: 'Klargjøre slokkeutstyr',
                  isCorrect: true,
                ),
              ],
            ),
            QuizQuestion(
              id: 'hot_q3',
              body:
                  'Hvor mange tilgjengelige slokkemidler krever sertifiseringen?',
              type: 'single',
              explanation:
                  'Det kreves minst to godkjente slokkemidler per arbeidssted.',
              options: [
                QuizOption(
                  id: 'hot_q3_a1',
                  body: 'Ett CO₂-apparat',
                  isCorrect: false,
                ),
                QuizOption(
                  id: 'hot_q3_a2',
                  body: 'To godkjente slokkemidler',
                  isCorrect: true,
                ),
                QuizOption(
                  id: 'hot_q3_a3',
                  body: 'Kun brannslange',
                  isCorrect: false,
                ),
              ],
            ),
          ],
        ),
      ),
      _ModuleTemplate(
        id: 'hot_action_plan',
        type: 'article',
        position: 6,
        durationSeconds: 240,
        localizedTitle: {
          'nb': 'Handlingsplan',
          'en': 'Action plan',
        },
        localizedBody: {
          'nb':
              'Oppsummer tiltakene du skal implementere på arbeidsplassen og planlegg oppfølging.',
          'en':
              'Summarise the actions you will implement on site and plan follow-up sessions.',
        },
      ),
    ],
  ),
];

class _CourseTemplate {
  _CourseTemplate({
    required this.id,
    required this.code,
    required this.durationMinutes,
    required this.certificateValidMonths,
    required this.localizedTitle,
    required this.localizedSummary,
    required this.localizedLevel,
    required this.localizedLanguageLabel,
    required this.localizedUpdatedAtText,
    required this.learnersCount,
    required this.rating,
    required this.reviewCount,
    required this.author,
    required this.localizedOutcomes,
    required this.localizedPrerequisites,
    required this.localizedCaptions,
    required this.resources,
    required this.modules,
    this.coverImageUrl,
  });

  final String id;
  final String code;
  final int durationMinutes;
  final int certificateValidMonths;
  final Map<String, String> localizedTitle;
  final Map<String, String> localizedSummary;
  final Map<String, String> localizedLevel;
  final Map<String, String> localizedLanguageLabel;
  final Map<String, String> localizedUpdatedAtText;
  final int learnersCount;
  final double rating;
  final int reviewCount;
  final _AuthorTemplate author;
  final Map<String, List<String>> localizedOutcomes;
  final Map<String, List<String>> localizedPrerequisites;
  final Map<String, List<String>> localizedCaptions;
  final List<_ResourceTemplate> resources;
  final List<_ModuleTemplate> modules;
  final String? coverImageUrl;

  Course build(String locale) {
    final language = locale == 'en' ? 'en' : 'nb';
    return Course(
      id: id,
      code: code,
      title: localizedTitle[language] ?? localizedTitle['nb'] ?? '',
      summary: localizedSummary[language] ?? localizedSummary['nb'] ?? '',
      durationMinutes: durationMinutes,
      certificateValidMonths: certificateValidMonths,
      level: localizedLevel[language] ?? localizedLevel['nb'] ?? '',
      language: localizedLanguageLabel[language] ??
          localizedLanguageLabel['nb'] ??
          '',
      updatedAtText: localizedUpdatedAtText[language] ??
          localizedUpdatedAtText['nb'] ??
          '',
      learnersCount: learnersCount,
      rating: rating,
      reviewCount: reviewCount,
      author: author.build(language),
      outcomes:
          localizedOutcomes[language] ?? localizedOutcomes['nb'] ?? const [],
      prerequisites: localizedPrerequisites[language] ??
          localizedPrerequisites['nb'] ??
          const [],
      captions:
          localizedCaptions[language] ?? localizedCaptions['nb'] ?? const [],
      resources: resources.map((resource) => resource.build(language)).toList(),
      coverImageUrl: coverImageUrl,
      modules: modules.map((module) => module.build(language)).toList(),
    );
  }
}

class _ModuleTemplate {
  _ModuleTemplate({
    required this.id,
    required this.type,
    required this.position,
    required this.durationSeconds,
    required this.localizedTitle,
    this.localizedBody,
    this.videoUrl,
    this.simulation,
    this.quiz,
  });

  final String id;
  final String type;
  final int position;
  final int? durationSeconds;
  final Map<String, String> localizedTitle;
  final Map<String, String>? localizedBody;
  final String? videoUrl;
  final Map<String, dynamic>? simulation;
  final Quiz? quiz;

  CourseModule build(String locale) {
    final language = locale == 'en' ? 'en' : 'nb';
    return CourseModule(
      id: id,
      type: type,
      position: position,
      title: localizedTitle[language] ?? localizedTitle['nb'],
      body: localizedBody?[language] ?? localizedBody?['nb'],
      videoUrl: videoUrl,
      simulation: simulation,
      quiz: quiz,
      durationSeconds: durationSeconds,
    );
  }
}

class _AuthorTemplate {
  _AuthorTemplate({
    required this.name,
    required this.localizedTitle,
    required this.localizedBio,
  });

  final String name;
  final Map<String, String> localizedTitle;
  final Map<String, String> localizedBio;

  CourseAuthor build(String locale) {
    final language = locale == 'en' ? 'en' : 'nb';
    return CourseAuthor(
      name: name,
      title: localizedTitle[language] ?? localizedTitle['nb'],
      bio: localizedBio[language] ?? localizedBio['nb'],
    );
  }
}

class _ResourceTemplate {
  _ResourceTemplate({
    required this.localizedLabel,
    required this.url,
    required this.type,
  });

  final Map<String, String> localizedLabel;
  final String url;
  final String type;

  CourseResource build(String locale) {
    final language = locale == 'en' ? 'en' : 'nb';
    return CourseResource(
      label: localizedLabel[language] ?? localizedLabel['nb'] ?? '',
      url: url,
      type: type,
    );
  }
}

final Map<String, String> _moduleToCourseId = {
  for (final course in _courseTemplates)
    for (final module in course.modules) module.id: course.id,
};

final Map<String, _ModuleTemplate> _moduleTemplatesById = {
  for (final course in _courseTemplates)
    for (final module in course.modules) module.id: module,
};

List<int> _generateWeeklyLaunches(List<CoursePerformance> performance) {
  final base = [18, 24, 26, 23, 28, 32, 38];
  final lift =
      performance.isEmpty ? 0.0 : performance.first.completionRate * 12;
  return base.asMap().entries.map((entry) {
    final wave = math.sin(entry.key / 1.5) * 3;
    return (entry.value + lift + wave).round();
  }).toList();
}

List<CertificateAlert> _mockCertificateAlerts(List<Course> courses) {
  final now = DateTime.now();
  final alerts = <CertificateAlert>[];
  for (var i = 0; i < courses.length; i++) {
    final course = courses[i];
    final dueInDays = 20 + i * 15;
    alerts.add(
      CertificateAlert(
        courseId: course.id,
        courseTitle: course.title,
        learners: math.max(4, (course.learnersCount * 0.1).round()),
        expiryDate: now.add(Duration(days: dueInDays)),
      ),
    );
  }
  return alerts;
}
