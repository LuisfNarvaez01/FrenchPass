import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  const TranslatorState({
    this.current,
    this.history = const [],
    this.loading = false,
    this.error,
  });

  @override
  List<Object?> get props => [current?.id, history.length, loading, error];
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

  TranslatorCubit({
    required TranslatorRepository translations,
    required TutorRepository tutor,
    required TutorReviewService gemini,
  })  : _translations = translations,
        _tutor = tutor,
        _gemini = gemini,
        super(TranslatorState(history: translations.history()));

  Future<void> translate(String text) async {
    final source = text.trim();
    if (source.isEmpty || state.loading) return;

    final saved = _translations.find(source);
    if (saved != null) {
      emit(TranslatorState(current: saved, history: state.history));
      return;
    }

    final key = await _tutor.apiKey();
    if (isClosed) return;
    if (key == null) {
      emit(TranslatorState(
        history: state.history,
        error: 'Añade tu clave de Gemini en Ajustes para usar el traductor.',
      ));
      return;
    }

    emit(TranslatorState(history: state.history, loading: true));
    Translation? result;
    String? error;
    try {
      result = await _gemini.explainTranslation(
        apiKey: key,
        text: source,
        levelEstimate: _tutor.profile().levelEstimate,
      );
    } on GeminiApiException catch (e) {
      error = e.isRateLimited
          ? 'Gemini está saturado ahora mismo. Prueba en un minuto.'
          : e.isAuth
              ? 'Tu clave de Gemini no funciona. Revísala en Ajustes.'
              : 'No pude traducir esto. Inténtalo otra vez.';
    } catch (e) {
      debugPrint('TranslatorCubit.translate failed: $e');
      error = 'No pude traducir esto. Revisa tu conexión.';
    }
    if (isClosed) return;

    if (result == null) {
      emit(TranslatorState(history: state.history, error: error));
      return;
    }
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
