import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:compliance_training_app/localization/app_localizations.dart';
import 'package:compliance_training_app/models/course.dart';
import 'package:compliance_training_app/services/course_service.dart';

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({
    required this.courseId,
    required this.service,
    this.initialCourse,
    super.key,
  });

  final String courseId;
  final CourseService service;
  final Course? initialCourse;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late final Course? _initialCourse =
      widget.initialCourse?.id == widget.courseId ? widget.initialCourse : null;
  late Future<Course?> _courseFuture;
  String? _localeTag;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode;
    if (_localeTag != locale) {
      _localeTag = locale;
      _courseFuture = widget.service.loadCourseById(
        widget.courseId,
        locale: locale,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FutureBuilder<Course?>(
      future: _courseFuture,
      initialData: _initialCourse,
      builder: (context, snapshot) {
        final course = snapshot.data ?? _initialCourse;
        if (snapshot.connectionState != ConnectionState.done &&
            course == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (course == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.translate('course_detail_not_found'),
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return _CourseDetailView(
          course: course,
          service: widget.service,
        );
      },
    );
  }
}

class _CourseDetailView extends StatefulWidget {
  const _CourseDetailView({
    required this.course,
    required this.service,
  });

  final Course course;
  final CourseService service;

  @override
  State<_CourseDetailView> createState() => _CourseDetailViewState();
}

class _CourseDetailViewState extends State<_CourseDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 5, vsync: this);

  bool _expandedSyllabus = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isWide = MediaQuery.of(context).size.width >= 1100;
    final statsText = _buildStatsText(context, widget.course);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: _AppHeader(onBack: () => context.go('/')),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWide ? 48 : 20,
                          vertical: isWide ? 32 : 20,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _HeroCard(
                                course: widget.course,
                                statsText: statsText,
                                onEnroll: () => _showSnack(
                                  context,
                                  l10n.translate('course_detail_enroll_toast'),
                                ),
                                onWishlist: () => _showSnack(
                                  context,
                                  l10n.translate(
                                      'course_detail_wishlist_toast'),
                                ),
                                onShare: () => _showSnack(
                                  context,
                                  l10n.translate('course_detail_share_toast'),
                                ),
                                onContinue: () => context.push(
                                  'player',
                                  extra: widget.course,
                                ),
                                isWide: isWide,
                              ),
                              const SizedBox(height: 32),
                              _buildTabbedContent(context, isWide),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabbedContent(BuildContext context, bool isWide) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final course = widget.course;

    final tabs = [
      Tab(text: l10n.translate('course_detail_tab_overview')),
      Tab(text: l10n.translate('course_detail_tab_syllabus')),
      Tab(text: l10n.translate('course_detail_tab_reviews')),
      Tab(text: l10n.translate('course_detail_tab_qa')),
      Tab(text: l10n.translate('course_detail_tab_resources')),
    ];

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelStyle: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                tabs: tabs,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: isWide ? 620 : null,
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _OverviewTab(course: course, isWide: isWide),
                  _SyllabusTab(
                    course: course,
                    expanded: _expandedSyllabus,
                    onToggle: () => setState(() {
                      _expandedSyllabus = !_expandedSyllabus;
                    }),
                  ),
                  _PlaceholderTab(
                    label: l10n.translate('course_detail_tab_reviews'),
                  ),
                  _PlaceholderTab(
                    label: l10n.translate('course_detail_tab_qa'),
                  ),
                  _ResourcesTab(course: course),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildStatsText(BuildContext context, Course course) {
    final l10n = AppLocalizations.of(context);
    final rating = course.rating.toStringAsFixed(1);
    final reviewCount = _formatCount(course.reviewCount);
    final durationHours =
        ((course.durationMinutes ?? 0) / 60).clamp(0, double.infinity);
    final durationLabel = durationHours >= 1
        ? '${durationHours.toStringAsFixed(durationHours % 1 == 0 ? 0 : 1)}h'
        : '${course.durationMinutes ?? 0}m';

    return l10n.translate(
      'course_detail_stats_format',
      params: {
        'rating': rating,
        'reviews': reviewCount,
        'duration': durationLabel,
        'level': course.level,
        'language': course.language,
        'updated': course.updatedAtText,
      },
    );
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toString();
  }

  void _showSnack(BuildContext context, String message) {
    if (message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: onBack,
        ),
        const SizedBox(width: 16),
        Text(
          'Compliance Academy',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        _HeaderButton(label: 'Catalog', onPressed: () => context.go('/')),
        const SizedBox(width: 12),
        _HeaderButton(
          label: 'Dashboard',
          onPressed: () => context.go('/dashboard'),
        ),
        const SizedBox(width: 12),
        _HeaderButton(label: 'My learning', onPressed: () {}),
        const SizedBox(width: 24),
        SizedBox(
          height: 44,
          width: 260,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search courses',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        IconButton(
          tooltip: 'Notifications',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined),
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          onPressed: () {},
        ),
        const SizedBox(width: 16),
        CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: const Icon(Icons.person, size: 20),
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.course,
    required this.statsText,
    required this.onEnroll,
    required this.onWishlist,
    required this.onShare,
    required this.onContinue,
    required this.isWide,
  });

  final Course course;
  final String statsText;
  final VoidCallback onEnroll;
  final VoidCallback onWishlist;
  final VoidCallback onShare;
  final VoidCallback onContinue;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final learners = NumberFormat.compact().format(course.learnersCount);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: isWide
            ? const EdgeInsets.symmetric(horizontal: 32, vertical: 32)
            : const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (course.coverImageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    course.coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) => Container(
                      color:
                          theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                      child: const Icon(Icons.broken_image_outlined, size: 48),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  course.title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star,
                          color: Color(0xFFF5B300), size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${course.rating.toStringAsFixed(1)} · $learners ${l10n.translate('course_detail_learners_short')}',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              statsText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.translate(
                'course_detail_author_line',
                params: {'author': course.author.name},
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: onEnroll,
                  child: Text(l10n.translate('course_detail_enroll')),
                ),
                OutlinedButton.icon(
                  onPressed: onWishlist,
                  icon: const Icon(Icons.favorite_border),
                  label: Text(l10n.translate('course_detail_wishlist')),
                ),
                OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share),
                  label: Text(l10n.translate('course_detail_share')),
                ),
                TextButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.play_circle),
                  label: Text(l10n.translate('course_detail_continue')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.course, required this.isWide});

  final Course course;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final outcomes = course.outcomes;
    final prerequisites = course.prerequisites;
    final captions = course.captions;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('course_detail_outcomes_heading'),
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ...outcomes.map(
          (outcome) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF22C55E), size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(outcome)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          course.summary,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        if (prerequisites.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(
            l10n.translate('course_detail_prerequisites_heading'),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...prerequisites.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          ),
        ],
      ],
    );

    final metadataCard = _MetadataColumn(
      course: course,
      captions: captions,
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      alignment: Alignment.topCenter,
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 28),
                SizedBox(width: 320, child: metadataCard),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                left,
                const SizedBox(height: 28),
                metadataCard,
              ],
            ),
    );
  }
}

