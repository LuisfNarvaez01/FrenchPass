import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:french_pass/core/di/injection.dart';
import 'package:french_pass/core/theme/app_theme.dart';
import 'package:french_pass/core/widgets/topic_icons.dart';
import 'package:french_pass/core/widgets/app_widgets.dart';
import 'package:french_pass/features/progress/data/progress_repository.dart';
import 'package:french_pass/features/progress/domain/entities/srs_card.dart';
import 'package:french_pass/features/progress/domain/word_state.dart';
import 'package:french_pass/features/word_of_the_day/data/word_repository.dart';
import 'package:french_pass/features/word_of_the_day/domain/entities/word.dart';

/// The sixteen topics grouped into four families, in the order a beginner
/// meets them.
const _families = <(String, List<WordCategory>)>[
  (
    'Vida diaria',
    [
      WordCategory.dailyLife,
      WordCategory.food,
      WordCategory.home,
      WordCategory.shopping,
      WordCategory.time,
      WordCategory.health,
    ],
  ),
  (
    'Personas y conversación',
    [WordCategory.conversation, WordCategory.people, WordCategory.emotions],
  ),
  (
    'Viajes, ocio y cultura',
    [
      WordCategory.travel,
      WordCategory.leisure,
      WordCategory.culture,
      WordCategory.nature,
    ],
  ),
  (
    'Trabajo y estudios',
    [
      WordCategory.business,
      WordCategory.education,
      WordCategory.technology,
    ],
  ),
];

/// How far the learner is into one topic.
typedef _Progress = ({int total, int started, int mastered});

