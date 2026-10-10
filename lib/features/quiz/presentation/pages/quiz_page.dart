import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/tts_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/quiz/domain/entities/quiz_question.dart';
import 'package:french_pass/features/quiz/presentation/cubit/quiz_cubit.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';

class QuizPage extends StatelessWidget {
  const QuizPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          QuizCubit(getIt<WordRepository>(), getIt<ProgressRepository>()),
      child: const _QuizView(),
    );
  }
}

class _QuizView extends StatelessWidget {
  const _QuizView();

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: BlocBuilder<QuizCubit, QuizState>(
          builder: (context, state) => switch (state.status) {
            QuizStatus.setup => const _QuizIntro(),
            QuizStatus.notEnoughWords => EmptyState(
                icon: Icons.filter_alt_off_outlined,
                title: 'Pocas palabras para un quiz',
                message: 'Amplía el filtro de nivel en Ajustes y vuelve.',
                actionLabel: 'Ir a Ajustes',
                onAction: () => context.go('/settings'),
              ),
            QuizStatus.running || QuizStatus.revealing => _QuizRound(state),
            QuizStatus.finished => _QuizSummary(state),
          },
        ),
      ),
    );
  }
}

class _QuizIntro extends StatelessWidget {
  const _QuizIntro();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final filter = context.watch<SettingsBloc>().state.levelFilter;
    final dueCount = getIt<ProgressRepository>().dueCards().length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          Insets.page, Insets.xl, Insets.page, Insets.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quiz', style: context.texts.headlineLarge),
          const SizedBox(height: Insets.xs),
          Text(
            '${QuizCubit.questionCount} preguntas mezclando traducción, '
            'escucha y transcripción fonética.',
            style: context.texts.bodyMedium,
          ),

          const SizedBox(height: Insets.xxl),

          AppCard(
            accent: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ESTA SESIÓN', style: AppTheme.eyebrow(context)),
                const SizedBox(height: Insets.lg),
                _IntroRow(
                  icon: Icons.layers_outlined,
                  label: 'Nivel',
                  value: filter.labelEs,
                ),
                const SizedBox(height: Insets.md),
                _IntroRow(
                  icon: Icons.event_repeat_rounded,
                  label: 'Repasos pendientes',
                  value: dueCount == 0
                      ? 'ninguno · se elegirán al azar'
                      : '$dueCount con prioridad',
                ),
                const SizedBox(height: Insets.md),
                const _IntroRow(
                  icon: Icons.insights_outlined,
                  label: 'Cuenta para',
                  value: 'tu racha y tu progreso',
                ),
              ],
            ),
          ),

          const SizedBox(height: Insets.xl),

          Text('MODOS DE PREGUNTA', style: AppTheme.eyebrow(context)),
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              for (final mode in QuizMode.values)
                Pill(label: mode.promptEs, tone: p.textSecondary),
            ],
          ),

          const SizedBox(height: Insets.xxl),

          ElevatedButton.icon(
            onPressed: () => context.read<QuizCubit>().start(filter),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Empezar el quiz'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56)),
          ),
        ],
      ),
    );
  }
}

