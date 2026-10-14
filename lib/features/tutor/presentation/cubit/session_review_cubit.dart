import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:french_pass/core/ai/ai_backend.dart';
import 'package:french_pass/features/tutor/data/tutor_repository.dart';
import 'package:french_pass/features/tutor/data/tutor_review_service.dart';
import 'package:french_pass/features/tutor/domain/lesson.dart';
import 'package:french_pass/features/tutor/domain/saved_session.dart';
import 'package:french_pass/features/tutor/domain/tutor_message.dart';

class SessionReviewState extends Equatable {
  final SavedSession? session;

  /// Lines whose study is being fetched.
  final Set<int> loading;

  /// Lines whose last fetch failed, with a message for the learner.
  final Map<int, String> failed;

  const SessionReviewState({
    this.session,
    this.loading = const {},
    this.failed = const {},
  });

  SessionReviewState copyWith({
    SavedSession? session,
    Set<int>? loading,
    Map<int, String>? failed,
  }) =>
      SessionReviewState(
        session: session ?? this.session,
        loading: loading ?? this.loading,
        failed: failed ?? this.failed,
      );

  @override
  List<Object?> get props => [session, loading, failed];
}

/// Loads a saved conversation and fetches the study material for a line the
/// first time the learner opens it, caching it back into the saved session.
class SessionReviewCubit extends Cubit<SessionReviewState> {
  final TutorRepository _repo;
  final TutorReviewService _reviewer;

  SessionReviewCubit({
    required String sessionId,
    required TutorRepository repository,
    required TutorReviewService reviewer,
  })  : _repo = repository,
        _reviewer = reviewer,
        super(SessionReviewState(session: repository.session(sessionId)));

  Lesson? get lesson {
    final s = state.session;
    return s == null ? null : Lessons.byId(s.lessonId);
  }

  /// Fetches the study for line [index] unless it is cached or in flight.
  Future<void> study(int index) async {
    final session = state.session;
    if (session == null || index < 0 || index >= session.messages.length) {
      return;
    }
    if (session.studies.containsKey(index) || state.loading.contains(index)) {
      return;
    }
    final line = session.messages[index];
    if (line.text.trim().isEmpty) return;

    emit(state.copyWith(
      loading: {...state.loading, index},
      failed: {...state.failed}..remove(index),
    ));

    String? previous;
    for (var i = index - 1; i >= 0; i--) {
      final text = session.messages[i].text.trim();
      if (text.isNotEmpty) {
        previous = text;
        break;
      }
    }

    LineStudy? result;
    String? error;
    try {
      result = await _reviewer.studyLine(
        line: line.text,
        byTutor: line is TutorLine,
        lessonTitle: lesson?.titleEs ?? 'Conversación libre',
        previousLine: previous,
        levelEstimate: _repo.profile().levelEstimate,
      );
    } on AiException catch (e) {
      error = e.rateLimited || e.unavailable
          ? e.messageEs
          : 'No pude analizar esta frase. Revisa tu conexión e inténtalo '
              'otra vez.';
    }
    if (isClosed) return;

    final loading = {...state.loading}..remove(index);
    if (result == null) {
      emit(state.copyWith(
        loading: loading,
        failed: {...state.failed, index: error ?? 'Algo salió mal.'},
      ));
      return;
    }

    // Re-read: another line may have been cached while this one loaded.
    final updated = state.session!.withStudy(index, result);
    emit(state.copyWith(session: updated, loading: loading));
    await _repo.saveSession(updated);
  }
}
