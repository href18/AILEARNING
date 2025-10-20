import 'dart:math';

import 'package:common/api/supabase_client.dart';
import 'package:common/models/course.dart';
import 'package:common/models/lesson.dart';
import 'package:common/models/module.dart';
import 'package:common/models/webhook_endpoint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'creator_providers.dart';

class CreatorDashboardScreen extends ConsumerWidget {
  const CreatorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    if (!auth.isCreator) {
      return const Center(child: Text('Creator access required. Contact an admin.'));
    }
    return DefaultTabController(
      length: 3,
      child: SafeArea(
        child: Column(
          children: const [
            TabBar(tabs: [
              Tab(text: 'Courses'),
              Tab(text: 'Analytics'),
              Tab(text: 'Webhooks'),
            ]),
            Expanded(
              child: TabBarView(
                children: [
                  CreatorCoursesTab(),
                  CreatorAnalyticsTab(),
                  CreatorWebhooksTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreatorCoursesTab extends ConsumerStatefulWidget {
  const CreatorCoursesTab({super.key});

  @override
  ConsumerState<CreatorCoursesTab> createState() => _CreatorCoursesTabState();
}

class _CreatorCoursesTabState extends ConsumerState<CreatorCoursesTab> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  bool _isPublished = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _createCourse(WidgetRef ref) async {
    final auth = ref.read(authNotifierProvider);
    final userId = auth.profile?.id;
    if (userId == null) return;
    final price = int.tryParse(_priceController.text) ?? 0;
    final slug = _slugify(_titleController.text);
    await SupabaseManager.client.from('courses').insert({
      'creator_id': userId,
      'title': _titleController.text,
      'slug': slug,
      'description': _descriptionController.text,
      'price_cents': price,
      'currency': 'usd',
      'is_published': _isPublished,
    });
    ref.invalidate(creatorCoursesProvider);
    _titleController.clear();
    _descriptionController.clear();
    _priceController.text = '0';
    setState(() {
      _isPublished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(creatorCoursesProvider);
    return coursesAsync.when(
      data: (courses) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create new course', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Price (cents)'),
                      keyboardType: TextInputType.number,
                    ),
                    SwitchListTile(
                      value: _isPublished,
                      title: const Text('Published'),
                      onChanged: (value) => setState(() => _isPublished = value),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _titleController.text.isEmpty
                            ? null
                            : () => _createCourse(ref),
                        child: const Text('Create'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            for (final course in courses)
              EditableCourseCard(
                key: ValueKey(course.id),
                course: course,
              ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Failed to load courses: $error')),
    );
  }

  String _slugify(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}

class EditableCourseCard extends ConsumerStatefulWidget {
  const EditableCourseCard({required this.course, super.key});

  final Course course;

  @override
  ConsumerState<EditableCourseCard> createState() => _EditableCourseCardState();
}

class _EditableCourseCardState extends ConsumerState<EditableCourseCard> {
  late TextEditingController _title;
  late TextEditingController _description;
  late TextEditingController _price;
  late TextEditingController _slug;
  late bool _isPublished;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.course.title);
    _description = TextEditingController(text: widget.course.description ?? '');
    _price = TextEditingController(text: widget.course.priceCents.toString());
    _slug = TextEditingController(text: widget.course.slug);
    _isPublished = widget.course.isPublished;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _slug.dispose();
    super.dispose();
  }

  Future<void> _saveCourse() async {
    setState(() => _saving = true);
    try {
      await SupabaseManager.client
          .from('courses')
          .update({
            'title': _title.text,
            'description': _description.text,
            'price_cents': int.tryParse(_price.text) ?? widget.course.priceCents,
            'slug': _slug.text,
            'is_published': _isPublished,
          })
          .eq('id', widget.course.id);
      ref.invalidate(creatorCoursesProvider);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _addModule() async {
    final controller = TextEditingController();
    final passingController = TextEditingController();
    bool required = true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInnerState) => AlertDialog(
          title: const Text('Add module'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: passingController,
                decoration: const InputDecoration(labelText: 'Passing score'),
                keyboardType: TextInputType.number,
              ),
              CheckboxListTile(
                value: required,
                onChanged: (value) => setInnerState(() => required = value ?? true),
                title: const Text('Required'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (result == true && controller.text.isNotEmpty) {
      await SupabaseManager.client.from('modules').insert({
        'course_id': widget.course.id,
        'title': controller.text,
        'order_index': Random().nextInt(1000),
        'required': required,
        'passing_score': int.tryParse(passingController.text),
      });
      ref.invalidate(creatorCourseContentProvider(widget.course.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final modulesAsync = ref.watch(creatorCourseContentProvider(widget.course.id));
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.course.title, style: Theme.of(context).textTheme.titleMedium),
                ),
                Switch(
                  value: _isPublished,
                  onChanged: (value) => setState(() => _isPublished = value),
                ),
              ],
            ),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: _slug,
              decoration: const InputDecoration(labelText: 'Slug'),
            ),
            TextField(
              controller: _price,
              decoration: const InputDecoration(labelText: 'Price cents'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveCourse,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save'),
              ),
            ),
            const Divider(),
            Row(
              children: [
                Text('Modules', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(onPressed: _addModule, icon: const Icon(Icons.add)),
              ],
            ),
            modulesAsync.when(
              data: (modules) => Column(
                children: [
                  for (final module in modules)
                    ModuleEditor(
                      courseId: widget.course.id,
                      module: module.module,
                      lessons: module.lessons,
                    ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load modules: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModuleEditor extends ConsumerStatefulWidget {
  const ModuleEditor({required this.courseId, required this.module, required this.lessons, super.key});

  final String courseId;
  final Module module;
  final List<Lesson> lessons;

  @override
  ConsumerState<ModuleEditor> createState() => _ModuleEditorState();
}

class _ModuleEditorState extends ConsumerState<ModuleEditor> {
  Future<void> _addLesson() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add lesson'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(labelText: 'Content URL'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (result == true && titleController.text.isNotEmpty) {
      await SupabaseManager.client.from('lessons').insert({
        'module_id': widget.module.id,
        'title': titleController.text,
        'content_url': contentController.text,
        'order_index': widget.lessons.length + 1,
      });
      ref.invalidate(creatorCourseContentProvider(widget.courseId));
    }
  }

  Future<void> _deleteLesson(Lesson lesson) async {
    await SupabaseManager.client.from('lessons').delete().eq('id', lesson.id);
    ref.invalidate(creatorCourseContentProvider(widget.courseId));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.module.title, style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(onPressed: _addLesson, icon: const Icon(Icons.add)),
              ],
            ),
            for (final lesson in widget.lessons)
              ListTile(
                title: Text(lesson.title),
                subtitle: Text(lesson.contentUrl ?? 'No content URL'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteLesson(lesson),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CreatorAnalyticsTab extends ConsumerWidget {
  const CreatorAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(creatorCoursesProvider);
    return coursesAsync.when(
      data: (courses) {
        if (courses.isEmpty) {
          return const Center(child: Text('Create a course to see analytics.'));
        }
        return ListView.builder(
          itemCount: courses.length,
          itemBuilder: (context, index) {
            final course = courses[index];
            final analyticsAsync = ref.watch(courseAnalyticsProvider(course.id));
            return Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: analyticsAsync.when(
                  data: (analytics) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Students: ${analytics.studentCount}'),
                      Text('Last activity: ${analytics.lastActivity ?? 'N/A'}'),
                      const SizedBox(height: 12),
                      DataTable(columns: const [
                        DataColumn(label: Text('Module')),
                        DataColumn(label: Text('Completion %')),
                        DataColumn(label: Text('Avg score')),
                      ], rows: [
                        for (final module in analytics.modules)
                          DataRow(cells: [
                            DataCell(Text(module.module.title)),
                            DataCell(Text('${(module.completionRate * 100).toStringAsFixed(0)}%')),
                            DataCell(Text(module.averageScore?.toStringAsFixed(1) ?? 'N/A')),
                          ]),
                      ]),
                    ],
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => Text('Failed to load analytics: $error'),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Failed to load analytics: $error')),
    );
  }
}

class CreatorWebhooksTab extends ConsumerStatefulWidget {
  const CreatorWebhooksTab({super.key});

  @override
  ConsumerState<CreatorWebhooksTab> createState() => _CreatorWebhooksTabState();
}

class _CreatorWebhooksTabState extends ConsumerState<CreatorWebhooksTab> {
  final _secretController = TextEditingController();
  final _urlController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _secretController.dispose();
    _urlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createEndpoint() async {
    final auth = ref.read(authNotifierProvider);
    final ownerId = auth.profile?.id;
    if (ownerId == null) return;
    final secret = _secretController.text.isEmpty
        ? _generateSecret()
        : _secretController.text;
    await SupabaseManager.client.from('webhook_endpoints').insert({
      'owner_id': ownerId,
      'url': _urlController.text,
      'description': _descriptionController.text,
      'secret': secret,
    });
    ref.invalidate(webhookEndpointsProvider);
    _urlController.clear();
    _descriptionController.clear();
    _secretController.clear();
  }

  Future<void> _sendTest(WebhookEndpoint endpoint) async {
    await SupabaseManager.client.from('webhook_events').insert({
      'event_type': 'module.completed',
      'payload': {
        'user_id': 'test-user',
        'module_id': 'test-module',
      },
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test webhook enqueued.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final endpointsAsync = ref.watch(webhookEndpointsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add endpoint', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(labelText: 'URL'),
                    onChanged: (_) => setState(() {}),
                  ),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  TextField(
                    controller: _secretController,
                    decoration: const InputDecoration(labelText: 'Secret (optional)'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _urlController.text.isEmpty ? null : _createEndpoint,
                      child: const Text('Create endpoint'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          endpointsAsync.when(
            data: (endpoints) => Column(
              children: [
                for (final endpoint in endpoints)
                  ListTile(
                    title: Text(endpoint.url),
                    subtitle: Text('Events: ${endpoint.eventTypes.join(', ')}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () => _sendTest(endpoint),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await SupabaseManager.client
                                .from('webhook_endpoints')
                                .delete()
                                .eq('id', endpoint.id);
                            ref.invalidate(webhookEndpointsProvider);
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => Text('Failed to load endpoints: $error'),
          ),
        ],
      ),
    );
  }

  String _generateSecret() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
