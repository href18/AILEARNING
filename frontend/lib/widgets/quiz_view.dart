import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:compliance_training_app/localization/app_localizations.dart';
import 'package:compliance_training_app/models/course.dart';
import 'package:compliance_training_app/services/course_service.dart';

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
  late final PageController _pageController;
  int _currentQuestionIndex = 0;
  static const _defaultBackgroundUrl =
      'https://sora.chatgpt.com/api/gens/gen_01k7q6252hefpsgwrk2wx7tdfb/cover.webp';

  @override
  void initState() {
    super.initState();
    _answers = {
      for (final question in widget.module.quiz?.questions ?? [])
        question.id: <String>{},
    };
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quiz = widget.module.quiz;
    if (quiz == null) {
      return const Center(child: Text('No quiz attached to this module.'));
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final questions = quiz.questions;
    final totalQuestions = questions.length;
    final answeredCount = _answers.values.where((set) => set.isNotEmpty).length;
    final questionProgress = totalQuestions == 0 ? 0.0 : (_currentQuestionIndex + 1) / totalQuestions;
    final hasResult = widget.result != null;
    final resultScore = widget.result?.score ?? 0;
    final passed = widget.result?.passed ?? false;

    Future<void> submitQuiz() async {
      if (!hasResult && answeredCount < totalQuestions) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('course_quiz_unanswered_toast'))),
        );
        return;
      }
      await widget.onSubmit({
        for (final entry in _answers.entries) entry.key: entry.value.toList(),
      });
    }

    return Stack(
      children: [
        const _QuizBackground(imageUrl: _defaultBackgroundUrl),
        Positioned.fill(
          child: Container(color: theme.colorScheme.surface.withValues(alpha: 0.82)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.85),
                    theme.colorScheme.secondaryContainer.withValues(alpha: 0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('course_quiz_intro'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: questionProgress,
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.translate('course_quiz_progress', params: {
                          'current': '${_currentQuestionIndex + 1}',
                          'total': '$totalQuestions',
                        }),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        l10n.translate('course_quiz_answered', params: {
                          'count': '$answeredCount',
                          'total': '$totalQuestions',
                        }),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      hasResult
                          ? l10n.translate(
                              passed ? 'course_quiz_final_pass' : 'course_quiz_final_fail',
                              params: {'score': '$resultScore'},
                            )
                          : l10n.translate('course_quiz_bonus_ready'),
                      key: ValueKey(hasResult ? 'result-$passed-$resultScore' : 'progress'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: hasResult
                            ? (passed
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.error)
                            : theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentQuestionIndex = index),
                itemCount: questions.length,
                itemBuilder: (context, index) {
              final question = questions[index];
              final resultDetail = _detailForQuestion(question);
              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: theme.colorScheme.primary,
                                      child: Text(
                                        '${index + 1}',
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          color: theme.colorScheme.onPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        question.isMultiple
                                            ? l10n.translate('course_quiz_multi_helper')
                                            : l10n.translate('course_quiz_single_helper'),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  question.body,
                                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 18),
                                for (final option in question.options)
                                  _buildOption(
                                    context: context,
                                    question: question,
                                    option: option,
                                    isSelected: _answers[question.id]!.contains(option.id),
                                    showResult: hasResult,
                                    resultDetail: resultDetail,
                                  ),
                                if (resultDetail != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Text(
                                      resultDetail.isCorrect
                                          ? l10n.translate('course_quiz_correct')
                                          : l10n.translate('course_quiz_incorrect'),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: resultDetail.isCorrect
                                            ? theme.colorScheme.secondary
                                            : theme.colorScheme.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (resultDetail?.explanation != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      resultDetail!.explanation!,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (widget.result != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              l10n.translate(
                'course_quiz_score',
                params: {
                  'score': '${widget.result!.score}',
                  'passing': '${quiz.passingScore}',
                },
              ),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _currentQuestionIndex == 0
                        ? null
                        : () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            ),
                    icon: const Icon(Icons.chevron_left),
                    label: Text(l10n.translate('course_quiz_prev_question')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.submitting
                        ? null
                        : () async {
                            if (hasResult) {
                              await submitQuiz();
                              return;
                            }
                            if (_currentQuestionIndex < totalQuestions - 1) {
                              await _pageController.nextPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            } else {
                              await submitQuiz();
                            }
                          },
                    icon: widget.submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            hasResult
                                ? Icons.refresh
                                : (_currentQuestionIndex < totalQuestions - 1
                                    ? Icons.chevron_right
                                    : Icons.flag_rounded),
                          ),
                    label: Text(
                      hasResult
                          ? l10n.translate('course_quiz_retry')
                          : (_currentQuestionIndex < totalQuestions - 1
                              ? l10n.translate('course_quiz_next_question')
                              : l10n.translate('course_quiz_submit_final')),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  QuizResultDetail? _detailForQuestion(QuizQuestion question) {
    if (widget.result == null) {
      return null;
    }
    final matches = widget.result!.details.where((detail) => detail.questionId == question.id);
    if (matches.isEmpty) {
      return null;
    }
    return matches.first;
  }

  Widget _buildOption({
    required BuildContext context,
    required QuizQuestion question,
    required QuizOption option,
    required bool isSelected,
    required bool showResult,
    required QuizResultDetail? resultDetail,
  }) {
    final theme = Theme.of(context);
    final canInteract = !showResult && !widget.submitting;
    final isCorrectOption = showResult && option.isCorrect;
    final isWrongSelection = showResult && isSelected && !option.isCorrect;

    Color backgroundColor = theme.colorScheme.surface.withValues(alpha: 0.9);
    Color borderColor = theme.colorScheme.outlineVariant;
    Color iconColor = theme.colorScheme.onSurfaceVariant;
    IconData icon;

    if (showResult) {
      if (isCorrectOption) {
        backgroundColor = theme.colorScheme.secondaryContainer.withValues(alpha: 0.7);
        borderColor = theme.colorScheme.secondary;
        iconColor = theme.colorScheme.secondary;
        icon = Icons.emoji_events_outlined;
      } else if (isWrongSelection) {
        backgroundColor = theme.colorScheme.errorContainer.withValues(alpha: 0.6);
        borderColor = theme.colorScheme.error;
        iconColor = theme.colorScheme.error;
        icon = Icons.close;
      } else {
        icon = question.isMultiple ? Icons.check_box_outline_blank : Icons.radio_button_unchecked;
      }
    } else {
      if (isSelected) {
        backgroundColor = theme.colorScheme.primaryContainer.withValues(alpha: 0.75);
        borderColor = theme.colorScheme.primary;
        iconColor = theme.colorScheme.primary;
        icon = question.isMultiple ? Icons.check_box : Icons.radio_button_checked;
      } else {
        icon = question.isMultiple ? Icons.check_box_outline_blank : Icons.radio_button_unchecked;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: canInteract
            ? () => _toggleOption(question.id, option.id, question.isMultiple)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.body,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleOption(String questionId, String optionId, bool isMultiple) {
    setState(() {
      final selections = _answers[questionId]!;
      if (isMultiple) {
        if (selections.contains(optionId)) {
          selections.remove(optionId);
        } else {
          selections.add(optionId);
        }
      } else {
        selections
          ..clear()
          ..add(optionId);
      }
    });
  }
}

class _QuizBackground extends StatelessWidget {
  const _QuizBackground({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blueGrey.shade900,
            Colors.indigo.shade700,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );

    if (imageUrl.isEmpty) {
      return fallback;
    }

    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.35), BlendMode.srcATop),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return child;
            }
            return fallback;
          },
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/images/quiz_fallback.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback,
            );
          },
        ),
      ),
    );
  }
}
