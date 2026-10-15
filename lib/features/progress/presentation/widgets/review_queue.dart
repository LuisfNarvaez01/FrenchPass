import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// The words spaced repetition is bringing back now, as one list: a row per
/// word, inside a single card, with the quiz one tap away.
class ReviewQueue extends StatelessWidget {
  final int dueCount;
  final List<Word> words;

  const ReviewQueue({super.key, required this.dueCount, required this.words});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (dueCount == 0) {
      return InfoNotice(
        icon: Icons.task_alt_rounded,
        iconColor: p.good,
        message: 'Sin repasos pendientes. Todo al día.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          eyebrow: 'Repetición espaciada',
          title: 'Tu cola de repaso',
          trailing: TextButton(
            onPressed: () => context.push('/practice/quiz'),
            child: Text('Repasar $dueCount'),
          ),
        ),
        const SizedBox(height: Insets.md),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, word) in words.indexed) ...[
                if (i > 0)
                  Divider(height: 1, indent: Insets.lg, color: p.border),
                InkWell(
                  onTap: () => context.push('/word/${word.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Insets.lg, vertical: Insets.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(word.french,
                                  style: AppTheme.french(context, size: 17)),
                              const SizedBox(height: 2),
                              Text(word.translationEs,
                                  style: context.texts.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Pill(
                            label: word.level.label,
                            tone: p.textSecondary,
                            dense: true),
                        const SizedBox(width: Insets.sm),
                        Icon(Icons.chevron_right_rounded,
                            color: p.textMuted, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
