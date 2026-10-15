import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/services/storage_service.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/pass_card.dart';
import 'package:french_pass/core/widgets/topic_icons.dart';
import 'package:french_pass/features/conjugation/domain/conjugator.dart';
import 'package:french_pass/features/path/data/path_repository.dart';
import 'package:french_pass/features/practice/data/learning_content.dart';
import 'package:french_pass/features/premium/data/usage_service.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';

typedef _Activity = ({
  PracticeKind kind,
  IconData icon,
  String title,
  String route,
});

const _quiz = (
  kind: PracticeKind.quiz,
  icon: Icons.psychology_rounded,
  title: 'Quiz',
  route: '/practice/quiz',
);
const _match = (
  kind: PracticeKind.match,
  icon: Icons.compare_arrows_rounded,
  title: 'Emparejar',
  route: '/practice/match',
);
const _dictation = (
  kind: PracticeKind.dictation,
  icon: Icons.hearing_rounded,
  title: 'Dictado',
  route: '/practice/dictation',
);
const _numbers = (
  kind: PracticeKind.numbers,
  icon: Icons.pin_rounded,
  title: 'Números y hora',
  route: '/practice/numbers',
);
const _conjugation = (
  kind: PracticeKind.conjugation,
  icon: Icons.edit_note_rounded,
  title: 'Conjugación',
  route: '/practice/conjugation',
);
const _grammar = (
  kind: PracticeKind.grammar,
  icon: Icons.rule_rounded,
  title: 'Gramática',
  route: '/practice/grammar',
);
const _order = (
  kind: PracticeKind.order,
  icon: Icons.reorder_rounded,
  title: 'Ordenar frases',
  route: '/practice/order',
);
const _readings = (
  kind: PracticeKind.reading,
  icon: Icons.menu_book_rounded,
  title: 'Lecturas',
  route: '/practice/readings',
);
const _falseFriends = (
  kind: PracticeKind.falseFriends,
  icon: Icons.masks_rounded,
  title: 'Falsos amigos',
  route: '/practice/false-friends',
);
const _placement = (
  kind: PracticeKind.placement,
  icon: Icons.school_outlined,
  title: 'Prueba de nivel',
  route: '/practice/placement',
);

/// What each group trains, in the order a learner needs it.
const _groups = <(String, List<_Activity>)>[
  ('Vocabulario', [_quiz, _match, _dictation, _numbers]),
  ('Gramática y verbos', [_conjugation, _grammar, _order]),
  ('Comprensión', [_readings, _falseFriends]),
];

/// Every exercise, with one picked out for the learner: reviews when they
/// are due, otherwise whatever they have practised least. All of it runs on
/// the phone, so none costs anything per use.
class PracticeHubPage extends StatefulWidget {
  const PracticeHubPage({super.key});

  @override
  State<PracticeHubPage> createState() => _PracticeHubPageState();
}

class _PracticeHubPageState extends State<PracticeHubPage> {
  final _progress = getIt<ProgressRepository>();

  Future<void> _open(String route) async {
    await context.push(route);
    // Coming back, today's goal and the recommendation have moved.
    if (mounted) setState(() {});
  }

  /// One line per activity: how much there is, or how much is waiting.
  String _detail(_Activity a, int due) {
    final content =
        getIt.isRegistered<LearningContent>() ? getIt<LearningContent>() : null;
    final storage = getIt<StorageService>();
    return switch (a.kind) {
      PracticeKind.quiz =>
        due > 0 ? '$due por repasar hoy' : '10 preguntas, con tus repasos',
      PracticeKind.match => 'Une palabra y significado',
      PracticeKind.dictation => 'Escucha y escribe',
      PracticeKind.numbers => 'Del 0 al 1000, y la hora',
      PracticeKind.conjugation => '${Verbs.all.length} verbos, 4 tiempos',
      PracticeKind.grammar => content == null
          ? 'Reglas con ejercicios'
          : '${storage.getStringSet(StorageKeys.grammarDone).length} de '
              '${content.grammar.length} temas hechos',
      PracticeKind.order => 'Arma la frase',
      PracticeKind.reading => content == null
          ? 'Historias cortas'
          : '${storage.getStringSet(StorageKeys.readingsDone).length} de '
              '${content.readings.length} historias leídas',
      PracticeKind.falseFriends => content == null
          ? 'Parecen español y no lo son'
          : '${content.falseFriends.length} trampas para hispanohablantes',
      PracticeKind.placement => '15 preguntas, unos 3 minutos',
      _ => '',
    };
  }

