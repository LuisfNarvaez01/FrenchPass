import 'package:flutter/material.dart';

import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/topic_icons.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// The hero card: category and level above, the French word as the focal
/// point, then the reading, the translation and a worked example.
class WordCard extends StatelessWidget {
  final Word word;
  final VoidCallback? onTapIpa;
  final bool compact;

  const WordCard({
    super.key,
    required this.word,
    this.onTapIpa,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    // A faint diagonal sheen over the card -- gold leaf caught at an angle --
    // is the one place the system allows a decorative flourish beyond the
    // divider ornament, since this card is the single focal point per screen.
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.xl),
      child: Stack(
        children: [
          AppCard(
            accent: true,
            radius: Radii.xl,
            padding: EdgeInsets.all(compact ? Insets.xl : Insets.xxl),
            child: _WordCardContent(
              word: word,
              onTapIpa: onTapIpa,
              compact: compact,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0, 0.32],
                    colors: [
                      p.gold.withValues(alpha: 0.05),
                      p.gold.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordCardContent extends StatelessWidget {
  final Word word;
  final VoidCallback? onTapIpa;
  final bool compact;
  const _WordCardContent({
    required this.word,
    this.onTapIpa,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Pill(
                label: word.category.labelEs,
                icon: word.category.icon,
                tone: p.gold,
              ),
              Pill(label: word.level.label, tone: p.textSecondary, dense: true),
            ],
          ),
          SizedBox(height: compact ? Insets.xl : Insets.xxl),

          // ── The word itself ──────────────────────────────────────────────
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              word.french,
              style: compact
                  ? context.texts.displaySmall
                  : context.texts.displayMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: Insets.sm),

          // Tapping the transcription plays it — the reading and the sound
          // belong together.
          InkWell(
            onTap: onTapIpa,
            borderRadius: BorderRadius.circular(Radii.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.sm, vertical: Insets.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(word.ipa, style: AppTheme.ipa(context, size: 17)),
                  if (onTapIpa != null) ...[
                    const SizedBox(width: Insets.sm),
                    Icon(Icons.graphic_eq_rounded, size: 14, color: p.gold),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.xs),
          Text(word.wordType.labelEs, style: context.texts.labelSmall),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.xl),
            child: _OrnamentDivider(color: p.gold.withValues(alpha: 0.35)),
          ),

          Text(
            word.translationEs,
            style: context.texts.titleLarge?.copyWith(fontSize: 19),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Insets.xl),

          // ── Worked example ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Insets.lg),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: p.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('«',
                        style: context.texts.headlineMedium
                            ?.copyWith(color: p.gold, height: 1)),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        word.exampleFr,
                        style: context.texts.bodyLarge?.copyWith(
                          color: p.textPrimary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                Padding(
                  padding: const EdgeInsets.only(left: Insets.xl),
                  child: Text(word.exampleEs, style: context.texts.bodySmall),
                ),
              ],
            ),
          ),
        ],
      );
  }
}

/// Thin rule with a centred diamond — the one decorative flourish in the
/// system, reserved for the hero card.
class _OrnamentDivider extends StatelessWidget {
  final Color color;
  const _OrnamentDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: color, thickness: 0.8)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.md),
          child: Transform.rotate(
            angle: 0.785398, // 45°
            child: Container(width: 5, height: 5, color: color),
          ),
        ),
        Expanded(child: Divider(color: color, thickness: 0.8)),
      ],
    );
  }
}
