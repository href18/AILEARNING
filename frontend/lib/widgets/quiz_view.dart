import 'dart:math';

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
    this.onReset,
  });

  final CourseModule module;
  final bool submitting;
  final QuizResult? result;
  final QuizSubmission onSubmit;
  final VoidCallback? onReset;

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  static const _transitionDuration = Duration(milliseconds: 450);

  late Map<String, Set<String>> _answers;
  int _currentQuestionIndex = 0;
  bool _showTransition = false;
  String _transitionMessage = '';
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _resetAnswers();
  }

  @override
  void didUpdateWidget(covariant QuizView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module.id != widget.module.id) {
      _resetAnswers(notify: true);
    } else if (oldWidget.result != widget.result && widget.result == null) {
      _resetAnswers(notify: true);
    }
  }

  void _resetAnswers({bool notify = false}) {
    final questions = widget.module.quiz?.questions ?? [];
    _answers = {
      for (final question in questions) question.id: <String>{},
    };
    _currentQuestionIndex = 0;
    _showTransition = false;
    _transitionMessage = '';
    if (notify && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiz = widget.module.quiz;
    if (quiz == null) {
      return const Center(child: Text('No quiz attached to this module.'));
    }

    final questions = quiz.questions;
    final question = questions[_currentQuestionIndex];
    final resultDetail = widget.result?.details
        .where((detail) => detail.questionId == question.id)
        .cast<QuizResultDetail?>()
        .firstWhere((detail) => detail != null, orElse: () => null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProgressRow(questions),
        const SizedBox(height: 16),
        _buildMentorPanel(resultDetail),
        const SizedBox(height: 16),
        Expanded(
          child: Stack(
            children: [
              AnimatedSwitcher(
                duration: _transitionDuration,
                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                child: _QuestionCard(
                  key: ValueKey(question.id + (widget.result == null ? '' : '_result')),
                  index: _currentQuestionIndex,
                  total: questions.length,
                  question: question,
                  resultDetail: resultDetail,
                  answers: _answers,
                  onChanged: widget.result != null ? null : (optionId) {
                    setState(() {
                      _toggleAnswer(question, optionId);
                    });
                  },
                ),
              ),
              if (_showTransition)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: _transitionDuration,
                      opacity: _showTransition ? 1 : 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary.withOpacity(0.9),
                              Theme.of(context).colorScheme.secondary.withOpacity(0.9),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.emoji_people, size: 64, color: Colors.white),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  _transitionMessage,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.result != null) _buildScoreBanner(context, quiz),
        const SizedBox(height: 12),
        _buildActions(context, questions.length),
      ],
    );
  }

  Widget _buildMentorPanel(QuizResultDetail? detail) {
    final theme = Theme.of(context);
    final List<String> positivePrompts = [
      'Bra jobba! Fortsett slik.',
      'Stødig kontroll – la oss ta neste scenario.',
      'Rune er imponert! Hold fokus.',
    ];
    final List<String> neutralPrompts = [
      'Les situasjonen nøye før du svarer.',
      'Ta et pust i bakken og tenk gjennom rutinene.',
      'Husk å bruke erfaringen fra forrige modul.',
    ];

    final bool? isCorrect = detail?.isCorrect;
    final indexSeed = _currentQuestionIndex;
    final String headline;
    if (widget.result == null) {
      headline = neutralPrompts[indexSeed % neutralPrompts.length];
    } else if (isCorrect == true) {
      headline = positivePrompts[indexSeed % positivePrompts.length];
    } else if (isCorrect == false) {
      headline = 'La oss gå gjennom dette sammen én gang til.';
    } else {
      headline = neutralPrompts[indexSeed % neutralPrompts.length];
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.85),
            theme.colorScheme.secondaryContainer.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: theme.colorScheme.onPrimaryContainer.withOpacity(0.1),
            child: const Icon(Icons.engineering, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.result == null
                      ? 'Svar på spørsmålet for å låse opp neste steg. Vi viser fremdriften i indikatorene over.'
                      : detail?.explanation ?? 'Se forklaringen over før du prøver igjen.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow(List<QuizQuestion> questions) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (var i = 0; i < questions.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentQuestionIndex = i;
                });
              },
              child: AnimatedContainer(
                duration: _transitionDuration,
                height: 8,
                margin: EdgeInsets.symmetric(horizontal: i == 0 || i == questions.length - 1 ? 0 : 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _progressColorFor(i, questions[i], theme),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _progressColorFor(int index, QuizQuestion question, ThemeData theme) {
    final detail = widget.result?.details
        .where((element) => element.questionId == question.id)
        .cast<QuizResultDetail?>()
        .firstWhere((element) => element != null, orElse: () => null);

    if (detail != null) {
      return detail.isCorrect
          ? theme.colorScheme.tertiary
          : theme.colorScheme.error.withOpacity(0.8);
    }

    if (index == _currentQuestionIndex) {
      return theme.colorScheme.primary;
    }

    if (_answers[question.id]?.isNotEmpty ?? false) {
      return theme.colorScheme.secondary;
    }

    return theme.colorScheme.outlineVariant.withOpacity(0.4);
  }

  Widget _buildScoreBanner(BuildContext context, Quiz quiz) {
    final theme = Theme.of(context);
    final result = widget.result!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: result.passed
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.errorContainer,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.passed ? 'Sertifisert!' : 'Et forsøk til',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Score: ${result.score}% (krav ${quiz.passingScore}%)'),
            ],
          ),
          Icon(result.passed ? Icons.emoji_events : Icons.restart_alt, size: 36),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, int totalQuestions) {
    final isLastQuestion = _currentQuestionIndex == totalQuestions - 1;
    final currentQuestion = widget.module.quiz!.questions[_currentQuestionIndex];
    final hasSelection = _answers[currentQuestion.id]?.isNotEmpty ?? false;
    final allAnswered = _answers.values.every((set) => set.isNotEmpty);

    if (widget.result != null) {
      return Row(
        children: [
          FilledButton.icon(
            onPressed: widget.submitting
                ? null
                : () {
                    widget.onReset?.call();
                  },
            icon: widget.submitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: const Text('Start nytt forsøk'),
          ),
        ],
      );
    }

    return Row(
      children: [
        if (_currentQuestionIndex > 0)
          TextButton.icon(
            onPressed: widget.submitting
                ? null
                : () {
                    setState(() {
                      _showTransition = false;
                      _currentQuestionIndex--;
                    });
                  },
            icon: const Icon(Icons.chevron_left),
            label: const Text('Tilbake'),
          ),
        const Spacer(),
        if (!isLastQuestion)
          FilledButton.icon(
            onPressed: widget.submitting || !hasSelection || _showTransition
                ? null
                : () {
                    _queueTransitionMessage();
                    Future.delayed(_transitionDuration ~/ 2, () {
                      if (!mounted) return;
                      setState(() {
                        _currentQuestionIndex++;
                      });
                    });
                    Future.delayed(_transitionDuration, () {
                      if (!mounted) return;
                      setState(() {
                        _showTransition = false;
                      });
                    });
                  },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Neste spørsmål'),
          )
        else
          FilledButton.icon(
            onPressed: widget.submitting || !allAnswered
                ? null
                : () async {
                    await widget.onSubmit({
                      for (final entry in _answers.entries) entry.key: entry.value.toList(),
                    });
                  },
            icon: widget.submitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_circle_outline),
            label: const Text('Lever svar'),
          ),
      ],
    );
  }

  void _toggleAnswer(QuizQuestion question, String optionId) {
    final current = _answers[question.id]!;
    if (question.isMultiple) {
      if (current.contains(optionId)) {
        current.remove(optionId);
      } else {
        current.add(optionId);
      }
    } else {
      current
        ..clear()
        ..add(optionId);
    }
  }

  void _queueTransitionMessage() {
    const messages = [
      'Supert! Rune gjør seg klar til neste scenario...',
      'Hold tempoet oppe – nytt spørsmål lastes inn.',
      'Sterk innsats! Vi hopper videre.',
    ];

    setState(() {
      _transitionMessage = messages[_random.nextInt(messages.length)];
      _showTransition = true;
    });
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.index,
    required this.total,
    required this.question,
    required this.resultDetail,
    required this.answers,
    required this.onChanged,
  });

  final int index;
  final int total;
  final QuizQuestion question;
  final QuizResultDetail? resultDetail;
  final Map<String, Set<String>> answers;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = answers[question.id] ?? <String>{};
    final correctOptions = resultDetail?.correctOptionIds.toSet() ?? <String>{};
    final isResultView = resultDetail != null;

    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scenario ${index + 1} av $total', style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),
            Text(question.body, style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final option in question.options)
                  _QuizOptionChip(
                    text: option.body,
                    selected: selected.contains(option.id),
                    showResult: isResultView,
                    isCorrect: correctOptions.contains(option.id),
                    isIncorrectSelection:
                        isResultView && selected.contains(option.id) && !correctOptions.contains(option.id),
                    onTap: onChanged == null
                        ? null
                        : () {
                            onChanged!(option.id);
                          },
                  ),
              ],
            ),
            if (resultDetail?.explanation != null) ...[
              const SizedBox(height: 24),
              Text('Forklaring', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(resultDetail!.explanation!),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuizOptionChip extends StatelessWidget {
  const _QuizOptionChip({
    required this.text,
    required this.selected,
    required this.showResult,
    required this.isCorrect,
    required this.isIncorrectSelection,
    this.onTap,
  });

  final String text;
  final bool selected;
  final bool showResult;
  final bool isCorrect;
  final bool isIncorrectSelection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color background = theme.colorScheme.surfaceVariant;
    Color border = theme.colorScheme.outlineVariant;
    Color foreground = theme.colorScheme.onSurfaceVariant;

    if (showResult) {
      if (isCorrect) {
        background = theme.colorScheme.tertiaryContainer;
        border = theme.colorScheme.tertiary;
        foreground = theme.colorScheme.onTertiaryContainer;
      } else if (isIncorrectSelection) {
        background = theme.colorScheme.errorContainer;
        border = theme.colorScheme.error;
        foreground = theme.colorScheme.onErrorContainer;
      } else if (selected) {
        background = theme.colorScheme.surfaceTint.withOpacity(0.2);
        border = theme.colorScheme.surfaceTint;
        foreground = theme.colorScheme.onSurface;
      }
    } else if (selected) {
      background = theme.colorScheme.primaryContainer;
      border = theme.colorScheme.primary;
      foreground = theme.colorScheme.onPrimaryContainer;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: background,
          border: Border.all(color: border, width: 2),
          boxShadow: [
            if (selected && !showResult)
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 140),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}
