import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'feature/auth/auth_providers.dart';
import 'feature/auth/login_screen.dart';
import 'feature/certificates/certificates_screen.dart';
import 'feature/creator/creator_dashboard_screen.dart';
import 'feature/explore/explore_screen.dart';
import 'feature/learning/course_learning_screen.dart';
import 'widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authNotifierProvider);
  return GoRouter(
    initialLocation: '/explore',
    refreshListenable: auth,
    redirect: (context, state) {
      final isLoggedIn = auth.isAuthenticated;
      final loggingIn = state.matchedLocation == '/login';
      if (!isLoggedIn) {
        return loggingIn ? null : '/login';
      }
      if (loggingIn) {
        return '/explore';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(state: state, child: child),
        routes: [
          GoRoute(
            path: '/explore',
            pageBuilder: (context, state) => const NoTransitionPage(child: ExploreScreen()),
          ),
          GoRoute(
            path: '/learning',
            pageBuilder: (context, state) => const NoTransitionPage(child: CourseLearningScreen()),
          ),
          GoRoute(
            path: '/certificates',
            pageBuilder: (context, state) => const NoTransitionPage(child: CertificatesScreen()),
          ),
          GoRoute(
            path: '/creator',
            pageBuilder: (context, state) => const NoTransitionPage(child: CreatorDashboardScreen()),
          ),
        ],
      ),
    ],
  );
});
