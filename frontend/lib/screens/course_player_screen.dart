import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import 'package:compliance_training_app/localization/app_localizations.dart';
import 'package:compliance_training_app/models/course.dart';
import 'package:compliance_training_app/services/course_service.dart';
import 'package:compliance_training_app/widgets/quiz_view.dart';
import 'package:compliance_training_app/widgets/simulation_view.dart';
import 'package:compliance_training_app/widgets/web_video_frame.dart';

class CoursePlayerScreen extends StatefulWidget {
  const CoursePlayerScreen(
      {super.key, required this.course, required this.service});

  final Course course;
  final CourseService service;

  @override
  State<CoursePlayerScreen> createState() => _CoursePlayerScreenState();
}

class _CoursePlayerScreenState extends State<CoursePlayerScreen> {
  int _currentIndex = 0;
  bool _quizSubmitting = false;
  QuizResult? _quizResult;
  late final ValueListenable<Set<String>> _progressListenable;
  Set<String> _completedModules = {};
  bool _syllabusPinned = true;
  bool _transcriptExpanded = false;
  bool _celebratedCompletion = false;
  final TextEditingController _notesController = TextEditingController();
  bool _notesSynced = true;
  Timer? _notesDebounce;

  @override
  void initState() {
    super.initState();
    _progressListenable = widget.service.watchProgress(widget.course.id);
    _completedModules = Set<String>.from(_progressListenable.value);
    _currentIndex =
        _determineInitialIndex(widget.course.modules, _completedModules);
    _progressListenable.addListener(_handleProgressChange);
    _notesController.addListener(_handleNotesChanged);
  }

