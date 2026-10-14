import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/features/progress/presentation/widgets/daily_goal_card.dart';
import 'package:french_pass/features/progress/domain/achievements.dart';
import 'package:french_pass/core/services/reminder_service.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/widget_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/mascot.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
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

  /// Spends a streak freeze if yesterday was missed, unlocks whatever
  /// was earned, then redraws.
  Future<void> _refresh() async {
    final cubit = context.read<HomeCubit>();
    final filter = context.read<SettingsBloc>().state.levelFilter;
    final froze = await getIt<ProgressRepository>().protectStreak();
    await getIt<AchievementService>().refresh();
    // The reminder's text follows the reviews due and the streak.
    unawaited(getIt<ReminderService>().refresh());
    if (!mounted) return;
    cubit.refresh(filter);
    setState(() {});
    if (froze) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ayer no practicaste: un congelador salvó tu racha.'),
      ));
    }
  }

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

                          if (_showPlacement) ...[
                            _PlacementPrompt(
                              onStart: () async {
                                await context.push('/practice/placement');
                                if (mounted) await _refresh();
                              },
                              onDismiss: () async {
                                await getIt<StorageService>().setBool(
                                    StorageKeys.placementDismissed, true);
                                if (mounted) setState(() {});
                              },
                            ),
                            const SizedBox(height: Insets.lg),
                          ],
                          DailyGoalCard(onTap: () => context.go('/quiz')),
                          if (getIt<AchievementService>().unseen()
                              case final fresh when fresh.isNotEmpty) ...[
                            const SizedBox(height: Insets.md),
                            _NewAchievements(
                              achievements: fresh,
                              onOpen: () async {
                                await getIt<AchievementService>().markAllSeen();
                                if (!context.mounted) return;
                                context.go('/progress');
                              },
                            ),
                          ],
                          const SizedBox(height: Insets.xxl),

                          Text('Palabra del día',
                              style: AppTheme.eyebrow(context)),
                          const SizedBox(height: Insets.xs),
                          Text(
                            _todayFormatted(),
                            style: context.texts.bodySmall,
                          ),
                          const SizedBox(height: Insets.lg),

                          _InkIn(
                            key: ValueKey(word.id),
                            child: WordCard(
                              word: word,
                              onTapIpa: () => speak(word.french),
                            ),
                          ),

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

/// Offered until the learner takes the placement test or says no.
bool get _showPlacement {
  final storage = getIt<StorageService>();
  return storage.getString(StorageKeys.placementLevel) == null &&
      !(storage.getBool(StorageKeys.placementDismissed) ?? false);
}

class _PlacementPrompt extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onDismiss;
  const _PlacementPrompt({required this.onStart, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      accent: true,
      child: Row(
        children: [
          const MascotSticker(size: 56, pose: MascotPose.thinking, tilt: 0),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Cuál es tu nivel?', style: context.texts.titleMedium),
                Text('Tres minutos y la app se ajusta a ti.',
                    style: context.texts.bodySmall),
                const SizedBox(height: Insets.xs),
                // Wrap, not Row: both buttons don't fit beside the mascot
                // on a typical phone.
                Wrap(
                  children: [
                    TextButton(
                        onPressed: onStart,
                        child: const Text('Hacer la prueba')),
                    TextButton(
                      onPressed: onDismiss,
                      child: Text('Ahora no',
                          style: TextStyle(color: p.textMuted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewAchievements extends StatelessWidget {
  final List<Achievement> achievements;
  final VoidCallback onOpen;
  const _NewAchievements({required this.achievements, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final first = achievements.first;
    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg, vertical: Insets.md),
      child: Row(
        children: [
          const MascotSticker(size: 48, pose: MascotPose.cool, tilt: 0),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievements.length == 1
                      ? 'Logro nuevo: ${first.title}'
                      : '${achievements.length} logros nuevos',
                  style: context.texts.titleMedium,
                ),
                Text(first.description, style: context.texts.bodySmall),
              ],
            ),
          ),
          Icon(first.icon, color: p.gold),
        ],
      ),
    ).animate().fadeIn(duration: Motion.base).scaleXY(
        begin: 0.96, end: 1, duration: Motion.base, curve: Curves.easeOutBack);
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
        IconButton(
          tooltip: 'Traductor',
          icon: Icon(Icons.translate_rounded, color: p.textSecondary),
          onPressed: () => context.push('/translator'),
        ),
        IconButton(
          tooltip: 'Ajustes',
          icon: Icon(Icons.settings_outlined, color: p.textSecondary),
          onPressed: () => context.push('/settings'),
        ),
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
      onTap: () => context.push('/practice/quiz'),
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

    final calm = MediaQuery.disableAnimationsOf(context);
    final flame = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.terracotta.withValues(alpha: 0.14),
      ),
      child: Icon(Icons.local_fire_department_rounded,
          color: p.terracotta, size: 24),
    );

    return AppCard(
      child: Row(
        children: [
          // Practising today earns the mascot; until then the flame asks
          // for it with a short flicker.
          if (studiedToday)
            const SizedBox(
              width: 48,
              height: 48,
              child: OverflowBox(
                maxWidth: 68,
                maxHeight: 68,
                child: MascotSticker(size: 68),
              ),
            )
          else if (streak > 0 && !calm)
            flame
                .animate(delay: 600.ms)
                .scaleXY(begin: 1, end: 1.12, duration: 260.ms)
                .then()
                .scaleXY(begin: 1.12, end: 1 / 1.12, duration: 260.ms)
                .then()
                .scaleXY(begin: 1, end: 1.08, duration: 220.ms)
                .then()
                .scaleXY(begin: 1.08, end: 1 / 1.08, duration: 220.ms)
          else
            flame,
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
            onPressed: () => context.push('/practice/quiz'),
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

/// The word of the day arriving like fresh ink: it sharpens from a soft blur
/// as it settles, then a single band of light crosses the card, gold leaf
/// catching the lamp. Replays only when the word itself changes.
class _InkIn extends StatelessWidget {
  final Widget child;
  const _InkIn({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (MediaQuery.disableAnimationsOf(context)) {
      return child.animate().fadeIn(duration: Motion.base);
    }
    return child
        .animate()
        .fadeIn(duration: 380.ms, curve: Curves.easeOut)
        .blurXY(
            begin: 7,
            end: 0,
            duration: 520.ms,
            curve: const Cubic(0.16, 1, 0.3, 1))
        .scaleXY(
            begin: 0.975,
            end: 1,
            duration: 520.ms,
            curve: const Cubic(0.16, 1, 0.3, 1))
        .then(delay: 120.ms)
        .shimmer(
          duration: 1100.ms,
          angle: 0.5,
          size: 0.6,
          color: p.goldBright.withValues(alpha: 0.22),
        );
  }
}
