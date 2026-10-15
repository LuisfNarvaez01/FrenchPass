import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
import 'package:french_pass/features/tutor/data/tutor_repository.dart';
import 'package:french_pass/features/tutor/domain/lesson.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/presentation/cubit/home_cubit.dart';
import 'package:french_pass/features/word_of_the_day/presentation/widgets/word_hero.dart';

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
                            Insets.page, Insets.md, Insets.sm, 0),
                        child: _Masthead(streak: state.streak),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          Insets.page, Insets.lg, Insets.page, Insets.xxxl),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (getIt<AchievementService>().unseen()
                              case final fresh when fresh.isNotEmpty) ...[
                            _NewAchievements(
                              achievements: fresh,
                              onOpen: () async {
                                await getIt<AchievementService>().markAllSeen();
                                if (!context.mounted) return;
                                context.go('/progress');
                              },
                            ),
                            const SizedBox(height: Insets.lg),
                          ],

                          // The word is the hero: the first and biggest thing
                          // on screen, with one gold action under it.
                          _InkIn(
                            key: ValueKey(word.id),
                            child: WordHero(
                              word: word,
                              eyebrow: state.isExploring
                                  ? null
                                  : 'Palabra del día · ${_todayFormatted()}',
                              speaking: speaking,
                              sequenceSpeaking: sequenceSpeaking,
                              onListen: () => speak(word.french),
                              onSentence: () => speak(word.exampleFr),
                              onWordByWord: () =>
                                  speakWordByWord(word.exampleFr),
                            ),
                          ),
                          const SizedBox(height: Insets.lg),
                          WordActions(
                            isSaved: state.isFavorite,
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
                          ).animate().fadeIn(delay: Motion.stagger(4)),
                          const SizedBox(height: Insets.xl),
                          _ContinueSection(
                            dueCount: state.dueCount,
                            onPlacement: () async {
                              await context.push('/practice/placement');
                              if (mounted) await _refresh();
                            },
                            onDismissPlacement: () async {
                              await getIt<StorageService>().setBool(
                                  StorageKeys.placementDismissed, true);
                              if (mounted) setState(() {});
                            },
                          ).animate().fadeIn(delay: Motion.stagger(5)),
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
    return '$weekday ${now.day} de ${months[now.month - 1]}';
  }
}

/// Offered until the learner takes the placement test or says no.
bool get _showPlacement {
  final storage = getIt<StorageService>();
  return storage.getString(StorageKeys.placementLevel) == null &&
      !(storage.getBool(StorageKeys.placementDismissed) ?? false);
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
      accent: true,
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
                Text(first.description,
                    style: context.texts.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
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

/// The wordmark, today's status in one chip (streak and goal), and the two
/// tools that live outside the tabs.
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
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
              TextSpan(
                text: 'Pass',
                style: context.texts.headlineMedium
                    ?.copyWith(color: p.gold, fontWeight: FontWeight.w800),
              ),
            ]),
          ),
        ),
        _TodayChip(streak: streak),
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

/// Streak and today's goal side by side, small enough for the header.
/// Opens Progreso, where both are explained.
class _TodayChip extends StatelessWidget {
  final int streak;
  const _TodayChip({required this.streak});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final progress = getIt<ProgressRepository>();
    final done = progress.practiceToday();
    final goal = progress.dailyGoal;
    final met = done >= goal;
    return Semantics(
      button: true,
      label: 'Racha de $streak días. Meta de hoy: $done de $goal ejercicios.',
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.pill),
          onTap: () => context.go('/progress'),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md, vertical: Insets.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department_rounded,
                      size: 16, color: streak > 0 ? p.terracotta : p.textMuted),
                  const SizedBox(width: 2),
                  Text('$streak', style: context.texts.labelLarge),
                  const SizedBox(width: Insets.md),
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      value: (done / goal).clamp(0, 1).toDouble(),
                      strokeWidth: 2.5,
                      color: met ? p.good : p.gold,
                      backgroundColor: p.surfaceAlt,
                    ),
                  ),
                  const SizedBox(width: Insets.xs + 2),
                  Text(met ? '$done' : '$done/$goal',
                      style: context.texts.labelLarge),
                ],
              ),
            ),
          ),
        ),
      ),
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
    final quiet = TextButton.styleFrom(foregroundColor: p.textSecondary);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isExploring)
          TextButton.icon(
            style: quiet,
            onPressed: onBackToToday,
            icon: const Icon(Icons.today_rounded, size: 16),
            label: const Text('Volver a la de hoy'),
          ),
        TextButton.icon(
          style: quiet,
          onPressed: onNext,
          icon: const Icon(Icons.shuffle_rounded, size: 16),
          label: const Text('Otra palabra'),
        ),
      ],
    );
  }
}