  /// Reviews first when any are due; otherwise the activity practised
  /// least, so the week covers everything.
  (_Activity, String) _recommend(int due) {
    if (due > 0) {
      return (
        _quiz,
        due == 1
            ? 'Tienes 1 palabra por repasar hoy.'
            : 'Tienes $due palabras por repasar hoy.'
      );
    }
    // Next, the journey: today's lesson if there is one to open.
    if (getIt.isRegistered<PathRepository>()) {
      final path = getIt<PathRepository>();
      final stop = path.next;
      final premium =
          getIt.isRegistered<UsageService>() && getIt<UsageService>().isPremium;
      if (stop != null && path.canStartNew(premium: premium)) {
        return (
          (
            kind: PracticeKind.lesson,
            icon: Icons.route_rounded,
            title: stop.titleEs,
            route: '/path/stop/${stop.id}',
          ),
          'La siguiente parada de tu viaje: ${stop.goalEs.toLowerCase()}.'
        );
      }
    }
    final storage = getIt<StorageService>();
    final totals = _progress.practiceTotals();
    final everything = totals.values.fold(0, (a, b) => a + b);
    if (everything == 0 &&
        storage.getString(StorageKeys.placementLevel) == null) {
      return (_placement, 'Empieza por saber tu nivel.');
    }
    final pool = [for (final (_, list) in _groups) ...list];
    pool.sort((a, b) => totals[a.kind]!.compareTo(totals[b.kind]!));
    final pick = pool.first;
    return (
      pick,
      totals[pick.kind] == 0
          ? 'Aún no lo has probado.'
          : 'Es lo que menos has practicado.'
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final due = _progress.dueCards().length;
    final (pick, reason) = _recommend(due);
    final done = _progress.practiceToday();
    final goal = _progress.dailyGoal;

    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Insets.xxxl),
          children: [
            const PageHeader(
              title: 'Practicar',
              subtitle: 'Gratis y sin conexión',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Insets.page, Insets.lg, Insets.page, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GoalLine(done: done, goal: goal),
                  const SizedBox(height: Insets.lg),
                  PassCard(
                    accent: true,
                    main: Row(
                      children: [
                        TopicBadge(icon: pick.icon, tone: p.gold, size: 48),
                        const SizedBox(width: Insets.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('RECOMENDADO AHORA',
                                  style: AppTheme.eyebrow(context)),
                              const SizedBox(height: Insets.xs),
                              Text(pick.title,
                                  style: context.texts.headlineSmall),
                              const SizedBox(height: 2),
                              Text(reason, style: context.texts.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                    stub: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: ElevatedButton(
                        onPressed: () => _open(pick.route),
                        child: const Text('Empezar'),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: Motion.base)
                      .moveY(begin: 10, end: 0, curve: Curves.easeOutCubic),
                  for (final (i, (title, activities)) in _groups.indexed) ...[
                    const SizedBox(height: Insets.xl),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: Insets.xs, bottom: Insets.sm),
                      child: Text(title.toUpperCase(),
                          style: AppTheme.eyebrow(context)),
                    ),
                    RowGroup(
                      indent: 64,
                      children: [
                        for (final a in activities)
                          ListRow(
                            leading: TopicBadge(
                                icon: a.icon, tone: p.textSecondary, size: 36),
                            title: a.title,
                            detail: _detail(a, due),
                            onTap: () => _open(a.route),
                          ),
                      ],
                    ).animate().fadeIn(
                        delay: Motion.stagger(i + 2), duration: Motion.base),
                  ],
                  const SizedBox(height: Insets.xl),
                  RowGroup(
                    indent: 64,
                    children: [
                      ListRow(
                        leading: TopicBadge(
                            icon: _placement.icon,
                            tone: p.textSecondary,
                            size: 36),
                        title: _placement.title,
                        detail: _detail(_placement, due),
                        onTap: () => _open(_placement.route),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's goal as one thin line: enough to know where you stand.
class _GoalLine extends StatelessWidget {
  final int done;
  final int goal;
  const _GoalLine({required this.done, required this.goal});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final met = done >= goal;
    return Semantics(
      label: 'Meta de hoy: $done de $goal ejercicios',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Text(met ? 'Meta de hoy cumplida' : 'Meta de hoy',
                style: context.texts.labelLarge),
            const SizedBox(width: Insets.md),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: LinearProgressIndicator(
                  value: (done / goal).clamp(0, 1).toDouble(),
                  minHeight: 6,
                  color: met ? p.good : p.gold,
                  backgroundColor: p.surfaceAlt,
                ),
              ),
            ),
            const SizedBox(width: Insets.md),
            Text('$done/$goal', style: context.texts.labelLarge),
          ],
        ),
      ),
    );
  }
}
