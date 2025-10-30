import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:compliance_training_app/localization/app_localizations.dart';
import 'package:compliance_training_app/models/course.dart';
import 'package:compliance_training_app/services/course_service.dart';
import 'package:compliance_training_app/services/auth_service.dart';
import 'package:compliance_training_app/widgets/language_toggle_button.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.courseService,
    required this.authService,
  });

  final CourseService courseService;
  final AuthService authService;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late Future<List<Course>> _future;
  String? _activeLocale;

  @override
  void initState() {
    super.initState();
    final initialLocale = Intl.defaultLocale ?? 'nb';
    _activeLocale = initialLocale;
    _future = widget.courseService.fetchCourses(locale: initialLocale);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeCode = Localizations.localeOf(context).languageCode;
    if (_activeLocale != localeCode) {
      _activeLocale = localeCode;
      setState(() {
        _future = widget.courseService.fetchCourses(locale: localeCode);
      });
    }
  }

  Future<void> _refresh() async {
    final localeCode =
        _activeLocale ?? Localizations.localeOf(context).languageCode;
    final future = widget.courseService.fetchCourses(locale: localeCode);
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.translate('catalog_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: l10n.translate('catalog_open_dashboard'),
            onPressed: () => GoRouter.of(context).go('/dashboard'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: LanguageToggleButton(showLabel: false, compact: true),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.translate('catalog_sign_out'),
            onPressed: () async {
              final router = GoRouter.of(context);
              await widget.authService.signOut();
              if (!mounted) return;
              router.go('/login');
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
              theme.colorScheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<List<Course>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _CatalogError(
                  error: snapshot.error,
                  onRetry: _refresh,
                  l10n: l10n,
                );
              }

              final courses = snapshot.data ?? [];
              if (courses.isEmpty) {
                return _EmptyState(l10n: l10n);
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: _CatalogHeader(
                            courseCount: courses.length, l10n: l10n),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(24),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 420,
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 24,
                          childAspectRatio: 0.95,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final course = courses[index];
                            return _CourseCard(
                              course: course,
                              l10n: l10n,
                              onTap: () => context.push('/course/${course.id}',
                                  extra: course),
                            )
                                .animate()
                                .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                                .slideY(begin: 0.08, end: 0);
                          },
                          childCount: courses.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: _CatalogFooter(l10n: l10n),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({required this.courseCount, required this.l10n});

  final int courseCount;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final courseLabel = courseCount == 1
        ? l10n.translate('catalog_summary_course_single')
        : l10n.translate('catalog_summary_course_multi',
            params: {'count': '$courseCount'});

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('catalog_summary_heading'),
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.translate('catalog_summary_body'),
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _CatalogMetaChip(icon: Icons.layers, label: courseLabel),
                _CatalogMetaChip(
                  icon: Icons.extension,
                  label: l10n.translate('catalog_summary_interactive'),
                ),
                _CatalogMetaChip(
                  icon: Icons.verified,
                  label: l10n.translate('catalog_summary_certified'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogFooter extends StatelessWidget {
  const _CatalogFooter({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            Icon(Icons.bolt, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                l10n.translate('catalog_footer_blurb'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError(
      {required this.error, required this.onRetry, required this.l10n});

  final Object? error;
  final Future<void> Function() onRetry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('catalog_loading_error',
                      params: {'error': '${error ?? ''}'}),
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.translate('course_quiz_retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              l10n.translate('catalog_empty_title'),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.translate('catalog_empty_body'),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogMetaChip extends StatelessWidget {
  const _CatalogMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard(
      {required this.course, required this.l10n, required this.onTap});

  final Course course;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.book_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    course.code,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                course.title,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  course.summary,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (course.durationMinutes != null)
                    _CatalogMetaChip(
                      icon: Icons.timer,
                      label: l10n.translate(
                        'catalog_course_duration',
                        params: {'minutes': '${course.durationMinutes}'},
                      ),
                    ),
                  if (course.certificateValidMonths != null)
                    _CatalogMetaChip(
                      icon: Icons.workspace_premium,
                      label: l10n.translate('catalog_course_certified'),
                    ),
                  _CatalogMetaChip(
                    icon: Icons.layers,
                    label: l10n.translate(
                      'catalog_course_modules',
                      params: {'count': '${course.modules.length}'},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
