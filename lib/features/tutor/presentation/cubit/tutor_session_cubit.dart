import 'dart:async';
import 'dart:typed_data' show BytesBuilder;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:french_pass/core/ai/ai_backend.dart';
import 'package:french_pass/features/tutor/data/gemini_live_client.dart';
import 'package:french_pass/features/tutor/data/tutor_audio.dart';
import 'package:french_pass/features/tutor/data/tutor_prompt.dart';
import 'package:french_pass/features/tutor/data/tutor_repository.dart';
import 'package:french_pass/features/tutor/data/tutor_review_service.dart';
import 'package:french_pass/features/tutor/domain/learner_profile.dart';
import 'package:french_pass/features/tutor/domain/lesson.dart';
import 'package:french_pass/features/tutor/domain/saved_session.dart';
import 'package:french_pass/features/tutor/domain/tutor_message.dart';

enum TutorPhase {
  connecting,

  /// Waiting for the tutor to answer.
  thinking,
  tutorSpeaking,

  /// The mic is open and streaming.
  listening,
  ended,
  error,
}

class TutorSessionState extends Equatable {
  final TutorPhase phase;
  final List<TutorMessage> messages;
  final double micLevel;
  final bool muted;
  final bool goalReached;
  final String? error;

  /// End-of-lesson review: null while running, or if it failed.
  final LessonReview? review;
  final bool reviewing;
  final bool reviewFailed;

  /// Spanish translations of tutor lines, by message index. A null value
  /// means the translation is loading.
  final Map<int, String?> translations;

  /// Tutor lines whose audio was kept and can be replayed.
  final Set<int> replayable;

  /// Id of the saved conversation once the lesson has ended, so the summary
  /// can open it for review.
  final String? savedSessionId;

  const TutorSessionState({
    this.phase = TutorPhase.connecting,
    this.messages = const [],
    this.micLevel = 0,
    this.muted = false,
    this.goalReached = false,
    this.error,
    this.review,
    this.reviewing = false,
    this.reviewFailed = false,
    this.translations = const {},
    this.replayable = const {},
    this.savedSessionId,
  });

  bool get isLive =>
      phase == TutorPhase.thinking ||
      phase == TutorPhase.tutorSpeaking ||
      phase == TutorPhase.listening;

  int get correctionCount => messages
      .whereType<LearnerLine>()
      .expand((l) => l.notes)
      .where((n) => n is CorrectionNote || n is PronunciationNote)
      .length;

  TutorSessionState copyWith({
    TutorPhase? phase,
    List<TutorMessage>? messages,
    double? micLevel,
    bool? muted,
    bool? goalReached,
    String? error,
    LessonReview? review,
    bool? reviewing,
    bool? reviewFailed,
    Map<int, String?>? translations,
    Set<int>? replayable,
    String? savedSessionId,
  }) =>
      TutorSessionState(
        phase: phase ?? this.phase,
        messages: messages ?? this.messages,
        micLevel: micLevel ?? this.micLevel,
        muted: muted ?? this.muted,
        goalReached: goalReached ?? this.goalReached,
        error: error ?? this.error,
        review: review ?? this.review,
        reviewing: reviewing ?? this.reviewing,
        reviewFailed: reviewFailed ?? this.reviewFailed,
        translations: translations ?? this.translations,
        replayable: replayable ?? this.replayable,
        savedSessionId: savedSessionId ?? this.savedSessionId,
      );

  @override
  List<Object?> get props => [
        phase,
        messages,
        micLevel,
        muted,
        goalReached,
        error,
        review,
        reviewing,
        reviewFailed,
        translations,
        replayable,
        savedSessionId,
      ];
}

/// Runs one live lesson: opens the Gemini Live session, gates the mic so the
/// tutor never hears itself, turns transcripts and tool calls into the chat,
/// and reviews the lesson at the end.
class TutorSessionCubit extends Cubit<TutorSessionState> {
  final Lesson lesson;
  final TutorRepository _repo;
  final TutorReviewService _reviewer;
  final TutorAudio _audio;
  final GeminiLiveClient _client;

  TutorSessionCubit({
    required this.lesson,
    required TutorRepository repository,
    required TutorReviewService reviewer,
    required TutorAudio audio,
    required GeminiLiveClient client,
  })  : _repo = repository,
        _reviewer = reviewer,
        _audio = audio,
        _client = client,
        super(const TutorSessionState());

