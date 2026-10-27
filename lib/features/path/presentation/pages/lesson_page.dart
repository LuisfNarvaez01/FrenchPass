import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/sound_service.dart';
import 'package:french_pass/core/services/speech_service.dart';
import 'package:french_pass/core/services/tts_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/mascot.dart';
import 'package:french_pass/features/path/data/path_repository.dart';
import 'package:french_pass/features/path/domain/journey.dart';
import 'package:french_pass/features/path/domain/lesson_builder.dart';
import 'package:french_pass/features/practice/data/learning_content.dart';
import 'package:french_pass/features/practice/presentation/widgets/practice_widgets.dart';
import 'package:french_pass/features/premium/data/usage_service.dart';
import 'package:french_pass/features/pronunciation/domain/entities/pronunciation_result.dart';
import 'package:french_pass/features/pronunciation/domain/usecases/pronunciation_scorer.dart';
import 'package:french_pass/features/tutor/presentation/widgets/phrase_practice.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';

/// Plays one stop of the journey, screen by screen, and records it.
///
/// [stopId] is a stop, or [mistakesId] for the Premium review of what the
/// learner got wrong.
class LessonPage extends StatefulWidget {
  final String stopId;
  const LessonPage({super.key, required this.stopId});

  static const mistakesId = 'errores';

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  final _path = getIt<PathRepository>();

  /// Share of the stop to get right to pass it.
  static const passMark = 0.8;
  static const hintsPerLesson = 3;

  PathStop? _stop;
  List<LessonStep> _steps = const [];
  int _index = 0;

  /// Scored answers, and the credit earned on them: 1 on the first try,
  /// 0.5 when a retry or a second pick puts it right.
  int _scored = 0;
  double _credit = 0;
  final Set<String> _missed = {};
  bool _finished = false;

  /// Indexes of steps that are second chances at a missed one.
  final Set<int> _retries = {};

  /// Words already shown again before their retry.
  final Set<String> _relearned = {};

  /// Where retries go: before the closing conversation.
  int _tail = 0;

  int _hints = hintsPerLesson;

  /// Bumped when a hint is used, so the step on screen applies it.
  int _hintTick = 0;
  bool _hintUsedHere = false;
  bool _answeredHere = false;

  /// Why the stop can't be played now, if it can't.
  _Block? _block;

  bool get _isMistakes => widget.stopId == LessonPage.mistakesId;

  bool get _premium =>
      getIt.isRegistered<UsageService>() && getIt<UsageService>().isPremium;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  void _prepare() {
    if (_isMistakes) {
      final items =
          _path.mistakes.map(_path.itemFor).whereType<PathItem>().toList();
      if (!_premium) {
        _block = _Block.premiumMistakes;
      } else if (items.isEmpty) {
        _block = _Block.noMistakes;
      } else {
        _start(LessonBuilder.questionsAbout(
            items.reversed.take(10).toList(), _path.stops));
      }
      return;
    }
    final stop = _path.byId(widget.stopId);
    _stop = stop;
    if (stop == null) {
      _block = _Block.missing;
    } else if (!_path.isOpen(stop)) {
      _block = _Block.locked;
    } else if (!_path.isDone(stop) && !_path.canStartNew(premium: _premium)) {
      _block = _Block.dailyLimit;
    } else {
      _start(LessonBuilder.build(stop, _path.stops));
    }
  }

  /// "Ahora no puedo hablar" leaves out speaking for a while, in this
  /// lesson and the next ones.
  static DateTime? _quietUntil;

  bool get _quiet =>
      _quietUntil != null && DateTime.now().isBefore(_quietUntil!);

  void _skipSpeaking() {
    _quietUntil = DateTime.now().add(const Duration(minutes: 15));
    final keep = <LessonStep>[];
    final retries = <int>{};
    var tail = _tail;
    for (final (i, s) in _steps.indexed) {
      if (i > _index && s is SpeakStep) {
        if (i < _tail) tail--;
        continue;
      }
      if (_retries.contains(i)) retries.add(keep.length);
      keep.add(s);
    }
    _steps = keep;
    _tail = tail;
    _retries
      ..clear()
      ..addAll(retries);
    _next();
  }

  void _start(List<LessonStep> steps) {
    if (_quiet) steps = [...steps.where((s) => s is! SpeakStep)];
    _steps = steps;
    _index = 0;
    _scored = 0;
    _credit = 0;
    _missed.clear();
    _retries.clear();
    _relearned.clear();
    _hints = hintsPerLesson;
    _finished = false;
    _resetStep();
    var tail = steps.length;
    while (tail > 0 && steps[tail - 1] is DialogueStep) {
      tail--;
    }
    _tail = tail;
  }

