import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/topic_icons.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/mascot.dart';
import 'package:french_pass/features/tutor/data/gemini_live_client.dart';
import 'package:french_pass/features/tutor/data/tutor_audio.dart';
import 'package:french_pass/features/tutor/data/tutor_repository.dart';
import 'package:french_pass/features/tutor/data/tutor_review_service.dart';
import 'package:french_pass/features/tutor/domain/lesson.dart';
import 'package:french_pass/features/tutor/domain/tutor_message.dart';
import 'package:french_pass/features/tutor/presentation/cubit/tutor_session_cubit.dart';
import 'package:french_pass/features/tutor/presentation/widgets/tutor_note_card.dart';

class TutorSessionPage extends StatelessWidget {
  final String lessonId;
  const TutorSessionPage({super.key, required this.lessonId});

  @override
  Widget build(BuildContext context) {
    final lesson = Lessons.byId(lessonId);
    if (lesson == null) {
      return const Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Lección no encontrada',
              message: 'Esta lección ya no existe.',
            ),
          ),
        ),
      );
    }
    return BlocProvider(
      create: (_) => TutorSessionCubit(
        lesson: lesson,
        repository: getIt<TutorRepository>(),
        reviewer: getIt<TutorReviewService>(),
        audio: DeviceTutorAudio(),
        client: GeminiLiveClient(),
      )..start(),
      child: _LifecycleGuard(child: _SessionView(lesson: lesson)),
    );
  }
}

/// Android stops feeding the mic to a backgrounded app, so a lesson left
/// running would hang half-open: leaving the app ends it (and saves it).
class _LifecycleGuard extends StatefulWidget {
  final Widget child;
  const _LifecycleGuard({required this.child});

  @override
  State<_LifecycleGuard> createState() => _LifecycleGuardState();
}

class _LifecycleGuardState extends State<_LifecycleGuard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    final cubit = context.read<TutorSessionCubit>();
    if (cubit.state.isLive) cubit.endLesson();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _SessionView extends StatelessWidget {
  final Lesson lesson;
  const _SessionView({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TutorSessionCubit>().state;
    final cubit = context.read<TutorSessionCubit>();

    return PopScope(
      // Leaving mid-conversation ends the lesson properly (so it is
      // reviewed and remembered) instead of silently dropping it.
      canPop: !state.isLive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) cubit.endLesson();
      },
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                _Header(
                  lesson: lesson,
                  canEnd: state.isLive,
                  onEnd: cubit.endLesson,
                ),
                Expanded(
                  child: switch (state.phase) {
                    TutorPhase.error => EmptyState(
                        icon: Icons.wifi_off_rounded,
                        title: 'No se pudo empezar',
                        message: state.error ?? 'Algo salió mal.',
                        actionLabel: 'Volver',
                        onAction: () => context.pop(),
                      ),
                    TutorPhase.connecting => _Connecting(lesson: lesson),
                    TutorPhase.ended => _Summary(lesson: lesson, state: state),
                    _ => _Conversation(state: state),
                  },
                ),
                if (state.isLive) _Dock(state: state),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Lesson lesson;
  final bool canEnd;
  final VoidCallback onEnd;

  const _Header({
    required this.lesson,
    required this.canEnd,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.sm, 0, Insets.sm, 0),
      child: Row(
        children: [
          canEnd
              ? AppBackButton.close(onPressed: onEnd)
              : const AppBackButton(),
          const SizedBox(width: Insets.xs),
          Icon(lesson.icon, size: 20, color: context.palette.gold),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(lesson.titleEs,
                style: context.texts.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          if (canEnd)
            TextButton(onPressed: onEnd, child: const Text('Terminar')),
        ],
      ),
    );
  }
}

/// While the session opens: the goal and the phrases to have ready.
class _Connecting extends StatelessWidget {
  final Lesson lesson;
  const _Connecting({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Insets.page, Insets.xl, Insets.page, Insets.xl),
      children: [
        Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: p.gold),
            ),
            const SizedBox(width: Insets.md),
            Text('Conectando con tu tutor…', style: context.texts.bodyMedium),
          ],
        ),
        const SizedBox(height: Insets.xxl),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TU OBJETIVO', style: AppTheme.eyebrow(context)),
              const SizedBox(height: Insets.sm),
              Text(lesson.goalEs, style: context.texts.bodyMedium),
              const SizedBox(height: Insets.lg),
              Text('FRASES ÚTILES', style: AppTheme.eyebrow(context)),
              const SizedBox(height: Insets.sm),
              for (final phrase in lesson.keyPhrasesFr)
                Padding(
                  padding: const EdgeInsets.only(bottom: Insets.xs),
                  child: Text('· $phrase',
                      style: context.texts.bodyMedium
                          ?.copyWith(color: p.textPrimary)),
                ),
            ],
          ),
        ).animate().fadeIn(duration: Motion.base),
      ],
    );
  }
}

