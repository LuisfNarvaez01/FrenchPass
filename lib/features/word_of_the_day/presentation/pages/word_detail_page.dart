import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/tts_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/progress/domain/entities/srs_card.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/presentation/widgets/action_buttons_row.dart';
import 'package:french_pass/features/word_of_the_day/presentation/widgets/word_card.dart';

class WordDetailPage extends StatefulWidget {
  final String wordId;
  const WordDetailPage({super.key, required this.wordId});

  @override
  State<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends State<WordDetailPage> {
  final _tts = getIt<TtsService>();
  final _progress = getIt<ProgressRepository>();

  bool _speaking = false;
  late bool _isFavorite;
  SrsCard? _card;

  @override
  void initState() {
    super.initState();
    _isFavorite = _progress.isFavorite(widget.wordId);
    _card = _progress.cardFor(widget.wordId);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

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
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay una voz francesa instalada en el dispositivo.'),
        ),
      );
    }
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
                    SliverAppBar(
                      pinned: true,
                      backgroundColor: p.bg,
                      surfaceTintColor: Colors.transparent,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 20),
                        onPressed: () => context.pop(),
                        tooltip: 'Volver',
                      ),
                      title: Text(word.french,
                          style: context.texts.titleLarge),
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
                            onTapIpa: () => _speak(word.french),
                          ).animate().fadeIn(duration: 300.ms),

                          const SizedBox(height: Insets.lg),

                          ActionButtonsRow(
                            isSpeaking: _speaking,
                            isSaved: _isFavorite,
                            onListen: () => _speak(word.french),
                            onPractice: () async {
                              await context.push(
                                  '/word/${word.id}/practice', extra: word);
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

                          OutlinedButton.icon(
                            onPressed: () => _speak(word.exampleFr),
                            icon: Icon(Icons.record_voice_over_outlined,
                                size: 18, color: p.gold),
                            label: const Text('Escuchar la frase completa'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              side: BorderSide(color: p.border),
                            ),
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
          width: 68,
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
    final p = context.palette;
    final c = card;

    if (c == null) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.schedule_rounded, color: p.textMuted, size: 20),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Text(
                'Practícala una vez y entrará en tu calendario de repasos.',
                style: context.texts.bodySmall,
              ),
            ),
          ],
        ),
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
                child: _Metric(
                    label: 'Próximo repaso', value: whenLabel),
              ),
              Expanded(
                child: _Metric(
                    label: 'Repeticiones', value: '${c.repetitions}'),
              ),
              Expanded(
                child: _Metric(
                  label: 'Facilidad',
                  value: c.easinessFactor.toStringAsFixed(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