/// What to do next, as one list: reviews due, today's goal, the tutor
/// lesson to pick up, and (until answered) the placement test.
class _ContinueSection extends StatelessWidget {
  final int dueCount;
  final VoidCallback onPlacement;
  final VoidCallback onDismissPlacement;

  const _ContinueSection({
    required this.dueCount,
    required this.onPlacement,
    required this.onDismissPlacement,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final progress = getIt<ProgressRepository>();
    final done = progress.practiceToday();
    final goal = progress.dailyGoal;
    final history = getIt<TutorRepository>().history();
    final last = history.isEmpty ? null : Lessons.byId(history.last.lessonId);
    final minutes = (dueCount * 12 / 60).ceil();

    final rows = <Widget>[
      if (dueCount > 0)
        _ContinueRow(
          icon: Icons.replay_rounded,
          tone: p.terracotta,
          title: dueCount == 1
              ? 'Repasar 1 palabra'
              : 'Repasar $dueCount palabras',
          subtitle: 'Unos $minutes min, antes de que se te olviden',
          onTap: () => context.push('/practice/quiz'),
        ),
      if (done < goal)
        _ContinueRow(
          icon: Icons.flag_rounded,
          tone: p.gold,
          title: 'Meta de hoy: $done de $goal',
          subtitle: goal - done == 1
              ? 'Te falta 1 ejercicio'
              : 'Te faltan ${goal - done} ejercicios',
          onTap: () => context.go('/quiz'),
        ),
      if (last != null && last.id != Lessons.freeTalkId)
        _ContinueRow(
          icon: Icons.record_voice_over_rounded,
          tone: p.textSecondary,
          title: 'Seguir con el tutor',
          subtitle: last.titleEs,
          onTap: () => context.push('/tutor/${last.id}'),
        )
      else
        _ContinueRow(
          icon: Icons.record_voice_over_rounded,
          tone: p.textSecondary,
          title: history.isEmpty
              ? 'Tu primera conversación'
              : 'Habla con el tutor',
          subtitle: 'Practica en voz alta, a tu nivel',
          onTap: () => context.go('/tutor'),
        ),
      if (_showPlacement)
        _ContinueRow(
          icon: Icons.school_rounded,
          tone: p.textSecondary,
          title: '¿Cuál es tu nivel?',
          subtitle: 'Prueba de 3 minutos',
          onTap: onPlacement,
          trailing: IconButton(
            tooltip: 'Ahora no',
            icon: Icon(Icons.close_rounded, size: 18, color: p.textMuted),
            onPressed: onDismissPlacement,
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CONTINÚA', style: AppTheme.eyebrow(context)),
        const SizedBox(height: Insets.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, row) in rows.indexed) ...[
                if (i > 0) Divider(height: 1, indent: 64, color: p.border),
                row,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ContinueRow extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ContinueRow({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            Insets.lg, Insets.md, Insets.sm, Insets.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tone.withValues(alpha: 0.14),
              ),
              child: Icon(icon, size: 18, color: tone),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.texts.titleMedium),
                  Text(subtitle,
                      style: context.texts.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            trailing ??
                Padding(
                  padding: const EdgeInsets.only(right: Insets.sm),
                  child: Icon(Icons.chevron_right_rounded,
                      color: p.textMuted, size: 20),
                ),
          ],
        ),
      ),
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
          color: p.goldBright.withValues(alpha: 0.16),
        );
  }
}
