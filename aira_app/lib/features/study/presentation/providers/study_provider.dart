import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/core/services/api_service.dart';

// ──────────────────── Models ────────────────────

class QuizQuestion {
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String explanation;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correct_answer'] ?? '',
      explanation: json['explanation'] ?? '',
    );
  }
}

// ──────────────────── State ────────────────────

class StudyState {
  final String? generatedNotes;
  final List<QuizQuestion> quizQuestions;
  final bool isLoading;
  final String? error;
  final int currentQuestionIndex;
  final int score;
  final bool quizSubmitted;
  final String? selectedAnswer;

  const StudyState({
    this.generatedNotes,
    this.quizQuestions = const [],
    this.isLoading = false,
    this.error,
    this.currentQuestionIndex = 0,
    this.score = 0,
    this.quizSubmitted = false,
    this.selectedAnswer,
  });

  StudyState copyWith({
    String? generatedNotes,
    List<QuizQuestion>? quizQuestions,
    bool? isLoading,
    String? error,
    int? currentQuestionIndex,
    int? score,
    bool? quizSubmitted,
    String? selectedAnswer,
  }) {
    return StudyState(
      generatedNotes: generatedNotes ?? this.generatedNotes,
      quizQuestions: quizQuestions ?? this.quizQuestions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      score: score ?? this.score,
      quizSubmitted: quizSubmitted ?? this.quizSubmitted,
      selectedAnswer: selectedAnswer,
    );
  }
}

// ──────────────────── Notifier ────────────────────

class StudyNotifier extends StateNotifier<StudyState> {
  final ApiService _api = ApiService();

  StudyNotifier() : super(const StudyState());

  Future<void> generateNotes(String topic) async {
    state = state.copyWith(isLoading: true, error: null, generatedNotes: null);
    try {
      final res = await _api.generateStudyNotes(topic);
      state = state.copyWith(
        generatedNotes: res['notes'],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> generateQuiz(String topic) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      quizQuestions: [],
      currentQuestionIndex: 0,
      score: 0,
      quizSubmitted: false,
      selectedAnswer: null,
    );
    try {
      final res = await _api.generateQuiz(topic);
      final questions = res.map((q) => QuizQuestion.fromJson(q)).toList();
      state = state.copyWith(
        quizQuestions: questions,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void selectAnswer(String answer) {
    if (state.quizSubmitted) return;
    state = state.copyWith(selectedAnswer: answer);
  }

  void submitAnswer() {
    if (state.selectedAnswer == null || state.quizSubmitted) return;
    
    final currentQ = state.quizQuestions[state.currentQuestionIndex];
    final isCorrect = state.selectedAnswer == currentQ.correctAnswer;
    
    state = state.copyWith(
      quizSubmitted: true,
      score: isCorrect ? state.score + 1 : state.score,
    );
  }

  void nextQuestion() {
    if (state.currentQuestionIndex + 1 < state.quizQuestions.length) {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex + 1,
        quizSubmitted: false,
        selectedAnswer: null,
      );
    }
  }
}

// ──────────────────── Provider ────────────────────

final studyProvider = StateNotifierProvider<StudyNotifier, StudyState>((ref) {
  return StudyNotifier();
});