  void _resetStep() {
    _hintTick = 0;
    _hintUsedHere = false;
    _answeredHere = false;
  }

  /// One answer to the step on screen. A miss on a first try comes back
  /// before the closing conversation, after another look at the word.
  void _answer(bool right, {String? about}) {
    final retry = _retries.contains(_index);
    setState(() {
      _answeredHere = true;
      if (retry) {
        if (right) _credit += 0.5;
        return;
      }
      _scored++;
      if (right) {
        _credit += 1;
        if (about != null && _isMistakes) _path.clearMistake(about);
      } else {
        if (about != null) _missed.add(about);
        _queueRetry(_steps[_index], about);
      }
    });
  }

  /// A conversation turn or a matching round: no retry, half credit when
  /// it took more than one try.
  void _scoreOnce(bool clean) {
    setState(() {
      _scored++;
      _credit += clean ? 1 : 0.5;
      _hintUsedHere = false;
    });
  }

  void _queueRetry(LessonStep step, String? about) {
    if (step is! ChoiceStep &&
        step is! ListenStep &&
        step is! OrderStep &&
        step is! SpeakStep) {
      return;
    }
    final item = about == null ? null : _itemFor(about);
    final at = _tail > _index ? _tail : _index + 1;
    final add = [
      if (item != null && _relearned.add(item.fr)) LearnStep(item, again: true),
      LessonBuilder.again(step),
    ];
    _steps = [..._steps]..insertAll(at, add);
    _retries.add(at + add.length - 1);
    _tail = at + add.length;
  }

  PathItem? _itemFor(String fr) {
    for (final i in _stop?.items ?? const <PathItem>[]) {
      if (i.fr == fr) return i;
    }
    return _path.itemFor(fr);
  }

  void _next() {
    if (_index < _steps.length - 1) {
      setState(() {
        _index++;
        _resetStep();
      });
    } else {
      _finish();
    }
  }

  // ── Hints ────────────────────────────────────────────────────────────────

  String? _hintLabel(LessonStep step) => switch (step) {
        ChoiceStep() => 'Quitar dos opciones',
        ListenStep() => 'Ver lo que dice',
        OrderStep() => 'Poner una palabra',
        MatchStep() => 'Unir un par',
        SpeakStep() => 'Oírlo por partes',
        DialogueStep() => 'Ayuda en tu turno',
        LearnStep() => null,
      };

  bool _canHint(LessonStep step) =>
      _hints > 0 &&
      !_answeredHere &&
      !_hintUsedHere &&
      _hintLabel(step) != null;

  /// A hint costs nothing in the score, but the word comes back in the
  /// review of mistakes.
  void _useHint() {
    final step = _steps[_index];
    final about = switch (step) {
      ChoiceStep(:final about) => about,
      ListenStep(:final fr) => fr,
      SpeakStep(:final fr) => fr,
      _ => null,
    };
    setState(() {
      _hints--;
      _hintTick++;
      _hintUsedHere = true;
      if (about != null) _missed.add(about);
    });
  }

  /// The two wrong options a hint takes away.
  Set<int> _hidden(List<String> options, int answer) {
    if (_hintTick == 0) return const {};
    return {
      for (var i = 0; i < options.length; i++)
        if (i != answer) i,
    }.take(2).toSet();
  }