/// The word catalogue, organised around the learner: what they have in
/// progress first, then every topic by family, each with how much of it
/// they know. Search and filters turn it into a word list.
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _words = getIt<WordRepository>();
  final _progress = getIt<ProgressRepository>();
  final _searchController = TextEditingController();

  String _query = '';
  CefrLevel? _level;
  WordState? _state;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _filtering =>
      _query.trim().isNotEmpty || _level != null || _state != null;

  List<Word> _filtered(Map<String, SrsCard> cards) {
    final base = _query.trim().isNotEmpty ? _words.search(_query) : _words.all;
    return [
      for (final w in base)
        if ((_level == null || w.level == _level) &&
            (_state == null || WordState.of(cards[w.id]) == _state))
          w,
    ];
  }

  _Progress _progressOf(WordCategory c, Map<String, SrsCard> cards) {
    var started = 0, mastered = 0;
    final words = _words.byCategory(c);
    for (final w in words) {
      final s = WordState.of(cards[w.id]);
      if (s != WordState.fresh) started++;
      if (s == WordState.mastered) mastered++;
    }
    return (total: words.length, started: started, mastered: mastered);
  }

  @override
  Widget build(BuildContext context) {
    final cards = _progress.loadCards();
    final favorites = _progress.loadFavorites();
    final progress = {
      for (final c in WordCategory.values) c: _progressOf(c, cards),
    };
    final known =
        cards.values.where((c) => WordState.of(c) != WordState.fresh).length;
    final inProgress = WordCategory.values
        .where((c) =>
            progress[c]!.started > 0 &&
            progress[c]!.mastered < progress[c]!.total)
        .toList()
      ..sort((a, b) => (progress[b]!.started / progress[b]!.total)
          .compareTo(progress[a]!.started / progress[a]!.total));
    final due = cards.values.where((c) => c.isDueToday).length;

    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Palabras',
                subtitle: known == 0
                    ? '${_words.all.length} palabras para empezar'
                    : '$known de ${_words.all.length} ya practicadas',
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.page, Insets.lg, Insets.page, 0),
                child: _SearchField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _filters()),
            if (_filtering)
              _WordSliverList(
                words: _filtered(cards),
                cards: cards,
                emptyMessage: _query.trim().isNotEmpty
                    ? 'Nada coincide con «$_query».'
                    : 'Ninguna palabra con estos filtros.',
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    Insets.page, Insets.lg, Insets.page, Insets.xxxl),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (favorites.isNotEmpty || due > 0) ...[
                      RowGroup(
                        indent: 64,
                        children: [
                          if (due > 0)
                            ListRow(
                              leading: TopicBadge(
                                icon: Icons.replay_rounded,
                                tone: context.palette.terracotta,
                                size: 36,
                              ),
                              title: 'Por repasar hoy',
                              detail: due == 1 ? '1 palabra' : '$due palabras',
                              onTap: () =>
                                  setState(() => _state = WordState.due),
                            ),
                          if (favorites.isNotEmpty)
                            ListRow(
                              leading: TopicBadge(
                                icon: Icons.bookmark_rounded,
                                tone: context.palette.gold,
                                size: 36,
                              ),
                              title: 'Guardadas',
                              detail: favorites.length == 1
                                  ? '1 palabra'
                                  : '${favorites.length} palabras',
                              onTap: () => _openFavorites(favorites),
                            ),
                        ],
                      ),
                      const SizedBox(height: Insets.xl),
                    ],
                    if (inProgress.isNotEmpty) ...[
                      const _FamilyHeader(title: 'Sigue con'),
                      RowGroup(
                        indent: 64,
                        children: [
                          for (final c in inProgress.take(3))
                            _CategoryRow(
                                category: c,
                                progress: progress[c]!,
                                featured: true),
                        ],
                      ),
                      const SizedBox(height: Insets.xl),
                    ],
                    for (final (i, (family, categories))
                        in _families.indexed) ...[
                      _FamilyHeader(title: family),
                      RowGroup(
                        indent: 64,
                        children: [
                          for (final c in categories)
                            _CategoryRow(category: c, progress: progress[c]!),
                        ],
                      )
                          .animate()
                          .fadeIn(
                              delay: Motion.stagger(i + 1),
                              duration: Motion.base)
                          .moveY(begin: 8, end: 0, curve: Curves.easeOutCubic),
                      const SizedBox(height: Insets.xl),
                    ],
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Level and state, one row each, scrolling sideways.
  Widget _filters() {
    Widget row(List<Widget> tags) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Insets.page),
          child: Row(
            children: [
              for (final (i, t) in tags.indexed) ...[
                if (i > 0) const SizedBox(width: Insets.sm),
                t,
              ],
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: Insets.md),
      child: Column(
        children: [
          row([
            ChoiceTag(
              label: 'Todos los niveles',
              selected: _level == null,
              onTap: () => setState(() => _level = null),
            ),
            for (final level in CefrLevel.values)
              ChoiceTag(
                label: level.label,
                selected: _level == level,
                onTap: () =>
                    setState(() => _level = _level == level ? null : level),
              ),
          ]),
          const SizedBox(height: Insets.sm),
          row([
            ChoiceTag(
              label: 'Cualquier estado',
              selected: _state == null,
              onTap: () => setState(() => _state = null),
            ),
            for (final state in WordState.values)
              ChoiceTag(
                label: state.labelEs,
                selected: _state == state,
                onTap: () =>
                    setState(() => _state = _state == state ? null : state),
              ),
          ]),
        ],
      ),
    );
  }

  void _openFavorites(Set<String> favorites) {
    final words = favorites.map(_words.byId).whereType<Word>().toList()
      ..sort((a, b) => a.french.compareTo(b.french));

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _WordListScaffold(
          title: 'Guardadas',
          subtitle: '${words.length} palabras',
          words: words,
        ),
      ),
    );
  }
}

class _FamilyHeader extends StatelessWidget {
  final String title;
  const _FamilyHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: Insets.xs, bottom: Insets.sm),
        child: Text(title.toUpperCase(), style: AppTheme.eyebrow(context)),
      );
}

/// Search, compact: it is a tool on this screen, not its headline.
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.pill),
      borderSide: BorderSide.none,
    );
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: context.texts.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Buscar en francés o español',
          hintStyle: context.texts.bodyMedium?.copyWith(color: p.textMuted),
          prefixIcon: Icon(Icons.search_rounded, color: p.textMuted, size: 20),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: p.textMuted),
                  tooltip: 'Limpiar',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          filled: true,
          fillColor: p.surface,
          contentPadding: EdgeInsets.zero,
          border: shape,
          enabledBorder: shape,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.pill),
            borderSide: BorderSide(color: p.borderStrong),
          ),
        ),
      ),
    );
  }
}

/// A topic with how much of it the learner knows: a thin bar while it is
/// in progress, a check once every word is mastered.
class _CategoryRow extends StatelessWidget {
  final WordCategory category;
  final _Progress progress;

