import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/widget_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/tts_playback_mixin.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';
import 'package:french_pass/features/word_of_the_day/presentation/cubit/home_cubit.dart';
import 'package:french_pass/features/word_of_the_day/presentation/widgets/action_buttons_row.dart';
import 'package:french_pass/features/word_of_the_day/presentation/widgets/example_audio_row.dart';
import 'package:french_pass/features/word_of_the_day/presentation/widgets/word_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit(
        getIt<WordRepository>(),
        getIt<ProgressRepository>(),
        getIt<WidgetService>(),
      )..refresh(context.read<SettingsBloc>().state.levelFilter),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView>
    with WidgetsBindingObserver, TtsPlaybackState {
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
    // Coming back from the practice screen or from another app can change the
    // streak and the review queue.
    if (state == AppLifecycleState.resumed && mounted) _refresh();
  }

  void _refresh() => context
      .read<HomeCubit>()
      .refresh(context.read<SettingsBloc>().state.levelFilter);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return BlocListener<SettingsBloc, SettingsState>(
      listenWhen: (a, b) => a.levelFilter != b.levelFilter,
      listener: (context, _) => _refresh(),
      child: AppBackground(
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) {
            final word = state.word;
            if (word == null) {
              return const SafeArea(
                child: EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'Sin palabras para este nivel',
                  message:
                      'Cambia el filtro de nivel en Ajustes para ver la palabra '
                      'del día.',
                ),
              );
            }

            return SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: p.gold,
                backgroundColor: p.surface,
                onRefresh: () async => _refresh(),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Insets.page, Insets.lg, Insets.page, 0),
                        child: _Masthead(streak: state.streak),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          Insets.page, Insets.xxl, Insets.page, Insets.xxxl),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Reviews are the one thing a returning learner
                          // came for, so they lead -- one tap, above the fold.
                          if (state.dueCount > 0) ...[
                            _DueBanner(dueCount: state.dueCount)
                                .animate()
                                .fadeIn(duration: Motion.base),
                            const SizedBox(height: Insets.xxl),
                          ],

                          Text('Palabra del día',
                              style: AppTheme.eyebrow(context)),
                          const SizedBox(height: Insets.xs),
                          Text(
                            _todayFormatted(),
                            style: context.texts.bodySmall,
                          ),
                          const SizedBox(height: Insets.lg),

                          WordCard(
                            word: word,
                            onTapIpa: () => speak(word.french),
                          ).animate().fadeIn(duration: Motion.base).slideY(
                              begin: 0.06, end: 0, curve: Curves.easeOut),

                          const SizedBox(height: Insets.lg),

                          ActionButtonsRow(
                            isSpeaking: speaking,
                            isSaved: state.isFavorite,
                            onListen: () => speak(word.french),
                            onPractice: () async {
                              // Captured before the await: practicing an
                              // explored word should not snap the card back
                              // to today's word, only refresh its SRS summary.
                              final cubit = context.read<HomeCubit>();
                              final wasExploring = cubit.state.isExploring;
                              await context.push(
                                '/word/${word.id}/practice',
                                extra: word,
                              );
                              if (!mounted) return;
                              if (wasExploring) {
                                cubit.refreshCurrentCard();
                              } else {
                                _refresh();
                              }
                            },
                            onSave: () async {
                              // Captured before the await: the callback may
                              // outlive this element.
                              final cubit = context.read<HomeCubit>();
                              final messenger = ScaffoldMessenger.of(context);
                              await cubit.toggleFavorite();
                              if (!mounted) return;
                              final saved = cubit.state.isFavorite;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(saved
                                      ? 'Guardada en tus palabras'
                                      : 'Quitada de tus palabras'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ).animate().fadeIn(delay: Motion.stagger(3)),

                          const SizedBox(height: Insets.lg),

                          ExampleAudioRow(
                            isSpeakingWord: speaking,
                            isSpeakingSequence: sequenceSpeaking,
                            onWordByWord: () => speakWordByWord(word.exampleFr),
                            onFullSentence: () => speak(word.exampleFr),
                          ).animate().fadeIn(delay: Motion.stagger(4)),

                          const SizedBox(height: Insets.md),

                          // Secondary: wandering off today's word comes after
                          // everything that serves it.
                          _NextWordRow(
                            isExploring: state.isExploring,
                            onNext: () {
                              stopSpeaking();
                              context.read<HomeCubit>().showRandomWord(context
                                  .read<SettingsBloc>()
                                  .state
                                  .levelFilter);
                            },
                            onBackToToday: _refresh,
                          ).animate().fadeIn(delay: Motion.stagger(5)),

                          const SizedBox(height: Insets.xxl),

                          _StreakCard(
                            streak: state.streak,
                            studiedToday: state.studiedToday,
                          ).animate().fadeIn(delay: Motion.stagger(6)),

                          const SizedBox(height: Insets.lg),

                          _ReviewQueue(
                            dueCount: state.dueCount,
                            words: state.dueWords,
                            corpusSize: state.corpusSize,
                          ).animate().fadeIn(delay: Motion.stagger(6)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _todayFormatted() {
    final now = DateTime.now();
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    const weekdays = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    final weekday = weekdays[now.weekday - 1];
    return '$weekday, ${now.day} de ${months[now.month - 1]}';
  }
}

class _Masthead extends StatelessWidget {
  final int streak;
  const _Masthead({required this.streak});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(children: [
              TextSpan(
                text: 'French',
                style: context.texts.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w400),
              ),
              TextSpan(
                text: 'Pass',
                style: context.texts.headlineMedium
                    ?.copyWith(color: p.gold, fontWeight: FontWeight.w700),
              ),
            ]),
          ),
        ),
        if (streak > 0)
          Pill(
              label: '$streak d',
              icon: Icons.local_fire_department_rounded,
              tone: p.terracotta),
      ],
    );
  }
}