  Widget? _hintBar(LessonStep step) {
    final label = _hintLabel(step);
    if (label == null) return null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.page - Insets.sm),
      child: Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _canHint(step) ? _useHint : null,
          icon: const Icon(Icons.lightbulb_outline_rounded, size: 18),
          label: Text('$label · $_hints'),
        ),
      ),
    );
  }

  double get _ratio => _scored == 0 ? 1 : _credit / _scored;

  /// Every stop is passed at 80 %; the review of mistakes always counts.
  bool get _passed => _stop == null || _ratio >= passMark;

  Future<void> _finish() async {
    for (final fr in _missed) {
      await _path.addMistake(fr);
    }
    final stop = _stop;
    if (stop != null && _passed) await _path.complete(stop);
    await getIt<ProgressRepository>()
        .recordPractice(PracticeKind.lesson, count: _scored.clamp(1, 30));
    if (mounted) setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isMistakes ? 'Tus errores' : (_stop?.titleEs ?? 'Lección');
    if (_block case final block?) {
      return PracticeScaffold(title: title, child: _BlockView(block: block));
    }
    if (_finished) {
      return PracticeScaffold(
        title: title,
        child: _Finished(
          stop: _stop,
          percent: (_ratio * 100).round(),
          passed: _passed,
          onRetry: () =>
              setState(() => _start(LessonBuilder.build(_stop!, _path.stops))),
        ),
      );
    }
    final step = _steps[_index];
    final isLast = _index == _steps.length - 1;
    return PracticeScaffold(
      title: title,
      progress: _index / _steps.length,
      toolbar: _hintBar(step),
      child: KeyedSubtree(
        key: ValueKey(_index),
        child: switch (step) {
          LearnStep(:final item, :final again) =>
            _LearnView(item: item, again: again, onNext: _next),
          ChoiceStep() => ChoiceQuestion(
              item: ChoiceItem(
                prompt: step.prompt,
                options: step.options,
                answer: step.answer,
                why: step.why,
              ),
              optionsAreFrench: step.french,
              hidden: _hidden(step.options, step.answer),
              isLast: isLast,
              onAnswered: (right) => _answer(right, about: step.about),
              onNext: _next,
            ),
          ListenStep() => ChoiceQuestion(
              item: ChoiceItem(
                prompt: '¿Qué escuchaste?',
                options: step.options,
                answer: step.answer,
              ),
              header: _ListenHeader(text: step.fr, reveal: _hintTick > 0),
              isLast: isLast,
              onAnswered: (right) => _answer(right, about: step.fr),
              onNext: _next,
            ),
          SpeakStep() => _SpeakView(
              step: step,
              hint: _hintTick > 0,
              onAnswered: (right) => _answer(right, about: step.fr),
              onNext: _next,
              onSkip: _skipSpeaking,
            ),
          MatchStep() => _MatchView(
              step: step,
              hintTick: _hintTick,
              onDone: (clean) {
                _scoreOnce(clean);
                _next();
              },
            ),
          OrderStep() => _OrderView(
              step: step,
              hintTick: _hintTick,
              onAnswered: (right) => _answer(right),
              onNext: _next,
            ),
          DialogueStep() => _DialogueView(
              step: step,
              hintTick: _hintTick,
              onTurn: _scoreOnce,
              onDone: _next,
            ),
        },
      ),
    );
  }
}

enum _Block { missing, locked, dailyLimit, premiumMistakes, noMistakes }

class _BlockView extends StatelessWidget {
  final _Block block;
  const _BlockView({required this.block});

  @override
  Widget build(BuildContext context) {
    final (title, message, premium) = switch (block) {
      _Block.missing => (
          'Esta parada no existe',
          'Vuelve al viaje y elige otra.',
          false
        ),
      _Block.locked => (
          'Todavía no',
          'Termina antes las paradas anteriores del viaje.',
          false
        ),
      _Block.dailyLimit => (
          'Ya hiciste tus ${PathRepository.freeStopsPerDay} lecciones de hoy',
          'Mañana te esperan más. Mientras tanto puedes repasar, practicar '
              'o hablar con el tutor. Con Premium avanzas sin límite.',
          true
        ),
      _Block.premiumMistakes => (
          'Tus errores, con Premium',
          'Premium guarda cada palabra que fallas en las lecciones y te la '
              'repasa hasta que la domines.',
          true
        ),
      _Block.noMistakes => (
          'Sin errores pendientes',
          'Cuando falles algo en una lección, aparecerá aquí para repasarlo.',
          false
        ),
    };
    return EmptyState(
      icon: Icons.lock_outline_rounded,
      mascot: true,
      title: title,
      message: message,
      actionLabel: premium ? 'Ver Premium' : 'Volver',
      onAction: premium
          ? () => context.pushReplacement('/premium')
          : () => Navigator.of(context).maybePop(),
    );
  }
}

/// A new word: heard as soon as it appears, with its meaning and example.
class _LearnView extends StatefulWidget {
  final PathItem item;

  /// A second look at a missed word, right before its retry.
  final bool again;
  final VoidCallback onNext;
  const _LearnView(
      {required this.item, this.again = false, required this.onNext});

  @override
  State<_LearnView> createState() => _LearnViewState();
}

