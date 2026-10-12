import 'package:flutter/material.dart';

import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/features/tutor/domain/tutor_message.dart';

/// A correction, pronunciation tip or hint the tutor put on screen.
class TutorNoteCard extends StatelessWidget {
  final TutorNote note;
  const TutorNoteCard({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (icon, tone, label, main, detail) = switch (note) {
      CorrectionNote(:final betterFr, :final explanationEs) => (
          Icons.edit_note_rounded,
          p.warning,
          'Mejor dicho',
          betterFr,
          explanationEs,
        ),
      PronunciationNote(:final wordFr, :final tipEs) => (
          Icons.record_voice_over_outlined,
          p.terracotta,
          'Pronunciación',
          wordFr,
          tipEs,
        ),
      HintNote(:final phraseFr, :final translationEs) => (
          Icons.lightbulb_outline_rounded,
          p.good,
          'Puedes decir',
          phraseFr,
          translationEs,
        ),
    };

    return Semantics(
      container: true,
      label: '$label: $main. $detail',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: tone.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: tone),
                const SizedBox(width: Insets.xs),
                Text(label.toUpperCase(),
                    style: AppTheme.eyebrow(context).copyWith(color: tone)),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(main,
                style:
                    context.texts.titleMedium?.copyWith(color: p.textPrimary)),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(detail, style: context.texts.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
