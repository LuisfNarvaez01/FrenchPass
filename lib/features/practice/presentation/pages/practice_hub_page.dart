import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/topic_icons.dart';
import 'package:french_pass/features/progress/presentation/widgets/daily_goal_card.dart';

typedef _Activity = ({
  IconData icon,
  String title,
  String detail,
  String route,
});

/// Every exercise in one place, grouped by what it trains. All of them run
/// on the phone, so none costs anything per use.
class PracticeHubPage extends StatefulWidget {
  const PracticeHubPage({super.key});

  @override
  State<PracticeHubPage> createState() => _PracticeHubPageState();
}

class _PracticeHubPageState extends State<PracticeHubPage> {
  static const _sections = <(String, List<_Activity>)>[
    (
      'Vocabulario',
      [
        (
          icon: Icons.psychology_rounded,
          title: 'Quiz',
          detail: 'Diez preguntas que priorizan tus repasos pendientes.',
          route: '/practice/quiz',
        ),
        (
          icon: Icons.compare_arrows_rounded,
          title: 'Emparejar',
          detail: 'Une cada palabra con su significado.',
          route: '/practice/match',
        ),
        (
          icon: Icons.hearing_rounded,
          title: 'Dictado',
          detail: 'Escucha y escribe palabras y frases.',
          route: '/practice/dictation',
        ),
        (
          icon: Icons.reorder_rounded,
          title: 'Ordenar frases',
          detail: 'Arma la frase con las palabras desordenadas.',
          route: '/practice/order',
        ),
      ],
    ),
    (
      'Verbos y gramática',
      [
        (
          icon: Icons.edit_note_rounded,
          title: 'Conjugación',
          detail: '100 verbos en presente, pasado, imperfecto y futuro.',
          route: '/practice/conjugation',
        ),
        (
          icon: Icons.rule_rounded,
          title: 'Gramática',
          detail: 'Una regla por tarjeta, con cinco ejercicios.',
          route: '/practice/grammar',
        ),
        (
          icon: Icons.masks_rounded,
          title: 'Falsos amigos',
          detail: 'Parecen español y significan otra cosa.',
          route: '/practice/false-friends',
        ),
      ],
    ),
    (
      'Escuchar y leer',
      [
        (
          icon: Icons.menu_book_rounded,
          title: 'Lecturas',
          detail: 'Historias cortas de A1 a B1, palabra por palabra.',
          route: '/practice/readings',
        ),
        (
          icon: Icons.pin_rounded,
          title: 'Números y hora',
          detail: 'Setenta, ochenta, noventa y los horarios.',
          route: '/practice/numbers',
        ),
      ],
    ),
    (
      'Tu nivel',
      [
        (
          icon: Icons.school_outlined,
          title: 'Prueba de nivel',
          detail: 'Quince preguntas para ajustar la app a tu nivel.',
          route: '/practice/placement',
        ),
      ],
    ),
  ];

  Future<void> _open(String route) async {
    await context.push(route);
    // Coming back, today's goal has moved.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    var n = 0;
    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Insets.page, Insets.xl, Insets.page, Insets.xxxl),
          children: [
            Text('Practicar', style: context.texts.headlineLarge),
            const SizedBox(height: Insets.xs),
            Text('Cada respuesta cuenta para tu meta de hoy.',
                style: context.texts.bodySmall),
            const SizedBox(height: Insets.xl),
            const DailyGoalCard(),
            for (final (title, activities) in _sections) ...[
              const SizedBox(height: Insets.xxl),
              SectionHeader(title: title),
              const SizedBox(height: Insets.md),
              for (final a in activities) ...[
                AppCard(
                  onTap: () => _open(a.route),
                  padding: const EdgeInsets.symmetric(
                      horizontal: Insets.lg, vertical: Insets.md),
                  child: Row(
                    children: [
                      TopicBadge(
                        icon: a.icon,
                        tone: (n++).isEven ? p.gold : p.terracotta,
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title, style: context.texts.titleMedium),
                            const SizedBox(height: 2),
                            Text(a.detail,
                                style: context.texts.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: p.textMuted, size: 20),
                    ],
                  ),
                ).animate().fadeIn(delay: Motion.stagger(n.clamp(0, 10))),
                const SizedBox(height: Insets.sm),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
