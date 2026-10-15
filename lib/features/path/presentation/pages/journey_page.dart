import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/path/data/path_repository.dart';
import 'package:french_pass/features/path/domain/journey.dart';
import 'package:french_pass/features/path/presentation/pages/lesson_page.dart';
import 'package:french_pass/features/premium/data/usage_service.dart';

/// The whole journey as a line of stations: where the learner started,
/// where they are, and what each stage lets them do. The current stage
/// opens up into its stops.
class JourneyPage extends StatefulWidget {
  const JourneyPage({super.key});

  @override
  State<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends State<JourneyPage> {
  final _path = getIt<PathRepository>();

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final current = _path.currentStage;
    final premium =
        getIt.isRegistered<UsageService>() && getIt<UsageService>().isPremium;
    final left = PathRepository.freeStopsPerDay - _path.newToday();
    final mistakes = _path.mistakes.length;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: Insets.xxxl),
            children: [
              const AppTopBar(title: 'Tu viaje'),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.page, Insets.sm, Insets.page, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      premium
                          ? 'Premium: avanza tantas paradas como quieras.'
                          : left > 0
                              ? 'Hoy puedes abrir $left '
                                  '${left == 1 ? 'parada nueva' : 'paradas nuevas'}.'
                              : 'Ya abriste tus paradas de hoy. Repasar '
                                  'siempre es libre.',
                      style: context.texts.bodyMedium,
                    ),
                    const SizedBox(height: Insets.lg),
                    RowGroup(
                      indent: 64,
                      children: [
                        ListRow(
                          leading: _Badge(
                              icon: Icons.healing_rounded, tone: p.terracotta),
                          title: 'Tus errores',
                          detail: mistakes == 0
                              ? 'Lo que falles aparecerá aquí'
                              : '$mistakes por repasar',
                          trailing: premium
                              ? null
                              : Pill(
                                  label: 'Premium', tone: p.gold, dense: true),
                          onTap: () =>
                              _open('/path/stop/${LessonPage.mistakesId}'),
                        ),
                        ListRow(
                          leading: _Badge(
                              icon: Icons.school_rounded,
                              tone: p.textSecondary),
                          title: '¿Ya sabes francés?',
                          detail: 'La prueba de nivel te coloca en tu etapa',
                          onTap: () => _open('/practice/placement'),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.xl),
                    for (final stage in Stage.values)
                      _StageStation(
                        stage: stage,
                        path: _path,
                        current: stage == current,
                        last: stage == Stage.values.last,
                        onOpen: (stop) => _open('/path/stop/${stop.id}'),
                      ).animate().fadeIn(
                          delay: Motion.stagger(stage.index),
                          duration: Motion.base),
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

class _Badge extends StatelessWidget {
  final IconData icon;
  final Color tone;
  const _Badge({required this.icon, required this.tone});

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 18, color: tone),
      );
}

/// One stage on the line: a node, its name in French, what it lets you do,
/// and, for the stage you are in, its stops.
class _StageStation extends StatelessWidget {
  final Stage stage;
  final PathRepository path;
  final bool current;
  final bool last;
  final ValueChanged<PathStop> onOpen;

  const _StageStation({
    required this.stage,
    required this.path,
    required this.current,
    required this.last,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final progress = path.progressIn(stage);
    final passed = progress >= 1;
    final built = path.builtStages.contains(stage);
    final nodeColor = passed
        ? p.good
        : current
            ? p.gold
            : p.surfaceAlt;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: current ? 22 : 16,
                  height: current ? 22 : 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: nodeColor,
                    border: current
                        ? Border.all(color: p.goldBright, width: 3)
                        : null,
                  ),
                  child: passed
                      ? Icon(Icons.check_rounded, size: 12, color: p.bg)
                      : null,
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: passed ? p.good.withValues(alpha: 0.5) : p.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Insets.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(stage.nameFr,
                            style: AppTheme.french(context,
                                    size: current ? 24 : 19)
                                .copyWith(
                                    color: current || passed
                                        ? p.textPrimary
                                        : p.textSecondary)),
                      ),
                      const SizedBox(width: Insets.sm),
                      if (stage.cefr != null)
                        Pill(
                            label: stage.cefr!,
                            tone: p.textSecondary,
                            dense: true),
                    ],
                  ),
                  Text(
                    '${stage.nameEs}${built ? '' : ' · próximamente'}',
                    style: context.texts.labelLarge
                        ?.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(stage.canDoEs, style: context.texts.bodySmall),
                  if (current && built) ...[
                    const SizedBox(height: Insets.md),
                    _StopList(stage: stage, path: path, onOpen: onOpen),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The stops of a stage, grouped by week.
class _StopList extends StatelessWidget {
  final Stage stage;
  final PathRepository path;
  final ValueChanged<PathStop> onOpen;

  const _StopList({
    required this.stage,
    required this.path,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final stops = path.stopsIn(stage);
    final weeks = {for (final s in stops) s.week}.toList()..sort();
    final next = path.next;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final week in weeks) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: Text('SEMANA $week', style: AppTheme.eyebrow(context)),
          ),
          RowGroup(
            indent: 60,
            children: [
              for (final (i, stop)
                  in stops.where((s) => s.week == week).indexed)
                ListRow(
                  enabled: path.isOpen(stop),
                  leading: _StopNode(
                    number: i + 1,
                    kind: stop.kind,
                    done: path.isDone(stop),
                    next: stop.id == next?.id,
                  ),
                  title: stop.titleEs,
                  detail: switch (stop.kind) {
                    StopKind.lesson => stop.goalEs,
                    StopKind.review => 'Repaso · ${stop.goalEs}',
                    StopKind.checkpoint => 'Reto · ${stop.goalEs}',
                  },
                  trailing: path.isOpen(stop)
                      ? null
                      : Icon(Icons.lock_outline_rounded,
                          size: 18, color: p.textMuted),
                  onTap: () => onOpen(stop),
                ),
            ],
          ),
          const SizedBox(height: Insets.md),
        ],
      ],
    );
  }
}

class _StopNode extends StatelessWidget {
  final int number;
  final StopKind kind;
  final bool done;
  final bool next;

  const _StopNode({
    required this.number,
    required this.kind,
    required this.done,
    required this.next,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bg = done
        ? p.good.withValues(alpha: 0.16)
        : next
            ? p.gold
            : p.surfaceAlt;
    final fg = done
        ? p.good
        : next
            ? p.onGold
            : p.textSecondary;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: done
          ? Icon(Icons.check_rounded, size: 18, color: fg)
          : switch (kind) {
              StopKind.review =>
                Icon(Icons.replay_rounded, size: 17, color: fg),
              StopKind.checkpoint =>
                Icon(Icons.flag_rounded, size: 17, color: fg),
              StopKind.lesson => Text('$number',
                  style: context.texts.labelLarge?.copyWith(color: fg)),
            },
    );
  }
}
