import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:compliance_training_app/localization/app_localizations.dart';
import 'package:compliance_training_app/services/course_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.service});

  final CourseService service;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<DashboardSnapshot>? _future;
  String? _localeTag;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode;
    if (_localeTag != locale || _future == null) {
      _localeTag = locale;
      _future = widget.service.loadDashboardSnapshot(locale: locale);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: FutureBuilder<DashboardSnapshot>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData) {
                return Center(
                  child: Text(
                    l10n.translate('dashboard_empty'),
                    style: theme.textTheme.titleMedium,
                  ),
                );
              }
              final data = snapshot.data!;
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _DashboardHeader(l10n: l10n),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: _MetricsWrap(data: data, l10n: l10n, theme: theme),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: _WeeklyActivityCard(
                        data: data, l10n: l10n, theme: theme),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child:
                        _TopCoursesCard(data: data, l10n: l10n, theme: theme),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: _CertificateAlertsCard(
                        data: data, l10n: l10n, theme: theme),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 48)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.translate('dashboard_title'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.translate('dashboard_activity_label'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricsWrap extends StatelessWidget {
  const _MetricsWrap({
    required this.data,
    required this.l10n,
    required this.theme,
  });

  final DashboardSnapshot data;
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricTile(
        label: l10n.translate('dashboard_metric_courses'),
        value: data.totalCourses.toString(),
        icon: Icons.menu_book_outlined,
        color: theme.colorScheme.primary,
      ),
      _MetricTile(
        label: l10n.translate('dashboard_metric_modules'),
        value: data.modulesInCatalog.toString(),
        icon: Icons.layers_outlined,
        color: const Color(0xFFF59E0B),
      ),
      _MetricTile(
        label: l10n.translate('dashboard_metric_learners'),
        value: data.totalLearners.toString(),
        icon: Icons.people_alt_outlined,
        color: const Color(0xFF22C55E),
      ),
      _MetricTile(
        label: l10n.translate('dashboard_metric_active'),
        value: data.activeLearners.toString(),
        icon: Icons.flash_on_outlined,
        color: const Color(0xFF6366F1),
      ),
      _MetricTile(
        label: l10n.translate('dashboard_metric_completion'),
        value: '${(data.averageCompletion * 100).round()}%',
        icon: Icons.task_alt_outlined,
        color: const Color(0xFF0EA5E9),
      ),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: cards
          .map(
            (card) => SizedBox(
              width: 220,
              child: card,
            ),
          )
          .toList(),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyActivityCard extends StatelessWidget {
  const _WeeklyActivityCard({
    required this.data,
    required this.l10n,
    required this.theme,
  });

  final DashboardSnapshot data;
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('dashboard_weekly_activity'),
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.translate('dashboard_activity_label'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 160,
              child: _Sparkline(
                  points: data.weeklyLaunches,
                  color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopCoursesCard extends StatelessWidget {
  const _TopCoursesCard({
    required this.data,
    required this.l10n,
    required this.theme,
  });

  final DashboardSnapshot data;
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('dashboard_top_courses'),
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Column(
              children: data.coursePerformance
                  .map(
                    (course) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.courseTitle,
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${course.learners} ${l10n.translate('course_detail_learners_short')}',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: theme.hintColor),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: LinearProgressIndicator(
                              value: course.completionRate.clamp(0, 1),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('${(course.completionRate * 100).round()}%'),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificateAlertsCard extends StatelessWidget {
  const _CertificateAlertsCard({
    required this.data,
    required this.l10n,
    required this.theme,
  });

  final DashboardSnapshot data;
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('dashboard_certificate_alerts'),
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ...data.certificateAlerts.map(
              (alert) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    alert.courseTitle.isNotEmpty
                        ? alert.courseTitle[0].toUpperCase()
                        : '?',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(alert.courseTitle),
                subtitle: Text(
                  '${l10n.translate('dashboard_certificate_due', params: {
                        'count': '${alert.learners}',
                      })} · ${_formatDate(alert.expiryDate)}',
                ),
                trailing: TextButton(
                  onPressed: () =>
                      GoRouter.of(context).go('/course/${alert.courseId}'),
                  child: Text(l10n.translate('dashboard_view_course')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.points, required this.color});

  final List<int> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(points: points, color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.points, required this.color});

  final List<int> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }
    final path = Path();
    final maxValue = points.reduce(math.max).toDouble();
    final minValue = points.reduce(math.min).toDouble();
    final range =
        (maxValue - minValue).abs() < 0.001 ? 1.0 : maxValue - minValue;

    for (var i = 0; i < points.length; i++) {
      final x = size.width * (i / (points.length - 1));
      final normalized = (points[i] - minValue) / range;
      final y = size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.02)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}