class _MetadataColumn extends StatelessWidget {
  const _MetadataColumn({
    required this.course,
    required this.captions,
  });

  final Course course;
  final List<String> captions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          _InfoCard(
            title: l10n.translate('course_detail_metadata_heading'),
            items: [
              _InfoEntry(
                icon: Icons.emoji_events_outlined,
                label: l10n.translate('course_detail_metadata_level'),
                value: course.level,
              ),
              if (course.durationMinutes != null)
                _InfoEntry(
                  icon: Icons.schedule,
                  label: l10n.translate('course_detail_metadata_duration'),
                  value:
                      '${(course.durationMinutes ?? 0) ~/ 60}h ${(course.durationMinutes ?? 0) % 60}m',
                ),
              _InfoEntry(
                icon: Icons.translate,
                label: l10n.translate('course_detail_metadata_language'),
                value: course.language,
              ),
              if (captions.isNotEmpty)
                _InfoEntry(
                  icon: Icons.closed_caption,
                  label: l10n.translate('course_detail_metadata_captions'),
                  value: captions.join(', '),
                ),
              if (course.certificateValidMonths != null)
                _InfoEntry(
                  icon: Icons.verified_user_outlined,
                  label: l10n.translate('course_detail_metadata_certificate'),
                  value: l10n.translate(
                    'course_detail_metadata_certificate_value',
                    params: {'months': '${course.certificateValidMonths}'},
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _InstructorCard(author: course.author),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_InfoEntry> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            for (final entry in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(entry.icon, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.label,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.hintColor),
                          ),
                          Text(
                            entry.value,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoEntry {
  _InfoEntry({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _InstructorCard extends StatelessWidget {
  const _InstructorCard({required this.author});

  final CourseAuthor author;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('course_detail_instructor_heading'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    author.name.isNotEmpty ? author.name[0].toUpperCase() : '?',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (author.title != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          author.title!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor),
                        ),
                      ],
                      if (author.bio != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          author.bio!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          l10n.translate('course_detail_instructor_profile'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SyllabusTab extends StatelessWidget {
  const _SyllabusTab({
    required this.course,
    required this.expanded,
    required this.onToggle,
  });

  final Course course;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final modules = course.modules.toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.translate('course_detail_syllabus_heading'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onToggle,
              icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(
                expanded
                    ? l10n.translate('course_detail_syllabus_collapse')
                    : l10n.translate('course_detail_syllabus_expand'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...modules.map((module) {
          final lessons = _estimateLessons(module.type);
          final duration = module.durationSeconds != null
              ? Duration(seconds: module.durationSeconds!)
              : null;
          final durationLabel = duration != null
              ? '${duration.inMinutes} ${l10n.translate('course_detail_minutes_abbrev')}'
              : l10n.translate('course_detail_duration_tbd');
          return Card(
            child: ListTile(
              leading: Icon(_moduleIcon(module.type)),
              title: Text(module.title ?? module.type.toUpperCase()),
              subtitle: Text(
                l10n.translate(
                  'course_detail_module_meta',
                  params: {
                    'lessons': '$lessons',
                    'duration': durationLabel,
                  },
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            ),
          );
        }),
        if (!expanded)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton(
              onPressed: onToggle,
              child: Text(l10n.translate('course_detail_syllabus_view_all')),
            ),
          ),
      ],
    );
  }

  int _estimateLessons(String type) {
    switch (type) {
      case 'video':
        return 3;
      case 'article':
        return 2;
      case 'simulation':
        return 1;
      case 'quiz':
        return 1;
      default:
        return math.max(1, type.length % 3 + 1);
    }
  }

  IconData _moduleIcon(String type) {
    switch (type) {
      case 'video':
        return Icons.play_circle;
      case 'article':
        return Icons.menu_book;
      case 'simulation':
        return Icons.track_changes;
      case 'quiz':
        return Icons.quiz;
      default:
        return Icons.extension;
    }
  }
}

class _ResourcesTab extends StatelessWidget {
  const _ResourcesTab({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resources = course.resources;

    if (resources.isEmpty) {
      return _PlaceholderTab(
        label: l10n.translate('course_detail_tab_resources'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('course_detail_resources_heading'),
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        ...resources.map(
          (resource) => Card(
            child: ListTile(
              leading: Icon(_resourceIcon(resource.type)),
              title: Text(resource.label),
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n.translate(
                        'course_detail_resource_open',
                        params: {'label': resource.label},
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  IconData _resourceIcon(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
        return Icons.description_outlined;
      default:
        return Icons.link_outlined;
    }
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Text(
        l10n.translate(
          'course_detail_tab_placeholder',
          params: {'label': label},
        ),
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }
}
