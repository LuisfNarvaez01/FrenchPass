import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/tts_playback_mixin.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/progress/domain/entities/srs_card.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/presentation/widgets/action_buttons_row.dart';
import 'package:french_pass/features/word_of_the_day/presentation/widgets/example_audio_row.dart';
import 'package:french_pass/features/word_of_the_day/presentation/widgets/word_card.dart';

class WordDetailPage extends StatefulWidget {
  final String wordId;
  const WordDetailPage({super.key, required this.wordId});

  @override
  State<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends State<WordDetailPage> with TtsPlaybackState {
  final _progress = getIt<ProgressRepository>();

  late bool _isFavorite;
  SrsCard? _card;

  @override
  void initState() {
    super.initState();
    _isFavorite = _progress.isFavorite(widget.wordId);
    _card = _progress.cardFor(widget.wordId);
  }

  @override
  Widget build(BuildContext context) {
    final word = getIt<WordRepository>().byId(widget.wordId);
    final p = context.palette;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: word == null
              ? const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Palabra no encontrada',
                  message: 'Esta palabra ya no está en el catálogo.',
                )
              : CustomScrollView(
                  slivers: [
                    AppSliverBar(
                      title: Text(word.french, style: context.texts.titleLarge),
                      actions: [
                        IconButton(
                          tooltip: _isFavorite
                              ? 'Quitar de guardadas'
                              : 'Guardar palabra',
                          icon: Icon(
                            _isFavorite
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: _isFavorite ? p.gold : p.textSecondary,
                          ),
                          onPressed: () async {
                            final saved =
                                await _progress.toggleFavorite(word.id);
                            if (mounted) setState(() => _isFavorite = saved);
                          },
                        ),
                      ],
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          Insets.page, Insets.sm, Insets.page, Insets.xxxl),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          WordCard(
                            word: word,
                            onTapIpa: () => speak(word.french),
                          ).animate().fadeIn(duration: Motion.base),
                          const SizedBox(height: Insets.lg),
                          ActionButtonsRow(
                            isSpeaking: speaking,
                            isSaved: _isFavorite,
                            onListen: () => speak(word.french),
                            onPractice: () async {
                              await context.push('/word/${word.id}/practice',
                                  extra: word);
                              if (!mounted) return;
                              setState(() =>
                                  _card = _progress.cardFor(widget.wordId));
                            },
                            onSave: () async {
                              final saved =
                                  await _progress.toggleFavorite(word.id);
                              if (mounted) setState(() => _isFavorite = saved);
                            },
                          ),
                          const SizedBox(height: Insets.lg),
                          ExampleAudioRow(
                            isSpeakingWord: speaking,
                            isSpeakingSequence: sequenceSpeaking,
                            onWordByWord: () => speakWordByWord(word.exampleFr),
                            onFullSentence: () => speak(word.exampleFr),
                          ),
                          const SizedBox(height: Insets.xxl),
                          _TranslationsCard(
                            es: word.translationEs,
                            en: word.translationEn,
                          ),
                          const SizedBox(height: Insets.lg),
                          _SrsCardSummary(card: _card),
                        ]),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TranslationsCard extends StatelessWidget {
  final String es;
  final String en;

  const _TranslationsCard({required this.es, required this.en});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TRADUCCIONES', style: AppTheme.eyebrow(context)),
          const SizedBox(height: Insets.md),
          _Row(flag: '🇪🇸', label: 'Español', value: es),
          const SizedBox(height: Insets.md),
          _Row(flag: '🇬🇧', label: 'English', value: en),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String flag;
  final String label;
  final String value;

  const _Row({required this.flag, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(flag, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: Insets.md),
        SizedBox(
          width: Sizes.labelColumn,
          child: Text(label, style: context.texts.bodySmall),
        ),
        Expanded(
          child: Text(value,
              style: context.texts.bodyMedium
                  ?.copyWith(color: context.palette.textPrimary)),
        ),
      ],
    );
  }
}

/// Where this word sits in the spaced-repetition schedule.
class _SrsCardSummary extends StatelessWidget {
  final SrsCard? card;
  const _SrsCardSummary({required this.card});

  @override
  Widget build(BuildContext context) {
    final c = card;

    if (c == null) {
      return const InfoNotice(
        icon: Icons.schedule_rounded,
        iconSize: 20,
        message: 'Practícala una vez y entrará en tu calendario de repasos.',
      );
    }

    final days = c.daysUntilReview;
    final whenLabel = switch (days) {
      <= 0 => 'Hoy',
      1 => 'Mañana',
      _ => 'En $days días',
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('REPETICIÓN ESPACIADA', style: AppTheme.eyebrow(context)),
              if (c.lastScore != null) StatusChip(score: c.lastScore!),
            ],
          ),
          const SizedBox(height: Insets.lg),
          Row(
            children: [
              Expanded(
                child: _Metric(label: 'Próximo repaso', value: whenLabel),
              ),
              Expanded(
                child:
                    _Metric(label: 'Repeticiones', value: '${c.repetitions}'),
              ),
              Expanded(
                child: _Metric(
                  label: 'Dificultad',
                  value: _difficultyLabel(c.easinessFactor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Plain-language reading of the SM-2 easiness factor (1.3 – 2.5): the raw
/// number means nothing to a learner, but "this one is hard for you" does.
String _difficultyLabel(double easiness) => switch (easiness) {
      >= 2.3 => 'Fácil',
      >= 1.8 => 'Media',
      _ => 'Difícil',
    };

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: context.texts.titleLarge
                ?.copyWith(color: context.palette.gold)),
        const SizedBox(height: 2),
        Text(label, style: context.texts.labelSmall, maxLines: 2),
      ],
    );
  }
}
