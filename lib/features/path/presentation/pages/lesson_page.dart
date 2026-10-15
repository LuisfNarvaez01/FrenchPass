import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/sound_service.dart';
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

  PathStop? _stop;
  List<LessonStep> _steps = const [];
  int _index = 0;
  int _scored = 0;
  int _right = 0;
  final Set<String> _missed = {};
  bool _finished = false;

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
        _steps = LessonBuilder.questionsAbout(
            items.reversed.take(10).toList(), _path.stops);
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
      _steps = LessonBuilder.build(stop, _path.stops);
    }
  }

  void _score(bool right, {String? about}) {
    _scored++;
    if (right) {
      _right++;
      if (about != null && _isMistakes) _path.clearMistake(about);
    } else if (about != null) {
      _missed.add(about);
    }
  }

  void _next() {
    if (_index < _steps.length - 1) {
      setState(() => _index++);
    } else {
      _finish();
    }
  }

  double get _ratio => _scored == 0 ? 1 : _right / _scored;

  /// A checkpoint is passed at 80 %; everything else always counts.
  bool get _passed => _stop?.kind != StopKind.checkpoint || _ratio >= 0.8;

  Future<void> _finish() async {
    for (final fr in _missed) {
      await _path.addMistake(fr);
    }
    final stop = _stop;
    if (stop != null && _passed) await _path.complete(stop);
    await getIt<ProgressRepository>()
        .recordPractice(PracticeKind.lesson, count: _scored.clamp(1, 20));
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
          right: _right,
          total: _scored,
          passed: _passed,
          onRetry: () => setState(() {
            _index = 0;
            _scored = 0;
            _right = 0;
            _missed.clear();
            _finished = false;
            _steps = LessonBuilder.build(_stop!, _path.stops);
          }),
        ),
      );
    }
    final step = _steps[_index];
    return PracticeScaffold(
      title: title,
      progress: _index / _steps.length,
      child: KeyedSubtree(
        key: ValueKey(_index),
        child: switch (step) {
          LearnStep(:final item) => _LearnView(item: item, onNext: _next),
          ChoiceStep() => ChoiceQuestion(
              item: ChoiceItem(
                prompt: step.prompt,
                options: step.options,
                answer: step.answer,
                why: step.why,
              ),
              isLast: _index == _steps.length - 1,
              onAnswered: (right) => _score(right, about: step.about),
              onNext: _next,
            ),
          ListenStep() => ChoiceQuestion(
              item: ChoiceItem(
                prompt: '¿Qué escuchaste?',
                options: step.options,
                answer: step.answer,
              ),
              header: _ListenHeader(text: step.fr),
              isLast: _index == _steps.length - 1,
              onAnswered: (right) => _score(right, about: step.fr),
              onNext: _next,
            ),
          MatchStep() => _MatchView(
              step: step,
              onDone: (clean) {
                _score(clean);
                _next();
              },
            ),
          OrderStep() => _OrderView(
              step: step,
              onAnswered: (right) => _score(right),
              onNext: _next,
            ),
          DialogueStep() => _DialogueView(
              step: step,
              onTurn: (right) => _score(right),
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
  final VoidCallback onNext;
  const _LearnView({required this.item, required this.onNext});

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
        Text('PALABRA NUEVA', style: AppTheme.eyebrow(context)),
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
  const _ListenHeader({required this.text});

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
  Widget build(BuildContext context) => Row(
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
      );
}

/// French on the left, Spanish on the right: tap one of each to pair them.
class _MatchView extends StatefulWidget {
  final MatchStep step;

  /// Called once every pair is made; true when no wrong pair was tried.
  final ValueChanged<bool> onDone;
  const _MatchView({required this.step, required this.onDone});

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
        Future<void>.delayed(
            const Duration(milliseconds: 450), () => widget.onDone(_clean));
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
  final ValueChanged<bool> onAnswered;
  final VoidCallback onNext;
  const _OrderView({
    required this.step,
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

  /// Each learner turn: right on the first try or not.
  final ValueChanged<bool> onTurn;
  final VoidCallback onDone;
  const _DialogueView({
    required this.step,
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

  List<DialogueLine> get _lines => widget.step.lines;

  @override
  void initState() {
    super.initState();
    _advance();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('TU TURNO', style: AppTheme.eyebrow(context)),
                        const SizedBox(height: Insets.sm),
                        for (final (i, option) in turn.options.indexed) ...[
                          OutlinedButton(
                            onPressed:
                                _wrongPicks.contains(i) ? null : () => _pick(i),
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

/// The end of a stop: the small win, or a retry for a missed checkpoint.
class _Finished extends StatelessWidget {
  final PathStop? stop;
  final int right;
  final int total;
  final bool passed;
  final VoidCallback onRetry;

  const _Finished({
    required this.stop,
    required this.right,
    required this.total,
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
                    ? 'Ya puedes: ${s.goalEs.toLowerCase()}.'
                    : '$right de $total bien.')
                : '$right de $total bien. Para superar el reto hace falta el '
                    '80 %. Repasa y vuelve a intentarlo.',
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