  @override
  void dispose() {
    _progressListenable.removeListener(_handleProgressChange);
    _notesDebounce?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modules = widget.course.modules;
    if (modules.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('No modules configured for this course.'),
        ),
      );
    }
    _currentIndex = _currentIndex.clamp(0, modules.length - 1);
    final module = modules[_currentIndex];
    final isCompleted = _completedModules.contains(module.id);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final completionRatio =
        modules.isEmpty ? 0.0 : _completedModules.length / modules.length;
    final progressPercent = (completionRatio * 100).round();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      floatingActionButton: _shouldShowMobileFab(context)
          ? FloatingActionButton.extended(
              onPressed: _openSyllabusSheet,
              icon: const Icon(Icons.menu_book),
              label: Text(l10n.translate('course_player_syllabus')),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _PlayerHeader(
              course: widget.course,
              currentModule: module,
              onToggleSyllabus: _toggleSyllabusPinned,
              onBookmark: () => _showSnack(
                  context, l10n.translate('course_player_bookmarked')),
              onSettings: () => _showSnack(
                context,
                l10n.translate('course_player_settings_soon'),
              ),
              onLightning: () => _showSnack(
                context,
                l10n.translate('course_player_action_lightning'),
              ),
              onHistory: () => _showSnack(
                context,
                l10n.translate('course_player_action_history'),
              ),
              syllabusPinned: _syllabusPinned,
              progressPercent: progressPercent,
            ),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showSyllabus = constraints.maxWidth >= 1080;
                  final showSideTabs = constraints.maxWidth >= 1400;
                  final showPinnedSyllabus = showSyllabus && _syllabusPinned;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showPinnedSyllabus)
                        SizedBox(
                          width: 300,
                          child: _SyllabusPanel(
                            course: widget.course,
                            currentIndex: _currentIndex,
                            completedModules: _completedModules,
                            onSelect: _goToIndex,
                          ).animate().fadeIn(duration: 300.ms),
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          child: _LessonWorkspace(
                            module: module,
                            moduleIndex: _currentIndex,
                            modules: modules,
                            isCompleted: isCompleted,
                            progressPercent: progressPercent,
                            completionRatio: completionRatio,
                            transcriptExpanded: _transcriptExpanded,
                            onToggleTranscript: () => setState(
                              () => _transcriptExpanded = !_transcriptExpanded,
                            ),
                            moduleContentBuilder: _buildModuleContent,
                            completionFooter: _buildCompletionFooter(
                                module, isCompleted, l10n),
                            navigationBar: _buildNavigation(
                              modules,
                              theme,
                              l10n,
                              isCompleted,
                            ),
                            unlockHint: !isCompleted &&
                                    _currentIndex < modules.length - 1
                                ? Text(
                                    l10n.translate('course_unlock_hint'),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.secondary,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      if (showSideTabs)
                        SizedBox(
                          width: 320,
                          child: _SideTabs(
                            notesController: _notesController,
                            notesSynced: _notesSynced,
                            course: widget.course,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            _PlayerFooter(
              onPrevious: _currentIndex == 0
                  ? null
                  : () => _goToIndex(_currentIndex - 1),
              onNext: _currentIndex == modules.length - 1 || !isCompleted
                  ? null
                  : () => _goToIndex(_currentIndex + 1),
              progressPercent: progressPercent,
              completionRatio: completionRatio,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleContent(CourseModule module) {
    switch (module.type) {
      case 'video':
        return _VideoHero(videoUrl: module.videoUrl);
      case 'article':
        return Markdown(
          data: module.body ?? '',
          styleSheet: MarkdownStyleSheet(
            h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            p: const TextStyle(fontSize: 16, height: 1.5),
            listBullet: const TextStyle(fontSize: 16),
          ),
        );
      case 'simulation':
        return SimulationView(simulation: module.simulation);
      case 'quiz':
        return QuizView(
          module: module,
          submitting: _quizSubmitting,
          result: _quizResult,
          onSubmit: (answers) async {
            setState(() {
              _quizSubmitting = true;
            });
            try {
              final result = await widget.service
                  .submitQuiz(moduleId: module.id, answers: answers);
              setState(() {
                _quizResult = result;
              });
              if (result.passed) {
                await widget.service
                    .markModuleComplete(widget.course.id, module.id);
              }
            } finally {
              setState(() {
                _quizSubmitting = false;
              });
            }
          },
        );
      default:
        return const Text('Unsupported module type');
    }
  }

  Widget _buildNavigation(List<CourseModule> modules, ThemeData theme,
      AppLocalizations l10n, bool currentCompleted) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                _currentIndex == 0 ? null : () => _goToIndex(_currentIndex - 1),
            icon: const Icon(Icons.chevron_left),
            label: Text(l10n.translate('course_navigation_previous')),
          ).animate().slideX(begin: -0.2, duration: 250.ms),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _currentIndex == modules.length - 1 || !currentCompleted
                ? null
                : () => _goToIndex(_currentIndex + 1),
            icon: const Icon(Icons.chevron_right),
            label: Text(l10n.translate('course_navigation_next')),
          ).animate().slideX(begin: 0.2, duration: 250.ms),
        ),
      ],
    );
  }

  bool _shouldShowMobileFab(BuildContext context) {
    return MediaQuery.of(context).size.width < 1080;
  }

  void _openSyllabusSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.75,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _SyllabusPanel(
                course: widget.course,
                currentIndex: _currentIndex,
                completedModules: _completedModules,
                onSelect: (index) {
                  Navigator.of(sheetContext).pop();
                  _goToIndex(index);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleSyllabusPinned() {
    setState(() {
      _syllabusPinned = !_syllabusPinned;
    });
  }

  void _showSnack(BuildContext context, String message) {
    if (message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleNotesChanged() {
    _notesDebounce?.cancel();
    if (_notesSynced) {
      setState(() {
        _notesSynced = false;
      });
    }
    _notesDebounce = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _notesSynced = true;
      });
    });
  }

  Widget _buildCompletionFooter(
      CourseModule module, bool isCompleted, AppLocalizations l10n) {
    if (module.type == 'quiz') {
      if (_quizResult?.passed == true || isCompleted) {
        return Align(
          alignment: Alignment.centerRight,
          child: _CompletedChip(
              label: l10n.translate('course_mark_complete_done')),
        );
      }
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.tonalIcon(
        onPressed: isCompleted ? null : () => _handleComplete(module),
        icon: Icon(isCompleted ? Icons.check_circle : Icons.flag),
        label: Text(
          isCompleted
              ? l10n.translate('course_mark_complete_done')
              : l10n.translate('course_mark_complete'),
        ),
      ),
    );
  }

  Future<void> _handleComplete(CourseModule module) async {
    await widget.service.markModuleComplete(widget.course.id, module.id);
  }

  void _goToIndex(int index) {
    final modules = widget.course.modules;
    if (modules.isEmpty) {
      return;
    }
    final nextIndex = index.clamp(0, modules.length - 1);
    if (nextIndex > _currentIndex) {
      final completed = _completedModules;
      final unlocked = widget.service.isModuleUnlocked(
        widget.course.id,
        modules,
        nextIndex,
        completed,
      );
      final nextModuleId = modules[nextIndex].id;
      if (!unlocked && !completed.contains(nextModuleId)) {
        return;
      }
    }

    setState(() {
      _currentIndex = nextIndex;
      _quizSubmitting = false;
      _quizResult = null;
    });
  }

  void _handleProgressChange() {
    final modules = widget.course.modules;
    final completed = Set<String>.from(_progressListenable.value);
    if (!mounted) {
      return;
    }
    setState(() {
      _completedModules = completed;
      _currentIndex =
          _normalizeIndex(_currentIndex, modules, _completedModules);
    });
    if (!_celebratedCompletion &&
        modules.isNotEmpty &&
        completed.length == modules.length) {
      _celebratedCompletion = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showCompletionDialog();
      });
    }
  }

  void _showCompletionDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.translate('course_player_completion_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.celebration,
                color: Theme.of(context).colorScheme.primary,
                size: 56,
              ).animate().scale(
                    duration: 400.ms,
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 16),
              Text(
                l10n.translate('course_player_completion_body'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.translate('course_player_completion_close')),
            ),
          ],
        );
      },
    );
  }

  int _determineInitialIndex(
    List<CourseModule> modules,
    Set<String> completed,
  ) {
    if (modules.isEmpty) {
      return 0;
    }
    for (var i = 0; i < modules.length; i++) {
      final previousDone = i == 0 || completed.contains(modules[i - 1].id);
      final currentDone = completed.contains(modules[i].id);
      if (previousDone && !currentDone) {
        return i;
      }
    }
    return modules.length - 1;
  }

  int _normalizeIndex(
    int index,
    List<CourseModule> modules,
    Set<String> completed,
  ) {
    if (modules.isEmpty) {
      return 0;
    }
    var safeIndex = index.clamp(0, modules.length - 1);
    final previousDone =
        safeIndex == 0 || completed.contains(modules[safeIndex - 1].id);
    final selfDone = completed.contains(modules[safeIndex].id);
    if (previousDone || selfDone) {
      return safeIndex;
    }
    return _determineInitialIndex(modules, completed);
  }
}

