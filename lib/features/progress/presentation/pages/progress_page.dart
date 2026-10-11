import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/core/widgets/charts.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  final _progress = getIt<ProgressRepository>();
  final _words = getIt<WordRepository>();

  bool _showTable = false;
  bool _showAllWeak = false;

  static const _weekdayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final stats = _progress.stats();
    final hasData = stats.totalAttempts > 0;

    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: p.gold,
          backgroundColor: p.surface,
          onRefresh: () async => setState(() {}),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.page, Insets.xl, Insets.page, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Progreso', style: context.texts.headlineLarge),
                      const SizedBox(height: Insets.xs),
                      Text(
                        hasData
                            ? '${stats.totalAttempts} prácticas registradas'
                            : 'Tu historial aparecerá aquí',
                        style: context.texts.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              if (!hasData)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.insights_outlined,
                    title: 'Aún sin datos',
                    message:
                        'Practica la palabra del día o haz un quiz y volverás '
                        'aquí a ver tu racha, tu precisión y tus repasos.',
                    actionLabel: 'Practicar ahora',
                    onAction: () => context.go('/home'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.page, Insets.xl, Insets.page, Insets.xxxl),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Headline numbers ──────────────────────────────
                      // Four single values with no shape to show: stat tiles,
                      // not charts.
                      Row(
                        children: [
                          Expanded(
                            child: StatTile(
                              value: '${stats.currentStreak}',
                              unit: 'd',
                              label: 'Racha actual',
                              icon: Icons.local_fire_department_rounded,
                              tone: p.terracotta,
                            ),
                          ),
                          const SizedBox(width: Insets.md),
                          Expanded(
                            child: StatTile(
                              value: '${(stats.averageScore * 100).round()}',
                              unit: '%',
                              label: 'Precisión media',
                              icon: Icons.track_changes_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.md),
                      Row(
                        children: [
                          Expanded(
                            child: StatTile(
                              value: '${stats.mastered}',
                              label: 'Palabras dominadas',
                              icon: Icons.workspace_premium_rounded,
                              tone: p.good,
                            ),
                          ),
                          const SizedBox(width: Insets.md),
                          Expanded(
                            child: StatTile(
                              value: '${stats.dueToday}',
                              label: 'Repasos para hoy',
                              icon: Icons.event_repeat_rounded,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: Insets.xxl),

                      // ── Weekly activity ───────────────────────────────
                      _ChartCard(
                        eyebrow: 'Últimos 7 días',
                        title: 'Prácticas por día',
                        child: WeeklyBars(points: _weeklyPoints()),
                      ).animate().fadeIn(duration: Motion.base),

                      const SizedBox(height: Insets.lg),

                      // ── Accuracy trend ────────────────────────────────
                      _ChartCard(
                        eyebrow: 'Últimas 2 semanas',
                        title: 'Precisión por día',
                        subtitle:
                            'Arrastra sobre la línea para ver un día concreto. '
                            'Los días sin práctica no se dibujan.',
                        child: TrendLine(points: _trendPoints()),
                      ).animate().fadeIn(delay: Motion.stagger(2)),

                      const SizedBox(height: Insets.lg),

                      // ── Practice by category ──────────────────────────
                      _ChartCard(
                        eyebrow: 'Reparto',
                        title: 'Prácticas por categoría',
                        child: RankedBars(rows: _categoryPoints()),
                      ).animate().fadeIn(delay: Motion.stagger(4)),

                      const SizedBox(height: Insets.lg),

                      // ── What needs work ───────────────────────────────
                      _WeakWords(
                        entries: _weakWords(),
                        showTable: _showTable,
                        showAll: _showAllWeak,
                        onToggleShowAll: () =>
                            setState(() => _showAllWeak = !_showAllWeak),
                        onToggleTable: () =>
                            setState(() => _showTable = !_showTable),
                      ).animate().fadeIn(delay: Motion.stagger(5)),

                      const SizedBox(height: Insets.lg),

                      _MilestoneCard(
                        mastered: stats.mastered,
                        corpusSize: _words.all.length,
                        longestStreak: stats.longestStreak,
                        favorites: stats.favoriteCount,
                      ).animate().fadeIn(delay: Motion.stagger(6)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<ChartPoint> _weeklyPoints() {
    final counts = _progress.dailyCounts(days: 7);
    final todayKey = ProgressRepository.dayKey(DateTime.now());
    return [
      for (final entry in counts)
        ChartPoint(
          label: _weekdayLabels[entry.day.weekday - 1],
          value: entry.count.toDouble(),
          highlight: ProgressRepository.dayKey(entry.day) == todayKey,
        ),
    ];
  }

  List<ChartPoint> _trendPoints() {
    final scores = _progress.dailyScores(days: 14);
    return [
      for (final entry in scores)
        ChartPoint(
          label: '${entry.day.day}/${entry.day.month}',
          value: entry.score,
        ),
    ];
  }

  List<ChartPoint> _categoryPoints() {
    final counts = <WordCategory, int>{};
    for (final entry in _progress.attemptsByWord().entries) {
      final word = _words.byId(entry.key);
      if (word == null) continue;
      counts[word.category] = (counts[word.category] ?? 0) + entry.value;
    }
    return [
      for (final entry in counts.entries)
        ChartPoint(label: entry.key.labelEs, value: entry.value.toDouble()),
    ];
  }

  /// Words whose mean score is below the "in progress" threshold, weakest
  /// first — the actionable end of the data.
  List<({Word word, double score})> _weakWords() {
    final averages = _progress.averageByWord();
    final entries = <({Word word, double score})>[];
    for (final entry in averages.entries) {
      if (entry.value >= 0.75) continue;
      final word = _words.byId(entry.key);
      if (word == null) continue;
      entries.add((word: word, score: entry.value));
    }
    entries.sort((a, b) => a.score.compareTo(b.score));
    return entries;
  }
}

/// A chart and its title in one card — the title names the single series, so
/// none of these charts needs a legend box.
class _ChartCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget child;

  const _ChartCard({
    required this.eyebrow,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(Insets.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow.toUpperCase(), style: AppTheme.eyebrow(context)),
          const SizedBox(height: Insets.xs),
          Text(title, style: context.texts.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: Insets.xs),
            Text(subtitle!, style: context.texts.bodySmall),
          ],
          const SizedBox(height: Insets.xl),
          child,
        ],
      ),
    );
  }
}

class _WeakWords extends StatelessWidget {
  static const _collapsedCount = 6;

  final List<({Word word, double score})> all;
  final bool showTable;
  final VoidCallback onToggleTable;
  final bool showAll;
  final VoidCallback onToggleShowAll;

  const _WeakWords({
    required List<({Word word, double score})> entries,
    required this.showTable,
    required this.onToggleTable,
    required this.showAll,
    required this.onToggleShowAll,
  }) : all = entries;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hidden = all.length - _collapsedCount;
    final entries = showAll ? all : all.take(_collapsedCount).toList();

    if (entries.isEmpty) {
      return InfoNotice(
        icon: Icons.verified_rounded,
        iconColor: p.good,
        message: 'Ninguna palabra por debajo del 75 %. Excelente trabajo.',
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(Insets.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PARA REFORZAR', style: AppTheme.eyebrow(context)),
                    const SizedBox(height: Insets.xs),
                    Text('Tus puntos débiles', style: context.texts.titleLarge),
                  ],
                ),
              ),
              // The table view: the same numbers without relying on the chart.
              IconButton(
                tooltip: showTable ? 'Ver medidores' : 'Ver tabla',
                icon: Icon(
                  showTable
                      ? Icons.bar_chart_rounded
                      : Icons.table_rows_outlined,
                  size: 20,
                ),
                onPressed: onToggleTable,
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          if (showTable)
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: IntrinsicColumnWidth(),
              },
              children: [
                TableRow(
                  children: [
                    _cell(context, 'Palabra', header: true),
                    _cell(context, 'Significado', header: true),
                    _cell(context, 'Media', header: true, right: true),
                  ],
                ),
                for (final entry in entries)
                  TableRow(
                    children: [
                      _cell(context, entry.word.french),
                      _cell(context, entry.word.translationEs),
                      _cell(context, '${(entry.score * 100).round()}%',
                          right: true),
                    ],
                  ),
              ],
            )
          else
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const SizedBox(height: Insets.lg),
              InkWell(
                onTap: () => context.push('/word/${entries[i].word.id}'),
                borderRadius: BorderRadius.circular(Radii.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(entries[i].word.french,
                              style: context.texts.titleMedium),
                        ),
                        StatusChip(score: entries[i].score),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    MeterRow(
                      label: entries[i].word.translationEs,
                      value: entries[i].score,
                      tone: p.statusFor(entries[i].score),
                    ),
                  ],
                ),
              ),
            ],
          if (hidden > 0) ...[
            const SizedBox(height: Insets.md),
            TextButton(
              onPressed: onToggleShowAll,
              child: Text(showAll ? 'Ver menos' : 'Ver todas ($hidden más)'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String text,
      {bool header = false, bool right = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
      child: Text(
        text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: header
            ? context.texts.labelSmall
            : context.texts.bodySmall
                ?.copyWith(color: context.palette.textPrimary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final int mastered;
  final int corpusSize;
  final int longestStreak;
  final int favorites;

  const _MilestoneCard({
    required this.mastered,
    required this.corpusSize,
    required this.longestStreak,
    required this.favorites,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fraction = corpusSize == 0 ? 0.0 : mastered / corpusSize;

    return AppCard(
      padding: const EdgeInsets.all(Insets.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EL CATÁLOGO', style: AppTheme.eyebrow(context)),
          const SizedBox(height: Insets.xs),
          Text('$mastered de $corpusSize dominadas',
              style: context.texts.titleLarge),
          const SizedBox(height: Insets.lg),
          MeterRow(label: 'Avance del catálogo', value: fraction),
          const SizedBox(height: Insets.xl),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.emoji_events_outlined,
                  value: '$longestStreak d',
                  label: 'Mejor racha',
                  tone: p.terracotta,
                ),
              ),
              Expanded(
                child: _MiniStat(
                  icon: Icons.bookmark_outline_rounded,
                  value: '$favorites',
                  label: 'Guardadas',
                  tone: p.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color tone;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: tone),
        const SizedBox(width: Insets.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: context.texts.titleMedium),
            Text(label, style: context.texts.labelSmall),
          ],
        ),
      ],
    );
  }
}