class _LearnViewState extends State<_LearnView> {
  @override
  void initState() {
    super.initState();
    if (getIt.isRegistered<TtsService>()) {
      getIt<TtsService>().speak(widget.item.fr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final item = widget.item;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Insets.page, Insets.xl, Insets.page, Insets.xxxl),
      children: [
        Text(widget.again ? 'LA REPASAMOS: TE COSTÓ ANTES' : 'PALABRA NUEVA',
            style: AppTheme.eyebrow(context)),
        const SizedBox(height: Insets.lg),
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(item.fr, style: AppTheme.french(context, size: 40)),
              ),
            ),
            SpeakButton(text: item.fr, size: 52),
          ],
        ),
        if (item.ipa.isNotEmpty)
          Text(item.ipa, style: AppTheme.ipa(context, size: 18)),
        const SizedBox(height: Insets.md),
        Text(item.es, style: context.texts.titleLarge?.copyWith(fontSize: 20)),
        if (item.exampleFr.isNotEmpty) ...[
          const SizedBox(height: Insets.xl),
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.exampleFr,
                          style: context.texts.bodyLarge?.copyWith(
                              color: p.textPrimary,
                              fontStyle: FontStyle.italic)),
                      const SizedBox(height: 2),
                      Text(item.exampleEs, style: context.texts.bodySmall),
                    ],
                  ),
                ),
                SpeakButton(text: item.exampleFr, size: 40),
              ],
            ),
          ),
        ],
        const SizedBox(height: Insets.xxl),
        ElevatedButton(
          onPressed: widget.onNext,
          style:
              ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Entendido'),
        ),
      ],
    ).animate().fadeIn(duration: Motion.base).moveY(begin: 8, end: 0);
  }
}

/// Plays the French once on arrival; the button repeats it.
class _ListenHeader extends StatefulWidget {
  final String text;

  /// A hint: the French is written out.
  final bool reveal;
  const _ListenHeader({required this.text, this.reveal = false});

  @override
  State<_ListenHeader> createState() => _ListenHeaderState();
}

class _ListenHeaderState extends State<_ListenHeader> {
  @override
  void initState() {
    super.initState();
    if (getIt.isRegistered<TtsService>()) {
      getIt<TtsService>().speak(widget.text);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SpeakButton(text: widget.text, size: 64),
              const SizedBox(width: Insets.md),
              SpeakButton(text: widget.text, size: 44, slow: true),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text('Escucha. El segundo botón lo dice despacio.',
                    style: context.texts.bodySmall),
              ),
            ],
          ),
          if (widget.reveal) ...[
            const SizedBox(height: Insets.md),
            Text('«${widget.text}»', style: AppTheme.french(context, size: 22))
                .animate()
                .fadeIn(duration: Motion.fast),
          ],
        ],
      );
}

/// Say the French aloud. Three tries; a clear one passes. Someone who
/// can't speak right now skips it without losing points.
class _SpeakView extends StatefulWidget {
  final SpeakStep step;

  /// A hint: the sounds are written out and read slowly, word by word.
  final bool hint;
  final ValueChanged<bool> onAnswered;
  final VoidCallback onNext;

  /// The learner can't speak right now: no speaking for a while.
  final VoidCallback onSkip;

  const _SpeakView({
    required this.step,
    this.hint = false,
    required this.onAnswered,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<_SpeakView> createState() => _SpeakViewState();
}

class _SpeakViewState extends State<_SpeakView> {
  static const tries = 3;

  int _attempts = 0;
  bool? _right;
  bool _noMic = false;

  @override
  void didUpdateWidget(_SpeakView old) {
    super.didUpdateWidget(old);
    if (widget.hint && !old.hint && getIt.isRegistered<TtsService>()) {
      final tts = getIt<TtsService>();
      tts.speakSequence(widget.step.fr.split(RegExp(r'\s+')),
          gap: const Duration(milliseconds: 350));
    }
  }

  void _scored(PronunciationResult result) {
    if (_right != null) return;
    _attempts++;
    if (result.isSuccess) {
      playSound(AppSound.correct);
      widget.onAnswered(true);
      setState(() => _right = true);
    } else if (_attempts >= tries) {
      playSound(AppSound.wrong);
      widget.onAnswered(false);
      setState(() => _right = false);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final done = _right != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Insets.page, Insets.lg, Insets.page, Insets.xxxl),
      children: [
        Text('Dilo en voz alta', style: context.texts.headlineSmall),
        const SizedBox(height: Insets.xs),
        Text('«${step.es}»', style: context.texts.bodyMedium),
        const SizedBox(height: Insets.xl),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.fr, style: AppTheme.french(context, size: 26)),
                    if (widget.hint && step.ipa.isNotEmpty)
                      Text(step.ipa, style: AppTheme.ipa(context, size: 16)),
                  ],
                ),
              ),
              SpeakButton(text: step.fr, size: 44),
              const SizedBox(width: Insets.sm),
              SpeakButton(text: step.fr, size: 36, slow: true),
            ],
          ),
        ),
        const SizedBox(height: Insets.xl),
        if (!done && !_noMic) ...[
          PhrasePractice(
            target: step.fr,
            onResult: _scored,
            onUnavailable: () => setState(() => _noMic = true),
          ),
          if (_attempts > 0) ...[
            const SizedBox(height: Insets.sm),
            Text('Intento $_attempts de $tries. Escúchalo y vuelve a probar.',
                style: context.texts.bodySmall),
          ],
          const SizedBox(height: Insets.lg),
          TextButton(
            onPressed: widget.onSkip,
            child: const Text('Ahora no puedo hablar'),
          ),
        ],
        if (_noMic && !done) ...[
          Text(
            'No puedo usar el micrófono en este teléfono. Puedes seguir sin '
            'hablar; este ejercicio no cuenta.',
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: Insets.lg),
          ElevatedButton(
            onPressed: widget.onSkip,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            child: const Text('Seguir'),
          ),
        ],
        if (done) ...[
          FeedbackBanner(
            right: _right!,
            title: _right! ? 'Se te entiende bien' : 'Lo repetimos al final',
            detail:
                _right! ? '' : 'Escúchalo despacio y fíjate en cada sonido.',
            speak: step.fr,
          ),
          const SizedBox(height: Insets.lg),
          ElevatedButton(
            onPressed: widget.onNext,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            child: const Text('Siguiente'),
          ),
        ],
      ],
    );
  }
}

