import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/quiz/domain/entities/quiz_question.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

enum QuizStatus { setup, running, revealing, finished, notEnoughWords }

class QuizState extends Equatable {
  final QuizStatus status;
  final List<QuizQuestion> questions;
  final List<QuizAnswer> answers;
  final int index;
  final int? selectedIndex;

  const QuizState({
    this.status = QuizStatus.setup,
    this.questions = const [],
    this.answers = const [],
    this.index = 0,
    this.selectedIndex,
  });

  QuizQuestion? get current =>
      index >= 0 && index < questions.length ? questions[index] : null;

  int get total => questions.length;
  int get correct => answers.where((a) => a.isCorrect).length;
  double get accuracy => answers.isEmpty ? 0 : correct / answers.length;
  double get progress => total == 0 ? 0 : answers.length / total;

  QuizState copyWith({
    QuizStatus? status,
    List<QuizQuestion>? questions,
    List<QuizAnswer>? answers,
    int? index,
    int? selectedIndex,
    bool clearSelection = false,
  }) =>
      QuizState(
        status: status ?? this.status,
        questions: questions ?? this.questions,
        answers: answers ?? this.answers,
        index: index ?? this.index,
        selectedIndex:
            clearSelection ? null : (selectedIndex ?? this.selectedIndex),
      );

  @override
  List<Object?> get props =>
      [status, questions, answers, index, selectedIndex];
}

class QuizCubit extends Cubit<QuizState> {
  final WordRepository _words;
  final ProgressRepository _progress;

  QuizCubit(this._words, this._progress) : super(const QuizState());

  static const questionCount = 10;
  static const optionCount = 4;

  /// Builds a session from the learner's level filter.
  ///
  /// Words that spaced repetition says are due come first — a quiz that
  /// ignored the schedule would be entertainment rather than practice — and
  /// the rest is filled randomly from the level pool.
  void start(LevelFilter filter, {WordCategory? category}) {
    final pool = _words.pool(levels: filter.levels, category: category);
    if (pool.length < optionCount) {
      emit(const QuizState(status: QuizStatus.notEnoughWords));
      return;
    }

    final random = Random();
    final dueIds = _progress.dueCards().map((c) => c.wordId).toSet();
    final due = pool.where((w) => dueIds.contains(w.id)).toList()
      ..shuffle(random);
    final rest = pool.where((w) => !dueIds.contains(w.id)).toList()
      ..shuffle(random);

    final targets = [...due, ...rest].take(questionCount).toList()
      ..shuffle(random);

    const modes = QuizMode.values;
    final questions = <QuizQuestion>[];
    for (var i = 0; i < targets.length; i++) {
      final target = targets[i];
      final mode = modes[random.nextInt(modes.length)];
      final options = [
        target,
        ..._words.distractorsFor(target,
            count: optionCount - 1, seed: random.nextInt(1 << 31)),
      ]..shuffle(random);

      // A distractor shortage would make the question unanswerable.
      if (options.length < optionCount) continue;
      questions.add(
          QuizQuestion(target: target, mode: mode, options: options));
    }

    if (questions.isEmpty) {
      emit(const QuizState(status: QuizStatus.notEnoughWords));
      return;
    }

    emit(QuizState(status: QuizStatus.running, questions: questions));
  }

  /// Records the choice and freezes the question so the learner can see which
  /// option was right before moving on.
  void answer(int optionIndex) {
    if (state.status != QuizStatus.running) return;
    final question = state.current;
    if (question == null) return;

    emit(state.copyWith(
      status: QuizStatus.revealing,
      selectedIndex: optionIndex,
      answers: [
        ...state.answers,
        QuizAnswer(question: question, selectedIndex: optionIndex),
      ],
    ));
  }

  Future<void> next() async {
    if (state.status != QuizStatus.revealing) return;

    final isLast = state.index >= state.questions.length - 1;
    if (!isLast) {
      emit(state.copyWith(
        status: QuizStatus.running,
        index: state.index + 1,
        clearSelection: true,
      ));
      return;
    }

    emit(state.copyWith(status: QuizStatus.finished, clearSelection: true));
    await _persist();
  }

  /// A quiz answer is a review too: a correct pick scores 1.0, a wrong one
  /// 0.2 rather than 0, since recognising three wrong options still carries
  /// partial knowledge and a hard zero would reset the card too aggressively.
  Future<void> _persist() async {
    for (final answer in state.answers) {
      await _progress.recordAttempt(
        wordId: answer.question.target.id,
        score: answer.isCorrect ? 1.0 : 0.2,
        kind: AttemptKind.quiz,
      );
    }
    await _progress.recordQuizRun(
      correct: state.correct,
      total: state.answers.length,
    );
  }

  void reset() => emit(const QuizState());
}
