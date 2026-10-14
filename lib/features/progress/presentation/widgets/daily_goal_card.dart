import 'package:flutter/material.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';

/// Today's goal as a ring, with the streak and the freezes saved up.
class DailyGoalCard extends StatelessWidget {
  final VoidCallback? onTap;
  const DailyGoalCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final progress = getIt<ProgressRepository>();
    final done = progress.practiceToday();
    final goal = progress.dailyGoal;
    final streak = progress.currentStreak();
    final freezes = progress.streakFreezes;
    final met = done >= goal;

    return AppCard(
      accent: met,
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: (done / goal).clamp(0, 1).toDouble(),
                    strokeWidth: 7,
                    color: met ? p.good : p.gold,
                    backgroundColor: p.surfaceAlt,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                met
                    ? Icon(Icons.check_rounded, color: p.good, size: 28)
                    : Text('$done', style: context.texts.titleLarge),
              ],
            ),
          ),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(met ? 'Meta de hoy cumplida' : 'Meta de hoy',
                    style: context.texts.titleMedium),
                const SizedBox(height: 2),
                Text(
                  met
                      ? '$done ejercicios. Lo que hagas ahora es extra.'
                      : '$done de $goal ejercicios. Te faltan ${goal - done}.',
                  style: context.texts.bodySmall,
                ),
                const SizedBox(height: Insets.sm),
                Wrap(
                  spacing: Insets.sm,
                  runSpacing: Insets.xs,
                  children: [
                    Pill(
                      label: streak == 1 ? '1 día' : '$streak días',
                      icon: Icons.local_fire_department_rounded,
                      tone: p.terracotta,
                      dense: true,
                    ),
                    Semantics(
                      label: 'Congeladores de racha guardados: $freezes',
                      child: Pill(
                        label: '$freezes / ${ProgressRepository.maxFreezes}',
                        icon: Icons.ac_unit_rounded,
                        tone: freezes > 0 ? p.gold : p.textMuted,
                        dense: true,
                      ),
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