/// French on the left, Spanish on the right: tap one of each to pair them.
class _MatchView extends StatefulWidget {
  final MatchStep step;

  /// Bumped by a hint: one pair is made for the learner.
  final int hintTick;

  /// Called once every pair is made; true when no wrong pair was tried.
  final ValueChanged<bool> onDone;
  const _MatchView(
      {required this.step, this.hintTick = 0, required this.onDone});

  @override
  State<_MatchView> createState() => _MatchViewState();
}

class _MatchViewState extends State<_MatchView> {
  late final List<String> _right = [for (final p in widget.step.pairs) p.$2]
    ..shuffle();
  final Set<int> _matched = {};
  int? _leftPick;
  String? _wrongRight;
  bool _clean = true;

  @override
  void didUpdateWidget(_MatchView old) {
    super.didUpdateWidget(old);
    if (widget.hintTick != old.hintTick) {
      final pairs = widget.step.pairs;
      for (var i = 0; i < pairs.length; i++) {
        if (!_matched.contains(i)) {
          _leftPick = i;
          _tapRight(pairs[i].$2);
          break;
        }
      }
    }
  }

  void _tapRight(String es) {
    final left = _leftPick;
    if (left == null) return;
    if (widget.step.pairs[left].$2 == es) {
      playSound(AppSound.correct);
      setState(() {
        _matched.add(left);
        _leftPick = null;
      });
      if (_matched.length == widget.step.pairs.length) {
        Future<void>.delayed(const Duration(milliseconds: 450), () {
          if (mounted) widget.onDone(_clean);
        });
      }
    } else {
      playSound(AppSound.wrong);
      setState(() {
        _clean = false;
        _wrongRight = es;
      });
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _wrongRight = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pairs = widget.step.pairs;
    Widget tile(String text,
        {required bool done,
        required bool picked,
        required bool wrong,
        required VoidCallback onTap,
        bool french = false}) {
      final bg = done
          ? p.good.withValues(alpha: 0.12)
          : wrong
              ? p.critical.withValues(alpha: 0.14)
              : picked
                  ? p.textPrimary
                  : p.surface;
      final fg = picked && !done ? p.bg : (done ? p.good : p.textPrimary);
      return AnimatedOpacity(
        duration: Motion.base,
        opacity: done ? 0.5 : 1,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.md),
          child: InkWell(
            onTap: done ? null : onTap,
            borderRadius: BorderRadius.circular(Radii.md),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(Insets.sm),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: french
                    ? AppTheme.french(context, size: 16).copyWith(color: fg)
                    : context.texts.bodyMedium?.copyWith(color: fg),
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Insets.page, Insets.lg, Insets.page, Insets.xxxl),
      children: [
        Text('Une cada palabra con su significado',
            style: context.texts.headlineSmall),
        const SizedBox(height: Insets.xl),
        for (var i = 0; i < pairs.length; i++) ...[
          Row(
            children: [
              Expanded(
                child: tile(
                  pairs[i].$1,
                  french: true,
                  done: _matched.contains(i),
                  picked: _leftPick == i,
                  wrong: false,
                  onTap: () => setState(() => _leftPick = i),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: tile(
                  _right[i],
                  done: _matched.any((m) => pairs[m].$2 == _right[i]),
                  picked: false,
                  wrong: _wrongRight == _right[i],
                  onTap: () => _tapRight(_right[i]),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
        ],
      ],
    );
  }
}

/// Build the French sentence from shuffled tiles.
class _OrderView extends StatefulWidget {
  final OrderStep step;

  /// Bumped by a hint: the next right word is put in place.
  final int hintTick;
  final ValueChanged<bool> onAnswered;
  final VoidCallback onNext;
  const _OrderView({
    required this.step,
    this.hintTick = 0,
    required this.onAnswered,
    required this.onNext,
  });

  @override
  State<_OrderView> createState() => _OrderViewState();
}

class _OrderViewState extends State<_OrderView> {
  late final List<(int, String)> _pool = [
    for (final (i, t) in widget.step.tiles.indexed) (i, t)
  ]..shuffle();
  final List<(int, String)> _built = [];
  bool? _right;

  @override
  void didUpdateWidget(_OrderView old) {
    super.didUpdateWidget(old);
    if (widget.hintTick != old.hintTick && _right == null) _placeNext();
  }

  /// Keeps the right start of the sentence, sends the rest back, and adds
  /// the next word.
  void _placeNext() {
    final tiles = widget.step.tiles;
    var keep = 0;
    while (keep < _built.length &&
        keep < tiles.length &&
        _built[keep].$2 == tiles[keep]) {
      keep++;
    }
    if (keep >= tiles.length) return;
    setState(() {
      _pool.addAll(_built.sublist(keep));
      _built.removeRange(keep, _built.length);
      final next = _pool.firstWhere((t) => t.$2 == tiles[keep]);
      _pool.remove(next);
      _built.add(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final checked = _right != null;
    Widget chip((int, String) t, VoidCallback? onTap) => Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md, vertical: Insets.md),
              child: Text(t.$2, style: AppTheme.french(context, size: 17)),
            ),
          ),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Insets.page, Insets.lg, Insets.page, Insets.xxxl),
      children: [
        Text('Ordena la frase', style: context.texts.headlineSmall),
        const SizedBox(height: Insets.xs),
        Text('«${widget.step.es}»', style: context.texts.bodyMedium),
        const SizedBox(height: Insets.xl),
        Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(Insets.sm),
          decoration: BoxDecoration(
            border:
                Border(bottom: BorderSide(color: p.borderStrong, width: 1.5)),
          ),
          child: Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              for (final t in _built)
                chip(
                    t,
                    checked
                        ? null
                        : () => setState(() {
                              _built.remove(t);
                              _pool.add(t);
                            })),
            ],
          ),
        ),
        const SizedBox(height: Insets.xl),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.sm,
          children: [
            for (final t in _pool)
              chip(
                  t,
                  checked
                      ? null
                      : () => setState(() {
                            _pool.remove(t);
                            _built.add(t);
                          })),
          ],
        ),
        const SizedBox(height: Insets.xl),
        if (checked) ...[
          FeedbackBanner(
            right: _right!,
            title: _right! ? 'Correcto' : 'Era: ${widget.step.fr}',
            speak: widget.step.fr,
          ),
          const SizedBox(height: Insets.lg),
          ElevatedButton(
            onPressed: widget.onNext,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            child: const Text('Siguiente'),
          ),
        ] else
          ElevatedButton(
            onPressed: _pool.isEmpty
                ? () {
                    final right =
                        _built.map((t) => t.$2).join(' ') == widget.step.fr;
                    widget.onAnswered(right);
                    setState(() => _right = right);
                  }
                : null,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            child: const Text('Comprobar'),
          ),
      ],
    );
  }
}

