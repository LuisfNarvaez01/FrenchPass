import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/progress/domain/entities/srs_card.dart';
import 'package:french_pass/features/pronunciation/domain/entities/pronunciation_result.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

class PronunciationResultPage extends StatefulWidget {
  final PronunciationResult result;
  final Word word;

  const PronunciationResultPage({
    super.key,
    required this.result,
    required this.word,
  });

  @override
  State<PronunciationResultPage> createState() =>
      _PronunciationResultPageState();
}

class _PronunciationResultPageState extends State<PronunciationResultPage> {
  SrsCard? _card;

  @override
  void initState() {
    super.initState();
    // Reaching this screen *is* the review event: persist it once, here, so
    // the scheduler and the streak cannot disagree with what the learner saw.
    _record();
  }

  Future<void> _record() async {
    final card = await getIt<ProgressRepository>().recordAttempt(
      wordId: widget.word.id,
      score: widget.result.overallScore,
      kind: AttemptKind.pronunciation,
    );
    if (mounted) setState(() => _card = card);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final result = widget.result;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const AppTopBar(
                title: 'Resultado',
                leading: AppBackButton.close(),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.page),
                  child: Column(
                    children: [
                      const SizedBox(height: Insets.lg),

                      Text(widget.word.french,
                          style: context.texts.headlineLarge),
                      Text(widget.word.ipa,
                          style: AppTheme.ipa(context, size: 16)),

                      const SizedBox(height: Insets.xxl),

                      ScoreRing(score: result.overallScore)
                          .animate()
                          .fadeIn(delay: Motion.stagger(3))
                          .scale(
                              delay: Motion.stagger(3),
                              begin: const Offset(0.85, 0.85),
                              curve: Curves.easeOutBack),

                      const SizedBox(height: Insets.xl),

                      Text(
                        result.feedback.labelEs,
                        style: context.texts.headlineMedium,
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: Motion.stagger(8)),
                      const SizedBox(height: Insets.xs),
                      Text(
                        result.feedback.subtitle,
                        style: context.texts.bodyMedium,
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: Motion.stagger(9)),

                      const SizedBox(height: Insets.xxl),

                      // What the recognizer heard — without this the score is
                      // unfalsifiable from the learner's side.
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ESCUCHÉ', style: AppTheme.eyebrow(context)),
                            const SizedBox(height: Insets.sm),
                            Text(
                              result.recognizedText.isEmpty
                                  ? '—'
                                  : '« ${result.recognizedText} »',
                              style: context.texts.bodyLarge
                                  ?.copyWith(fontStyle: FontStyle.italic),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: Insets.md),
                            Divider(color: p.border),
                            const SizedBox(height: Insets.md),
                            Text('ESPERABA', style: AppTheme.eyebrow(context)),
                            const SizedBox(height: Insets.sm),
                            Text('« ${widget.word.french} »',
                                style: context.texts.bodyLarge?.copyWith(
                                    color: p.gold,
                                    fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ).animate().fadeIn(delay: Motion.stagger(10)),

                      const SizedBox(height: Insets.lg),

                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DESGLOSE', style: AppTheme.eyebrow(context)),
                            const SizedBox(height: Insets.lg),
                            MeterRow(
                                label: 'Claridad', value: result.clarityScore),
                            const SizedBox(height: Insets.lg),
                            MeterRow(
                                label: 'Acento', value: result.accentScore),
                            const SizedBox(height: Insets.lg),
                            MeterRow(label: 'Ritmo', value: result.rhythmScore),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: Motion.stagger(12))
                          .slideY(begin: 0.06, end: 0),

                      const SizedBox(height: Insets.lg),

                      _NextReviewNote(card: _card)
                          .animate()
                          .fadeIn(delay: Motion.stagger(14)),

                      const SizedBox(height: Insets.xxl),
                    ],
                  ),
                ),
              ),

              // Actions pinned to the bottom: this is a decision point.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.page, Insets.sm, Insets.page, Insets.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52)),
                        child: const Text('Reintentar'),
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52)),
                        child: const Text('Continuar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tells the learner what the SM-2 scheduler just decided.
class _NextReviewNote extends StatelessWidget {
  final SrsCard? card;
  const _NextReviewNote({required this.card});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = card;
    if (c == null) {
      return const SizedBox(height: 20);
    }

    final days = c.daysUntilReview;
    final when = switch (days) {
      <= 0 => 'hoy mismo',
      1 => 'mañana',
      _ => 'en $days días',
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.event_repeat_rounded, size: 16, color: p.textMuted),
        const SizedBox(width: Insets.sm),
        Flexible(
          child: Text(
            'Te la volveré a pedir $when.',
            style: context.texts.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