class _IntroRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _IntroRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Icon(icon, size: 17, color: p.gold),
        const SizedBox(width: Insets.md),
        Expanded(child: Text(label, style: context.texts.bodyMedium)),
        Flexible(
          child: Text(
            value,
            style:
                context.texts.labelMedium?.copyWith(color: p.textPrimary),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _QuizRound extends StatefulWidget {
  final QuizState state;
  const _QuizRound(this.state);

  @override
  State<_QuizRound> createState() => _QuizRoundState();
}

class _QuizRoundState extends State<_QuizRound> {
  final _tts = getIt<TtsService>();
  int? _lastSpokenFor;

  @override
  void didUpdateWidget(_QuizRound old) {
    super.didUpdateWidget(old);
    _maybeSpeak();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSpeak());
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  /// Audio questions play themselves once on arrival — the prompt *is* the
  /// sound, so making the learner hunt for a play button first would be busywork.
  void _maybeSpeak() {
    final question = widget.state.current;
    if (question == null || !question.mode.needsAudio) return;
    if (_lastSpokenFor == widget.state.index) return;
    _lastSpokenFor = widget.state.index;
    _tts.speak(question.target.french);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = widget.state;
    final question = state.current;
    if (question == null) return const AppLoader();

    final revealing = state.status == QuizStatus.revealing;

    return Column(
      children: [
        // ── Progress header ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              Insets.page, Insets.md, Insets.page, 0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Salir del quiz',
                    onPressed: () => _confirmExit(context),
                  ),
                  Expanded(
                    child: Text(
                      'Pregunta ${state.index + 1} de ${state.total}',
                      textAlign: TextAlign.center,
                      style: context.texts.labelMedium,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${state.correct}✓',
                      textAlign: TextAlign.center,
                      style: context.texts.labelMedium
                          ?.copyWith(color: p.good),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: state.progress),
                  duration: Motion.base,
                  curve: Curves.easeOut,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 5,
                    backgroundColor: p.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation<Color>(p.gold),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                Insets.page, Insets.xxl, Insets.page, Insets.lg),
            child: Column(
              key: ValueKey(state.index),
              children: [
                Text(question.mode.promptEs,
                    style: AppTheme.eyebrow(context)),
                const SizedBox(height: Insets.xl),

                _Prompt(question: question, onReplay: () {
                  _tts.speak(question.target.french);
                }),

                const SizedBox(height: Insets.xxl),

                for (var i = 0; i < question.options.length; i++) ...[
                  _OptionTile(
                    label: question.labelFor(question.options[i]),
                    index: i,
                    state: revealing
                        ? (i == question.correctIndex
                            ? _OptionState.correct
                            : i == state.selectedIndex
                                ? _OptionState.wrong
                                : _OptionState.dimmed)
                        : _OptionState.idle,
                    onTap: revealing
                        ? null
                        : () => context.read<QuizCubit>().answer(i),
                  ),
                  const SizedBox(height: Insets.md),
                ],

                if (revealing) ...[
                  const SizedBox(height: Insets.sm),
                  _RevealNote(question: question)
                      .animate()
                      .fadeIn(duration: 200.ms),
                ],
              ],
            ).animate(key: ValueKey(state.index)).fadeIn(duration: 220.ms),
          ),
        ),

        // ── Advance ───────────────────────────────────────────────────────
        if (revealing)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.page, 0, Insets.page, Insets.lg),
            child: ElevatedButton(
              onPressed: () => context.read<QuizCubit>().next(),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54)),
              child: Text(state.index >= state.total - 1
                  ? 'Ver resultado'
                  : 'Siguiente'),
            ),
          )
        else
          const SizedBox(height: Insets.xxl + Insets.lg),
      ],
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final cubit = context.read<QuizCubit>();
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir del quiz?'),
        content: const Text(
            'Perderás el avance de esta sesión. No se guardará nada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (leave ?? false) cubit.reset();
  }
}

class _Prompt extends StatelessWidget {
  final QuizQuestion question;
  final VoidCallback onReplay;

  const _Prompt({required this.question, required this.onReplay});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (question.mode.needsAudio) {
      return Column(
        children: [
          GestureDetector(
            onTap: onReplay,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.gold.withValues(alpha: 0.12),
                border: Border.all(color: p.gold.withValues(alpha: 0.45)),
              ),
              child: Icon(Icons.volume_up_rounded, size: 42, color: p.gold),
            ),
          ),
          const SizedBox(height: Insets.md),
          Text('Toca para repetir', style: context.texts.bodySmall),
        ],
      );
    }

    return AppCard(
      accent: true,
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.xl, vertical: Insets.xxl),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                question.prompt,
                textAlign: TextAlign.center,
                style: question.mode == QuizMode.ipa
                    ? AppTheme.ipa(context, size: 34)
                        .copyWith(color: p.textPrimary)
                    : context.texts.displaySmall,
              ),
            ),
            if (question.mode == QuizMode.frToEs) ...[
              const SizedBox(height: Insets.sm),
              Text(question.target.ipa,
                  style: AppTheme.ipa(context, size: 15)),
            ],
          ],
        ),
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