/// The micro-conversation: the other person's lines appear one by one,
/// read aloud; on the learner's turn they pick what to say.
class _DialogueView extends StatefulWidget {
  final DialogueStep step;

  /// Bumped by a hint: on this turn one wrong reply goes away and the
  /// meaning of the right one shows.
  final int hintTick;

  /// Each learner turn: right on the first try or not.
  final ValueChanged<bool> onTurn;
  final VoidCallback onDone;
  const _DialogueView({
    required this.step,
    this.hintTick = 0,
    required this.onTurn,
    required this.onDone,
  });

  @override
  State<_DialogueView> createState() => _DialogueViewState();
}

class _DialogueViewState extends State<_DialogueView> {
  int _shown = 0;
  final Set<int> _wrongPicks = {};
  bool _missedThisTurn = false;
  final _scroll = ScrollController();

  /// The turn a hint was used on.
  int? _hintTurn;

  bool _listening = false;
  String _partial = '';
  double _level = 0;

  /// What the microphone made of the last attempt, when it matched nothing.
  String? _heard;

  List<DialogueLine> get _lines => widget.step.lines;

  @override
  void initState() {
    super.initState();
    _advance();
  }

  @override
  void didUpdateWidget(_DialogueView old) {
    super.didUpdateWidget(old);
    if (widget.hintTick != old.hintTick && _shown < _lines.length) {
      final line = _lines[_shown];
      if (!line.isLearner) return;
      setState(() {
        _hintTurn = _shown;
        for (var i = 0; i < line.options.length; i++) {
          if (i != line.answer && !_wrongPicks.contains(i)) {
            _wrongPicks.add(i);
            break;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    if (_listening) getIt<SpeechService>().cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Says the reply instead of tapping it: what was heard is matched to
  /// the closest option.
  Future<void> _speak(DialogueLine line) async {
    final speech = getIt<SpeechService>();
    if (_listening) {
      await speech.stop();
      return;
    }
    await getIt<TtsService>().stop();
    setState(() {
      _listening = true;
      _partial = '';
      _heard = null;
    });
    final words = line.options[line.answer].split(RegExp(r'\s+')).length;
    final result = await speech.listenOnce(
      maxDuration: Duration(seconds: (4 + words * 0.8).clamp(6, 20).round()),
      onPartial: (t) {
        if (mounted) setState(() => _partial = t);
      },
      onLevel: (l) {
        if (mounted) setState(() => _level = l);
      },
    );
    if (!mounted) return;
    setState(() => _listening = false);
    switch (result.outcome) {
      case SpeechOutcome.ok:
        var best = -1;
        var bestScore = 0.0;
        for (final (i, option) in line.options.indexed) {
          if (_wrongPicks.contains(i)) continue;
          final score = PronunciationScorer.score(
                  targetWord: option, recognizedText: result.transcript)
              .overallScore;
          if (score > bestScore) {
            best = i;
            bestScore = score;
          }
        }
        if (best >= 0 && bestScore >= 0.6) {
          _pick(best);
        } else {
          setState(() => _heard = 'Escuché «${result.transcript}». Dilo otra '
              'vez o toca tu respuesta.');
        }
      case SpeechOutcome.permissionDenied:
        setState(() => _heard =
            'Necesito el micrófono. Actívalo en los ajustes de la app, o toca '
                'tu respuesta.');
      case SpeechOutcome.unavailable:
        setState(() => _heard = 'Este teléfono no reconoce voz en francés. '
            'Toca tu respuesta.');
      case SpeechOutcome.noMatch:
        setState(() => _heard = 'No te escuché. Acércate y dilo otra vez.');
      case SpeechOutcome.error:
        setState(() => _heard = 'Algo falló al escuchar. Inténtalo otra vez.');
    }
  }

  /// Shows the other person's lines up to the learner's next turn.
  void _advance() {
    Future<void> step() async {
      while (_shown < _lines.length && !_lines[_shown].isLearner) {
        final line = _lines[_shown];
        if (!mounted) return;
        setState(() => _shown++);
        _scrollDown();
        if (getIt.isRegistered<TtsService>()) {
          await getIt<TtsService>().speak(line.fr);
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
      if (mounted) setState(() {});
    }

    step();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: Motion.base, curve: Curves.easeOut);
      }
    });
  }

  void _pick(int option) {
    final line = _lines[_shown];
    if (option == line.answer) {
      playSound(AppSound.correct);
      widget.onTurn(!_missedThisTurn);
      setState(() {
        _shown++;
        _wrongPicks.clear();
        _missedThisTurn = false;
        _heard = null;
      });
      _scrollDown();
      _advance();
    } else {
      playSound(AppSound.wrong);
      setState(() {
        _wrongPicks.add(option);
        _missedThisTurn = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final done = _shown >= _lines.length;
    final turn = !done && _lines[_shown].isLearner ? _lines[_shown] : null;
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(
                Insets.page, Insets.lg, Insets.page, Insets.lg),
            children: [
              Text('Tu conversación', style: context.texts.headlineSmall),
              const SizedBox(height: Insets.lg),
              for (final line in _lines.take(_shown))
                _Bubble(line: line)
                    .animate()
                    .fadeIn(duration: Motion.fast)
                    .moveY(begin: 8, end: 0),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(
              Insets.page, Insets.md, Insets.page, Insets.lg),
          decoration: BoxDecoration(
            color: p.bgAlt,
            border: Border(top: BorderSide(color: p.border)),
          ),
          child: done
              ? SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onDone,
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    child: const Text('Continuar'),
                  ),
                )
              : turn == null
                  ? const SizedBox(
                      height: 52,
                      child: Center(child: MascotSticker(size: 44, tilt: 0)),
                    )
                  : ConstrainedBox(
                      constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.55),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('TU TURNO · DILO O TÓCALO',
                                style: AppTheme.eyebrow(context)),
                            if (_hintTurn == _shown && turn.es.isNotEmpty) ...[
                              const SizedBox(height: Insets.xs),
                              Text('Quieres decir: «${turn.es}»',
                                  style: context.texts.bodySmall),
                            ],
                            const SizedBox(height: Insets.sm),
                            MicPill(
                              listening: _listening,
                              level: _level,
                              compact: true,
                              label: _listening
                                  ? (_partial.isEmpty
                                      ? 'Te escucho…'
                                      : '« $_partial »')
                                  : 'Decirlo en voz alta',
                              onTap: () => _speak(turn),
                            ),
                            if (_heard case final heard?) ...[
                              const SizedBox(height: Insets.xs),
                              Text(heard,
                                  style: context.texts.bodySmall
                                      ?.copyWith(color: p.critical)),
                            ],
                            const SizedBox(height: Insets.sm),
                            for (final (i, option) in turn.options.indexed) ...[
                              OutlinedButton(
                                onPressed: _wrongPicks.contains(i)
                                    ? null
                                    : () => _pick(i),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  alignment: Alignment.centerLeft,
                                  side: BorderSide(
                                      color: _wrongPicks.contains(i)
                                          ? p.critical.withValues(alpha: 0.5)
                                          : p.border),
                                ),
                                child: Text(option,
                                    style: AppTheme.french(context, size: 16)
                                        .copyWith(
                                            color: _wrongPicks.contains(i)
                                                ? p.textMuted
                                                : p.textPrimary)),
                              ),
                              const SizedBox(height: Insets.sm),
                            ],
                          ],
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final DialogueLine line;
  const _Bubble({required this.line});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mine = line.isLearner;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          margin: const EdgeInsets.only(bottom: Insets.md),
          padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg, vertical: Insets.md),
          decoration: BoxDecoration(
            color: mine ? p.gold.withValues(alpha: 0.16) : p.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(Radii.lg),
              topRight: const Radius.circular(Radii.lg),
              bottomLeft: Radius.circular(mine ? Radii.lg : Insets.xs),
              bottomRight: Radius.circular(mine ? Insets.xs : Radii.lg),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                Text(line.who!.toUpperCase(), style: AppTheme.eyebrow(context)),
              Text(line.said, style: AppTheme.french(context, size: 17)),
              if (line.es.isNotEmpty)
                Text(line.es, style: context.texts.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// The end of a stop: the small win, or a retry below 80 %.
class _Finished extends StatelessWidget {
  final PathStop? stop;
  final int percent;
  final bool passed;
  final VoidCallback onRetry;

  const _Finished({
    required this.stop,
    required this.percent,
    required this.passed,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final s = stop;
    final title = !passed
        ? 'Casi'
        : switch (s?.kind) {
            StopKind.checkpoint => '¡Reto superado!',
            StopKind.review => 'Repaso hecho',
            StopKind.lesson => '¡Lección completada!',
            null => 'Repaso hecho',
          };
    return SoundOnMount(
      sound: passed ? AppSound.complete : AppSound.wrong,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            Insets.page, Insets.xl, Insets.page, Insets.xxxl),
        children: [
          Center(
            child: passed
                ? MascotCelebration(
                    size: 120,
                    caption:
                        s?.kind == StopKind.checkpoint ? 'Bravo !' : 'Bien !',
                  )
                : const MascotSticker(size: 120, pose: MascotPose.thinking),
          ),
          const SizedBox(height: Insets.xl),
          Text(title,
              textAlign: TextAlign.center, style: context.texts.headlineMedium),
          const SizedBox(height: Insets.xs),
          Text(
            passed
                ? (s != null && s.goalEs.isNotEmpty
                    ? '$percent % bien. Ya puedes: ${s.goalEs.toLowerCase()}.'
                    : '$percent % bien.')
                : '$percent % bien. Para pasar hace falta el 80 %. Repasa y '
                    'vuelve a intentarlo.',
            textAlign: TextAlign.center,
            style: context.texts.bodyMedium,
          ),
          if (s != null && s.items.isNotEmpty && passed) ...[
            const SizedBox(height: Insets.xl),
            RowGroup(
              children: [
                for (final item in s.items)
                  ListRow(
                    leading: SpeakButton(text: item.fr, size: 36),
                    title: item.fr,
                    detail: item.es,
                    trailing: const SizedBox.shrink(),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Insets.xxl),
          if (!passed)
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: const Text('Intentarlo otra vez'),
            )
          else ...[
            if (s?.tutorLessonId case final tutorId?) ...[
              ElevatedButton.icon(
                onPressed: () => context.pushReplacement('/tutor/$tutorId'),
                icon: const Icon(Icons.record_voice_over_rounded, size: 20),
                label: const Text('Ahora dilo en voz alta con el tutor'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
              ),
              const SizedBox(height: Insets.sm),
            ],
            if (s?.tutorLessonId == null)
              ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: const Text('Seguir mi viaje'),
              )
            else
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: const Text('Seguir mi viaje'),
              ),
          ],
        ],
      ),
    );
  }
}
