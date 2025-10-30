import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:compliance_training_app/localization/app_localizations.dart';
import 'package:compliance_training_app/models/course.dart';
import 'package:compliance_training_app/screens/catalog_screen.dart';
import 'package:compliance_training_app/screens/dashboard_screen.dart';
import 'package:compliance_training_app/screens/course_detail_screen.dart';
import 'package:compliance_training_app/screens/course_player_screen.dart';
import 'package:compliance_training_app/screens/login_screen.dart';
import 'package:compliance_training_app/services/auth_service.dart';
import 'package:compliance_training_app/services/course_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'nb';

  final courseService = CourseService();
  await courseService.init();
  final authService = AuthService()..seedDemoUser();

  runApp(
    ComplianceTrainingApp(
      courseService: courseService,
      authService: authService,
    ),
  );
}

class ComplianceTrainingApp extends StatefulWidget {
  const ComplianceTrainingApp({
    super.key,
    required this.courseService,
    required this.authService,
  });

  final CourseService courseService;
  final AuthService authService;

  @override
  State<ComplianceTrainingApp> createState() => _ComplianceTrainingAppState();
}

class _ComplianceTrainingAppState extends State<ComplianceTrainingApp> {
  late final ValueListenable<bool> _authListenable;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authListenable = widget.authService.authState;
    _router = GoRouter(
      refreshListenable: _authListenable,
      redirect: (context, state) {
        final isSignedIn = widget.authService.isSignedIn;
        final loggingIn = state.matchedLocation == '/login';
        if (!isSignedIn) {
          return loggingIn
              ? null
              : '/login?redirect=${Uri.encodeComponent(state.uri.toString())}';
        }
        if (loggingIn) {
          final redirect = state.uri.queryParameters['redirect'];
          return redirect ?? '/';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              LoginScreen(authService: widget.authService),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) =>
              DashboardScreen(service: widget.courseService),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => CatalogScreen(
            courseService: widget.courseService,
            authService: widget.authService,
          ),
          routes: [
            GoRoute(
              path: 'course/:id',
              builder: (context, state) {
                final courseId = state.pathParameters['id'] ?? '';
                final course = state.extra as Course?;
                return CourseDetailScreen(
                  courseId: courseId,
                  service: widget.courseService,
                  initialCourse: course,
                );
              },
              routes: [
                GoRoute(
                  path: 'player',
                  builder: (context, state) {
                    final courseId = state.pathParameters['id'] ?? '';
                    final course = state.extra as Course?;
                    return CoursePlayerRoute(
                      courseId: courseId,
                      service: widget.courseService,
                      initialCourse: course,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff3366ff),
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff3366ff),
      brightness: Brightness.dark,
    );

    final baseText = ThemeData(brightness: Brightness.light).textTheme;
    final darkText = ThemeData(brightness: Brightness.dark).textTheme;

    ThemeData themed(ColorScheme scheme, TextTheme textTheme) {
      return ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: scheme.surface,
        textTheme: textTheme.copyWith(
          headlineLarge:
              textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
          headlineMedium:
              textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          headlineSmall:
              textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          titleLarge:
              textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          titleTextStyle: textTheme.titleLarge?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle:
                textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        ),
      );
    }

    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocalizationsDelegateHolder.notifier,
      builder: (context, locale, _) {
        return MaterialApp.router(
          title: 'Compliance & Safety Training',
          theme: themed(colorScheme, baseText),
          darkTheme: themed(darkScheme, darkText),
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.localizationsDelegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: _router,
        );
      },
    );
  }
}