  StreamSubscription<LiveEvent>? _eventSub;
  StreamSubscription<void>? _drainSub;
  LearnerProfile _profile = LearnerProfile.empty;

  /// The server finished its turn; once the audio queue drains, the mic
  /// opens again.
  bool _turnComplete = true;

  /// After the learner cuts the tutor off, the rest of that turn's audio is
  /// still in flight; it is dropped until the turn completes.
  bool _dropAudio = false;

  /// Whether new transcript fragments continue the last bubble or start one.
  bool _learnerOpen = false;
  bool _tutorOpen = false;

  bool _ending = false;

  /// The audio of the tutor turn in progress, and of finished tutor lines
  /// (by message index) so the learner can hear them again.
  BytesBuilder _turnAudio = BytesBuilder(copy: false);
  final Map<int, Uint8List> _lineAudio = {};
  static const _maxStoredLines = 20;
  DateTime _lastLevelEmit = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> start() async {
    if (!AiBackend.isReady) {
      _fail(const AiException(unavailable: true).messageEs);
      return;
    }
    if (!await _audio.requestMicrophone()) {
      _fail('Necesito permiso para usar el micrófono. Actívalo en los '
          'ajustes de Android para hablar con el tutor.');
      return;
    }

    emit(state.copyWith(phase: TutorPhase.connecting));
    _profile = _repo.profile();
    _eventSub = _client.events.listen(_onEvent);
    _drainSub = _audio.playbackDrained.listen((_) => _onDrained());

    try {
      await _connect(GeminiModels.live);
    } on LiveConnectException catch (e) {
      if (!e.modelRejected) {
        _fail(_connectError(e));
        return;
      }
      // The preview model was refused (withdrawn or renamed): retry once
      // on the fallback before giving up.
      try {
        await _connect(GeminiModels.liveFallback);
      } on LiveConnectException catch (e2) {
        _fail(_connectError(e2));
        return;
      }
    }

    try {
      await _audio.startMic(onChunk: _onMicChunk, onLevel: _onMicLevel);
    } catch (e) {
      debugPrint('TutorSessionCubit.startMic: $e');
      _fail('No pude abrir el micrófono.');
      return;
    }

    _turnComplete = false;
    emit(state.copyWith(phase: TutorPhase.thinking));
    _client.sendText(TutorPrompt.startRequest);
  }

  Future<void> _connect(String model) => _client.connect(
        model: model,
        voice: _repo.voice,
        systemInstruction: TutorPrompt.systemInstruction(lesson, _profile),
        tools: TutorPrompt.tools(),
      );

  String _connectError(LiveConnectException e) {
    final ai = e.asAiException;
    return ai.rateLimited || ai.unavailable
        ? ai.messageEs
        : 'No pude conectar con el tutor. Revisa tu conexión a internet.';
  }

  // ── Mic ──────────────────────────────────────────────────────────────────
  void _onMicChunk(Uint8List pcm) {
    // Gate: while the tutor talks the mic stays closed, so it can never
    // answer itself through the speaker.
    if (state.phase == TutorPhase.tutorSpeaking || state.muted) return;
    if (!state.isLive) return;
    _client.sendAudio(pcm);
  }

  void _onMicLevel(double level) {
    if (state.phase != TutorPhase.listening || state.muted) return;
    final now = DateTime.now();
    if (now.difference(_lastLevelEmit).inMilliseconds < 90) return;
    _lastLevelEmit = now;
    emit(state.copyWith(micLevel: level));
  }

  // ── Server events ────────────────────────────────────────────────────────
  void _onEvent(LiveEvent event) {
    if (isClosed || _ending) return;
    switch (event) {
      case LiveAudio(:final pcm):
        if (_dropAudio) return;
        _learnerOpen = false;
        _turnAudio.add(pcm);
        unawaited(_audio.play(pcm));
        if (state.phase != TutorPhase.tutorSpeaking) {
          emit(state.copyWith(phase: TutorPhase.tutorSpeaking, micLevel: 0));
        }
      case LiveOutputTranscript(:final text):
        if (_dropAudio) return;
        _learnerOpen = false;
        _appendTutor(text);
      case LiveInputTranscript(:final text):
        _tutorOpen = false;
        _appendLearner(text);
      case LiveToolCalls(:final calls):
        _client.sendToolResponses(calls);
        for (final call in calls) {
          _handleTool(call);
        }
      case LiveTurnComplete():
        _keepTurnAudio();
        _turnComplete = true;
        _dropAudio = false;
        _tutorOpen = false;
        if (!_audio.isPlaying) _onDrained();
      case LiveInterrupted():
        unawaited(_audio.stopPlayback());
        _tutorOpen = false;
        _turnComplete = true;
        _enterListening();
      case LiveGoAway():
        break; // The close that follows ends the lesson.
      case LiveClosed():
        if (state.isLive) {
          unawaited(endLesson(
              note: 'La sesión con el tutor se cerró. Puedes empezar otra '
                  'cuando quieras.'));
        }
      case LiveSetupComplete():
        break;
    }
  }

