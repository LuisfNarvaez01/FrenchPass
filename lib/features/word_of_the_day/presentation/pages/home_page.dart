import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/tts_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';
import 'package:french_pass/features/word_of_the_day/presentation/cubit/home_cubit.dart';
import 'package:french_pass/features/word_of_the_day/presentation/widgets/action_buttons_row.dart';
import 'package:french_pass/features/word_of_the_day/presentation/widgets/word_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit(
        getIt<WordRepository>(),
        getIt<ProgressRepository>(),
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

class _HomeViewState extends State<_HomeView> with WidgetsBindingObserver {
  final _tts = getIt<TtsService>();
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tts.stop();
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

  Future<void> _speak(String text) async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    final ok = await _tts.speak(text);
    if (!mounted) return;
    setState(() => _speaking = false);
    if (!ok) _showNoVoice();
  }

  void _showNoVoice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No hay una voz francesa instalada en este dispositivo. '
          'Instálala en Ajustes de Android › Idioma › Texto a voz.',
        ),
        duration: Duration(seconds: 5),
      ),
    );
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
                            onTapIpa: () => _speak(word.french),
                          )
                              .animate()
                              .fadeIn(duration: 350.ms)
                              .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),

                          const SizedBox(height: Insets.lg),

                          ActionButtonsRow(
                            isSpeaking: _speaking,
                            isSaved: state.isFavorite,
                            onListen: () => _speak(word.french),
                            onPractice: () async {
                              await context.push(
                                '/word/${word.id}/practice',
                                extra: word,
                              );
                              if (mounted) _refresh();
                            },
                            onSave: () async {
                              // Captured before the await: the callback may
                              // outlive this element.
                              final cubit = context.read<HomeCubit>();
                              final messenger =
                                  ScaffoldMessenger.of(context);
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
                          ).animate().fadeIn(delay: 120.ms),

                          const SizedBox(height: Insets.xl),

                          _ExampleAudioButton(
                            onTap: () => _speak(word.exampleFr),
                          ).animate().fadeIn(delay: 180.ms),

                          const SizedBox(height: Insets.xxl),

                          _StreakCard(
                            streak: state.streak,
                            studiedToday: state.studiedToday,
                          ).animate().fadeIn(delay: 220.ms),

                          const SizedBox(height: Insets.lg),

                          _ReviewQueue(
                            dueCount: state.dueCount,
                            words: state.dueWords,
                            corpusSize: state.corpusSize,
                          ).animate().fadeIn(delay: 260.ms),
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
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    const weekdays = [
      'lunes', 'martes', 'miércoles', 'jueves',
      'viernes', 'sábado', 'domingo',
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
          Pill(label: '$streak d', icon: Icons.local_fire_department_rounded,
              tone: p.terracotta),
      ],
    );
  }
}

class _ExampleAudioButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExampleAudioButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.record_voice_over_outlined, size: 18, color: p.gold),
      label: const Text('Escuchar la frase completa'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: p.border),
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
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.task_alt_rounded, color: p.good, size: 22),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Text(
                words.isEmpty && corpusSize > 0
                    ? 'Aún no tienes repasos programados. Practica la palabra '
                        'de hoy y el sistema te la devolverá en el momento justo.'
                    : 'Sin repasos pendientes. Todo al día.',
                style: context.texts.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          eyebrow: 'Repetición espaciada',
          title: 'Toca repasar',
          subtitle: '$dueCount ${dueCount == 1 ? 'palabra' : 'palabras'} '
              'esperando tu voz',
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