  /// In the "Sigue con" list: the bar is gold, since it is the next step.
  final bool featured;

  const _CategoryRow({
    required this.category,
    required this.progress,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final done = progress.total > 0 && progress.mastered == progress.total;
    final started = progress.started > 0;
    return ListRow(
      leading: TopicBadge(
        icon: category.icon,
        tone: category.toneIn(p),
        size: 36,
      ),
      title: category.labelEs,
      detail: done
          ? 'Completada · ${progress.total} palabras'
          : started
              ? '${progress.started} de ${progress.total} practicadas'
              : '${progress.total} palabras',
      onTap: () => context.push('/category/${category.key}'),
      trailing: done
          ? Semantics(
              label: 'Completada',
              child: Icon(Icons.check_circle_rounded, color: p.good, size: 22),
            )
          : started
              ? SizedBox(
                  width: 44,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: LinearProgressIndicator(
                      value: progress.started / progress.total,
                      minHeight: 5,
                      color: featured ? p.gold : p.textSecondary,
                      backgroundColor: p.surfaceAlt,
                    ),
                  ),
                )
              : null,
    );
  }
}

/// One word in a list: French first, in its serif, then the meaning, the
/// level and where the learner stands with it.
class WordRow extends StatelessWidget {
  final Word word;
  final SrsCard? card;
  const WordRow({super.key, required this.word, this.card});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = WordState.of(card);
    final tone = switch (state) {
      WordState.fresh => null,
      WordState.learning => p.textSecondary,
      WordState.due => p.terracotta,
      WordState.mastered => p.good,
    };
    return InkWell(
      onTap: () => context.push('/word/${word.id}'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Insets.lg, Insets.md, Insets.md, Insets.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(word.french,
                        style: AppTheme.french(context, size: 17)),
                    const SizedBox(height: 2),
                    Text(
                      tone == null
                          ? word.translationEs
                          : '${word.translationEs} · ${state.labelEs}',
                      style: context.texts.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (tone != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: tone),
                ),
                const SizedBox(width: Insets.sm),
              ],
              Pill(label: word.level.label, tone: p.textSecondary, dense: true),
              const SizedBox(width: Insets.xs),
              Icon(Icons.chevron_right_rounded, size: 20, color: p.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Words as one grouped list, capped so a broad filter stays quick.
class _WordSliverList extends StatelessWidget {
  final List<Word> words;
  final Map<String, SrsCard> cards;
  final String emptyMessage;

  const _WordSliverList({
    required this.words,
    required this.cards,
    required this.emptyMessage,
  });

  static const _cap = 150;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Sin resultados',
          message: emptyMessage,
          mascot: true,
        ),
      );
    }
    final shown = words.take(_cap).toList();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
          Insets.page, Insets.lg, Insets.page, Insets.xxxl),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Padding(
            padding: const EdgeInsets.only(left: Insets.xs, bottom: Insets.sm),
            child: Text(
              words.length > _cap
                  ? 'Primeras $_cap de ${words.length} palabras'
                  : words.length == 1
                      ? '1 palabra'
                      : '${words.length} palabras',
              style: AppTheme.eyebrow(context),
            ),
          ),
          RowGroup(
            children: [
              for (final w in shown) WordRow(word: w, card: cards[w.id]),
            ],
          ),
        ]),
      ),
    );
  }
}

/// Full-screen list used for favourites.
class _WordListScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Word> words;

  const _WordListScaffold({
    required this.title,
    required this.subtitle,
    required this.words,
  });

  @override
  Widget build(BuildContext context) {
    final cards = getIt<ProgressRepository>().loadCards();
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              AppSliverBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: context.texts.titleLarge),
                    Text(subtitle, style: context.texts.labelSmall),
                  ],
                ),
              ),
              if (words.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.bookmark_border_rounded,
                    mascot: true,
                    title: 'Nada guardado aún',
                    message: 'Toca el marcador de una palabra para tenerla '
                        'a mano.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.page, Insets.sm, Insets.page, Insets.xxxl),
                  sliver: SliverToBoxAdapter(
                    child: RowGroup(
                      children: [
                        for (final w in words)
                          WordRow(word: w, card: cards[w.id]),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