class _Conversation extends StatefulWidget {
  final TutorSessionState state;
  const _Conversation({required this.state});

  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant _Conversation old) {
    super.didUpdateWidget(old);
    if (old.state.messages != widget.state.messages) {
      // Follow the conversation as it grows.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: Motion.fast,
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final cubit = context.read<TutorSessionCubit>();

    if (state.messages.isEmpty) {
      return Center(
        child: Text('Tu tutor está a punto de hablar…',
            style: context.texts.bodySmall),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
          Insets.page, Insets.md, Insets.page, Insets.lg),
      itemCount: state.messages.length,
      itemBuilder: (context, i) {
        final message = state.messages[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: Insets.md),
          child: switch (message) {
            TutorLine() => _TutorBubble(
                text: message.text,
                translation: state.translations[i],
                translating: state.translations.containsKey(i) &&
                    state.translations[i] == null,
                canReplay: state.replayable.contains(i) &&
                    state.phase == TutorPhase.listening,
                onReplay: () => cubit.replayLine(i),
                onTranslate: () => cubit.translateLine(i),
              ),
            LearnerLine() => _LearnerBlock(line: message),
          },
        ).animate().fadeIn(duration: Motion.fast);
      },
    );
  }
}

class _TutorBubble extends StatelessWidget {
  final String text;
  final String? translation;
  final bool translating;
  final bool canReplay;
  final VoidCallback onReplay;
  final VoidCallback onTranslate;

  const _TutorBubble({
    required this.text,
    required this.translation,
    required this.translating,
    required this.canReplay,
    required this.onReplay,
    required this.onTranslate,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
              Insets.lg, Insets.md, Insets.sm, Insets.xs),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border.all(color: p.border),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(Radii.sm),
              topRight: Radius.circular(Radii.lg),
              bottomLeft: Radius.circular(Radii.lg),
              bottomRight: Radius.circular(Radii.lg),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: Insets.sm),
                child: Text(text,
                    style: context.texts.bodyLarge
                        ?.copyWith(color: p.textPrimary)),
              ),
              if (translation != null) ...[
                const SizedBox(height: Insets.xs),
                Padding(
                  padding: const EdgeInsets.only(right: Insets.sm),
                  child: Text(translation!,
                      style: context.texts.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic)),
                ),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (translation == null)
                    TextButton(
                      onPressed: translating ? null : onTranslate,
                      style: TextButton.styleFrom(
                        foregroundColor: p.textSecondary,
                        padding:
                            const EdgeInsets.symmetric(horizontal: Insets.sm),
                        visualDensity: VisualDensity.compact,
                      ),
                      child:
                          Text(translating ? 'Traduciendo…' : '¿Qué ha dicho?'),
                    ),
                  if (canReplay)
                    IconButton(
                      tooltip: 'Escuchar otra vez',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.replay_rounded, size: 18, color: p.gold),
                      onPressed: onReplay,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the learner said, with the tutor's on-screen notes under it.
