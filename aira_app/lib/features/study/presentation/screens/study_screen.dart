import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:aira_app/core/theme/aira_colors.dart';
import 'package:aira_app/core/theme/aira_typography.dart';
import 'package:aira_app/core/widgets/glassmorphic_container.dart';
import 'package:aira_app/core/widgets/aira_button.dart';
import 'package:aira_app/core/widgets/aira_text_field.dart';
import 'package:aira_app/features/study/presentation/providers/study_provider.dart';

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _notesTopicController = TextEditingController();
  final _quizTopicController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesTopicController.dispose();
    _quizTopicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyProvider);

    return Scaffold(
      backgroundColor: AiraColors.scaffoldDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Study Tools', style: AiraTypography.h4),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AiraColors.electricCyan,
          labelColor: AiraColors.electricCyan,
          unselectedLabelColor: AiraColors.textMuted,
          tabs: const [
            Tab(text: 'Study Notes', icon: Icon(Icons.notes_rounded)),
            Tab(text: 'Practice Quiz', icon: Icon(Icons.quiz_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotesTab(state),
          _buildQuizTab(state),
        ],
      ),
    );
  }

  // ──────────────────── Notes Tab ────────────────────

  Widget _buildNotesTab(StudyState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AiraTextField(
                  controller: _notesTopicController,
                  hintText: 'Enter topic (e.g. Spaced Repetition)',
                ),
              ),
              const SizedBox(width: 8),
              AiraButton(
                label: 'Create',
                onPressed: () {
                  if (_notesTopicController.text.trim().isEmpty) return;
                  ref.read(studyProvider.notifier).generateNotes(_notesTopicController.text.trim());
                },
                isLoading: state.isLoading && state.generatedNotes == null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: state.isLoading && state.generatedNotes == null
                ? const Center(child: CircularProgressIndicator(color: AiraColors.electricCyan))
                : state.generatedNotes == null
                    ? _buildEmptyState('Type a topic above to generate study notes!')
                    : GlassmorphicContainer(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        child: Markdown(
                          data: state.generatedNotes!,
                          styleSheet: MarkdownStyleSheet(
                            p: AiraTypography.bodyMedium.copyWith(color: AiraColors.textPrimary, height: 1.5),
                            h1: AiraTypography.h4.copyWith(color: AiraColors.textPrimary),
                            h2: AiraTypography.h5.copyWith(color: AiraColors.textPrimary),
                            h3: AiraTypography.h6.copyWith(color: AiraColors.textPrimary),
                            listBullet: AiraTypography.bodyMedium.copyWith(color: AiraColors.electricCyan),
                          ),
                        ),
                      ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ──────────────────── Quiz Tab ────────────────────

  Widget _buildQuizTab(StudyState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AiraColors.electricCyan));
    }

    if (state.quizQuestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AiraTextField(
              controller: _quizTopicController,
              hintText: 'Enter quiz topic (e.g. Python OOP)',
            ),
            const SizedBox(height: 16),
            AiraButton(
              label: 'Generate Quiz',
              onPressed: () {
                if (_quizTopicController.text.trim().isEmpty) return;
                ref.read(studyProvider.notifier).generateQuiz(_quizTopicController.text.trim());
              },
              isFullWidth: true,
            ),
          ],
        ),
      );
    }

    // Active Quiz Play Screen
    final questionIndex = state.currentQuestionIndex;
    final totalQuestions = state.quizQuestions.length;
    final currentQ = state.quizQuestions[questionIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Question ${questionIndex + 1} of $totalQuestions', style: AiraTypography.caption.copyWith(color: AiraColors.textMuted)),
              Text('Score: ${state.score}', style: AiraTypography.caption.copyWith(color: AiraColors.success, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (questionIndex + 1) / totalQuestions,
              backgroundColor: AiraColors.surfaceDark,
              color: AiraColors.electricCyan,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 24),
          GlassmorphicContainer(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(currentQ.question, style: AiraTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                // Options list
                ...currentQ.options.map((option) {
                  final isSelected = state.selectedAnswer == option;
                  final isCorrect = option == currentQ.correctAnswer;
                  
                  Color cardBorderColor = AiraColors.glassBorder;
                  Color cardBgColor = AiraColors.surfaceDark.withValues(alpha: 0.5);

                  if (state.quizSubmitted) {
                    if (isCorrect) {
                      cardBorderColor = AiraColors.success;
                      cardBgColor = AiraColors.success.withValues(alpha: 0.1);
                    } else if (isSelected) {
                      cardBorderColor = AiraColors.error;
                      cardBgColor = AiraColors.error.withValues(alpha: 0.1);
                    }
                  } else if (isSelected) {
                    cardBorderColor = AiraColors.electricCyan;
                    cardBgColor = AiraColors.electricCyan.withValues(alpha: 0.05);
                  }

                  return GestureDetector(
                    onTap: () => ref.read(studyProvider.notifier).selectAnswer(option),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorderColor, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: AiraTypography.bodyMedium.copyWith(
                                color: isSelected || (state.quizSubmitted && isCorrect)
                                    ? Colors.white
                                    : AiraColors.textSecondary,
                              ),
                            ),
                          ),
                          if (state.quizSubmitted && isCorrect)
                            const Icon(Icons.check_circle_rounded, color: AiraColors.success)
                          else if (state.quizSubmitted && isSelected)
                            const Icon(Icons.cancel_rounded, color: AiraColors.error),
                        ],
                      ),
                    ),
                  );
                }),
                // Explanation block
                if (state.quizSubmitted) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AiraColors.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(left: BorderSide(color: AiraColors.electricCyan, width: 3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Explanation:', style: AiraTypography.overline.copyWith(color: AiraColors.electricCyan)),
                        const SizedBox(height: 4),
                        Text(currentQ.explanation, style: AiraTypography.bodySmall.copyWith(color: AiraColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Action button
          if (!state.quizSubmitted)
            AiraButton(
              label: 'Submit Answer',
              onPressed: state.selectedAnswer != null
                  ? () => ref.read(studyProvider.notifier).submitAnswer()
                  : null,
              isFullWidth: true,
            )
          else
            AiraButton(
              label: questionIndex + 1 == totalQuestions ? 'Finish Quiz' : 'Next Question',
              onPressed: () {
                if (questionIndex + 1 == totalQuestions) {
                  // Finish and reset
                  ref.read(studyProvider.notifier).generateQuiz('');
                } else {
                  ref.read(studyProvider.notifier).nextQuestion();
                }
              },
              isFullWidth: true,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, size: 52, color: AiraColors.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            text,
            style: AiraTypography.bodySmall.copyWith(color: AiraColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