/// Lets the learner go straight to a different word without waiting for the
/// next calendar day, and shows a way back once they have wandered off it.
class _NextWordRow extends StatelessWidget {
  final bool isExploring;
  final VoidCallback onNext;
  final VoidCallback onBackToToday;

  const _NextWordRow({
    required this.isExploring,
    required this.onNext,
    required this.onBackToToday,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        if (isExploring) ...[
          Expanded(
            child: TextButton.icon(
              onPressed: onBackToToday,
              icon: Icon(Icons.today_rounded, size: 16, color: p.textSecondary),
              label: const Text('Volver a la palabra de hoy'),
              style: TextButton.styleFrom(foregroundColor: p.textSecondary),
            ),
          ),
          const SizedBox(width: Insets.sm),
        ],
        Expanded(
          child: TextButton.icon(
            onPressed: onNext,
            icon: Icon(Icons.shuffle_rounded, size: 16, color: p.gold),
            label: const Text('Otra palabra'),
          ),
        ),
      ],
    );
  }
}

/// Compact call to review, pinned above the word of the day whenever the
/// spaced-repetition queue has something due.
class _DueBanner extends StatelessWidget {
  final int dueCount;
  const _DueBanner({required this.dueCount});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      onTap: () => context.go('/quiz'),
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg, vertical: Insets.md),
      child: Row(
        children: [
          Icon(Icons.replay_rounded, color: p.terracotta, size: 22),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Toca repasar', style: context.texts.titleMedium),
                Text(
                  '$dueCount ${dueCount == 1 ? 'palabra espera' : 'palabras esperan'} tu voz',
                  style: context.texts.bodySmall,
                ),
              ],
            ),
          ),
          Text('Repasar',
              style: context.texts.labelLarge?.copyWith(color: p.gold)),
          Icon(Icons.chevron_right_rounded, color: p.gold, size: 20),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;
  final bool studiedToday;

  const _StreakCard({required this.streak, required this.studiedToday});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final (title, message) = switch ((streak, studiedToday)) {
      (0, _) => ('Empieza tu racha hoy', 'Una palabra basta para arrancar.'),
      (_, true) => (
          '$streak ${streak == 1 ? 'día' : 'días'} de racha',
          '¡Ya practicaste hoy! Nos vemos mañana.'
        ),
      _ => (
          '$streak ${streak == 1 ? 'día' : 'días'} de racha',
          'Practica hoy para no perderla.'
        ),
    };

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (studiedToday ? p.good : p.terracotta)
                  .withValues(alpha: 0.14),
            ),
            child: Icon(
              studiedToday
                  ? Icons.check_circle_rounded
                  : Icons.local_fire_department_rounded,
              color: studiedToday ? p.good : p.terracotta,
              size: 24,
            ),
          ),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.texts.titleMedium),
                const SizedBox(height: 2),
                Text(message, style: context.texts.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewQueue extends StatelessWidget {
  final int dueCount;
  final List<Word> words;
  final int corpusSize;

  const _ReviewQueue({
    required this.dueCount,
    required this.words,
    required this.corpusSize,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (dueCount == 0) {
      return InfoNotice(
        icon: Icons.task_alt_rounded,
        iconColor: p.good,
        message: words.isEmpty && corpusSize > 0
            ? 'Aún no tienes repasos programados. Practica la palabra '
                'de hoy y el sistema te la devolverá en el momento justo.'
            : 'Sin repasos pendientes. Todo al día.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          eyebrow: 'Repetición espaciada',
          title: 'Tu cola de repaso',
          subtitle: 'Toca una palabra para verla antes del quiz',
          trailing: TextButton(
            onPressed: () => context.go('/quiz'),
            child: const Text('Quiz'),
          ),
        ),
        const SizedBox(height: Insets.md),
        for (final word in words) ...[
          AppCard(
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.lg, vertical: Insets.md),
            onTap: () => context.push('/word/${word.id}'),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(word.french, style: context.texts.titleMedium),
                      const SizedBox(height: 2),
                      Text(word.translationEs,
                          style: context.texts.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.md),
                Pill(label: word.level.label, tone: p.terracotta, dense: true),
                const SizedBox(width: Insets.sm),
                Icon(Icons.chevron_right_rounded, color: p.textMuted, size: 20),
              ],
            ),
          ),
          const SizedBox(height: Insets.sm),
        ],
      ],
    );
  }
}