class _CompletedChip extends StatelessWidget {
  const _CompletedChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 18, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colorScheme.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({
    required this.course,
    required this.currentModule,
    required this.onToggleSyllabus,
    required this.onBookmark,
    required this.onSettings,
    required this.onLightning,
    required this.onHistory,
    required this.syllabusPinned,
    required this.progressPercent,
  });

  final Course course;
  final CourseModule currentModule;
  final VoidCallback onToggleSyllabus;
  final VoidCallback onBookmark;
  final VoidCallback onSettings;
  final VoidCallback onLightning;
  final VoidCallback onHistory;
  final bool syllabusPinned;
  final int progressPercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => GoRouter.of(context).pop(),
          ),
          TextButton.icon(
            onPressed: onToggleSyllabus,
            icon: Icon(syllabusPinned ? Icons.menu_open : Icons.menu),
            label: Text(l10n.translate('course_player_syllabus')),
          ),
          const SizedBox(width: 12),
          const VerticalDivider(width: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.hintColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  currentModule.title ?? currentModule.type.toUpperCase(),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                const Icon(Icons.percent, size: 18),
                const SizedBox(width: 6),
                Text(
                  l10n.translate(
                    'course_player_progress_chip',
                    params: {'percent': '$progressPercent'},
                  ),
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: l10n.translate('course_player_action_lightning'),
            icon: const Icon(Icons.flash_on_outlined),
            onPressed: onLightning,
          ),
          IconButton(
            tooltip: l10n.translate('course_player_bookmark'),
            icon: const Icon(Icons.bookmark_border),
            onPressed: onBookmark,
          ),
          IconButton(
            tooltip: l10n.translate('course_player_action_history'),
            icon: const Icon(Icons.history),
            onPressed: onHistory,
          ),
          IconButton(
            tooltip: l10n.translate('course_player_settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

enum _LessonState { locked, inProgress, completed, upcoming }

class _SyllabusPanel extends StatelessWidget {
  const _SyllabusPanel({
    required this.course,
    required this.currentIndex,
    required this.completedModules,
    required this.onSelect,
  });

  final Course course;
  final int currentIndex;
  final Set<String> completedModules;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final modules = course.modules.toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('course_player_syllabus_header'),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.translate(
                    'course_module_progress',
                    params: {
                      'current': '${currentIndex + 1}',
                      'total': '${modules.length}',
                    },
                  ),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: modules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final module = modules[index];
                final state = _resolveState(index, module, modules);
                final isCurrent = index == currentIndex;
                final subtitle = _moduleSubtitle(module, context);

                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  tileColor: isCurrent
                      ? theme.colorScheme.primary.withValues(alpha: 0.08)
                      : null,
                  leading: Icon(
                    _stateIcon(state),
                    color: _stateColor(state, theme),
                  ),
                  title: Text(
                    module.title ?? module.type.toUpperCase(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: state == _LessonState.locked
                      ? const Icon(Icons.lock_outline, size: 18)
                      : const Icon(Icons.chevron_right),
                  onTap: state == _LessonState.locked
                      ? null
                      : () => onSelect(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  _LessonState _resolveState(
    int index,
    CourseModule module,
    List<CourseModule> modules,
  ) {
    if (completedModules.contains(module.id)) {
      return _LessonState.completed;
    }
    if (index == currentIndex) {
      return _LessonState.inProgress;
    }
    final unlocked = index == 0 ||
        completedModules.contains(modules[index - 1].id) ||
        index < currentIndex;
    return unlocked ? _LessonState.upcoming : _LessonState.locked;
  }

  IconData _stateIcon(_LessonState state) {
    switch (state) {
      case _LessonState.completed:
        return Icons.check_circle;
      case _LessonState.inProgress:
        return Icons.radio_button_checked;
      case _LessonState.upcoming:
        return Icons.circle_outlined;
      case _LessonState.locked:
        return Icons.lock_outline;
    }
  }

  Color _stateColor(_LessonState state, ThemeData theme) {
    switch (state) {
      case _LessonState.completed:
        return const Color(0xFF22C55E);
      case _LessonState.inProgress:
        return theme.colorScheme.primary;
      case _LessonState.upcoming:
        return theme.hintColor;
      case _LessonState.locked:
        return theme.disabledColor;
    }
  }

  String _moduleSubtitle(CourseModule module, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final durationMinutes =
        module.durationSeconds != null ? module.durationSeconds! ~/ 60 : null;
    final typeLabel = l10n.translate(
      'course_player_module_type_${module.type}',
    );
    if (durationMinutes == null || durationMinutes == 0) {
      return typeLabel;
    }
    return '$typeLabel · $durationMinutes ${l10n.translate('course_detail_minutes_abbrev')}';
  }
}

class _SideTabs extends StatelessWidget {
  const _SideTabs({
    required this.notesController,
    required this.notesSynced,
    required this.course,
  });

  final TextEditingController notesController;
  final bool notesSynced;
  final Course course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 3,
      child: Card(
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Column(
          children: [
            TabBar(
              labelStyle: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: l10n.translate('course_player_notes_tab')),
                Tab(text: l10n.translate('course_player_discussion_tab')),
                Tab(text: l10n.translate('course_player_resources_tab')),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate('course_player_notes_heading'),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: TextField(
                            controller: notesController,
                            maxLines: null,
                            decoration: InputDecoration(
                              hintText: l10n
                                  .translate('course_player_notes_placeholder'),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              notesSynced
                                  ? Icons.check_circle
                                  : Icons.sync_problem,
                              size: 16,
                              color: notesSynced
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              notesSynced
                                  ? l10n.translate(
                                      'course_player_notes_saved_status')
                                  : l10n.translate(
                                      'course_player_notes_saving_status'),
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate('course_player_discussion_heading'),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.translate(
                              'course_player_discussion_placeholder'),
                          style: theme.textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add_comment_outlined),
                          label: Text(
                            l10n.translate(
                                'course_player_discussion_start_thread'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate('course_player_resources_heading'),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        if (course.resources.isEmpty)
                          Text(
                            l10n.translate(
                                'course_player_resources_placeholder'),
                            style: theme.textTheme.bodyMedium,
                          )
                        else
                          Expanded(
                            child: ListView.separated(
                              itemCount: course.resources.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final resource = course.resources[index];
                                return ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  tileColor: theme
                                      .colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.4),
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
                                );
                              },
                            ),
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

class _LessonWorkspace extends StatelessWidget {
  const _LessonWorkspace({
    required this.module,
    required this.moduleIndex,
    required this.modules,
    required this.isCompleted,
    required this.progressPercent,
    required this.completionRatio,
    required this.transcriptExpanded,
    required this.onToggleTranscript,
    required this.moduleContentBuilder,
    required this.completionFooter,
    required this.navigationBar,
    this.unlockHint,
  });

  final CourseModule module;
  final int moduleIndex;
  final List<CourseModule> modules;
  final bool isCompleted;
  final int progressPercent;
  final double completionRatio;
  final bool transcriptExpanded;
  final VoidCallback onToggleTranscript;
  final Widget Function(CourseModule) moduleContentBuilder;
  final Widget completionFooter;
  final Widget navigationBar;
  final Widget? unlockHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final moduleProgress = (moduleIndex + 1) / modules.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
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
                            module.title ?? module.type.toUpperCase(),
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.translate(
                              'course_module_progress',
                              params: {
                                'current': '${moduleIndex + 1}',
                                'total': '${modules.length}',
                              },
                            ),
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.hintColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CompletedChip(
                      label: l10n.translate(
                        isCompleted
                            ? 'course_mark_complete_done'
                            : 'course_player_progress_chip',
                        params: {'percent': '$progressPercent'},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: moduleProgress,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation(
                      theme.colorScheme.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Card(
            child: AnimatedSwitcher(
              duration: 300.ms,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: Padding(
                key: ValueKey(module.id),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: moduleContentBuilder(module),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: onToggleTranscript,
                      leading: const Icon(Icons.subtitles_outlined),
                      title: Text(
                        l10n.translate('course_player_transcript_toggle'),
                      ),
                      trailing: Icon(
                        transcriptExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                    ),
                    AnimatedCrossFade(
                      duration: 200.ms,
                      crossFadeState: transcriptExpanded
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          l10n.translate(
                              'course_player_transcript_placeholder'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      secondChild: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        completionFooter,
        if (unlockHint != null) ...[
          const SizedBox(height: 12),
          unlockHint!,
        ],
        const SizedBox(height: 12),
        navigationBar,
      ],
    );
  }
}

class _PlayerFooter extends StatelessWidget {
  const _PlayerFooter({
    required this.onPrevious,
    required this.onNext,
    required this.progressPercent,
    required this.completionRatio,
  });

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final int progressPercent;
  final double completionRatio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            label: Text(l10n.translate('course_player_previous')),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: completionRatio.clamp(0, 1),
                  minHeight: 6,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.translate(
                    'course_player_progress_label',
                    params: {'percent': '$progressPercent'},
                  ),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            label: Text(l10n.translate('course_player_next')),
          ),
        ],
      ),
    );
  }
}

class CoursePlayerRoute extends StatefulWidget {
  const CoursePlayerRoute({
    required this.courseId,
    required this.service,
    this.initialCourse,
    super.key,
  });

  final String courseId;
  final CourseService service;
  final Course? initialCourse;

  @override
  State<CoursePlayerRoute> createState() => _CoursePlayerRouteState();
}

class _CoursePlayerRouteState extends State<CoursePlayerRoute> {
  late Future<Course?> _future;
  String? _localeTag;

  @override
  void initState() {
    super.initState();
    _future = Future.value(widget.initialCourse);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode;
    if (_localeTag != locale) {
      _localeTag = locale;
      _future = widget.service.loadCourseById(widget.courseId, locale: locale);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialCourse?.id == widget.courseId
        ? widget.initialCourse
        : null;
    return FutureBuilder<Course?>(
      future: _future,
      initialData: initial,
      builder: (context, snapshot) {
        final course = snapshot.data ?? initial;
        if (snapshot.connectionState != ConnectionState.done &&
            course == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (course == null) {
          final l10n = AppLocalizations.of(context);
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(l10n.translate('course_detail_not_found')),
            ),
          );
        }
        return CoursePlayerScreen(course: course, service: widget.service);
      },
    );
  }
}

class _VideoHero extends StatefulWidget {
  const _VideoHero({this.videoUrl});

  final String? videoUrl;

  @override
  State<_VideoHero> createState() => _VideoHeroState();
}

class _VideoHeroState extends State<_VideoHero> {
  VideoPlayerController? _controller;
  Future<void>? _initialise;
  bool _showControls = true;
  bool _loadFailed = false;

  static const _fallbackImagePath = 'assets/images/quiz_fallback.png';
  static const double _defaultAspectRatio = 16 / 9;
  static const double _minVideoHeight = 180;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(covariant _VideoHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _setupController();
    }
  }

  void _setupController() {
    if (kIsWeb) {
      _controller = null;
      _initialise = null;
      _loadFailed = false;
      return;
    }
    final url = widget.videoUrl;
    if (url == null || url.isEmpty) {
      _loadFailed = true;
      return;
    }
    _loadFailed = false;
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      _initialise = controller.initialize().then((_) {
        controller.setLooping(true);
        if (mounted) {
          setState(() {});
        }
      }).catchError((error) {
        debugPrint('Video load error: $error');
        if (mounted) {
          setState(() {
            _loadFailed = true;
          });
        } else {
          _loadFailed = true;
        }
      });
    } catch (error) {
      debugPrint('Failed to create controller: $error');
      _loadFailed = true;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _initialise = null;
    _showControls = true;
    _loadFailed = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasUrl = widget.videoUrl != null && widget.videoUrl!.isNotEmpty;

    if (kIsWeb && hasUrl) {
      final webColumn = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WebVideoFrame(
              url: widget.videoUrl!, aspectRatio: _defaultAspectRatio),
          const SizedBox(height: 12),
          Text(
            l10n.translate('course_video_placeholder'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            widget.videoUrl!,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      );
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight.isFinite) {
            return SingleChildScrollView(child: webColumn);
          }
          return webColumn;
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 1024.0;
        final hasMaxHeight = constraints.maxHeight.isFinite;
        final availableHeight =
            hasMaxHeight ? constraints.maxHeight : double.infinity;

        var aspect = _defaultAspectRatio;
        if (_controller?.value.isInitialized ?? false) {
          final ratio = _controller!.value.aspectRatio;
          if (ratio > 0) {
            aspect = ratio;
          }
        }

        final desiredHeight = width / aspect;
        final constrainedHeight = hasMaxHeight
            ? availableHeight.clamp(_minVideoHeight, desiredHeight)
            : desiredHeight;

        final surface = (_controller != null && !_loadFailed)
            ? FutureBuilder<void>(
                future: _initialise,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return _buildLoadingSurface();
                  }

                  final controllerValue = _controller!.value;
                  if (!controllerValue.isInitialized ||
                      controllerValue.hasError) {
                    final message =
                        controllerValue.errorDescription ?? 'Video unavailable';
                    return _buildFallbackSurface(context,
                        errorMessage: message);
                  }

                  return _buildInteractivePlayer(context);
                },
              )
            : _buildFallbackSurface(
                context,
                errorMessage: _loadFailed ? 'Video unavailable' : null,
              );

        final videoBox = SizedBox(
          width: width,
          height: constrainedHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: width,
                height: desiredHeight,
                child: surface,
              ),
            ),
          ),
        );

        final column = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            videoBox,
            if (hasUrl) ...[
              const SizedBox(height: 12),
              Text(
                l10n.translate('course_video_placeholder'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                widget.videoUrl!,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );

        if (hasMaxHeight) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: width),
              child: column,
            ),
          );
        }

        return column;
      },
    );
  }

  Widget _buildInteractivePlayer(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!(_controller?.value.isInitialized ?? false)) {
          return;
        }
        setState(() {
          if (_controller!.value.isPlaying) {
            _controller!.pause();
            _showControls = true;
          } else {
            _controller!.play();
            _showControls = false;
          }
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayer(_controller!),
          AnimatedOpacity(
            opacity: _showControls || !(_controller!.value.isPlaying) ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              color: Colors.black38,
              child: Center(
                child: Icon(
                  _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSurface() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _fallbackDecoration(),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildFallbackSurface(BuildContext context, {String? errorMessage}) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        _fallbackDecoration(),
        if (errorMessage != null)
          Container(
            color: Colors.black54,
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                errorMessage,
                style:
                    theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _fallbackDecoration() {
    return Image.asset(
      _fallbackImagePath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey.shade800,
      ),
    );
  }
}
