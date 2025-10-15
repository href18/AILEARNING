import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../demo_profile.dart';
import '../models/course.dart';
import '../services/course_service.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.courseService});

  final CourseService courseService;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late Future<List<Course>> _future;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _future = widget.courseService.fetchCourses(locale: Intl.getCurrentLocale());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compliance & Safety Catalog'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'My page',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go('/me'),
          ),
        ],
      ),
      body: FutureBuilder<List<Course>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load courses: ${snapshot.error}'),
              ),
            );
          }

          final courses = snapshot.data ?? [];
          if (courses.isEmpty) {
            return const Center(child: Text('No courses published yet.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.8,
            ),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return _CourseCard(course: course)
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .move(begin: const Offset(0, 16), duration: 350.ms);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating
            ? null
            : () async {
                final draft = await showDialog<CourseDraft>(
                  context: context,
                  builder: (context) => const _QuickCourseDialog(),
                );
                if (draft == null) return;
                setState(() {
                  _creating = true;
                });
                try {
                  await widget.courseService.createCourseFromDraft(
                    draft: draft,
                    createdBy: DemoProfile.adminId,
                    locale: Intl.getCurrentLocale(),
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nytt kurs er publisert!')),
                  );
                  setState(() {
                    _future = widget.courseService.fetchCourses(locale: Intl.getCurrentLocale());
                  });
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Kunne ikke opprette kurs: $error')),
                  );
                } finally {
                  if (mounted) {
                    setState(() {
                      _creating = false;
                    });
                  }
                }
              },
        icon: const Icon(Icons.add_chart),
        label: Text(_creating ? 'Oppretter…' : 'Nytt demokurs'),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/course/${course.id}', extra: course),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(course.code, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(course.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  course.summary,
                  style: theme.textTheme.bodyLarge,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  if (course.durationMinutes != null)
                    Chip(
                      avatar: const Icon(Icons.timer, size: 16),
                      label: Text('${course.durationMinutes} min'),
                    ),
                  if (course.certificateValidMonths != null)
                    Chip(
                      avatar: const Icon(Icons.verified, size: 16),
                      label: Text('Certificate ${course.certificateValidMonths} mth'),
                    ),
                  Chip(
                    avatar: const Icon(Icons.layers, size: 16),
                    label: Text('${course.modules.length} modules'),
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

class _QuickCourseDialog extends StatefulWidget {
  const _QuickCourseDialog();

  @override
  State<_QuickCourseDialog> createState() => _QuickCourseDialogState();
}

class _QuickCourseDialogState extends State<_QuickCourseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController(text: 'FORK-101');
  final _titleNbController = TextEditingController(text: 'Truckfører sikkerhet');
  final _summaryNbController = TextEditingController(
    text: 'Interaktiv gjennomgang av trygge rutiner for truck og personløfter.',
  );
  final _titleEnController = TextEditingController(text: 'Forklift safety essentials');
  final _summaryEnController = TextEditingController(
    text: 'Interactive forklift and MEWP safety refresher.',
  );
  final _articleNbController = TextEditingController(
    text: 'Rune guider deg gjennom et lager-scenario med fokus på sikring av last og varsling.',
  );
  final _questionController = TextEditingController(
    text: 'Hva er første steg når du oppdager en ustabil pall på trucken?',
  );
  final _optionsController = TextEditingController(
    text: '*Stans trucken trygt og sikre området\nVarsle kollegaen om å holde lasten\nFortsett kjøringen for å spare tid',
  );

  @override
  void dispose() {
    _codeController.dispose();
    _titleNbController.dispose();
    _summaryNbController.dispose();
    _titleEnController.dispose();
    _summaryEnController.dispose();
    _articleNbController.dispose();
    _questionController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lag et hurtig demokurs'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(labelText: 'Kurskode'),
                  validator: (value) => value == null || value.isEmpty ? 'Påkrevd' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleNbController,
                  decoration: const InputDecoration(labelText: 'Tittel (NO)'),
                  validator: (value) => value == null || value.isEmpty ? 'Påkrevd' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _summaryNbController,
                  decoration: const InputDecoration(labelText: 'Sammendrag (NO)'),
                  maxLines: 3,
                  validator: (value) => value == null || value.isEmpty ? 'Påkrevd' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleEnController,
                  decoration: const InputDecoration(labelText: 'Title (EN)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _summaryEnController,
                  decoration: const InputDecoration(labelText: 'Summary (EN)'),
                  maxLines: 3,
                ),
                const Divider(height: 32),
                TextFormField(
                  controller: _articleNbController,
                  decoration: const InputDecoration(
                    labelText: 'Scenariobeskrivelse (vises som artikkel)',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _questionController,
                  decoration: const InputDecoration(labelText: 'Quiz-spørsmål'),
                  validator: (value) => value == null || value.isEmpty ? 'Påkrevd' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _optionsController,
                  decoration: const InputDecoration(
                    labelText: 'Svaralternativer (* foran riktige)',
                    hintText: '*Korrekt svar\nFeil svar',
                  ),
                  maxLines: 4,
                  validator: (value) => value == null || value.isEmpty ? 'Påkrevd' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            final options = _optionsController.text
                .split(RegExp(r'\r?\n'))
                .where((element) => element.trim().isNotEmpty)
                .map((line) => line.trim())
                .toList();
            final parsedOptions = options
                .map((option) => QuizOptionDraft(
                      body: option.startsWith('*') ? option.substring(1).trim() : option,
                      isCorrect: option.startsWith('*'),
                    ))
                .toList();

            final draft = CourseDraft(
              code: _codeController.text.trim(),
              status: 'published',
              durationMinutes: 30,
              certificateValidMonths: 12,
              translations: [
                CourseTranslationDraft(
                  locale: 'nb',
                  title: _titleNbController.text.trim(),
                  summary: _summaryNbController.text.trim(),
                ),
                CourseTranslationDraft(
                  locale: 'en',
                  title: _titleEnController.text.trim().isEmpty
                      ? _titleNbController.text.trim()
                      : _titleEnController.text.trim(),
                  summary: _summaryEnController.text.trim().isEmpty
                      ? _summaryNbController.text.trim()
                      : _summaryEnController.text.trim(),
                ),
              ],
              modules: [
                ModuleDraft(
                  type: 'article',
                  position: 1,
                  translations: [
                    ModuleTranslationDraft(
                      locale: 'nb',
                      title: 'Scenario',
                      body: _articleNbController.text.trim(),
                    ),
                    ModuleTranslationDraft(
                      locale: 'en',
                      title: 'Scenario',
                      body: _articleNbController.text.trim(),
                    ),
                  ],
                ),
                ModuleDraft(
                  type: 'quiz',
                  position: 2,
                  translations: [
                    ModuleTranslationDraft(locale: 'nb', title: 'Kontrollspørsmål'),
                    ModuleTranslationDraft(locale: 'en', title: 'Knowledge check'),
                  ],
                  quiz: QuizDraft(
                    passingScore: 80,
                    questions: [
                      QuizQuestionDraft(
                        body: _questionController.text.trim(),
                        options: parsedOptions,
                        explanation: 'Stans, sikre området og varsle leder før du fortsetter.',
                      ),
                    ],
                  ),
                ),
              ],
            );

            Navigator.of(context).pop(draft);
          },
          child: const Text('Publiser'),
        ),
      ],
    );
  }
}
