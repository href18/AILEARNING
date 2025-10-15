import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/course.dart';
import 'screens/catalog_screen.dart';
import 'screens/course_player_screen.dart';
import 'services/course_service.dart';
import 'supabase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'nb';

  await Supabase.initialize(
    url: SupabaseOptions.url,
    anonKey: SupabaseOptions.anonKey,
    debug: true,
  );

  final courseService = CourseService(Supabase.instance.client);

  runApp(ComplianceTrainingApp(courseService: courseService));
}

class ComplianceTrainingApp extends StatelessWidget {
  ComplianceTrainingApp({super.key, required this.courseService});

  final CourseService courseService;

  late final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => CatalogScreen(courseService: courseService),
        routes: [
          GoRoute(
            path: 'course/:id',
            builder: (context, state) {
              final course = state.extra as Course?;
              if (course == null) {
                return const _MissingCourse();
              }
              return CoursePlayerScreen(course: course, service: courseService);
            },
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Compliance & Safety Training',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xff0052cc),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xff0052cc),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      routerConfig: _router,
    );
  }
}

class _MissingCourse extends StatelessWidget {
  const _MissingCourse();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(
        child: Text('Course not found. Return to the catalog.'),
      ),
    );
  }
}
