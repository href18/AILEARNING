import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/assignment.dart';
import '../services/course_service.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({
    super.key,
    required this.courseService,
    required this.participantId,
    required this.participantName,
  });

  final CourseService courseService;
  final String participantId;
  final String participantName;

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  late Future<List<Assignment>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAssignments();
  }

  Future<List<Assignment>> _loadAssignments() {
    return widget.courseService.fetchAssignmentsForUser(
      userId: widget.participantId,
      locale: Intl.getCurrentLocale(),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadAssignments();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My learning'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Assignment>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load assignments: ${snapshot.error}',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              );
            }

            final assignments = snapshot.data ?? [];

            if (assignments.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hei, ${widget.participantName}!', style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text(
                          'Du har ingen aktive oppgaver akkurat nå. Nye kurs dukker opp her når en administrator tildeler dem.',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              itemCount: assignments.length + 1,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hei, ${widget.participantName}!', style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text(
                          'Følg fremdriften din og hent sertifikater når du er klar.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                final assignment = assignments[index - 1];
                return _AssignmentCard(assignment: assignment)
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .move(begin: const Offset(0, 12), duration: 300.ms, curve: Curves.easeOut);
              },
            );
          },
        ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dueLabel = assignment.dueLabel;
    final lastActivity = assignment.progress.lastActivityLabel;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                        assignment.course.code,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        assignment.course.title,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                _StatusChip(statusLabel: assignment.statusLabel),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: assignment.progress.completionRatio.clamp(0, 1),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Text(
              '${assignment.progress.modulesCompleted}/${assignment.progress.modulesTotal} modules fullført'
              ' • ${assignment.progress.percent}% ferdig',
              style: theme.textTheme.bodyMedium,
            ),
            if (dueLabel != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.event, size: 18),
                  const SizedBox(width: 8),
                  Text('Frist: $dueLabel', style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
            if (lastActivity != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.update, size: 18),
                  const SizedBox(width: 8),
                  Text('Sist oppdatert: $lastActivity', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
            if (assignment.certificate != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text('Sertifikat tilgjengelig', style: theme.textTheme.titleMedium),
                ],
              ),
              if (assignment.certificate?.issuedLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Utstedt: ${assignment.certificate!.issuedLabel}', style: theme.textTheme.bodyMedium),
                ),
              if (assignment.certificate?.expiresLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Gyldig til: ${assignment.certificate!.expiresLabel}', style: theme.textTheme.bodyMedium),
                ),
              if (assignment.certificate?.url != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SelectableText(
                    assignment.certificate!.url!,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.statusLabel});

  final String statusLabel;

  Color _backgroundColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (statusLabel) {
      case 'Completed':
        return theme.colorScheme.primaryContainer;
      case 'Overdue':
      case 'Expired':
        return theme.colorScheme.errorContainer;
      case 'In progress':
        return theme.colorScheme.secondaryContainer;
      default:
        return theme.colorScheme.surfaceVariant;
    }
  }

  Color _foregroundColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (statusLabel) {
      case 'Completed':
        return theme.colorScheme.onPrimaryContainer;
      case 'Overdue':
      case 'Expired':
        return theme.colorScheme.onErrorContainer;
      case 'In progress':
        return theme.colorScheme.onSecondaryContainer;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(statusLabel),
      backgroundColor: _backgroundColor(context),
      labelStyle: TextStyle(color: _foregroundColor(context), fontWeight: FontWeight.w600),
    );
  }
}