class _OptionTile extends StatelessWidget {
  final String label;
  final int index;
  final _OptionState state;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.label,
    required this.index,
    required this.state,
    required this.onTap,
  });

  static const _letters = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final (border, tint, icon, iconColor) = switch (state) {
      _OptionState.correct => (
          p.good,
          p.good.withValues(alpha: 0.12),
          Icons.check_circle_rounded,
          p.good,
        ),
      _OptionState.wrong => (
          p.critical,
          p.critical.withValues(alpha: 0.12),
          Icons.cancel_rounded,
          p.critical,
        ),
      _OptionState.dimmed => (p.border, p.surface, null, null),
      _OptionState.idle => (p.border, p.surface, null, null),
    };

    return AnimatedOpacity(
      duration: Motion.fast,
      opacity: state == _OptionState.dimmed ? 0.45 : 1,
      child: Material(
        color: tint,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.lg, vertical: Insets.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                color: border,
                width: state == _OptionState.idle ? 1 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.surfaceAlt,
                    border: Border.all(color: p.border),
                  ),
                  child: Text(_letters[index % _letters.length],
                      style: context.texts.labelSmall
                          ?.copyWith(letterSpacing: 0)),
                ),
                const SizedBox(width: Insets.lg),
                Expanded(
                  child: Text(label, style: context.texts.titleMedium),
                ),
                // Correct / wrong is carried by an icon as well as a colour.
                if (icon != null) ...[
                  const SizedBox(width: Insets.sm),
                  Icon(icon, size: 20, color: iconColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RevealNote extends StatelessWidget {
  final QuizQuestion question;
  const _RevealNote({required this.question});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final word = question.target;
    return AppCard(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(word.french, style: context.texts.titleLarge),
              const SizedBox(width: Insets.sm),
              Text(word.ipa, style: AppTheme.ipa(context, size: 14)),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(word.exampleFr,
              style: context.texts.bodyMedium?.copyWith(
                  color: p.textPrimary, fontStyle: FontStyle.italic)),
          const SizedBox(height: 2),
          Text(word.exampleEs, style: context.texts.bodySmall),
        ],
      ),
    );
  }
}

class _QuizSummary extends StatelessWidget {
  final QuizState state;
  const _QuizSummary(this.state);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final wrong =
        state.answers.where((a) => !a.isCorrect).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          Insets.page, Insets.xl, Insets.page, Insets.xxxl),
      child: Column(
        children: [
          Text('Resultado', style: AppTheme.eyebrow(context)),
          const SizedBox(height: Insets.xl),

          ScoreRing(
            score: state.accuracy,
            caption: '${state.correct}/${state.total} correctas',
          ).animate().fadeIn().scale(
              begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),

          const SizedBox(height: Insets.xl),

          Text(
            switch (state.accuracy) {
              >= 0.9 => '¡Impecable !',
              >= 0.7 => '¡Très bien !',
              >= 0.5 => 'Vas por buen camino',
              _ => 'A repasar con calma',
            },
            style: context.texts.headlineMedium,
          ),
          const SizedBox(height: Insets.xs),
          Text(
            'Guardado en tu progreso y en el calendario de repasos.',
            style: context.texts.bodySmall,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: Insets.xxl),

          if (wrong.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text('PARA REFORZAR', style: AppTheme.eyebrow(context)),
            ),
            const SizedBox(height: Insets.md),
            for (final answer in wrong) ...[
              AppCard(
                onTap: () =>
                    context.push('/word/${answer.question.target.id}'),
                padding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg, vertical: Insets.md),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 18, color: p.warning),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(answer.question.target.french,
                              style: context.texts.titleMedium),
                          Text(answer.question.target.translationEs,
                              style: context.texts.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: p.textMuted),
                  ],
                ),
              ),
              const SizedBox(height: Insets.sm),
            ],
            const SizedBox(height: Insets.lg),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/progress'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  child: const Text('Ver progreso'),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.read<QuizCubit>().start(
                      context.read<SettingsBloc>().state.levelFilter),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  child: const Text('Otra ronda'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