  void _keepTurnAudio() {
    final audio = _turnAudio.takeBytes();
    _turnAudio = BytesBuilder(copy: false);
    if (audio.isEmpty) return;
    final i = state.messages.lastIndexWhere((m) => m is TutorLine);
    if (i < 0) return;
    _lineAudio[i] = audio;
    // Bounded: only the most recent lines keep their audio.
    while (_lineAudio.length > _maxStoredLines) {
      _lineAudio.remove(_lineAudio.keys.reduce((a, b) => a < b ? a : b));
    }
    emit(state.copyWith(replayable: _lineAudio.keys.toSet()));
  }

  void _onDrained() {
    if (isClosed || _ending || !_turnComplete) return;
    if (state.goalReached) {
      // Let the tutor's goodbye play out, then wrap up.
      unawaited(endLesson());
      return;
    }
    _enterListening();
  }

  void _enterListening() {
    if (!state.isLive) return;
    emit(state.copyWith(phase: TutorPhase.listening));
  }

  void _appendTutor(String fragment) {
    final messages = [...state.messages];
    if (_tutorOpen && messages.isNotEmpty && messages.last is TutorLine) {
      messages[messages.length - 1] =
          (messages.last as TutorLine).append(fragment);
    } else {
      messages.add(TutorLine(fragment.trim()));
      _tutorOpen = true;
    }
    emit(state.copyWith(messages: messages));
  }

  void _appendLearner(String fragment) {
    final messages = [...state.messages];
    final i = _lastLearnerIndex(messages);
    if (_learnerOpen && i == messages.length - 1 && i >= 0) {
      messages[i] = (messages[i] as LearnerLine).append(fragment);
    } else {
      messages.add(LearnerLine(fragment.trim()));
      _learnerOpen = true;
    }
    emit(state.copyWith(messages: messages));
  }

