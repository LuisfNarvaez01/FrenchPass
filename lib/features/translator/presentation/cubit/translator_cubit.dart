import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:french_pass/core/ai/ai_backend.dart';
import 'package:french_pass/features/premium/data/usage_service.dart';
import 'package:french_pass/features/translator/data/translator_repository.dart';
import 'package:french_pass/features/translator/domain/translation.dart';
import 'package:french_pass/features/tutor/data/tutor_repository.dart';
import 'package:french_pass/features/tutor/data/tutor_review_service.dart';

class TranslatorState extends Equatable {
  /// The translation on screen, if any.
  final Translation? current;
  final List<Translation> history;
  final bool loading;

  /// Why the last translation failed, worded for the learner.
  final String? error;

  /// The failure was the free daily limit: offer Premium.
  final bool needsPremium;

  const TranslatorState({
    this.current,
    this.history = const [],
    this.loading = false,
    this.error,
    this.needsPremium = false,
  });

  @override
  List<Object?> get props =>
      [current?.id, history.length, loading, error, needsPremium];
}

/// Sends a Spanish sentence to Gemini and keeps the result in the history,
/// so translating the same thing twice costs nothing.
class TranslatorCubit extends Cubit<TranslatorState> {
  /// Long enough for a short paragraph, short enough that the word-by-word
  /// breakdown stays readable.
  static const maxLength = 280;

  final TranslatorRepository _translations;
  final TutorRepository _tutor;
  final TutorReviewService _gemini;
  final UsageService _usage;

  TranslatorCubit({
    required TranslatorRepository translations,
    required TutorRepository tutor,
    required TutorReviewService gemini,
    required UsageService usage,
  })  : _translations = translations,
        _tutor = tutor,
        _gemini = gemini,
        _usage = usage,
        super(TranslatorState(history: translations.history()));

  Future<void> translate(String text) async {
    final source = text.trim();
    if (source.isEmpty || state.loading) return;

    final saved = _translations.find(source);
    if (saved != null) {
      emit(TranslatorState(current: saved, history: state.history));
      return;
    }

    // Saved translations above are free; only a new request counts.
    if (!_usage.canUseAi) {
      emit(TranslatorState(
        history: state.history,
        error: _usage.aiLimitMessageEs,
        needsPremium: !_usage.isPremium,
      ));
      return;
    }

    emit(TranslatorState(history: state.history, loading: true));
    Translation? result;
    String? error;
    try {
      result = await _gemini.explainTranslation(
        text: source,
        levelEstimate: _tutor.profile().levelEstimate,
      );
    } on AiException catch (e) {
      error = e.rateLimited || e.unverified
          ? e.messageEs
          : e.unavailable
              ? e.messageEs
              : 'No pude traducir esto. Revisa tu conexión e inténtalo otra '
                  'vez.';
    }
    if (isClosed) return;

    if (result == null) {
      emit(TranslatorState(history: state.history, error: error));
      return;
    }
    await _usage.addAiQuery();
    await _translations.save(result);
    if (isClosed) return;
    emit(TranslatorState(current: result, history: _translations.history()));
  }

  void open(Translation translation) =>
      emit(TranslatorState(current: translation, history: state.history));

  /// Back to the empty input, history underneath.
  void clear() => emit(TranslatorState(history: state.history));

  Future<void> delete(Translation translation) async {
    await _translations.delete(translation.id);
    if (isClosed) return;
    emit(TranslatorState(
      current: state.current?.id == translation.id ? null : state.current,
      history: _translations.history(),
    ));
  }
}