class _LearnerBlock extends StatelessWidget {
  final LearnerLine line;
  const _LearnerBlock({required this.line});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (line.text.trim().isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.82),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg, vertical: Insets.md),
              decoration: BoxDecoration(
                color: p.gold.withValues(alpha: 0.14),
                border: Border.all(color: p.gold.withValues(alpha: 0.35)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(Radii.lg),
                  topRight: Radius.circular(Radii.sm),
                  bottomLeft: Radius.circular(Radii.lg),
                  bottomRight: Radius.circular(Radii.lg),
                ),
              ),
              child: Text(line.text,
                  style:
                      context.texts.bodyLarge?.copyWith(color: p.textPrimary)),
            ),
          ),
        for (final note in line.notes) ...[
          const SizedBox(height: Insets.sm),
          TutorNoteCard(note: note)
              .animate()
              .fadeIn(duration: Motion.base)
              .slideY(begin: 0.15, end: 0, curve: Curves.easeOut),
        ],
      ],
    );
  }
}

/// Bottom controls: who has the floor, the help button and mute.
class _Dock extends StatelessWidget {
  final TutorSessionState state;
  const _Dock({required this.state});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cubit = context.read<TutorSessionCubit>();

    final (label, sub) = switch (state.phase) {
      TutorPhase.tutorSpeaking => (
          'Tu tutor está hablando',
          'Toca para interrumpir'
        ),
      TutorPhase.thinking => ('Pensando…', ''),
      _ when state.muted => ('Micrófono en pausa', 'Toca para reanudar'),
      _ => ('Te escucho', 'Habla en francés cuando quieras'),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(
          Insets.page, Insets.md, Insets.page, Insets.lg),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _Orb(
                phase: state.phase,
                level: state.micLevel,
                muted: state.muted,
                onTap: switch (state.phase) {
                  TutorPhase.tutorSpeaking => cubit.interrupt,
                  TutorPhase.listening => cubit.toggleMute,
                  _ => null,
                },
              ),
              const SizedBox(width: Insets.lg),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: context.texts.titleMedium),
                      if (sub.isNotEmpty)
                        Text(sub, style: context.texts.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  state.phase == TutorPhase.listening ? cubit.askForHelp : null,
              icon: Icon(Icons.lightbulb_outline_rounded,
                  size: 18, color: p.gold),
              label: const Text('No sé cómo decirlo'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: p.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The round status control: pulses with your voice while listening, glows
/// while the tutor speaks.
class _Orb extends StatelessWidget {
  final TutorPhase phase;
  final double level;
  final bool muted;
  final VoidCallback? onTap;

  const _Orb({
    required this.phase,
    required this.level,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final listening = phase == TutorPhase.listening && !muted;
    final speaking = phase == TutorPhase.tutorSpeaking;
    final tone = speaking ? p.gold : (listening ? p.good : p.textMuted);
    final scale = listening ? 1 + level * 0.25 : 1.0;

    final orb = AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 90),
      child: AnimatedContainer(
        duration: Motion.fast,
        width: Sizes.actionHeight,
        height: Sizes.actionHeight,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tone.withValues(alpha: 0.14),
          border: Border.all(color: tone, width: 2),
        ),
        child: Icon(
          speaking
              ? Icons.graphic_eq_rounded
              : muted
                  ? Icons.mic_off_rounded
                  : phase == TutorPhase.thinking
                      ? Icons.more_horiz_rounded
                      : Icons.mic_rounded,
          color: tone,
          size: 28,
        ),
      ),
    );

    return Semantics(
      button: onTap != null,
      label: speaking
          ? 'Interrumpir al tutor'
          : muted
              ? 'Reanudar micrófono'
              : 'Pausar micrófono',
      child: GestureDetector(
        onTap: onTap,
        child: speaking
            ? orb
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1, end: 1.06, duration: Motion.slow)
            : orb,
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final Lesson lesson;
  final TutorSessionState state;
  const _Summary({required this.lesson, required this.state});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final review = state.review;
    final notes = state.messages
        .whereType<LearnerLine>()
        .expand((l) => l.notes)
        .where((n) => n is! HintNote)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Insets.page, Insets.lg, Insets.page, Insets.xxxl),
      children: [
        // Finishing a conversation in French is the effort worth marking.
        if (state.messages.any((m) => m is LearnerLine && m.text.isNotEmpty))
          Center(
            child: MascotCelebration(
              size: 132,
              caption: state.goalReached ? '¡Bravo !' : 'Bien joué !',
            ),
          ),
        const SizedBox(height: Insets.md),
        Text(
          state.goalReached ? '¡Lección completada!' : 'Lección terminada',
          style: context.texts.headlineMedium,
          textAlign: TextAlign.center,
        ),
        if (state.error != null) ...[
          const SizedBox(height: Insets.xs),
          Text(state.error!,
              style: context.texts.bodySmall, textAlign: TextAlign.center),
        ],
        const SizedBox(height: Insets.lg),
        if (state.reviewing)
          InfoNotice(
            icon: Icons.auto_awesome_rounded,
            iconColor: p.gold,
            message: 'Tu tutor está repasando la conversación…',
          )
        else if (review != null) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(review.summaryEs, style: context.texts.bodyMedium),
                if (review.wellDoneEs.isNotEmpty) ...[
                  const SizedBox(height: Insets.lg),
                  Text('LO HICISTE BIEN', style: AppTheme.eyebrow(context)),
                  for (final item in review.wellDoneEs)
                    _SummaryItem(
                        icon: Icons.check_rounded, tone: p.good, text: item),
                ],
                if (review.practiceNextEs.isNotEmpty) ...[
                  const SizedBox(height: Insets.lg),
                  Text('PARA LA PRÓXIMA', style: AppTheme.eyebrow(context)),
                  for (final item in review.practiceNextEs)
                    _SummaryItem(
                        icon: Icons.arrow_forward_rounded,
                        tone: p.terracotta,
                        text: item),
                ],
              ],
            ),
          ).animate().fadeIn(duration: Motion.base),
        ] else if (state.reviewFailed)
          const InfoNotice(
            icon: Icons.cloud_off_rounded,
            message: 'No pude preparar el resumen esta vez, pero tus '
                'correcciones están abajo.',
          ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: Insets.xl),
          Text('TUS CORRECCIONES', style: AppTheme.eyebrow(context)),
          const SizedBox(height: Insets.sm),
          for (final note in notes) ...[
            TutorNoteCard(note: note),
            const SizedBox(height: Insets.sm),
          ],
        ] else if (!state.reviewing && state.messages.isNotEmpty) ...[
          const SizedBox(height: Insets.xl),
          InfoNotice(
            icon: Icons.verified_rounded,
            iconColor: p.good,
            message: 'Sin correcciones en esta lección. ¡Muy bien!',
          ),
        ],
        const SizedBox(height: Insets.xxl),
        if (state.savedSessionId != null) ...[
          ElevatedButton.icon(
            onPressed: () =>
                context.pushReplacement('/review/${state.savedSessionId}'),
            icon: const Icon(Icons.menu_book_rounded, size: 20),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            label: const Text('Repasar la conversación'),
          ),
          const SizedBox(height: Insets.md),
        ],
        OutlinedButton(
          onPressed: () => context.pushReplacement('/tutor/${lesson.id}'),
          style:
              OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Repetir lección'),
        ),
        const SizedBox(height: Insets.sm),
        TextButton(
          onPressed: () => context.pop(),
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Volver a las lecciones'),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String text;
  const _SummaryItem(
      {required this.icon, required this.tone, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Insets.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tone),
          const SizedBox(width: Insets.sm),
          Expanded(child: Text(text, style: context.texts.bodySmall)),
        ],
      ),
    );
  }
}
