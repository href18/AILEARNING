import 'package:flutter/material.dart';

import '../models/course.dart';
import '../services/course_service.dart';

typedef QuizSubmission = Future<void> Function(Map<String, List<String>> answers);

class QuizView extends StatefulWidget {
  const QuizView({
    super.key,
    required this.module,
    required this.submitting,
    required this.result,
    required this.onSubmit,
  });

  final CourseModule module;
  final bool submitting;
  final QuizResult? result;
  final QuizSubmission onSubmit;

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  late final Map<String, Set<String>> _answers;

  @override
  void initState() {
    super.initState();
    _answers = {
      for (final question in widget.module.quiz?.questions ?? [])
        question.id: <String>{},
    };
  }

  @override
  Widget build(BuildContext context) {
    final quiz = widget.module.quiz;
    if (quiz == null) {
      return const Center(child: Text('No quiz attached to this module.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: quiz.questions.length,
            itemBuilder: (context, index) {
              final question = quiz.questions[index];
              final resultDetail = widget.result?.details
                  .where((detail) => detail.questionId == question.id)
                  .cast<QuizResultDetail?>()
                  .firstWhere((detail) => detail != null, orElse: () => null);

              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Q${index + 1}', style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 8),
                      Text(question.body, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      ...question.options.map((option) {
                        final isSelected = _answers[question.id]!.contains(option.id);
                        return CheckboxListTile(
                          value: isSelected,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(option.body),
                          subtitle: widget.result != null && option.isCorrect
                              ? const Text('Correct answer', style: TextStyle(color: Colors.green))
                              : null,
                          onChanged: widget.result != null
                              ? null
                              : (checked) {
                                  setState(() {
                                    if (question.isMultiple) {
                                      if (checked ?? false) {
                                        _answers[question.id]!.add(option.id);
                                      } else {
                                        _answers[question.id]!.remove(option.id);
                                      }
                                    } else {
                                      _answers[question.id]!
                                        ..clear()
                                        ..add(option.id);
                                    }
                                  });
                                },
                        );
                      }),
                      if (resultDetail != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            resultDetail.isCorrect ? '✅ Correct' : '❌ Incorrect',
                            style: TextStyle(color: resultDetail.isCorrect ? Colors.green : Colors.red),
                          ),
                        ),
                      if (resultDetail?.explanation != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(resultDetail!.explanation!),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (widget.result != null)
          Text('Score: ${widget.result!.score}% | Passing score ${quiz.passingScore}%',
              style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: widget.submitting
              ? null
              : () async {
                  await widget.onSubmit({
                    for (final entry in _answers.entries) entry.key: entry.value.toList(),
                  });
                },
          icon: widget.submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check_circle_outline),
          label: Text(widget.result == null ? 'Submit quiz' : 'Retry quiz'),
        ),
      ],
    );
  }
}