  static int _lastLearnerIndex(List<TutorMessage> messages) {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i] is LearnerLine) return i;
    }
    return -1;
  }

  void _handleTool(LiveToolCall call) {
    String arg(String name) => (call.args[name] as String? ?? '').trim();

    final TutorNote? note = switch (call.name) {
      TutorPrompt.toolShowCorrection when arg('better_fr').isNotEmpty =>
        CorrectionNote(
          originalFr: arg('original_fr').isEmpty ? null : arg('original_fr'),
          betterFr: arg('better_fr'),
          explanationEs: arg('explanation_es'),
        ),
      TutorPrompt.toolShowPronunciation when arg('word_fr').isNotEmpty =>
        PronunciationNote(wordFr: arg('word_fr'), tipEs: arg('tip_es')),
      TutorPrompt.toolShowHint when arg('phrase_fr').isNotEmpty => HintNote(
          phraseFr: arg('phrase_fr'),
          translationEs: arg('translation_es'),
        ),
      _ => null,
    };

    if (call.name == TutorPrompt.toolCompleteLesson) {
      emit(state.copyWith(goalReached: true));
      return;
    }
    if (note == null) return;

    final messages = [...state.messages];
    final i = _lastLearnerIndex(messages);
    if (note is HintNote && (i < 0 || i != messages.length - 1)) {
      // A hint asked for with the help button belongs to the learner's
      // *next* line, which does not exist yet: start it empty.
      messages.add(LearnerLine('', [note]));
      _learnerOpen = true;
    } else if (i >= 0) {
      messages[i] = (messages[i] as LearnerLine).withNote(note);
    } else {
      messages.add(LearnerLine('', [note]));
    }
    emit(state.copyWith(messages: messages));
  }

  // ── Learner actions ──────────────────────────────────────────────────────
  /// "No sé cómo decirlo".
  void askForHelp() {
    if (!state.isLive) return;
    _turnComplete = false;
    emit(state.copyWith(phase: TutorPhase.thinking));
    _client.sendText(TutorPrompt.helpRequest);
  }

  /// Cuts the tutor off so the learner can speak.
  Future<void> interrupt() async {
    if (state.phase != TutorPhase.tutorSpeaking) return;
    _dropAudio = !_turnComplete;
    _tutorOpen = false;
    await _audio.stopPlayback();
    _turnComplete = true;
    _enterListening();
  }

  /// Plays a tutor line again. Only while the learner has the floor, so a
  /// replay never talks over the tutor.
  Future<void> replayLine(int index) async {
    final audio = _lineAudio[index];
    if (audio == null || state.phase != TutorPhase.listening) return;
    _turnComplete = true;
    emit(state.copyWith(phase: TutorPhase.tutorSpeaking, micLevel: 0));
    await _audio.play(audio);
  }

  /// "¿Qué ha dicho?": translates a tutor line into Spanish.
  Future<void> translateLine(int index) async {
    if (index >= state.messages.length) return;
    if (state.translations.containsKey(index)) return;
    final line = state.messages[index];
    if (line is! TutorLine || line.text.trim().isEmpty) return;

    emit(state.copyWith(translations: {...state.translations, index: null}));
    String? result;
    try {
      result = await _reviewer.translate(french: line.text);
    } catch (e) {
      debugPrint('translateLine failed: $e');
    }
    if (isClosed) return;
    final next = {...state.translations};
    if (result == null || result.isEmpty) {
      next.remove(index); // Let the learner try again.
    } else {
      next[index] = result;
    }
    emit(state.copyWith(translations: next));
  }

  void toggleMute() {
    emit(state.copyWith(muted: !state.muted, micLevel: 0));
  }

  /// Ends the conversation and reviews it.
  Future<void> endLesson({String? note}) async {
    if (_ending) return;
    _ending = true;
    await _drainSub?.cancel();
    await _eventSub?.cancel();
    await _audio.stopMic();
    await _audio.stopPlayback();
    await _client.close();

    if (isClosed) return;
    final spoke = state.messages
        .whereType<LearnerLine>()
        .any((l) => l.text.trim().isNotEmpty);

    // Kept before the review runs, so the conversation survives even if the
    // review fails or the learner leaves while it loads.
    final now = DateTime.now();
    var saved = SavedSession(
      id: '${now.millisecondsSinceEpoch}',
      lessonId: lesson.id,
      date: now,
      goalReached: state.goalReached,
      messages: [
        for (final m in state.messages)
          if (m.text.trim().isNotEmpty ||
              m is LearnerLine && m.notes.isNotEmpty)
            m,
      ],
    );
    final hasConversation = saved.spokenLines > 0;
    if (hasConversation) await _repo.saveSession(saved);

    if (isClosed) return;
    emit(state.copyWith(
      phase: TutorPhase.ended,
      micLevel: 0,
      error: note,
      reviewing: spoke,
      savedSessionId: hasConversation ? saved.id : null,
    ));
    if (!spoke) return;

    LessonReview? review;
    try {
      review = await _reviewer.review(
        lesson: lesson,
        transcript: state.messages,
        previous: _profile,
        goalReached: state.goalReached,
      );
      await _repo.saveProfile(review.profile);
    } catch (e) {
      debugPrint('TutorSessionCubit review failed: $e');
    }

    if (review != null && review.summaryEs.isNotEmpty) {
      saved = SavedSession(
        id: saved.id,
        lessonId: saved.lessonId,
        date: saved.date,
        goalReached: saved.goalReached,
        messages: saved.messages,
        summaryEs: review.summaryEs,
      );
      await _repo.saveSession(saved);
    }

    await _repo.addRecord(LessonRecord(
      lessonId: lesson.id,
      date: DateTime.now(),
      goalReached: state.goalReached,
      corrections: state.correctionCount,
      summaryEs: review?.summaryEs ?? '',
    ));
    if (isClosed) return;
    emit(state.copyWith(
      reviewing: false,
      review: review,
      reviewFailed: review == null,
    ));
  }

  void _fail(String message) {
    if (isClosed) return;
    emit(state.copyWith(phase: TutorPhase.error, error: message));
  }

  @override
  Future<void> close() async {
    _ending = true;
    await _drainSub?.cancel();
    await _eventSub?.cancel();
    await _audio.stopMic();
    await _audio.stopPlayback();
    await _client.close();
    return super.close();
  }
}
