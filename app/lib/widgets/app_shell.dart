import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../feature/auth/auth_providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.child, required this.state, super.key});

  final Widget child;
  final GoRouterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final tabs = [
      _ShellTab(path: '/explore', label: 'Explore', icon: Icons.explore),
      _ShellTab(path: '/learning', label: 'My Learning', icon: Icons.menu_book),
      _ShellTab(path: '/certificates', label: 'Certificates', icon: Icons.workspace_premium),
      if (auth.isCreator)
        _ShellTab(path: '/creator', label: 'Creator', icon: Icons.dashboard_customize),
    ];

    final location = state.matchedLocation;
    final currentIndex = tabs.indexWhere((tab) => location.startsWith(tab.path));

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex < 0 ? 0 : currentIndex,
        onDestinationSelected: (index) {
          context.go(tabs[index].path);
        },
        destinations: [
          for (final tab in tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}

class _ShellTab {
  const _ShellTab({required this.path, required this.label, required this.icon});

  final String path;
  final String label;
  final IconData icon;
}
